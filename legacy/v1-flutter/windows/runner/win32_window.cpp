#include "win32_window.h"

#include <algorithm>
#include <cstdlib>
#include <dwmapi.h>
#include <flutter_windows.h>
#include <filesystem>
#include <fstream>
#include <optional>
#include <windowsx.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWA_COLOR_NONE
#define DWMWA_COLOR_NONE 0xFFFFFFFE
#endif

constexpr DWORD kDwmWindowCornerPreferenceRound = 2;
constexpr COLORREF kHeniWindowBackground = RGB(18, 15, 25);

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr int kMinimumLogicalClientWidth = 900;
constexpr int kMinimumLogicalClientHeight = 620;
constexpr int kResizeBorderLogical = 8;
constexpr DWORD kHeniWindowStyle =
    WS_POPUP | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU;
constexpr UINT kEnsureMinimumSizeMessage = WM_APP + 1;

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

struct PersistedWindowState {
  int left = 10;
  int top = 10;
  int width = 1280;
  int height = 720;
  UINT dpi = 0;
  bool maximized = false;
};

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

std::filesystem::path GetWindowStatePath() {
  wchar_t* appdata = nullptr;
  size_t length = 0;
  if (_wdupenv_s(&appdata, &length, L"APPDATA") == 0 && appdata != nullptr) {
    const auto path =
        std::filesystem::path(appdata) / L"Heni" / L"window-state.ini";
    free(appdata);
    return path;
  }
  return std::filesystem::temp_directory_path() / L"Heni-window-state.ini";
}

std::optional<PersistedWindowState> LoadWindowState() {
  const auto path = GetWindowStatePath();
  std::ifstream stream(path);
  if (!stream.is_open()) {
    return std::nullopt;
  }

  PersistedWindowState state;
  std::string line;
  try {
    while (std::getline(stream, line)) {
      const auto separator = line.find('=');
      if (separator == std::string::npos) {
        continue;
      }
      const auto key = line.substr(0, separator);
      const auto value = line.substr(separator + 1);
      if (key == "left") {
        state.left = std::stoi(value);
      } else if (key == "top") {
        state.top = std::stoi(value);
      } else if (key == "width") {
        state.width = std::stoi(value);
      } else if (key == "height") {
        state.height = std::stoi(value);
      } else if (key == "dpi") {
        state.dpi = static_cast<UINT>(std::stoul(value));
      } else if (key == "maximized") {
        state.maximized = value == "1";
      }
    }
  } catch (...) {
    return std::nullopt;
  }

  if (state.width <= 0 || state.height <= 0 ||
      (state.dpi != 0 && (state.dpi < 48 || state.dpi > 960))) {
    return std::nullopt;
  }

  return state;
}

void SaveWindowState(HWND hwnd) {
  if (hwnd == nullptr || IsIconic(hwnd)) {
    return;
  }

  WINDOWPLACEMENT placement;
  placement.length = sizeof(WINDOWPLACEMENT);
  if (!GetWindowPlacement(hwnd, &placement)) {
    return;
  }

  RECT rect = placement.rcNormalPosition;
  if (rect.right <= rect.left || rect.bottom <= rect.top) {
    return;
  }

  const auto path = GetWindowStatePath();
  std::error_code error;
  std::filesystem::create_directories(path.parent_path(), error);

  std::ofstream stream(path, std::ios::trunc);
  if (!stream.is_open()) {
    return;
  }

  stream << "left=" << rect.left << '\n';
  stream << "top=" << rect.top << '\n';
  stream << "width=" << (rect.right - rect.left) << '\n';
  stream << "height=" << (rect.bottom - rect.top) << '\n';
  stream << "dpi=" << GetDpiForWindow(hwnd) << '\n';
  stream << "maximized="
         << (placement.showCmd == SW_SHOWMAXIMIZED ? 1 : 0) << '\n';
}

void EnsureMinimumClientSize(HWND window) {
  if (window == nullptr) {
    return;
  }

  const UINT dpi = GetDpiForWindow(window);
  if (IsZoomed(window)) {
    return;
  }

  RECT client_rect{};
  RECT window_rect{};
  if (!GetClientRect(window, &client_rect) ||
      !GetWindowRect(window, &window_rect)) {
    return;
  }

  const int client_width = client_rect.right - client_rect.left;
  const int client_height = client_rect.bottom - client_rect.top;
  const int window_width = window_rect.right - window_rect.left;
  const int window_height = window_rect.bottom - window_rect.top;
  const int non_client_width = window_width - client_width;
  const int non_client_height = window_height - client_height;

  const HMONITOR monitor =
      MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }

  const int work_width =
      monitor_info.rcWork.right - monitor_info.rcWork.left;
  const int work_height =
      monitor_info.rcWork.bottom - monitor_info.rcWork.top;
  const int minimum_width = std::min(
      Scale(kMinimumLogicalClientWidth, static_cast<double>(dpi) / 96.0) +
          non_client_width,
      work_width);
  const int minimum_height = std::min(
      Scale(kMinimumLogicalClientHeight, static_cast<double>(dpi) / 96.0) +
          non_client_height,
      work_height);
  const int target_width =
      std::clamp(window_width, minimum_width, work_width);
  const int target_height =
      std::clamp(window_height, minimum_height, work_height);
  const int target_left =
      std::clamp(static_cast<int>(window_rect.left),
                 static_cast<int>(monitor_info.rcWork.left),
                 static_cast<int>(monitor_info.rcWork.right) - target_width);
  const int target_top =
      std::clamp(static_cast<int>(window_rect.top),
                 static_cast<int>(monitor_info.rcWork.top),
                 static_cast<int>(monitor_info.rcWork.bottom) - target_height);

  if (target_left == window_rect.left && target_top == window_rect.top &&
      target_width == window_width && target_height == window_height) {
    return;
  }

  SetWindowPos(window, nullptr, target_left, target_top, target_width,
               target_height, SWP_NOZORDER | SWP_NOACTIVATE);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    // Paint a deterministic dark fallback while Flutter is attaching or
    // resizing instead of leaving uninitialized host pixels at the corners.
    window_class.hbrBackground = CreateSolidBrush(kHeniWindowBackground);
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  auto restored_state = LoadWindowState();
  int left = origin.x;
  int top = origin.y;
  int width = size.width;
  int height = size.height;
  HMONITOR monitor = nullptr;
  bool restored_monitor_missing = false;

  if (restored_state.has_value()) {
    left = restored_state->left;
    top = restored_state->top;
    const RECT restored_rect = {
        left, top, left + restored_state->width,
        top + restored_state->height};
    monitor = MonitorFromRect(&restored_rect, MONITOR_DEFAULTTONULL);
    if (monitor == nullptr) {
      restored_monitor_missing = true;
      monitor = MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
    }
    const UINT target_dpi = FlutterDesktopGetDpiForMonitor(monitor);
    const UINT source_dpi =
        restored_state->dpi == 0 ? target_dpi : restored_state->dpi;
    width = MulDiv(restored_state->width, target_dpi, source_dpi);
    height = MulDiv(restored_state->height, target_dpi, source_dpi);
    initial_show_command_ =
        restored_state->maximized ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL;
  } else {
    const POINT target_point = {static_cast<LONG>(origin.x),
                                static_cast<LONG>(origin.y)};
    monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
    const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
    const double scale_factor = dpi / 96.0;
    left = Scale(origin.x, scale_factor);
    top = Scale(origin.y, scale_factor);
    width = Scale(size.width, scale_factor);
    height = Scale(size.height, scale_factor);
    initial_show_command_ = SW_SHOWNORMAL;
  }

  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  if (monitor != nullptr && GetMonitorInfo(monitor, &monitor_info)) {
    const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
    const int work_width =
        monitor_info.rcWork.right - monitor_info.rcWork.left;
    const int work_height =
        monitor_info.rcWork.bottom - monitor_info.rcWork.top;
    const int minimum_width = std::min(
        Scale(kMinimumLogicalClientWidth, static_cast<double>(dpi) / 96.0),
        work_width);
    const int minimum_height = std::min(
        Scale(kMinimumLogicalClientHeight, static_cast<double>(dpi) / 96.0),
        work_height);
    width = std::clamp(width, minimum_width, work_width);
    height = std::clamp(height, minimum_height, work_height);

    if (restored_monitor_missing) {
      left = monitor_info.rcWork.left + (work_width - width) / 2;
      top = monitor_info.rcWork.top + (work_height - height) / 2;
    } else {
      left = std::clamp(left, static_cast<int>(monitor_info.rcWork.left),
                        static_cast<int>(monitor_info.rcWork.right) - width);
      top = std::clamp(top, static_cast<int>(monitor_info.rcWork.top),
                       static_cast<int>(monitor_info.rcWork.bottom) - height);
    }
  }

  HWND window = CreateWindow(
      window_class, title.c_str(), kHeniWindowStyle,
      left, top, width, height,
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);
  EnsureMinimumClientSize(window);

  return OnCreate();
}

bool Win32Window::Show() {
  const bool was_visible =
      ShowWindow(window_handle_, initial_show_command_) != FALSE;
  PostMessage(window_handle_, kEnsureMinimumSizeMessage, 0, 0);
  return was_visible;
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      SaveWindowState(hwnd);
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_NCCALCSIZE:
      if (wparam == TRUE) {
        if (IsZoomed(hwnd)) {
          auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
          const HMONITOR monitor =
              MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
          MONITORINFO monitor_info{sizeof(MONITORINFO)};
          if (GetMonitorInfo(monitor, &monitor_info)) {
            params->rgrc[0] = monitor_info.rcWork;
          }
        }
        return 0;
      }
      break;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);
      EnsureMinimumClientSize(hwnd);

      return 0;
    }
    case kEnsureMinimumSizeMessage:
      EnsureMinimumClientSize(hwnd);
      return 0;
    case WM_GETMINMAXINFO: {
      auto min_max_info = reinterpret_cast<MINMAXINFO*>(lparam);
      const UINT dpi = GetDpiForWindow(hwnd);
      const double scale_factor = dpi / 96.0;
      const HMONITOR monitor =
          MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      MONITORINFO monitor_info{sizeof(MONITORINFO)};
      if (GetMonitorInfo(monitor, &monitor_info)) {
        const LONG work_width =
            monitor_info.rcWork.right - monitor_info.rcWork.left;
        const LONG work_height =
            monitor_info.rcWork.bottom - monitor_info.rcWork.top;
        min_max_info->ptMinTrackSize.x = std::min(
            Scale(kMinimumLogicalClientWidth, scale_factor),
            static_cast<int>(work_width));
        min_max_info->ptMinTrackSize.y = std::min(
            Scale(kMinimumLogicalClientHeight, scale_factor),
            static_cast<int>(work_height));
        min_max_info->ptMaxTrackSize.x = work_width;
        min_max_info->ptMaxTrackSize.y = work_height;
      } else {
        min_max_info->ptMinTrackSize.x =
            Scale(kMinimumLogicalClientWidth, scale_factor);
        min_max_info->ptMinTrackSize.y =
            Scale(kMinimumLogicalClientHeight, scale_factor);
      }
      return 0;
    }
    case WM_NCHITTEST: {
      if (IsZoomed(hwnd)) {
        return HTCLIENT;
      }

      RECT window_rect;
      if (!GetWindowRect(hwnd, &window_rect)) {
        return HTCLIENT;
      }

      const UINT dpi = GetDpiForWindow(hwnd);
      const int border =
          Scale(kResizeBorderLogical, static_cast<double>(dpi) / 96.0);
      const int x = GET_X_LPARAM(lparam);
      const int y = GET_Y_LPARAM(lparam);
      const bool left = x >= window_rect.left && x < window_rect.left + border;
      const bool right =
          x < window_rect.right && x >= window_rect.right - border;
      const bool top = y >= window_rect.top && y < window_rect.top + border;
      const bool bottom =
          y < window_rect.bottom && y >= window_rect.bottom - border;

      if (top && left) {
        return HTTOPLEFT;
      }
      if (top && right) {
        return HTTOPRIGHT;
      }
      if (bottom && left) {
        return HTBOTTOMLEFT;
      }
      if (bottom && right) {
        return HTBOTTOMRIGHT;
      }
      if (left) {
        return HTLEFT;
      }
      if (right) {
        return HTRIGHT;
      }
      if (top) {
        return HTTOP;
      }
      if (bottom) {
        return HTBOTTOM;
      }
      return HTCLIENT;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_EXITSIZEMOVE:
      SaveWindowState(hwnd);
      return 0;

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

Win32Window::ClientWidthResult Win32Window::EnsureClientWidth(
    int logical_width) {
  ClientWidthResult result;
  if (window_handle_ == nullptr || logical_width <= 0) {
    return result;
  }

  const UINT dpi = GetDpiForWindow(window_handle_);
  const double scale = static_cast<double>(dpi) / 96.0;
  auto read_result = [&]() {
    RECT client{};
    if (!GetClientRect(window_handle_, &client)) {
      return ClientWidthResult{};
    }
    const double achieved =
        static_cast<double>(client.right - client.left) / scale;
    return ClientWidthResult{
        achieved, achieved + 0.5 >= static_cast<double>(logical_width)};
  };

  ClientWidthResult current = read_result();
  if (current.reached_requested_width || IsZoomed(window_handle_)) {
    return current;
  }

  RECT window_rect{};
  RECT client_rect{};
  if (!GetWindowRect(window_handle_, &window_rect) ||
      !GetClientRect(window_handle_, &client_rect)) {
    return current;
  }
  const HMONITOR monitor =
      MonitorFromWindow(window_handle_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return current;
  }

  const int current_window_width = window_rect.right - window_rect.left;
  const int current_window_height = window_rect.bottom - window_rect.top;
  const int current_client_width = client_rect.right - client_rect.left;
  const int non_client_width = current_window_width - current_client_width;
  const int work_left = static_cast<int>(monitor_info.rcWork.left);
  const int work_top = static_cast<int>(monitor_info.rcWork.top);
  const int work_right = static_cast<int>(monitor_info.rcWork.right);
  const int work_bottom = static_cast<int>(monitor_info.rcWork.bottom);
  const int work_width = work_right - work_left;
  const int requested_window_width =
      Scale(logical_width, scale) + non_client_width;
  const int target_width = std::min(requested_window_width, work_width);
  const int latest_left = work_right - target_width;
  const int target_left =
      std::clamp(static_cast<int>(window_rect.left), work_left, latest_left);
  const int work_height = work_bottom - work_top;
  const int target_height = std::min(current_window_height, work_height);
  const int latest_top = work_bottom - target_height;
  const int target_top =
      std::clamp(static_cast<int>(window_rect.top), work_top, latest_top);

  SetWindowPos(window_handle_, nullptr, target_left, target_top, target_width,
               target_height, SWP_NOZORDER | SWP_NOACTIVATE);
  return read_result();
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }

  // Let DWM own the top-level silhouette and shadow. Unsupported Windows
  // versions safely ignore the corner preference.
  const DWORD corner_preference = kDwmWindowCornerPreferenceRound;
  DwmSetWindowAttribute(window, DWMWA_WINDOW_CORNER_PREFERENCE,
                        &corner_preference, sizeof(corner_preference));

  // Flutter paints its own edge-to-edge shell. Suppressing the extra DWM
  // outline keeps the client area flush with the top-level window.
  const COLORREF border_color = DWMWA_COLOR_NONE;
  DwmSetWindowAttribute(window, DWMWA_BORDER_COLOR, &border_color,
                        sizeof(border_color));
}
