# 生产依赖登记

更新日期：2026-09-03

## 2026-09-11 Windows 打包预审

使用锁文件与本机 registry 的 `cargo metadata --offline --locked --filter-platform
x86_64-pc-windows-msvc` 核对实际解析图：存在 MIT/Apache、BSD、Unicode、Zlib、
MPL-2.0 等声明。图包含构建期依赖，不能将它直接当成二进制链接清单。
其中 21 个包声明 MPL-2.0（Symphonia 系列，以及 cssparser、cssparser-macros、
dtoa-short、option-ext、selectors）；React 本机包声明 MIT。此项是元数据盘点，
不是完整许可证合规结论。尚未整理第三方 notice 原文、实际随包组件及来源材料。
当前 NSIS 候选仅附项目 MIT License，未捆绑 ffprobe，不得标记为完成许可验收。

`pnpm audit:licenses` 从锁定 Windows Cargo 解析图及实际安装的 npm 生产依赖提取
许可原文，输出到被忽略的 `output/release-license-audit/`。`inventory.json` 包含输入
hash、上游仓库/源码提交、原文文件 hash 与缺项；文本是审核候选，不自动进入 bundle。
2026-09-11 实跑：340 个包，14 个包缺常见名称的本地许可原文，命令返回 1：
alloc-stdlib、dasp_sample、defmt-parser、realfft、selectors、tauri-plugin、5 个 unic
包及3 个 webview2-com 包。下一步按 inventory 中的固定源码提交补齐上游原文并审阅
内嵌组件；不可直接用“MIT”等标识替代许可文本。此图包含构建期依赖，数量不代表
安装包实际链接数量。pnpm 自带 licenses 命令因本地包索引缺失失败，未因此重装依赖；
当前脚本使用可正常读取的 pnpm list 与已安装包清单。

补充核对：`pnpm audit:licenses --fetch-upstream` 仅对缺项请求 Cargo 元数据记录的
GitHub 固定提交根目录，校验返回文本的 Git blob hash 并记录来源 URL/SHA-256。
本轮输出的缺项已由 14 降为 2：realfft 3.5.0、selectors 0.36.1。其余 12 项原文已
写入审核候选；离线模式仍只反映本地 crate 文件，不应把 14 项本地缺文件误报为退步。
selectors 的 lib.rs 头部明确指向 https://mozilla.org/MPL/2.0/，官网已核对存在相同
MPL 2.0 声明与文本；其固定提交仓库根目录未附独立许可文件。realfft 的 Cargo/README
声明 MIT，但对应提交根目录没有原文；不自行填写版权年份或持有人来冒充上游许可。
这两项、嵌入第三方源码的分发范围及 MPL 源码获取材料仍需完成，未改 bundle 资源。

打包入口：`pnpm package:windows` 重新构建并打包；`pnpm bundle:windows` 仅打包已有
Release，调用前需正常退出 Heni，并确认该 Release 对应当前源码。Tauri 会尝试写入
bundler 标记，运行中程序会造成文件锁冲突；不能把打包旧 exe 当成构建新源码。
配置采用 currentUser 和 WebView2 downloadBootstrapper；缺少 WebView2 的机器可能
需要联网。安装/卸载须在独立测试用户或虚拟机执行，避免触碰现有曲库配置。

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
