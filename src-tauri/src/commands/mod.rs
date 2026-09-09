use serde::Serialize;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct RuntimeInfo {
    app_name: &'static str,
    app_version: &'static str,
    platform: &'static str,
}

#[tauri::command]
pub fn runtime_info() -> RuntimeInfo {
    RuntimeInfo {
        app_name: "Heni",
        app_version: env!("CARGO_PKG_VERSION"),
        platform: std::env::consts::OS,
    }
}

#[cfg(test)]
mod tests {
    use super::runtime_info;

    #[test]
    fn reports_the_package_identity() {
        let info = runtime_info();

        assert_eq!(info.app_name, "Heni");
        assert!(!info.app_version.is_empty());
        assert!(!info.platform.is_empty());
    }
}
