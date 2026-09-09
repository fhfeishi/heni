# 生产依赖登记

更新日期：2026-09-03

本表记录当前生产切片新增且会进入 Windows 二进制的数据与系统依赖。完整传递依赖版本以 `Cargo.lock` 为准。

| 依赖 | 固定版本 | 用途 | 维护/许可证 | 分发与跨平台影响 |
|---|---:|---|---|---|
| [`rusqlite`](https://github.com/rusqlite/rusqlite) | 0.40.2 | Rust repository、migration 和事务 | 活跃维护；MIT | 开启 `bundled`，由构建编译并链接 SQLite，避免依赖用户机器上的 SQLite；Windows/Linux/macOS 可用，移动端仍需单独验证构建链 |
| [SQLite](https://sqlite.org/copyright.html) | rusqlite bundled 对应版本 | 本地曲库数据库引擎 | public domain | 进入应用二进制；无单独动态库部署，仍需保留依赖/构建来源记录 |
| [`sha2`](https://github.com/RustCrypto/hashes) | 0.10.9 | 为 Flutter v1 源 JSON 生成 SHA-256 审计指纹 | RustCrypto 维护；MIT OR Apache-2.0 | 纯 Rust 小型依赖，无 sidecar/DLL；桌面平台可移植，移动端需随 Rust target 一并验证 |
| [`tauri-plugin-window-state`](https://github.com/tauri-apps/plugins-workspace/tree/v2/plugins/window-state) | 2.4.1 | 保存并恢复主窗口的位置、大小和最大化状态 | Tauri 官方维护；MIT OR Apache-2.0 | 仅桌面 target 编译，无 sidecar/DLL；状态写入应用配置目录的 `.window-state.json`。插件会持续观察窗口事件，因此 MiniPlayer 的会话内普通几何由 Heni Rust runtime 另行保存，并在返回或关闭前恢复后再刷新插件状态；Linux/macOS 后续验证，移动端不编译 |

以上选择均未改变 Heni 自有代码的许可证。正式安装包阶段仍需生成完整 third-party notices，并重新审计全部传递依赖与实际链接方式。

## S2-2 美景切片增量

- `image = 0.25.10`：仅启用 `jpeg` / `png`，关闭默认格式集合；负责限额解码与坏图校验，MIT OR Apache-2.0。来源：[image-rs](https://github.com/image-rs/image)。最低 Rust 1.88，当前工程 1.95 满足；无新 sidecar。传递依赖和锁定校验值见 `Cargo.lock`。
- `base64 = 0.22.1`：把经过校验的、受体积限制的本地图片交给 WebView；MIT OR Apache-2.0。它原本已在依赖图中，本次提升为显式直接依赖。来源：[rust-base64](https://github.com/marshallpierce/rust-base64)。
- 文件字节、尺寸和解码预算有独立上限，不把解码库的非严格分配限制误写成进程硬内存限制。
- 不读取或分发系统壁纸作为产品资源；实机验收中的系统图片仅作为本机临时选图输入，不进入仓库和安装包。

## 外部工具边界

媒体完整详情会按需执行 `ffprobe`。当前代码只从未来受控的 `resources/bin/ffprobe.exe` 或开发机 `PATH` 查找它，仓库与当前 no-bundle Release 都没有复制、链接或分发 FFmpeg 二进制。快速索引和音频播放不依赖 `ffprobe`。

正式 bundle 若要携带 sidecar，必须先固定二进制来源、构建配置、版本、SHA-256 和对应 LGPL/GPL 义务，并补 third-party notices 与安装包验证；不同 FFmpeg build 的许可证可能不同，因此这一步不能根据开发机现有文件推断或自动复制。
