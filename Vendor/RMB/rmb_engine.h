#ifndef RMB_ENGINE_H
#define RMB_ENGINE_H

/* C interface to the vendored RMB engine (original C++ approach:
 * Mouse smoothing → NpadController deadzone math → KeyboardManager
 * → Native key simulation), driven from the Swift UI layer. */

#ifdef __cplusplus
extern "C" {
#endif

typedef struct RmbEngineConfig {
    const char* target_name;      /* window/app name substring to match */
    int stick_keys[4];            /* 0=left, 1=right, 2=up, 3=down (CGKeyCode) */
    int left_mouse_key;           /* CGKeyCode, or -1 for unbound */
    int right_mouse_key;
    int middle_mouse_key;
    float sensitivity;            /* upstream scale; default 10 */
    float deadzone;               /* 0..1 radial deadzone */
    float range;                  /* ~0.95 */
    float threshold;              /* 0..1 axis press threshold */
    float x_offset;               /* -0.75..0.75 stick-axis bias */
    float y_offset;
    int hide_mouse;               /* bool: auto-hide cursor over target */
    int auto_focus;               /* bool: focus emulator on panning start */
    int bind_mouse_button;        /* bool: enable mouse-button bindings */
    int persistent_key_press;     /* bool: re-press keys every tick */
} RmbEngineConfig;

/* Lifecycle. start() also triggers the engine's own permission requests
 * (Accessibility + Input Monitoring + PostEvent). Returns 0 on success. */
int rmb_engine_start(void);
void rmb_engine_stop(void);

/* Push UI settings into the engine (mutates the live Config in place). */
void rmb_engine_reconfig(const RmbEngineConfig* config);

/* Toggle panning; call rmb_engine_set_pin() first for a custom pin point. */
void rmb_engine_toggle_panning(void);
int rmb_engine_is_panning(void);
int rmb_engine_is_target_active(void);

/* Pin point in CG global coordinates (origin top-left of main display).
 * Pass (-1, -1) to fall back to the screen center (upstream behavior). */
void rmb_engine_set_pin(int x, int y);

/* hide/show the system cursor through the engine's Native path. */
void rmb_engine_cursor_hide(int hide);

/* Self-test: hide → 400ms → show, returns 0 on completion. */
int rmb_engine_cursor_self_test(void);

#ifdef __cplusplus
}
#endif

#endif /* RMB_ENGINE_H */
