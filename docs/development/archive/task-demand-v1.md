# Heni Tauri + TypeScript 重构 Task Demand

状态：第一阶段历史执行版；后续工作已由根目录 `strata-v2.txt` 接管  
冻结日期：2026-08-31  
进度更新：2026-09-02  
目标：把现有 Flutter 版 Heni 渐进式重构为 Windows 优先的 Tauri 2 + React + TypeScript 本地音乐播放器，同时把工程建设成可持续学习 TypeScript 的真实项目。

> 使用方法：把“执行 Prompt”全文交给编码 Agent。它既是需求基线，也是范围、质量和自主执行授权。若实现与本文冲突，先记录 ADR；涉及破坏用户数据、许可证改变或产品范围扩大时，必须暂停并取得用户决定。

## 动态执行进度

本节只记录实施事实，不降低后文成功标准。详细证据见 `docs/migration/`。

| 阶段 | 当前状态 | 已完成 | 仍需完成 |
|---|---|---|---|
| Phase 0 基线 | 已完成 | 开源研究固定提交、Flutter v1/Release 归档、审计、矩阵、ADR 和任务基线 | 持续随切片更新矩阵 |
| Phase 1 Walking Skeleton | 音频竖切完成，发布门槛部分完成 | Tauri/React/strict TS、最小 capability、typed facade、Symphonia+CPAL、播放控制、Windows no-bundle Release | libmpv 视频、真实媒体矩阵、设备/休眠/长时、安装器与签名 |
| Phase 2 播放会话 | 核心队列竖切完成 | Rust 权威队列、多选、上一首/下一首、repeat/shuffle、移除、追加/下一首插入、后台自动续播、generation/sequence 抗乱序、两端 IPC fixture、权威拖放/键盘重排 | position event/插值、重载 E2E、压力验证 |
| Phase 3 曲库和数据 | 元数据在内的核心竖切完成 | SQLite 曲库/扫描/对账；旧 JSON 安全迁移；歌单事务；Symphonia 快索引；按需 ffprobe 详情 | 大目录/特殊路径 E2E、真实旧数据、安装包 ffprobe sidecar |
| Phase 4 产品 UI | 4A–4G 核心竖切与首轮收口完成 | 应用框架、播放台、常驻播放条、按需详情抽屉；曲库/歌单/队列工作区；Rust 权威重排；三套语义主题；同会话 MiniPlayer；详情 dialog 焦点边界；四档浏览器与真实 Windows Release 窗口检查 | 真实美景来源/设置持久化；125%/150% DPI、对比度和更多错误/缺失状态 E2E；自定义标题栏启用前的完整 Windows 行为矩阵 |
| Phase 5 迁移验收 | 已开始，5A 错误恢复、重新定位与文件定位竖切完成 | 结构化错误到中文提示的展示防火墙；文件/目录选择与曲库恢复动作；缺失引用保留；事务化换路径重新定位；活动队列同 ID 刷新；稳定媒体 ID 驱动的 Windows 资源管理器定位；轮询错误可关闭；新 Release 主窗口和 201 项真实曲库检查 | 真实缺失/权限 E2E；DPI/对比度；真实 codec、长时和内存；安装升级/卸载；矩阵闭环 |
| Phase 6 切换 | 未开始 | 切换约束已冻结 | 视频闭环或批准差异、全部发布门槛、用户明确批准 |

截至 2026-09-02 的当前证据：TypeScript 32 个测试文件、119 项测试与 Rust 67 项常规测试通过，3 项依赖真实音频设备或 `ffprobe` 的环境测试默认忽略，并已在前序里程碑显式执行通过。Phase 4A–4G 已在 1180×760、900×620、420×236 和 360×220 浏览器视口完成结构与溢出检查；详情 dialog 具备初始焦点、Esc 关闭、焦点回还和 Tab 边界测试。Phase 5A 已禁止 UI 展示底层错误 `message`，按错误码生成稳定中文标题、说明和文件/文件夹/曲库恢复动作；重复轮询失败被关闭后不会每 300ms 再次打扰，成功连接或新命令会解除抑制。缺失媒体现在可通过受限单文件选择器重新定位：SQLite 事务保留稳定媒体 ID 和歌单引用、替换路径与快速元数据，并把同 ID 更新投影到活动播放队列；路径冲突会整体回滚。曲库文件定位只从 React 发送稳定媒体 ID，Rust 从 SQLite 解析现有路径，再用 Windows Shell API 打开资源管理器；实机已确认 201 项真实曲库中的中文文件被唯一选中且没有触发播放。真实缺失媒体与权限异常仍保留为 Windows E2E 门槛。真实 Windows Release 已验证 1180×760 主窗口、420×236 MiniPlayer、窗口几何恢复，以及两种窗口模式左上角的纯小写 `heni` 字标。当前 Release 大小为 16,874,496 bytes，SHA-256 为 `498F0BEB5A2C04E0431EC39D401E702C11A5992E64524E987273E35CC8F93FDD`；详见 `docs/migration/release-evidence.md`。

## 执行 Prompt

你是一名资深桌面应用架构师、Tauri/Rust 工程师和 TypeScript 教练。请在当前 Heni 仓库中，以“可运行、可验证、可学习、可回退”为原则，把现有 Flutter 版 Heni 本地播放器渐进式重构为 Windows 优先的 Tauri 2 + React + TypeScript 应用。

这不是 Dart 到 TypeScript 的逐行翻译，也不是一次 Big Bang 重写。Tauri/TypeScript 是仓库根唯一在建实现；Flutter v1 已完整归档到 `legacy/v1-flutter/`，在 Tauri Windows Release 通过功能等价、真实媒体、数据迁移和安装包验收前不得删除。用户数据始终受保护。

### 1. 先读取事实

开始任何阶段前，必须检查工作区并阅读与任务相关的真实代码和文档，至少包括：

- `README.md`、`strata.md`；
- `docs/project-overview.md`、`docs/architecture.md`、`docs/media-pipeline.md`；
- `research/README.md`；
- `legacy/v1-flutter/logs/plan.md`、`legacy/v1-flutter/logs/windows.md`、`legacy/v1-flutter/logs/paused-platforms.md`；
- `legacy/v1-flutter/` 中的 Flutter domain、queue controller、storage、scanner、playback、ffprobe、player screen、测试和 Windows Runner。

立项基线不是空白 Demo：Flutter 版本已有本地音频/视频、文件和目录导入、曲库、歌单、独立播放队列、四种播放模式、媒体详情、主题/美景、响应式侧栏、自定义标题栏、窗口状态和 JSON 持久化；同时存在约 8,000 行以上的播放器大页面和 1,000 行以上的队列控制器。它们是需要拆解的行为资产，不能照搬成新的超大 React 组件或 store。

### 2. 产品目标和非目标

Windows 首个正式 Tauri 版本必须保持 local-first，并达到当前核心体验的行为等价。开发顺序是 Windows，稳定后再评估 Linux、macOS，最后单独评估 iOS、Android。

首个 Windows 里程碑不包含：

- 在线音源、搜索、抓取或下载；
- 账户、云同步、歌词、均衡器、标签编辑；
- 音频导出、伪无损 FLAC 或 bit-perfect 承诺；
- 同时开发非 Windows 客户端；
- 为展示技术而增加与迁移无关的框架或抽象。

品牌显示采用用户确认的纯文字方案：主窗口和 MiniPlayer 左上角只显示四个小写英文字母 `heni`。不得再使用单字母 `H`/`h` 圆形徽标，也不得把应用内字标改回首字母大写的 `Heni`。

现有视频能力不能静默消失。如果音频 Spike 选择纯音频内核，必须在功能等价矩阵中把视频标为明确的独立 adapter/后续阻塞项，并在切换默认版本前完成或取得用户对降级范围的明确批准。

### 3. 目标技术栈

- 桌面容器：Tauri 2；
- 前端：React + Vite + TypeScript；
- 包管理：pnpm 单根应用，并提交 lockfile；只有出现第二个真实消费者时才升级为 workspace；
- TypeScript：开启 `strict`、`noUncheckedIndexedAccess`、`exactOptionalPropertyTypes`、`useUnknownInCatchVariables`、`noImplicitReturns`；
- 运行时校验：Zod，用于 IPC、旧数据和外部进程输入；
- 客户端状态：Zustand，只保存客户端视图/交互状态；领域规则和 I/O 不得全部塞进 store；
- 持久化：SQLite，schema、migration、事务和 repository 由 Rust 管理；
- 测试：Vitest、Testing Library、Rust 单元/集成测试，稳定后加入 Windows WebdriverIO E2E；
- 样式：原生 CSS、CSS Modules、CSS 变量设计令牌；没有明确收益时不引入大型 UI 组件库；
- 播放候选：优先验证 Symphonia + CPAL 和 libmpv；Web Audio 仅作对照；
- 元数据候选：Lofty/Symphonia 负责快速索引，ffprobe adapter 负责详细探测和视频信息。

必须持续向用户说明：Tauri 不是纯 TypeScript。Rust 工具链、原生音频和操作系统边界是必要组成部分。这里的“TypeScript 核心技术栈”指产品交互、应用用例、契约、展示模型、前端和大部分可移植工程实践以 TypeScript 为主；实时音频、大目录扫描、SQLite 和原生能力由小而明确的 Rust 系统核心承担。

### 4. 冻结的职责边界

```text
React UI
   ↓
TypeScript application/use cases
   ↓
typed ports + Zod contracts
   ↓
Tauri facade（唯一 invoke/listen 入口）
   ↓
Rust commands ─ application services ─ domain/runtime
   ↓                 ↓                    ↓
OS/window        SQLite/scanner      playback engine
```

TypeScript 负责：

- React 组件、主题、布局和可访问性；
- 浏览、筛选、选择、多选、对话框和视图状态；
- 用户操作的 application use case 和可测试纯函数；
- IPC DTO 的 TypeScript 类型、Zod 校验、错误收窄和 adapter；
- 播放 snapshot 的前端投影、4–5Hz position 事件之间的本地平滑；
- 学习文档和组件/应用层测试。

Rust 负责：

- 播放资源、输出设备和实时线程；
- 权威 playback session、活动队列、repeat/shuffle 执行和自动续播；
- SQLite schema/migration/事务/repository；
- 大目录扫描、取消、批处理和路径规范化；
- 元数据/ffprobe、文件系统、窗口、系统媒体控制和其他 OS 能力；
- Release 包中的 native/sidecar 生命周期。

前端可用纯 TypeScript 规则作为交互预览和学习样例，但不得形成第二套会与 Rust 权威播放状态漂移的隐式真相。队列行为通过共享 fixture/契约测试验证两端语义，而不是复制一套未经约束的业务实现。

React 组件不得直接调用散落的 `invoke()`、`listen()`、SQL、文件系统或外部进程。所有桌面调用必须集中在有类型、可替换、可 mock 的 facade/adapter。Tauri command 只做 DTO 校验、调用 use case 和错误映射，不得形成新的超大 `lib.rs`。

当前根结构如下，可用 ADR 解释必要调整：

```text
src/
  app/                        # 启动和依赖装配
  contracts/                  # DTO、Zod schema、错误协议
  features/                   # library、playlist、playback、settings、scenery
  infrastructure/tauri/       # 唯一 Tauri facade
  shared/                     # 有真实跨 feature 复用时才建立
src-tauri/src/
  commands/
  playback/
  library/                    # 相关切片开始时才建立
  storage/
  platform/
```

不要预先创建空包。仓库根就是 walking skeleton；只有出现第二个真实消费者时才考虑提取 workspace package。

### 5. IPC、并发和安全约束

- 启动/重载时先请求完整 playback snapshot，再订阅增量事件；
- command 用于请求—响应；可取消扫描进度使用 Tauri Channel；少量跨窗口通知使用 event；
- playback 事件包含 `generation` 或 `sequence`，丢弃旧播放源的迟到事件；
- position 最多约 4–5Hz，React 在本地插值，禁止逐动画帧 IPC 和全局 store 全树刷新；
- 所有订阅、定时器、音频资源和后台任务都必须有清理/取消路径；
- 音频 callback 不阻塞、不分配、不写日志、不做数据库/IPC；
- 扫描使用后台任务、批量写库、背压和取消，不能阻塞 UI；
- Tauri capability 默认拒绝，只开放应用数据目录和用户明确选择后持久化的曲库 scope；
- 禁止 `csp: null`、`withGlobalTauri: true`、全局 `**/*` 权限；
- 外部程序用结构化参数调用，禁止拼接 shell 字符串；
- 日志和测试产物不得泄露用户完整媒体路径。

建议统一的错误协议是带 `code` 的 discriminated union，例如 unavailable、permission-denied、unsupported-format、decode-failed、stale-generation、database 和 internal；面向用户的信息与可诊断 cause 分开。

### 6. 播放内核必须先 Spike

在大规模迁移 UI 前完成独立播放 Spike 和 ADR，不默认 `<audio>` 足够，也不因某个参考项目能运行就直接采用。

至少比较：

1. Symphonia + CPAL 原生 Rust 管线；
2. libmpv/mpv 受控集成，尤其用于视频等价；
3. WebView2 `<audio>` / Web Audio，仅作复杂度和兼容性对照。

Windows Debug 与 Release 使用真实样本验证 MP3、AAC in M4A/MP4、FLAC、WAV、Opus，以及至少一个常见视频文件。样本覆盖中文、空格、特殊字符、长路径、损坏文件和较长音频。验证：load、play、pause、stop、seek、position、duration、completed、音量、静音恢复、连续切歌、资源释放、设备变化、休眠恢复、WebView 重载、窗口隐藏、打包后的 codec/动态库/sidecar 和许可证。

Spike 还必须记录：首帧/首声延迟、seek 误差、连续切歌内存趋势、CPU、包体、许可证、Windows 部署，以及 Linux/macOS 和移动端的替换成本。没有真实证据不得宣布引擎定案。

对 TypeScript 暴露稳定的 `PlaybackPort`，以用例级命令和 snapshot/event 为核心，而不是大量字段 getter/setter。具体接口以 Spike 为准。

### 7. 数据迁移

Flutter 数据位于 `%APPDATA%/Heni/library.json`，当前 `schemaVersion = 1`。Tauri 首次导入必须：

- 把旧内容视为 `unknown` 并严格校验；
- 导入前创建带时间戳、只读意图的备份；
- 通过单个事务写入有 migration 的 SQLite；
- Windows 路径比较规范化且大小写不敏感，同时保存原始显示路径；
- 缺失文件标为 unavailable，不静默删除歌单引用；
- 可安全重试或明确识别已经导入；
- 失败时回滚且不修改 Flutter JSON；
- 新版稳定前不回写旧 JSON。

初始数据模型至少覆盖：media、library_roots、manual_imports、playlists、playlist_items、settings、schema_migrations 和 import_history。播放队列是否持久化必须先核对现有语义并单独记录。

### 8. Windows 功能等价范围

切换默认实现前，以下项目必须在矩阵中有“通过证据”或“用户批准的差异”：

- 多文件选择、文件夹递归扫描、是否包含视频、载入后自动播放；
- 曲库来源合并、路径去重、刷新、取消和错误恢复；
- 歌单新建、重命名、描述、删除、批量加歌和移除；
- 浏览歌单不打断独立的活动播放队列；
- 立即播放、下一首播放、加入队列、上一首、下一首；
- 顺序、列表循环、单曲循环、随机及当前测试中的边界语义；
- 播放/暂停/停止、seek、duration、position、音量和静音恢复；
- codec、bitrate、sample rate、channels 等媒体信息；
- 音频和现有视频显示/播放；
- 缺失文件状态、重新定位和在资源管理器中显示；
- 中文 UI、Microsoft YaHei 字体策略；
- 主题、美景背景、不透明度、侧栏模式和响应式布局；
- 自定义 Windows 标题栏、拖动、最小化、最大化/还原和关闭；
- 900 × 620 最小可用尺寸，窗口位置/尺寸/最大化恢复；
- 图标、Debug/Release、安装/升级/卸载数据策略。

### 9. 分阶段执行和估时

以下是单人全职、已有 Flutter 行为可参考情况下的规划区间，不是承诺日期。Windows 可用 MVP 约 5–8 周；达到当前主要功能等价、真实 codec 和发布验收约 9–15 周；视频后端、系统媒体控制或安装升级若出现兼容问题，可能另增 1–3 周。

#### Phase 0：基线（2–4 天）

- 现状审计、功能等价矩阵、风险登记；
- 播放 Spike 计划、样本清单、ADR 草案；
- 不改变现有产品行为。

#### Phase 1：Windows walking skeleton（1–2 周）

- 建立严格 TypeScript 的 Tauri + React 工程；
- 最小 capability、统一 IPC facade、错误契约；
- 完成播放候选 Spike；
- 打通“选择文件 → 播放 → 暂停 → seek → 音量 → completed”；
- 至少一个 Windows Release 无 bundle 构建和真实媒体冒烟。

#### Phase 2：播放会话与 TypeScript 应用层（1–2 周）

- 建立 typed ports、use cases、snapshot/event 投影；
- 迁移现有队列行为 fixture 和 TypeScript/Rust 契约测试；
- 完成 repeat/shuffle、队列编辑、异常和重载恢复。

#### Phase 3：曲库和数据（2–3 周）

- Rust 扫描、进度、取消、批量索引；
- SQLite migration/repository；
- 旧 JSON 只读导入和回滚；
- 快速元数据与详细 ffprobe 分层。

#### Phase 4：产品 UI 垂直切片（3–5 周）

- 外壳/标题栏/主题；曲库；歌单；队列；播放器；设置；
- 最后迁移美景舞台、复杂动效和细节；
- 大列表虚拟化，不产生新的超大页面/store。

#### Phase 5：迁移验收（1–2 周）

- 单元、组件、Rust、Windows E2E；
- 真实 codec Release 冒烟、长时间播放、切歌和内存回归；
- 安装、升级、旧数据导入和卸载策略；
- 功能等价矩阵闭环。

#### Phase 6：切换

- 用户明确批准后才把 Tauri 设为默认；
- Flutter 已保存在 `legacy/v1-flutter/`，切换前补稳定 tag/归档记录；
- 删除旧实现需要单独授权。

### 10. TypeScript 学习要求

这不是附带几篇教程，而是通过生产代码学习 TypeScript：

- 每个阶段先用中文说明要用的 TypeScript 概念、为何需要、替代方案；
- 在真实场景展示 discriminated union、readonly、泛型边界、类型收窄、Result 风格错误、纯函数和依赖倒置；
- 禁止 `any` 逃避建模；外部输入从 `unknown` 开始校验；
- 不滥用类型断言、非空断言、全局单例和类型体操；
- 每个关键模块在 `docs/learning/` 留下短文：设计原因、数据如何流动、值得掌握什么；
- 每个里程碑列出建议用户亲自阅读的 3–5 个 TypeScript 文件，并给一个小型练习；
- 高级写法先给直白模型，再说明抽象是否值得；
- 命名表达 Heni 领域含义，不复刻 Flutter/Riverpod 术语。

### 11. 开源参考和许可证

以 `research/README.md` 固定的提交为研究快照：

- musicdl：只借鉴 adapter、统一 DTO、并发/错误隔离；其 PolyForm Noncommercial 代码不得进入 Heni；
- Museek（MIT）：借鉴 Tauri/React 产品切片、播放时钟、缺失资源和发布清单；拒绝整文件 WebAudio 解码、TypeScript 大目录扫描、无迁移 JSON、过宽 capability；
- Luminous（MIT）：借鉴 Rust 权威播放/SQLite/扫描、深用例 IPC 和测试策略；
- WaveFlow（GPL-3.0）：只研究公开行为和通用架构，不复制、改写或移植源码、注释、类型或算法。

Heni 采用 clean-room 独立实现、独立命名和独立测试。新增依赖必须记录用途、维护状态、许可证、二进制分发义务和跨平台影响。任何可能改变 Heni 当前许可证义务的选择都必须先暂停并让用户决定。

### 12. 质量门槛

每个适用里程碑实际运行并报告：

```text
pnpm lint
pnpm typecheck
pnpm test
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
pnpm tauri build --no-bundle
```

稳定后加入 Windows E2E 和正式 bundle。不得把未运行、失败或因环境受阻的检查描述为通过。持久化写入使用事务/原子策略；migration 入库并有测试；依赖应锁定；代码、测试和文档同步更新。

### 13. 每次任务的工作协议

1. 读取仓库事实和工作区，保留用户已有改动；
2. 简短说明本次范围、不会做什么和验收方式；
3. 选择最小可交付垂直切片，优先行为/契约测试；
4. 实现后运行与风险相称的检查；
5. 汇报可观察结果、文件、检查结果、风险和下一步；
6. 遇到普通实现选择时根据本文和 ADR 自主推进，不反复把工程判断抛回给用户；
7. 只有涉及数据破坏、许可证变化、不可逆迁移、付费依赖、范围扩张或本文未覆盖的重大产品取舍时才暂停请求决定。

本 Prompt 已授权在各阶段验收通过后继续推进，不需要再次等待“可以开始”的确认。它不授权删除 `legacy/v1-flutter/`、覆盖旧用户数据、改变开源许可证或发布到外部渠道。

最终成功标准：新 Heni 不只是界面相似，而是在真实 Windows Release 中可靠播放本地媒体，保持队列与歌单语义，安全导入旧数据，具备最小权限和可维护模块边界；同时用户能通过阅读、测试和修改这套代码，逐步掌握 TypeScript 类型建模、应用分层、异步边界、React 状态和完整工程工具链。
