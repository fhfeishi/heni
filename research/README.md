# Heni 开源音乐播放器研究记录

更新时间：2026-08-31

本目录用于保存 Heni Tauri 重构前的开源项目研究。第三方源码放在 `research/upstream/`，该目录已加入 Heni 的 `.gitignore`，保留各自独立 Git 历史，仅作为只读参考；Heni 仓库只跟踪本研究记录和基于独立实现形成的设计文档。

## 固定的参考版本

| 项目 | 本地提交 | 许可证 | 与 Heni 的关系 |
|---|---|---|---|
| [musicdl](https://github.com/CharlesPikachu/musicdl) | `72e6727` | PolyForm Noncommercial 1.0.0 | Python 多音源搜索/下载器；参考 adapter 注册、统一媒体 DTO 和并发进度，不参考播放器实现 |
| [Museek](https://github.com/aeroray/Museek) | `83c547d` | MIT | Tauri 2 + React + TypeScript 音乐聚合器；与 Heni 前端和桌面集成最接近 |
| [Luminous](https://github.com/esoltys/luminous) | `4b97acf` | MIT | 本地优先播放器；参考 Rust 原生音频、SQLite、扫描、深层 IPC 和测试策略 |
| [WaveFlow](https://github.com/InstaZDLL/WaveFlow) | `c20b17a` | GPL-3.0 | Tauri 2 + React + TypeScript 本地播放器；仅研究架构与行为，不复制代码 |

这些提交是研究快照，不应在实现过程中自动更新。升级参考版本前，先重新审计许可证、架构变化和安全边界。

## 1. musicdl

### 值得借鉴

- `MusicClientBuilder` 把几十个来源注册为可替换 adapter，调用者只依赖统一入口。
- `SongInfo` 把来源差异规整成统一媒体信息，包括标题、歌手、专辑、扩展名、大小、时长、码率、codec、采样率和声道。
- 搜索和下载对来源进行隔离，并提供并发上限、重试、结构化进度和来源级错误。
- 外部工具和不同协议被放在边界层，而不是渗入 UI。

### 不应带入 Heni

- 它是网络搜索/下载工具，不是本地播放引擎。
- Heni 当前产品范围不包含在线音源、抓取、下载、DRM 或受限内容处理。
- PolyForm Noncommercial 不等同于 MIT。不得把它的代码、实现细节或衍生代码复制进 Heni；只采用不受版权保护的抽象思想，并独立实现。

## 2. Museek

### 值得借鉴

- Tauri 2、React、TypeScript、Vite、Zustand 的组合已经在 Windows/macOS 发布流程中使用。
- `AudioPlayer` 对外隐藏具体音频对象，并提供状态和播放时间订阅；UI 通过独立 playback clock 更新进度，而不是直接持有音频元素。
- 本地媒体导入区分“选择文件”“选择目录”“转换成本地资源 URL”“在资源管理器中显示”。
- 播放队列、当前曲目、播放模式、系统媒体控制和防休眠形成了明确的产品切片。
- 对缺失本地文件进行 unavailable 标记，而不是直接从用户曲库中静默删除。
- Windows NSIS、macOS DMG、自动更新和系统媒体控制提供了可参考的发布清单。

### 不能照搬

- Windows 下的实现会用 `fetch(...).arrayBuffer()` 和 `decodeAudioData()` 把整首音频读入 WebView 内存。长音频、大文件和连续切歌存在内存、解码延迟与释放风险，不适合作为 Heni 的正式播放内核。
- 目录递归扫描主要在 TypeScript 中逐级调用文件系统插件。小目录可用，但大型曲库应放到 Rust 后台任务，并支持进度、取消和批量数据库写入。
- 数据主要保存为多个 JSON 文件和 localStorage；Heni 应使用有 migration 的 SQLite，并对旧 JSON 做运行时校验。
- `csp` 被设为 `null`，asset protocol 和文件系统 capability 含有 `**/*` 等过宽范围。Heni 必须启用 CSP，并只授权用户选择的曲库目录和应用数据目录。
- 参考版本没有自动化测试文件，TypeScript 严格选项也少于 Heni 的目标门槛。
- `playerStore.ts`、`localMusicStore.ts` 和 Rust `lib.rs` 已接近或超过一千行，说明“按功能拆 store”仍不足以替代 domain/application/adapter 分层。

## 3. Luminous

### 值得借鉴

- 前端负责 UI、展示状态和交互；Rust 负责音频解码/输出、SQLite 曲库、扫描和 OS 媒体集成。
- IPC command 以完整用例为单位，而不是把 Rust 包装成大量字段级 getter/setter。
- 播放器、队列和自动前进由后端持有权威状态，WebView 重载、隐藏或多窗口不会使播放状态丢失。
- 扫描、数据库、播放器和媒体会话是独立 Rust 模块，避免形成单个超大 `lib.rs`。
- 参考快照包含约 72 个测试文件、439 个测试用例，并同时覆盖 TypeScript/Svelte 与 Rust。
- 功能规格和真实发布清单被纳入仓库，适合作为 Heni 功能等价矩阵的参考方式。

### Heni 的调整

- Heni 前端仍采用 React + TypeScript，而不是 Svelte。
- Heni 第一阶段不实现均衡器、歌词、标签编辑、智能歌单等扩展功能。
- Heni 不追求一次建立 Luminous 的完整音频/DSP 规模，先通过 codec、seek、连续切歌、设备变化和 Release 打包 Spike。

## 4. WaveFlow

### 值得借鉴

- React 组件只调用集中式的 typed player facade，不在组件中散落 `invoke()`。
- Rust 播放器通过 command 接收控制，通过少量事件发送 state、position、track-ended 和 error；前端挂载时先取 snapshot，再订阅增量事件。
- 播放 position 约 250ms 更新一次，UI 在本地平滑插值，避免每帧 IPC 和全局 store 重渲染。
- Symphonia 解码、CPAL 输出、SQLite 曲库、Lofty 元数据和文件 watcher 的职责边界清晰。
- 实时音频回调遵循“不阻塞、不分配、不日志”的约束；控制命令、解码线程和输出回调相互隔离。
- React 虚拟列表、拖放排序、播放器 Context/hook 和后端权威队列为大型曲库提供了实际参考。
- 文档明确记录音频线程、数据库路径、事件和不变量，值得借鉴其 ADR/架构文档习惯。

### 许可证边界

WaveFlow 是 GPL-3.0，而 Heni 当前是 MIT。默认不复制、改写或移植 WaveFlow 源码，不复制其注释、类型声明或算法实现；只记录公开行为、通用架构思想和待验证假设，由 Heni 独立设计、独立命名、独立测试。如果未来决定采用 GPL 代码，必须先由用户明确决定是否愿意让 Heni 整体遵循兼容的 GPL 发布义务。

## 5. 对 Heni 的冻结决策

1. Heni 保持 local-first：首个 Tauri 版本不引入在线音乐、下载、账户、歌词或云同步。
2. React + TypeScript 是产品开发和学习主线；Rust 是小而明确的系统核心，不以“提高 TypeScript 占比”为由把实时音频和大目录扫描塞进 WebView。
3. Rust 持有权威 playback state machine、活动队列、自动前进、音频设备和 Release 播放资源；TypeScript 持有浏览状态、视图模型、主题、筛选、选择和用户交互用例。
4. SQLite schema/migration/事务由 Rust repository 管理；TypeScript 通过有类型的 application port 访问，不直接写 SQL。
5. IPC 使用“启动 snapshot + 增量事件/Channel”：command 做请求响应，Channel 做可取消扫描进度，播放事件带 generation/sequence，position 最多 4–5Hz，UI 自己平滑显示。
6. 播放内核优先验证 Rust 原生方案（Symphonia + CPAL）和 libmpv 方案。Web Audio 仅作为 Spike 对照，不作为默认正式引擎。
7. 现有视频能力必须被显式记录：若选择纯音频内核，则提供独立视频 adapter 或把视频等价迁移列为后续阻塞项，不能悄悄丢失。
8. 元数据读取分成“快速曲库索引”和“详细探测”。优先评估 Lofty/Symphonia 批量读取；ffprobe 保留在详细探测 adapter，避免为大型曲库逐文件启动进程。
9. capability 默认拒绝；只开放应用数据目录和用户明确选择后持久化的曲库 scope。禁止 `csp: null`、`withGlobalTauri: true` 和全局 `**/*` 路径权限。
10. 从第一天建立 Vitest、Testing Library 和 Rust 测试。播放器队列、repeat/shuffle、迁移、路径规范化和 IPC DTO 必须先有行为测试。
11. Tauri/TypeScript 是仓库根唯一在建实现；Flutter 位于 `legacy/v1-flutter/` 作为只读基线，通过 Windows 验收前不删除归档和旧用户数据。

## 6. 可采用但需要独立实现的模式

- `PlaybackBackend` / `PlaybackService` 端口；
- command facade 与运行时 DTO 校验；
- snapshot + event rehydrate；
- playback clock seam；
- unavailable media，而不是静默删除；
- 文件夹扫描进度、取消和 generation token；
- 大列表虚拟化；
- 系统媒体控制和窗口隐藏后继续播放；
- SQLite migration、事务和导入备份；
- 功能等价矩阵、ADR、真实 codec Release 测试清单。

## 7. 明确拒绝的模式

- Dart 到 TypeScript 的逐行翻译；
- React 组件直接访问 SQL、文件系统、外部进程或散落的 Tauri `invoke()`；
- 在 Zustand store 中同时放领域规则、I/O、播放器和所有 UI 状态；
- WebView 整文件解码作为正式 Windows 播放后端；
- 为方便而关闭 CSP 或授予全用户目录读写权限；
- 未经验证就捆绑 FFmpeg、mpv 或 codec 动态库；
- 从 GPL/Noncommercial 项目复制代码却继续宣称 Heni 是独立 MIT 实现；
- 在 Windows MVP 中加入在线音源、歌词、云同步、均衡器等范围膨胀。
