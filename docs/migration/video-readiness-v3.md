# V3 视频接入核对

## 2026-09-10 状态更新

下方“当前证据/初始实现方向”保留为接入前审计，不再代表最新实现。现在已实现 HybridEngine、唯一 VideoOutput/VideoStage、共享队列控制、带 epoch/revision 的反馈，以及仅监听 127.0.0.1 的受控视频连续流。文件授权仍来自原有选择器/曲库；URL 不接受任意文件路径。

首个自定义协议候选有画面但约 20 秒停顿，已用 tiny_http 流式响应替换。真实 TCP 的完整 3MiB+17 字节传输、Range、令牌撤销等测试通过；前端 330 项、原生 132 项通过（另有 3 项忽略）。computer-use 辅助程序启动故障，流式修正版的 WebView 连续播放、声音同步和格式矩阵仍待实机验收。不能把原候选截图当成修正版完成证据。

实现入口与最新证据详见 `docs/media-pipeline.md`、`docs/learning/048-video-output-and-session.md` 与 `docs/migration/strata-v3-progress.md`。

## 当前证据

- `src-tauri/src/playback/engine/native.rs` 的 `NativeAudioEngine::build_active` 明确拒绝非 Audio 项，错误为 unsupported-media-kind。它使用 Symphonia/CPAL 音频路径，并没有视频解码或画面输出。
- `engine/mod.rs` 的 PlaybackEngine 已提供 load、set_playing、stop、set_volume、set_muted、observation；队列与状态归属必须继续统一，不能前端另开一个视频播放器后让两个时钟各自运行。
- Cargo 当前没有启用 Tauri protocol-asset；现有 CSP 也不是一套完成的视频资源授权方案。视频能被扫描/保留不代表能播放。

## 初始实现方向与验证门槛

优先验证 Tauri WebView 视频表面配合按文件授权的本地资源流，保留现有音频路径；先用 H.264/AAC MP4 作为真实验收样本，不承诺 MKV、HEVC、AVI 等全部可播。WebView 的实际编码支持取决于运行环境，容器扩展名不能代替验证。

1. 原型验证：受控测试视频的播放/暂停/时间定位、Range 请求、大文件首帧、失败格式与文件授权撤销。只开放明确选中文件，不使用磁盘全路径通配权限，也不把整部视频变成 base64 传过 IPC。
2. 统一会话：播放命令仍从现有应用工作流进入；切到视频前可靠停止音频，切回前停视频并释放资源。视频事件携带会话代次，迟到的 timeupdate/ended/error 不得覆盖新曲目。
3. 舞台接入：视频画面作为舞台主内容，不在背景玻璃后播放。视频区域不加 backdrop blur，不被未来 100–300 背景遮盖；控制台保持一致。主窗/Mini 往返不允许复制声音源。
4. 验收：真实音画同步、定位、静音/恢复、播完下一项、快速切歌、最小化/恢复、关闭释放、无编码器/损坏文件反馈。未通过前不开放一个看似能播放却没有声音控制权的按钮。

本文件是接入计划，不是视频功能已完成。下一开发切片先验证资源流和唯一会话衔接，再实现完整 UI；若 WebView 格式边界不满足旧版实际视频样本，再比较原生视频引擎，不提前引入庞大依赖。

## 官方参考

- [Tauri Asset protocol scope](https://v2.tauri.app/security/asset-protocol/)：本地资源路径由 assetProtocol scope 控制。
- [Microsoft Edge 视频播放问题与编码支持](https://learn.microsoft.com/en-us/troubleshoot/microsoft-edge/development/video-playback-issues)：并非所有编码均原生支持。此为验证 WebView 方案的参考，不能用浏览器文档替代目标机器的实测。
