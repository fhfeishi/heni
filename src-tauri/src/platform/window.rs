use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};

use serde::{Deserialize, Serialize};
use tauri::{LogicalSize, Manager, PhysicalPosition, PhysicalSize, State, WebviewWindow};

#[cfg(desktop)]
use tauri_plugin_window_state::{AppHandleExt, StateFlags};

const MAIN_MIN_WIDTH: f64 = 900.0;
const MAIN_MIN_HEIGHT: f64 = 620.0;
const MAIN_DEFAULT_WIDTH: f64 = 1180.0;
const MAIN_DEFAULT_HEIGHT: f64 = 760.0;
const MINI_WIDTH: f64 = 420.0;
const MINI_HEIGHT: f64 = 236.0;
const MINI_MIN_WIDTH: f64 = 360.0;
const MINI_MIN_HEIGHT: f64 = 220.0;
const MINI_MARGIN: f64 = 24.0;

#[derive(Debug, Clone, Copy, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub(crate) enum WindowMode {
    Main,
    MiniPlayer,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct WindowSnapshot {
    mode: WindowMode,
    maximized: bool,
    always_on_top: bool,
    inner_width: f64,
    inner_height: f64,
    scale_factor: f64,
}

#[derive(Debug, Serialize)]
pub(crate) struct WindowCommandError {
    code: &'static str,
    message: &'static str,
}

impl WindowCommandError {
    fn unavailable() -> Self {
        Self {
            code: "window-unavailable",
            message: "Windows did not complete the requested window operation.",
        }
    }

    #[cfg(not(desktop))]
    fn unsupported() -> Self {
        Self {
            code: "unsupported-platform",
            message: "MiniPlayer window geometry is currently available on desktop only.",
        }
    }
}

impl From<tauri::Error> for WindowCommandError {
    fn from(_: tauri::Error) -> Self {
        Self::unavailable()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
struct MainWindowGeometry {
    position: PhysicalPosition<i32>,
    inner_size: PhysicalSize<u32>,
    maximized: bool,
}

#[derive(Clone, Default)]
pub(crate) struct WindowRuntime {
    mini_player: Arc<AtomicBool>,
    main_geometry: Arc<Mutex<Option<MainWindowGeometry>>>,
}

impl WindowRuntime {
    fn mode(&self) -> WindowMode {
        if self.mini_player.load(Ordering::Acquire) {
            WindowMode::MiniPlayer
        } else {
            WindowMode::Main
        }
    }

    fn set_mode(&self, mode: WindowMode) {
        self.mini_player
            .store(mode == WindowMode::MiniPlayer, Ordering::Release);
    }

    fn remember_main_geometry(
        &self,
        geometry: MainWindowGeometry,
    ) -> Result<(), WindowCommandError> {
        *self
            .main_geometry
            .lock()
            .map_err(|_| WindowCommandError::unavailable())? = Some(geometry);
        Ok(())
    }

    fn main_geometry(&self) -> Result<MainWindowGeometry, WindowCommandError> {
        self.main_geometry
            .lock()
            .map_err(|_| WindowCommandError::unavailable())?
            .ok_or_else(WindowCommandError::unavailable)
    }

    fn forget_main_geometry(&self) -> Result<(), WindowCommandError> {
        *self
            .main_geometry
            .lock()
            .map_err(|_| WindowCommandError::unavailable())? = None;
        Ok(())
    }
}

#[cfg(desktop)]
pub(crate) fn persisted_state_flags() -> StateFlags {
    StateFlags::SIZE | StateFlags::POSITION | StateFlags::MAXIMIZED
}

#[tauri::command]
pub(crate) fn window_snapshot(
    window: WebviewWindow,
    runtime: State<'_, WindowRuntime>,
) -> Result<WindowSnapshot, WindowCommandError> {
    let mode = runtime.mode();
    #[cfg(desktop)]
    if mode == WindowMode::Main {
        repair_invalid_main_geometry(&window)?;
    }
    read_snapshot(&window, mode)
}

#[tauri::command]
pub(crate) fn window_set_mode(
    window: WebviewWindow,
    runtime: State<'_, WindowRuntime>,
    mode: WindowMode,
) -> Result<WindowSnapshot, WindowCommandError> {
    if runtime.mode() == mode {
        return read_snapshot(&window, mode);
    }

    #[cfg(not(desktop))]
    {
        let _ = window;
        let _ = mode;
        return Err(WindowCommandError::unsupported());
    }

    #[cfg(desktop)]
    {
        match mode {
            WindowMode::Main => restore_main_window(&window, &runtime)?,
            WindowMode::MiniPlayer => enter_mini_player(&window, &runtime)?,
        }
        read_snapshot(&window, runtime.mode())
    }
}

fn read_snapshot(
    window: &WebviewWindow,
    mode: WindowMode,
) -> Result<WindowSnapshot, WindowCommandError> {
    let scale_factor = window.scale_factor()?;
    let inner_size = window.inner_size()?.to_logical::<f64>(scale_factor);
    Ok(WindowSnapshot {
        mode,
        maximized: window.is_maximized()?,
        always_on_top: window.is_always_on_top()?,
        inner_width: inner_size.width,
        inner_height: inner_size.height,
        scale_factor,
    })
}

#[cfg(desktop)]
fn enter_mini_player(
    window: &WebviewWindow,
    runtime: &WindowRuntime,
) -> Result<(), WindowCommandError> {
    window
        .app_handle()
        .save_window_state(persisted_state_flags())
        .map_err(|_| WindowCommandError::unavailable())?;
    let geometry = capture_main_geometry(window)?;
    if let Err(error) = runtime.remember_main_geometry(geometry) {
        if geometry.maximized {
            let _ = window.maximize();
        }
        return Err(error);
    }
    runtime.set_mode(WindowMode::MiniPlayer);

    let result = (|| -> Result<(), WindowCommandError> {
        window.set_min_size(Some(LogicalSize::new(MINI_MIN_WIDTH, MINI_MIN_HEIGHT)))?;
        window.set_always_on_top(true)?;
        window.set_size(LogicalSize::new(MINI_WIDTH, MINI_HEIGHT))?;

        if let Some(monitor) = window.current_monitor()? {
            let scale_factor = monitor.scale_factor();
            let margin = (MINI_MARGIN * scale_factor).round() as u32;
            window.set_position(bottom_right_position(
                monitor.work_area().position,
                monitor.work_area().size,
                window.outer_size()?,
                margin,
            ))?;
        }
        Ok(())
    })();

    if result.is_err() {
        let _ = restore_main_window(window, runtime);
    }
    result
}

#[cfg(desktop)]
fn capture_main_geometry(window: &WebviewWindow) -> Result<MainWindowGeometry, WindowCommandError> {
    let maximized = window.is_maximized()?;
    // A maximized client rectangle is not the restored window rectangle.
    // Read the normal geometry before MiniPlayer changes size or monitor.
    if maximized {
        window.unmaximize()?;
    }
    let result = (|| {
        repair_invalid_main_geometry(window)?;
        Ok(MainWindowGeometry {
            position: window.outer_position()?,
            inner_size: window.inner_size()?,
            maximized,
        })
    })();
    if result.is_err() && maximized {
        let _ = window.maximize();
    }
    result
}

#[cfg(desktop)]
fn restore_main_window(
    window: &WebviewWindow,
    runtime: &WindowRuntime,
) -> Result<(), WindowCommandError> {
    let geometry = runtime.main_geometry()?;
    window.set_always_on_top(false)?;
    window.set_min_size(Some(LogicalSize::new(MAIN_MIN_WIDTH, MAIN_MIN_HEIGHT)))?;
    if window.is_maximized()? {
        window.unmaximize()?;
    }
    window.set_size(geometry.inner_size)?;
    window.set_position(geometry.position)?;
    // The saved monitor/work area may have changed while MiniPlayer was open.
    repair_invalid_main_geometry(window)?;
    if geometry.maximized {
        window.maximize()?;
    }
    runtime.set_mode(WindowMode::Main);
    runtime.forget_main_geometry()?;
    let _ = window
        .app_handle()
        .save_window_state(persisted_state_flags());
    Ok(())
}

#[cfg(desktop)]
pub(crate) fn restore_main_before_close(window: &WebviewWindow, runtime: &WindowRuntime) {
    if runtime.mode() == WindowMode::MiniPlayer {
        let _ = restore_main_window(window, runtime);
    }
}

#[cfg(desktop)]
fn repair_invalid_main_geometry(window: &WebviewWindow) -> Result<(), WindowCommandError> {
    if window.is_maximized()? || window.is_minimized()? {
        return Ok(());
    }
    window.set_min_size(Some(LogicalSize::new(MAIN_MIN_WIDTH, MAIN_MIN_HEIGHT)))?;
    let Some(monitor) = window.current_monitor()?.or(window.primary_monitor()?) else {
        return Ok(());
    };
    let scale_factor = window.scale_factor()?;
    let inner_size = window.inner_size()?;
    let outer_size = window.outer_size()?;
    let position = window.outer_position()?;
    let frame_size = PhysicalSize::new(
        outer_size.width.saturating_sub(inner_size.width),
        outer_size.height.saturating_sub(inner_size.height),
    );
    let (fitted_position, fitted_size) = fit_main_geometry(
        position,
        inner_size,
        frame_size,
        monitor.work_area().position,
        monitor.work_area().size,
        LogicalSize::new(MAIN_MIN_WIDTH, MAIN_MIN_HEIGHT).to_physical::<u32>(scale_factor),
        LogicalSize::new(MAIN_DEFAULT_WIDTH, MAIN_DEFAULT_HEIGHT).to_physical::<u32>(scale_factor),
    );
    if fitted_size != inner_size {
        window.set_size(fitted_size)?;
    }
    if fitted_position != position {
        window.set_position(fitted_position)?;
    }
    if fitted_size != inner_size || fitted_position != position {
        let _ = window
            .app_handle()
            .save_window_state(persisted_state_flags());
    }
    Ok(())
}

fn fit_main_geometry(
    position: PhysicalPosition<i32>,
    inner_size: PhysicalSize<u32>,
    frame_size: PhysicalSize<u32>,
    work_position: PhysicalPosition<i32>,
    work_size: PhysicalSize<u32>,
    minimum: PhysicalSize<u32>,
    default_size: PhysicalSize<u32>,
) -> (PhysicalPosition<i32>, PhysicalSize<u32>) {
    let too_small = inner_size.width < minimum.width || inner_size.height < minimum.height;
    let requested = if too_small { default_size } else { inner_size };
    let fitted_size = PhysicalSize::new(
        requested.width.clamp(
            minimum.width,
            work_size
                .width
                .saturating_sub(frame_size.width)
                .max(minimum.width),
        ),
        requested.height.clamp(
            minimum.height,
            work_size
                .height
                .saturating_sub(frame_size.height)
                .max(minimum.height),
        ),
    );
    let outer_size = PhysicalSize::new(
        fitted_size.width.saturating_add(frame_size.width),
        fitted_size.height.saturating_add(frame_size.height),
    );
    let max_x = work_position
        .x
        .saturating_add_unsigned(work_size.width.saturating_sub(outer_size.width));
    let max_y = work_position
        .y
        .saturating_add_unsigned(work_size.height.saturating_sub(outer_size.height));
    (
        PhysicalPosition::new(
            position.x.clamp(work_position.x, max_x),
            position.y.clamp(work_position.y, max_y),
        ),
        fitted_size,
    )
}

fn bottom_right_position(
    work_position: PhysicalPosition<i32>,
    work_size: PhysicalSize<u32>,
    window_size: PhysicalSize<u32>,
    margin: u32,
) -> PhysicalPosition<i32> {
    let horizontal_gap = work_size
        .width
        .saturating_sub(window_size.width)
        .saturating_sub(margin);
    let vertical_gap = work_size
        .height
        .saturating_sub(window_size.height)
        .saturating_sub(margin);
    PhysicalPosition::new(
        work_position.x.saturating_add(horizontal_gap as i32),
        work_position.y.saturating_add(vertical_gap as i32),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn places_mini_player_inside_a_negative_origin_monitor() {
        let position = bottom_right_position(
            PhysicalPosition::new(-1920, 0),
            PhysicalSize::new(1920, 1040),
            PhysicalSize::new(420, 236),
            24,
        );

        assert_eq!(position, PhysicalPosition::new(-444, 780));
    }

    #[test]
    fn saturates_when_the_work_area_is_smaller_than_the_mini_player() {
        let position = bottom_right_position(
            PhysicalPosition::new(100, 200),
            PhysicalSize::new(320, 180),
            PhysicalSize::new(420, 236),
            24,
        );

        assert_eq!(position, PhysicalPosition::new(100, 200));
    }

    #[test]
    fn preserves_a_valid_user_size_and_position() {
        let position = PhysicalPosition::new(180, 90);
        let size = PhysicalSize::new(1180, 760);
        assert_eq!(
            fit_test_geometry(
                position,
                size,
                PhysicalPosition::new(0, 0),
                PhysicalSize::new(1920, 1040),
                1.0
            ),
            (position, size)
        );
    }

    #[test]
    fn repairs_legacy_mini_geometry_without_exceeding_the_work_area() {
        let (position, size) = fit_test_geometry(
            PhysicalPosition::new(1700, 850),
            PhysicalSize::new(420, 236),
            PhysicalPosition::new(0, 0),
            PhysicalSize::new(1920, 1040),
            1.0,
        );
        assert_eq!(size, PhysicalSize::new(1180, 760));
        assert_eq!(position, PhysicalPosition::new(724, 242));
    }

    #[test]
    fn fits_a_maximized_rectangle_saved_as_normal_geometry() {
        let (position, size) = fit_test_geometry(
            PhysicalPosition::new(3300, 650),
            PhysicalSize::new(2560, 1560),
            PhysicalPosition::new(3200, 533),
            PhysicalSize::new(2560, 1560),
            1.75,
        );
        assert_eq!(position, PhysicalPosition::new(3200, 533));
        assert_eq!(size, PhysicalSize::new(2532, 1493));
    }

    #[test]
    fn keeps_negative_origin_monitors_and_accounts_for_dpi_and_decorations() {
        for scale in [1.0, 1.25, 1.5, 1.75] {
            let frame: PhysicalSize<u32> = LogicalSize::new(16.0, 38.0).to_physical(scale);
            let expected_size: PhysicalSize<u32> =
                LogicalSize::new(1180.0, 760.0).to_physical(scale);
            let (position, size) = fit_test_geometry(
                PhysicalPosition::new(-100, -20),
                expected_size,
                PhysicalPosition::new(-2560, -400),
                PhysicalSize::new(2560, 1800),
                scale,
            );
            assert_eq!(size, expected_size);
            assert_eq!(position.x, -(size.width as i32) - frame.width as i32);
            assert!(position.y >= -400);
            assert!(position.y as i64 + i64::from(size.height) + i64::from(frame.height) <= 1400);
        }
    }

    #[test]
    fn anchors_to_work_area_when_the_screen_cannot_fit_the_product_minimum() {
        let (position, size) = fit_test_geometry(
            PhysicalPosition::new(-500, -500),
            PhysicalSize::new(1180, 760),
            PhysicalPosition::new(100, 200),
            PhysicalSize::new(800, 600),
            1.0,
        );
        assert_eq!(position, PhysicalPosition::new(100, 200));
        assert_eq!(size, PhysicalSize::new(900, 620));
    }

    #[test]
    fn extreme_monitor_coordinates_do_not_wrap() {
        let (position, _) = fit_test_geometry(
            PhysicalPosition::new(i32::MAX, i32::MIN),
            PhysicalSize::new(900, 620),
            PhysicalPosition::new(i32::MAX - 100, i32::MIN),
            PhysicalSize::new(u32::MAX, u32::MAX),
            1.0,
        );
        assert_eq!(position, PhysicalPosition::new(i32::MAX, i32::MIN));
    }

    fn fit_test_geometry(
        position: PhysicalPosition<i32>,
        inner_size: PhysicalSize<u32>,
        work_position: PhysicalPosition<i32>,
        work_size: PhysicalSize<u32>,
        scale: f64,
    ) -> (PhysicalPosition<i32>, PhysicalSize<u32>) {
        fit_main_geometry(
            position,
            inner_size,
            LogicalSize::new(16.0, 38.0).to_physical(scale),
            work_position,
            work_size,
            LogicalSize::new(MAIN_MIN_WIDTH, MAIN_MIN_HEIGHT).to_physical(scale),
            LogicalSize::new(MAIN_DEFAULT_WIDTH, MAIN_DEFAULT_HEIGHT).to_physical(scale),
        )
    }
}
