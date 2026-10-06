// EngineDriver.cpp — the Swift-facing driver for the vendored RMB engine.
//
// This replicates upstream's Application.cpp logic (worker thread →
// Native::Update + 1ms cursor poll → Mouse smoothing → NpadController →
// KeyboardManager → Native key posts, plus the 2.5s cursor-visibility
// re-assert) without its GLFW window or Dear ImGui UI: the Swift app is
// the interface, this file is the glue.

#include "rmb_engine.h"
#include "driver_hooks.h"

#include "native.h"
#include "Config.h"
#include "mouse.h"
#include "npad_controller.h"
#include "EventSystem.h"

#include <CoreGraphics/CoreGraphics.h>

#include <atomic>
#include <chrono>
#include <thread>

namespace {

std::atomic<bool> g_running{false};
std::atomic<bool> g_panning{false};

NpadController* g_controller = nullptr;
Mouse* g_mouse = nullptr;
std::jthread g_worker;

int g_pin_x = -1;
int g_pin_y = -1;
bool g_pin_valid = false;

int g_last_cursor_x = 0;
int g_last_cursor_y = 0;
double g_last_mouse_moved = 0.0;

double TotalRunningTime() {
    using Time = std::chrono::high_resolution_clock;
    using fmsec = std::chrono::duration<double, std::milli>;
    static auto starting_time = Time::now().time_since_epoch();
    auto now = Time::now().time_since_epoch();
    return std::chrono::duration_cast<fmsec>(now - starting_time).count();
}

// Upstream Application::UpdateMouseVisibility, verbatim behavior:
// show on movement, re-assert hide every 2.5s while the target is focused.
void UpdateMouseVisibility(double new_moved_time = 0.0) {
    constexpr double default_mouse_hide_timeout = 2500;

    if (new_moved_time > 0.0) {
        g_last_mouse_moved = new_moved_time;
        Native::GetInstance()->CursorHide(false);
        return;
    }

    double current_time = TotalRunningTime();
    if (current_time - g_last_mouse_moved >= default_mouse_hide_timeout) {
        Native::GetInstance()->CursorHide(
            Native::GetInstance()->IsMainWindowActive(Config::Current()->TARGET_NAME));
        g_last_mouse_moved = current_time;
    }
}

// Upstream Application::OnMouseMove.
void OnMouseMove(int x, int y) {
    if (g_panning) {
        if (g_mouse && g_pin_valid) {
            g_mouse->MouseMoved(x, y, g_pin_x, g_pin_y);
            Native::GetInstance()->SetMousePos(g_pin_x, g_pin_y);
        }
    } else {
        UpdateMouseVisibility(TotalRunningTime());
    }
}

// Upstream Application::OnHotkey (only fires if a hotkey was registered
// on the engine side; the Swift app normally owns the toggle hotkey).
void OnHotkey(HotkeyEvent& evt) {
    Config* config = Config::Current();
    if (config->TOGGLE_KEY < 0 || config->TOGGLE_MODIFIER < 0) {
        return;
    }
    if (evt.key == static_cast<uint32_t>(config->TOGGLE_KEY) &&
        evt.modifier == static_cast<uint32_t>(config->TOGGLE_MODIFIER)) {
        rmb_engine_toggle_panning();
    }
}

// Upstream Application::OnMouseButton (Windows-only focus dance dropped).
void OnMouseButton(MouseButtonEvent& evt) {
    if (!Config::Current()->BIND_MOUSE_BUTTON) {
        return;
    }
    int key = -1;
    switch (evt.key) {
    case MOUSE_LBUTTON: key = Config::Current()->LEFT_MOUSE_KEY; break;
    case MOUSE_RBUTTON: key = Config::Current()->RIGHT_MOUSE_KEY; break;
    case MOUSE_MBUTTON: key = Config::Current()->MIDDLE_MOUSE_KEY; break;
    }
    if (key >= 0 && g_controller) {
        g_controller->SetButton(static_cast<uint32_t>(key), evt.is_pressed ? 1 : 0);
    }
}

// Upstream Application::DetectMouseMove (1ms cursor poll).
void DetectMouseMove() {
    int x = 0;
    int y = 0;
    Native::GetInstance()->GetMousePos(&x, &y);

    if (x != g_last_cursor_x || y != g_last_cursor_y) {
        g_last_cursor_x = x;
        g_last_cursor_y = y;
        OnMouseMove(x, y);
    }

    if (Config::Current()->HIDE_MOUSE) {
        UpdateMouseVisibility();
    }
}

void WorkerLoop(std::stop_token stop_token) {
    while (!stop_token.stop_requested()) {
        Native::GetInstance()->Update();
        DetectMouseMove();
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
}

} // namespace

bool driver_is_panning() {
    return g_panning;
}

NpadController* driver_controller() {
    return g_controller;
}

extern "C" int rmb_engine_start(void) {
    if (g_running) {
        return 0;
    }

    static bool subscribed = false;
    if (!subscribed) {
        EventBus::Instance().subscribe(&OnHotkey);
        EventBus::Instance().subscribe(&OnMouseButton);
        subscribed = true;
    }

    (void)Config::Current(); // ensure a Config exists before threads read it
    Native::GetInstance();   // constructs AppKit + event tap + permission prompts

    if (!g_controller) {
        g_controller = new NpadController();
    }
    if (!g_mouse) {
        g_mouse = new Mouse();
    }

    g_last_mouse_moved = TotalRunningTime();
    g_running = true;
    g_worker = std::jthread([](std::stop_token st) { WorkerLoop(st); });
    return 0;
}

extern "C" void rmb_engine_stop(void) {
    if (!g_running) {
        return;
    }
    g_running = false;
    g_worker.request_stop();
    if (g_worker.joinable()) {
        g_worker.join();
    }
    g_panning = false;
    if (g_controller) {
        g_controller->ClearState();
    }
    Native::GetInstance()->CursorHide(false); // restore the cursor on quit
}

extern "C" void rmb_engine_reconfig(const RmbEngineConfig* c) {
    if (!c) {
        return;
    }
    // Mutate the live config in place (same as upstream's UI did) so the
    // worker/keyboard threads never observe a swapped pointer.
    Config* cfg = Config::Current();
    if (c->target_name) {
        cfg->TARGET_NAME = c->target_name;
    }
    for (int i = 0; i < 4; i++) {
        cfg->RIGHT_STICK_KEYS[i] = c->stick_keys[i];
    }
    cfg->LEFT_MOUSE_KEY = c->left_mouse_key;
    cfg->RIGHT_MOUSE_KEY = c->right_mouse_key;
    cfg->MIDDLE_MOUSE_KEY = c->middle_mouse_key;
    cfg->SENSITIVITY = c->sensitivity;
    cfg->DEADZONE = c->deadzone;
    cfg->RANGE = c->range;
    cfg->THRESHOLD = c->threshold;
    cfg->X_OFFSET = c->x_offset;
    cfg->Y_OFFSET = c->y_offset;
    cfg->HIDE_MOUSE = c->hide_mouse != 0;
    cfg->AUTO_FOCUS_EMU_WINDOW = c->auto_focus != 0;
    cfg->BIND_MOUSE_BUTTON = c->bind_mouse_button != 0;
    cfg->PERSISTANT_KEY_PRESS = c->persistent_key_press != 0;
    // The Swift app owns the toggle hotkey (Carbon ⌥⌘P).
    cfg->TOGGLE_KEY = -1;
    cfg->TOGGLE_MODIFIER = -1;
    if (g_controller) {
        g_controller->SetPersistentMode(cfg->PERSISTANT_KEY_PRESS);
    }
}

extern "C" void rmb_engine_set_pin(int x, int y) {
    g_pin_x = x;
    g_pin_y = y;
    g_pin_valid = !(x == -1 && y == -1);
}

extern "C" void rmb_engine_toggle_panning(void) {
    if (!g_running || !g_controller) {
        return;
    }
    if (!g_panning) {
        Config* config = Config::Current();
        // No point starting panning if the right-stick keys are not all set.
        for (int i = 0; i < 4; i++) {
            if (config->RIGHT_STICK_KEYS[i] < 0) {
                return;
            }
        }
        if (config->AUTO_FOCUS_EMU_WINDOW) {
            Native::GetInstance()->SetFocusOnWindow(config->TARGET_NAME);
        }
        if (!g_pin_valid) {
            // Upstream behavior: center of the main display.
            CGRect bounds = CGDisplayBounds(CGMainDisplayID());
            g_pin_x = static_cast<int>(bounds.origin.x + bounds.size.width / 2);
            g_pin_y = static_cast<int>(bounds.origin.y + bounds.size.height / 2);
            g_pin_valid = true;
        }
        Native::GetInstance()->SetMousePos(g_pin_x, g_pin_y);
        g_panning = true;
    } else {
        g_panning = false;
        g_controller->ClearState();
        UpdateMouseVisibility(TotalRunningTime()); // shows the cursor again
    }
}

extern "C" int rmb_engine_is_panning(void) {
    return g_panning ? 1 : 0;
}

extern "C" int rmb_engine_is_target_active(void) {
    return Native::GetInstance()->IsMainWindowActive(Config::Current()->TARGET_NAME) ? 1 : 0;
}

extern "C" void rmb_engine_cursor_hide(int hide) {
    Native::GetInstance()->CursorHide(hide != 0);
}

extern "C" int rmb_engine_cursor_self_test(void) {
    Native::GetInstance()->CursorHide(true);
    std::this_thread::sleep_for(std::chrono::milliseconds(400));
    Native::GetInstance()->CursorHide(false);
    return 0;
}
