#pragma once

// Bridge used by the vendored engine (mouse.cpp) instead of upstream's
// GLFW/ImGui-bound Application class. Implemented by EngineDriver.cpp.

class NpadController;

bool driver_is_panning();
NpadController* driver_controller();
