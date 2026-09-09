# Phase 0：Flutter 基线审计

审计日期：2026-08-31  
状态：完成  
范围：只记录当前行为、迁移边界和风险，不改变 Flutter 产品行为。

## 结论

Heni 的重构工作量是中大型，不是“替换 UI 框架”级别。真正昂贵的是媒体兼容、权威播放会话、旧数据迁移、Windows 原生行为和功能等价验证。按单人全职估算，Windows 可用 MVP 约 5–8 周；达到当前主要功能等价并完成 Release/安装验收约 9–15 周。视频或 native/sidecar 分发问题可能另增 1–3 周。

应采用渐进迁移：Tauri/TypeScript 作为仓库根在建应用，Flutter 保持在 `legacy/v1-flutter/` 可单独构建，先完成播放 walking skeleton，再迁移曲库、数据和 UI。当前没有证据支持删除归档或提前选择播放内核。

## 代码与测试基线

| 指标 | 审计结果 |
|---|---:|
| `lib/**/*.dart` | 44 个文件 |
| Flutter 业务代码 | 约 14,900 行（立项统计） |
| `test/**/*.dart` | 26 个文件 |
| Dart 测试用例 | 123 个 |
| `player_screen.dart` | 8,946 行 |
| `playback_queue_controller.dart` | 1,312 行 |
| JSON schema | `schemaVersion = 1` |

两个超大文件说明当前行为边界不足，但里面也包含大量已验证细节。迁移时应按垂直功能提取测试和行为，不应把它们机械翻译为 `PlayerPage.tsx` 或单个 Zustand store。

## 当前运行结构

```text
Flutter presentation
  ├─ Riverpod / PlaybackQueueController
  │    ├─ library + playlists + active queue
  │    ├─ repeat/shuffle + automatic advance
  │    ├─ scan settings + persistence orchestration
  │    └─ current media probe
  ├─ PlaybackEngine -> media_kit
  ├─ MediaInspector -> ffprobe process
  ├─ LocalMediaScanner -> dart:io
  ├─ HeniLibraryStore -> JSON
  └─ MethodChannel -> Windows Runner
```

关键事实：

- 曲库、用户歌单、当前播放队列是三个不同概念；浏览歌单不会替换正在播放的队列。
- `MediaKitPlaybackEngine` 已形成最小播放端口，提供 playing、completed、position、duration、volume 和同步快照。
- 音频和视频都由 `media_kit` 打开；视频通过 `media_kit_video` 真正渲染，不只是把视频文件当音频。
- `ffprobe` 使用结构化参数返回 codec、bitrate、sample rate、channels、stream/chapter 等信息。
- 文件夹扫描支持递归、跳过符号链接、音频/视频过滤和路径排序，但一次返回完整数组，没有进度与取消。
- Windows Runner 负责自定义边框、拖动、最小化、最大化/还原、关闭、最小客户区和窗口状态。

## 媒体范围

当前扩展名白名单：

- 音频：AAC、AIFF、ALAC、FLAC、M4A、MP3、OGG、Opus、WAV、WMA；
- 视频：AVI、FLV、M4V、MKV、MOV、MP4、MPEG/MPG、TS、WebM、WMV。

扩展名表示“候选媒体”，不等于 codec 一定可解码。Tauri 版本必须用真实 Windows Release 样本验证，不可仅靠单元测试或文件后缀宣称兼容。

## 播放语义基线

- 兼容旧值 `sequence`，读取后会规范化为 `listLoop`；当前可选择模式实际是列表循环、单曲循环、随机播放。
- `random` 等价于 `shuffle = true + repeat all`。
- 开启 shuffle 时，当前曲目固定为新随机顺序的第一项，其余项洗牌。
- repeat one 的 next 会保留当前项；repeat all 会在尾部回到首项。
- 非 repeat all 的 previous 在队首保留当前项，而不是停止。
- 自动前进与用户手动切换在现有 controller 中有显式区分。
- 音量范围为 0–100，并保存最后一个大于 0 的 audible volume 供静音恢复。

这些语义必须转为语言无关的 fixture，并由 TypeScript 与 Rust 契约测试共同验证。

## 持久化基线

默认文件：Windows `%APPDATA%/Heni/library.json`。

schema v1 字段：

- 曲库：`libraryDirectories`、`libraryFiles`、`mediaDurations`；
- 歌单：`playlists[{id,name,description,itemPaths}]`、`activePlaylistId`；
- 美景/主题：`sceneryImagePaths`、`sceneryImageOpacity`、`activePaletteName`、`activeUiStyle`；
- 布局：`sidebarMode`；
- 播放：旧 `playbackModeName`，新 `repeatModeName`、`shuffleEnabled`、`volumeLevel`、`lastAudibleVolume`；
- 扫描：`recursiveScan`、`includeVideo`、`autoplayOnLoad`。

现实现会容忍部分错误字段并使用默认值，但写入是直接覆盖文件，没有备份、原子替换或 migration 执行记录。Tauri 导入必须只读、校验、备份、事务写 SQLite，并保留缺失文件的歌单引用。

## Windows UI 与原生基线

- 自定义主题标题栏和无系统装饰窗口；
- 拖动、最小化、最大化/还原、关闭；
- `900 × 620` 逻辑客户区下限；
- 窗口位置、尺寸、最大化状态保存到 `%APPDATA%/Heni/window-state.ini`；
- 全窗口美景背景、主题色、Microsoft YaHei、扩展/紧凑侧栏及滞回；
- 播放控制、进度、音量弹层、媒体信息、队列定位和文件位置；
- Windows Release 构建和启动冒烟在旧日志中有记录，但代表性 codec Release 覆盖仍是待办。

## 质量基线

现有 123 个测试覆盖领域播放顺序、queue controller、JSON store、scanner、ffprobe/ffmpeg、文件操作、窗口 controller 和多种 UI 计算/组件。迁移优先复用“行为预期”，不能逐行翻译 mock 结构。

已知环境风险：旧 Flutter widget test 在当前机器曾因 `127.0.0.1` listener 失败而无法启动。新的 Vitest/Rust 测试必须单独验证；不得把旧环境问题误归为 Tauri 实现失败，也不得把未运行的 Flutter 测试称为通过。

## 目标模块映射

| Flutter 责任 | Tauri 目标责任 |
|---|---|
| `player_screen.dart` | React app shell + player/library/playlist/queue/settings/scenery feature |
| `PlaybackQueueController` | TypeScript use case/facade + Rust authoritative playback session |
| `PlaybackEngine` / media_kit | `PlaybackPort` + 经 Spike 选择的 Rust native 或 libmpv adapter |
| `LocalMediaScanner` | Rust cancellable scanner + Channel progress |
| `HeniLibraryStore` | Rust SQLite repository + 一次性 JSON importer |
| `FfprobeMediaInspector` | Rust metadata/detail adapter，继续结构化调用 |
| MethodChannel / Runner | Tauri window API；不足处才用小型 Windows adapter |
| Riverpod presentation state | feature-scoped React state/Zustand，领域/I/O 不进入 store |

## 风险登记

| ID | 风险 | 等级 | 控制措施与退出条件 |
|---|---|---|---|
| R1 | 新引擎 codec/seek/切歌不及 media_kit | 极高 | Phase 1 真实 Debug/Release Spike；未通过不迁移全量 UI |
| R2 | 纯音频方案丢失视频 | 极高 | 同时验证 libmpv/视频 adapter；默认切换前必须闭环或获得批准 |
| R3 | JSON 导入破坏用户曲库 | 极高 | 只读源、时间戳备份、Zod/serde 校验、单事务、失败回滚、幂等测试 |
| R4 | TS 与 Rust 各自维护队列导致漂移 | 高 | Rust 运行时权威；语言无关 fixture；snapshot + generation/sequence |
| R5 | Tauri 路径 capability 过宽 | 高 | 默认拒绝、persisted scope、CSP、capability 审计测试 |
| R6 | 大目录扫描卡 UI 或耗尽内存 | 高 | Rust 后台任务、批次、Channel、取消、背压、性能样本 |
| R7 | UI 大文件在 React 中重生 | 高 | 垂直切片、文件预算/code review、只在真实复用时提取公共层 |
| R8 | 每个文件启动 ffprobe 导致索引过慢 | 高 | Lofty/Symphonia 快索引；ffprobe 仅详细/视频探测 |
| R9 | native/sidecar 打包和许可证失败 | 高 | lock 版本、许可证清单、Release `--no-bundle` 后再正式 bundle |
| R10 | 自定义标题栏/DPI 与 Flutter 不等价 | 中高 | 最小尺寸、拖动区域、多 DPI/最大化 E2E 清单 |
| R11 | 高频 position 事件拖慢 React | 中 | 4–5Hz 事件、局部 external store、UI 本地插值 |
| R12 | 学习目标被 Rust 或框架样板淹没 | 中 | 每阶段 learning note、3–5 个阅读文件、小练习、限制抽象 |

## Phase 0 退出条件

- [x] 最终 Task Demand 已冻结；
- [x] 开源参考提交和许可证边界已记录；
- [x] 当前代码、存储、播放、窗口和测试基线已审计；
- [x] 功能等价矩阵已建立；
- [x] 目标架构 ADR 已接受；
- [x] 播放 Spike ADR 与首个 1–2 周计划已建立；
- [x] Phase 1 工程骨架通过 lint/typecheck/test/build；
