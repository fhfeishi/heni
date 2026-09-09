#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <cstdint>
#include <optional>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

std::optional<double> EncodableNumber(
    const flutter::EncodableValue& value) {
  if (const auto* number = std::get_if<double>(&value)) {
    return *number;
  }
  if (const auto* number = std::get_if<int32_t>(&value)) {
    return static_cast<double>(*number);
  }
  if (const auto* number = std::get_if<int64_t>(&value)) {
    return static_cast<double>(*number);
  }
  return std::nullopt;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterWindowChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_APP + 1) {
    return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
  }

  if (message == WM_SIZE) {
    NotifyMaximizedChanged(hwnd);
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::RegisterWindowChannel() {
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "heni/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
              result) {
        const auto& method = call.method_name();
        const HWND window = GetHandle();
        if (window == nullptr) {
          result->Error("window-unavailable", "The Heni window is unavailable.");
          return;
        }

        if (method == "minimize") {
          ShowWindow(window, SW_MINIMIZE);
          result->Success();
          return;
        }
        if (method == "toggleMaximize") {
          ShowWindow(window, IsZoomed(window) ? SW_RESTORE : SW_MAXIMIZE);
          result->Success();
          return;
        }
        if (method == "close") {
          PostMessage(window, WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        if (method == "beginDrag") {
          ReleaseCapture();
          SendMessage(window, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success();
          return;
        }
        if (method == "isMaximized") {
          result->Success(
              flutter::EncodableValue(IsZoomed(window) != FALSE));
          return;
        }
        if (method == "ensureClientWidth") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("invalid-width", "Missing resize arguments.");
            return;
          }
          const auto width_entry = arguments->find(
              flutter::EncodableValue("logicalWidth"));
          if (width_entry == arguments->end()) {
            result->Error("invalid-width", "Missing logicalWidth.");
            return;
          }
          const auto logical_width = EncodableNumber(width_entry->second);
          if (!logical_width.has_value() || *logical_width <= 0) {
            result->Error("invalid-width", "logicalWidth must be positive.");
            return;
          }

          const auto resize =
              EnsureClientWidth(static_cast<int>(*logical_width));
          flutter::EncodableMap response;
          response[flutter::EncodableValue("achievedLogicalWidth")] =
              flutter::EncodableValue(resize.achieved_logical_width);
          response[flutter::EncodableValue("reachedRequestedWidth")] =
              flutter::EncodableValue(resize.reached_requested_width);
          result->Success(flutter::EncodableValue(response));
          return;
        }

        result->NotImplemented();
      });
}

void FlutterWindow::NotifyMaximizedChanged(HWND window) {
  if (!window_channel_ || window == nullptr || IsIconic(window)) {
    return;
  }

  const bool maximized = IsZoomed(window) != FALSE;
  if (maximized == last_maximized_) {
    return;
  }
  last_maximized_ = maximized;
  window_channel_->InvokeMethod(
      "maximizedChanged",
      std::make_unique<flutter::EncodableValue>(maximized));
}
