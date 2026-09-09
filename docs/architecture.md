# Heni Architecture

状态：Strata V3 音频/视频统一会话、玻璃界面与常驻窗口栏实现已落地；视频连续实播、声音同步和完整视觉/DPI 矩阵仍待验收
更新日期：2026-09-10

## 设计目标

Heni 是一个 Windows 优先、local-first 的本地音乐播放器。架构首先服务于可靠播放、清楚的数据边界和可测试性，其次才是复用与扩展。Linux、macOS 和移动端是后续约束，不提前为尚未存在的平台制造抽象。

## 顶层规则

1. 仓库根就是唯一在建产品，不使用只有一层消费者的 workspace 包装。
2. React 负责界面和用户用例；Rust 负责播放资源、权威播放会话、文件/数据库和系统能力。
3. 只有 `src/infrastructure/tauri/` 可以导入 `@tauri-apps/api`。
4. Rust `#[tauri::command]` 是薄边界：反序列化、调用模块、序列化结果；不在 command 中堆业务流程。
5. Rust 播放 session 是运行时唯一真相。前端只持有投影，使用 generation/sequence 和请求 revision 拒绝迟到结果。
6. 外部输入先视为 `unknown`；TypeScript 通过 Zod、Rust 通过 serde 和显式不变量校验。
7. 没有第二个真实消费者前不建立 `packages/`；没有真实替换需求前不建立通用插件系统。
8. 不使用全局事件总线、service locator、万能 store 或“BaseRepository”一类无领域含义的抽象。
9. capability 默认拒绝，路径授权来自用户明确选择；`playback_dispatch` 会再次检查 dialog 写入的临时文件 scope，禁止关闭 CSP 或开放全用户目录。
10. Flutter v1 是只读行为基线，位于 `legacy/v1-flutter/`，不与新代码形成运行时依赖。

## 源码结构

```text
src/
  app/                       # React 根组件与依赖装配
    boot/                    # 纯启动状态投影，不创建第二套状态源
    workflows/               # 仅承载真实跨 feature 用户用例
  contracts/                 # IPC DTO、Zod schema、Result/错误协议
  features/
    library/                 # 曲库、扫描和旧数据导入 Hook/展示
    player/                  # 当前媒体播放控制台
    playlist/                # 歌单外壳、元数据与批量曲目组件
    playback/                # 播放 Hook、队列/播放条、快照/位置投影和用例
    runtime/                 # 本地核心连接状态
    shell/                   # AppFrame、侧栏、主题和窗口视图状态
  infrastructure/tauri/      # 唯一 invoke/listen adapter
  styles/                    # 有序入口、单一 token 源、基础/外壳/功能/响应式样式
  test/                      # 测试环境装配

src-tauri/src/
  commands/                  # 非领域的薄 command，例如 runtime info
  playback/
    contracts.rs             # Rust wire types
    session.rs               # 权威播放会话与不变量
    controller.rs            # session/engine 事务协调与失败回滚
    engine/                  # HybridEngine、Symphonia/CPAL adapter 与 PCM 转换
    video.rs                 # 唯一 WebView 输出的意图、反馈与加载代次
    video/stream.rs          # 本机授权视频流，完整 Range 与有界磁盘读取
    mod.rs                   # Tauri state 和 command adapter
  library/
    repository.rs           # SQLite 查询、事务和路径来源
    playlist_repository.rs  # 歌单 CRUD、顺序去重和批量事务
    scanner.rs              # 后台遍历、批次、进度和取消
    legacy_import.rs        # Flutter v1 严格解析、备份和导入计划
    metadata/               # Symphonia 快索引与 ffprobe 按需详情 adapter
  media_support.rs          # 播放与索引共享的只读 codec registry
  platform/window.rs        # 普通窗口几何与 MiniPlayer 系统边界
  platform/file_action.rs   # 稳定媒体 ID 到 Windows Shell 文件定位
  storage/migrations.rs     # 顺序化 SQLite schema migration
  lib.rs                     # 只做应用装配

spikes/                      # 与生产依赖隔离的技术验证
legacy/v1-flutter/           # 旧实现、历史文档与本地 Release
research/                    # 固定提交的开源研究，不进入产品依赖
```

目录随真实垂直切片增长。曲库、SQLite 或平台模块只在对应功能开始时创建，不预先铺设空目录。

## 依赖方向

```text
React component
      ↓
feature application function / hook
      ↓
typed port + contract
      ↓
Tauri adapter
      ↓
thin Rust command
      ↓
Rust playback / library / storage / platform module
```

禁止反向依赖：contract 不依赖 React，application 不依赖 Tauri，Rust 核心模块不依赖前端概念。

## 播放状态

- Rust `PlaybackSession` 持有 queue、current index、status、position、volume、repeat 和 shuffle；
- 替换播放源增加 `generation`，同一播放源内的状态变化增加 `sequence`；
- React 首次挂载或恢复可见时读取完整 snapshot；随后每 300ms 用 `playback_poll(knownVersion)` 做条件读取。Rust 先同步完成/失败/自动续播，再比较版本：仅当 `generation/sequence` 相同才返回不带队列的 position，否则返回完整 snapshot。位置采样不推进状态版本，前端保留原 queue 引用；
- 接收时原子保存权威投影和带单调采样时间的窄 `PlaybackClockSample`。完整 snapshot 按 `generation/sequence` 投影；position 必须同时匹配版本、媒体 ID 和状态，无法匹配就请求完整恢复。连接内 `latestSnapshot` 仅引用已接受的投影，作为下一次条件请求游标，不产生第二份可编辑队列；
- 同一连接只有一个未完成读取，命令开始前发出的读取还受请求 revision 保护。当前优化减少稳定播放时的传输量和队列复制，不减少 IPC 次数；Rust 事件订阅尚未连接。推送若引入并行采样，必须另有独立采样顺序，不能挪用状态 sequence。见 ADR 0004；
- `projectPlaybackClock` 只推算 playing 的显示位置，上限 750ms，并夹紧到已知 duration；不判定 completed 或自动切歌。`usePlaybackPosition` 仅让进度控件以约 30Hz 更新，隐藏/卸载时取消帧，长时间恢复后不把离线时间冒充音频进度；
- `PlaybackController` 先在 session 副本上验证命令，再执行 engine 操作，只有 engine 成功才提交新 snapshot；
- 正式音频 adapter 使用 Symphonia、rubato、有界 ring buffer 和 CPAL；视频保留独立 adapter 边界并显式拒绝，避免能力降级被隐藏。

播放内核证据见 `docs/adr/0002-playback-engine-spike.md` 和 `docs/migration/playback-spike-results.md`。

## UI 状态

S2-3 音量偏好由 Rust `PlaybackPreferences` 定义，SQLite `settings` 的一个 JSON 值原子保存
volume/muted/lastAudibleVolume；启动先读取，再创建播放核心，首次加载媒体前已经恢复。
缺失键不写库且保留历史默认；损坏／读取失败以静音回退并附带有限 `preferencesError`。
只有音量和静音命令写入：校验候选 → 保存 → 无失败引擎 setter → 提交会话，失败不更改
输出或候选版本。实时音频回调不读写数据库；命令持锁时数据库争用延迟仍待测量。见 ADR 0005。

播放的 snapshot/poll/dispatch 与 settings snapshot/update 已改成异步命令，并在显式
阻塞工作池执行锁等待、读取、加载和保存。AppHandle 仅在边界取得既有 runtime；不建立
第二个连接或 session。客户端生命周期回归全绿后，曲库/歌单/旧库/扫描/ffprobe 的
12 条 I/O 入口也迁入阻塞工作池；取消扫描只接触独立注册表和原子标记，仍使用短同步
入口。Windows 文件定位与窗口线程语义仍待独立核对，不能宣称整个应用已无阻塞风险。
后台任务失败使用有限错误映射，见 ADR 0006、学习 030。

主窗 `PlaybackVolume` 只管理手势草稿与等待，按当前音量／静音校验草稿，不绑定曲目身份。
松开才应用和保存，与 Flutter 拖动中实时试听的差异仍开放。命令错误不会被正常轮询覆盖；
读取恢复警告可关闭，只有明确调节音量／静音才修复保存记录。Mini 使用同一命令和会话。

`projectAppBootState` 是读取既有 Hook 状态的纯投影，不是启动管理器或全局 store。运行时握手
与初始曲库/播放快照尚未完成时为 `booting`；两份快照可用后为 `ready`；缺失基础快照或明确的
浏览器环境为 `degraded`；真实桌面握手失败或契约不匹配为 `blocked`。设置 hydration 仍使用
安全默认值，不加入主流程阻塞条件。已有快照后的普通操作失败继续由 feature 错误处理，不会
因为一次操作错误重置启动状态。

当前限制：Rust 的数据库初始化仍在 Tauri setup 内使用 `?` 返回错误。这里的四态投影
描述已经进入前端后的握手和快照状态，不覆盖数据库初始化硬失败时的可见恢复界面；
该启动错误路径仍需单独设计与隔离故障验证，不能把前端 blocked 单测当成它已经闭环。

Tauri adapter 在唯一基础设施边界调用官方 `isTauri()`，普通浏览器返回有限的
`browser-preview` 原因，不尝试 runtime IPC。App 只在这个明确环境下抑制预期的曲库、播放与
设置自动读取错误，真实桌面错误仍照常呈现。共享 `AppBootState` 是 runtime feature 的只读
视图类型；外壳不反向导入 app 装配层。该投影不承担重试或关闭进程策略。

S2-1 的首个装配收敛切片把“选择本地文件 → 写入曲库 → 按已保存偏好替换活动队列”和
“选择目录 → 按已保存遍历偏好启动扫描”放入 `useLocalImportWorkflows`。该 Hook 只协调已有
typed port 与 feature 操作，不直接导入 Tauri、不复制曲库或播放状态，也不成为通用 manager。
`App.tsx` 仍是依赖装配根，并保留视图选择、重新定位和跨错误恢复这些尚未证明需要继续拆分的
职责。导入工作流使用独立 Hook 测试验证调用顺序和设置快照语义。

Phase 4A 的 `AppView` 是 React 局部字符串联合类型，只决定四个主视图中的哪一个可见。它不进入 Rust snapshot、不写 SQLite，也不经由导航发送 playback command。`AppFrame` 组合顶栏、侧栏、单一主视图、可选 overlay 和常驻 `PlaybackBar`；领域操作仍由原有 feature Hook 与 typed port 完成。这样既避免建立第二套播放真相，也防止 `App.tsx` 再次增长成 Flutter v1 式超大页面。

Phase 4B 的 seek 草稿在 S2-3 收敛为带 `generation/sequence/mediaId` 的局部拖动或等待提交状态。只有身份和序号仍匹配时才显示/提交；切歌或其他原生命令使旧手势失效。提交保留目标位置直到原生 Promise 完成，取消手势不发命令，失败回到权威采样。主窗与 Mini 共用此控件。`usePlayback` 分别维护连接生命周期、读取 revision 和未完成命令数量，避免旧读取覆盖命令、旧 port 回流或并发请求过早解除 busy。媒体详情仍由独立 `useMediaDetails` epoch 管理，与播放时钟无关。

Phase 4C 的曲库搜索、媒体类型、可用性和排序位于纯 `projectLibraryItems` 投影。它只接收只读 snapshot 与局部筛选值，返回新的数组，不调用 repository 或 playback port，也不改变输入顺序。行级展开状态留在 `LibraryItemRow`，避免把 5,000 个条目的 UI 披露状态提升到全局；是否引入虚拟列表要等真实渲染性能证据，而不是因投影规模预先增加依赖。

Phase 4D 用同一原则处理歌单与活动队列。`projectQueueRows` 为每个可见行携带权威 `queueIndex`，搜索不会把可见下标误当作 Rust session 下标；`projectPlaylistMembers` 保留 SQLite 成员顺序与无法解析的媒体引用，`projectPlaylistCandidates` 只计算当前可加入项。搜索、选中歌单、编辑展开和确认框都是组件局部状态，不复制到全局 store。清空确认与拖动均绑定 snapshot 的 `generation:sequence`。队列重排通过共享 command 进入 Rust session，保持当前媒体、generation、position 和 status，只调整 current index、order 与 sequence；controller 不重新加载 engine。React 拖放和键盘按钮只是同一命令的两个入口。

Phase 4E 的主题目录通过只读字面量推导 `HeniThemeId`，`AppFrame` 只接收收窄后的主题值。S2-0 后，主题、递归扫描、视频扫描和导入后自动播放通过 `SettingsPort`、Zod contract、Tauri adapter 与 Rust `SettingsRuntime` 写入同一 SQLite `settings` 表；它们不进入 Rust 播放会话，也不需要全局客户端 store。`useSettings` 在读取期间提供版本化安全默认值，用户主操作不会因 hydration 被禁用；mutation epoch 防止迟到读取覆盖已提交更新。持久化失败只在设置入口显示有限中文状态，不升级成遮挡播放或曲库的全局错误。

S2-2 的 `SceneryPort` 独立提供 read/choose/clear，原生选择器在 Rust 后台任务中打开，IPC 不接受调用者路径。Rust 限制输入为 8 MiB、8192px 单边和 2400 万像素以内的静态 PNG/JPEG，实际解码成功后才把规范路径写入现有 `settings` 表的 `ui.sceneryPath`。解码预算为 128 MiB，不等于整个进程硬内存上限。清除只保存 null，不删除原图；取消不提交。重启仅读取已保存的选择，丢失/坏图保留文件名并回退。没有新增数据库连接、迁移分支、通用 manager 或宽泛 asset scope。

前端通过 Zod 校验有限 data URL 和 empty/ready/unavailable 状态，不接收完整系统路径。`useScenery` 对重复操作同步加锁，并用生命周期 epoch 拒绝迟到结果；失败只显示在设置面板。`SceneryBackdrop` 仍是主窗/Mini 共用的唯一背景层，播放/浏览强度由样式控制，WebView 解码失败也回退主题。data URL 有编码和复制成本，当前单图、不轮询且限额明确；多图/大资源只能在测量后另做资源 ID 与缓存设计。

窗口几何方面，进入 Mini 前先取得普通窗口矩形，并单独保存“曾最大化”的状态；不能把最大化尺寸当成普通尺寸。恢复时按显示器工作区、窗口边框与缩放换算限位，之后再恢复最大化；正常最大化/最小化窗口不做普通尺寸修复。该纯几何计算有边界测试，真实多显示器/DPI 仍按发布矩阵单独验收。

Phase 4F 的窗口边界由 `WindowPort`、Zod snapshot、Tauri adapter 和 Rust `platform/window.rs` 串联。MiniPlayer 是同一 React 树中的窗口视图模式，继续使用同一个 `PlaybackPort` 和 Rust `PlaybackSession`，不是第二个播放器或第二个窗口。官方 window-state 插件负责主窗口跨重启的 size/position/maximized；由于插件会持续观察 resize/move，进入小窗前还要把主窗口几何保存到 `WindowRuntime`，返回或收到关闭请求时先恢复主窗口，再刷新插件状态。启动 snapshot 会修复早期版本留下的非法小窗主界面。原生标题栏和系统装饰保持开启，直到更完整 Windows E2E 能证明自定义拖动、最大化、DPI 和系统菜单语义。

Windows Release 的 `main.rs` 使用 `cfg_attr(not(debug_assertions), windows_subsystem = "windows")`。因此 Release 是 PE `Windows GUI` 子系统，不附带控制台窗口；Debug 构建仍可保留控制台用于本地诊断。该设置只属于二进制入口，不渗入播放、曲库或前端模块。

Phase 4G 把媒体详情抽屉收敛为明确的 modal dialog：组件挂载时保存并接管焦点，Esc 关闭，Tab 留在 dialog 内，卸载后把焦点还给仍存在的触发控件。该状态完全属于组件生命周期，不进入 `App` store 或 Rust。窄窗顶栏只在 CSS 中隐藏重复文案，combobox 和 runtime status 的 aria 名称保持稳定，因此响应式视觉优化不会牺牲语义树。

Phase 5A 在端口错误与 UI 之间增加纯 TypeScript 展示防火墙。`AppErrorContext` 用 discriminated union 同时保留来源和结构化错误，`presentAppError` 穷举有限 `code` 并只返回中文标题、说明和有限恢复意图；原始 `message` 留在诊断边界，不进入 DOM。`AppNotice` 只负责可访问展示和发出恢复意图，文件选择、目录选择和曲库导航仍由 `App` 编排。播放轮询对用户已关闭的同一失败指纹暂时静默，成功 snapshot 或主动 command 会解除静默，因此不会用全局 toast store 或永久吞掉后续故障。

缺失媒体重新定位继续遵守这条依赖链：`LibraryItemRow` 只发出媒体意图，独立 picker port 返回经系统对话框授权的单一路径，Rust command 检查 scope、文件存在性和媒体类型后才进入 repository。SQLite 事务保留旧媒体 ID 和所有歌单外键，只替换路径、标题、可用性与快速元数据；目标路径冲突会整体回滚。若同一 ID 已在活动队列中，`refresh-item` 只更新 Rust 权威 session：非当前项不触碰 engine，当前项在候选 session 中按原位置/状态重新加载，失败不提交队列变化。

文件定位与重新定位共用稳定身份原则，但权限方向相反：`FileActionPort.revealMedia(mediaId)` 只传用户已在曲库中选择的 ID，不允许 React 把任意路径传给系统。Rust 通过 repository 解析当前路径并复核文件存在，再由 `platform/file_action.rs` 调用 Windows Shell 的 UTF-16 PIDL API。这样路径不会回流到 React，也不会经过 `explorer.exe` 命令行或 shell 字符串；缺失文件与 Shell 失败分别映射为有限错误码并由展示防火墙转成用户文案。

## 数据边界

SQLite 由 Rust 持有 schema、顺序 migration、事务和 repository；React 只消费经 Zod 校验的 snapshot/status。目录扫描通过 Tauri Channel 发送有界进度，媒体按 128 项批次写库并在成功完成后对账。

`useLibrary` 在同一端口连接中同步防止重复写入，初始 snapshot 不能覆盖已提交结果；
旧库检测可独立合并，但不覆盖已导入状态。换端口或卸载后，旧回包和回调不再驱动 UI；
晚收到的扫描 started 仍通过原端口取消，取消去重且允许失败重试。扫描命令结束但没有
终止事件时仅显示“已结束”，不冒充 completed/cancelled；失败也不会无限保留 scanning。
本地生命周期取消不撤销已经提交的 SQLite 事务。

`media.id` 是引用身份，不是可随路径变化的显示字段。初次导入仍用规范化路径生成 ID，但重新定位后 ID 保持不变；后续导入/扫描必须按 `normalized_path` 回查真实 ID，再写 `manual_imports` 或 `root_media`。这条规则让路径可以修复，同时避免歌单外键和播放队列媒体身份被静默替换。

元数据采用两层读取：目录扫描和手动导入只用 Symphonia 读取音频容器头，并以 SQLite migration v3 保存 `pending/indexed/failed` 状态和少量快速字段；视频保持 `pending`。完整容器、流、章节和标签只在用户点“详情”时由 Rust `ffprobe` adapter 读取。adapter 不经 shell，限制为 30 秒、8 MiB 标准输出和 128 KiB 错误输出；TypeScript 用请求 epoch 丢弃迟到详情。当前 Release 未捆绑 FFmpeg，开发环境从 `PATH` 查找，安装包 sidecar 必须另行完成许可证与来源审计。

Flutter v1 的 `%APPDATA%/Heni/library.json` 只读迁移由 `legacy_import` 负责：固定来源检测、serde 严格校验、32 MiB 上限、SHA-256 留证和新应用目录只读备份先于数据库写入；目录、媒体、歌单、设置和 `import_history` 在一个 `IMMEDIATE` 事务中提交。启动只检测，真实导入必须由用户点击，旧 JSON 永不回写。

## 样式边界

`styles/global.css` 只声明固定导入顺序。`tokens.css` 持有默认语义变量和三套主题覆盖；
`base.css` 持有元素默认值与焦点规则；`shell.css` 持有外壳和共享控件；now-playing、queue、
library、playlist、playback 按功能收敛；feedback 与 responsive 最后加载。此次先保留已有
选择器、声明值和功能规则的级联顺序，不引入 CSS-in-JS 或 UI 框架。S2-2 可逐步改进视觉，
但主题值只能在 token 源中定义。Windows 主要尺寸已目视复核，浏览器 DOM 与 DPI 证据仍待补齐。

S2-2 的首切片仅修改展示层：启动/媒体类型的中文标签由有限类型映射穷举，codec 名称、
路径、媒体标签和采样参数保留来源事实。纯装饰唱片由 CSS 语义 token 绘制，保持
`aria-hidden`，不引入图片资源、共享状态或独立资源管理器。应用内字标只使用 `heni`。
四工作区集成测试和媒体详情组件测试守住这条边界；UI 文案调整不改变 IPC、SQLite 或
Rust 权威播放行为。后续视觉切片仍须补齐浏览器精确视口与 DPI 证据。

## 模块增长准则

出现以下信号时才拆模块：

- 一个文件承担两个独立变化原因；
- 测试需要启动与目标行为无关的基础设施；
- 同一协议出现第二个真实 adapter；
- 一个 feature 的公开 API 已能用少量领域操作表达。

不以行数本身机械拆文件，但页面、store 或 Rust module 接近数百行且混合 UI、I/O、状态机时必须审查职责。抽取后的名称必须表达 Heni 领域含义。
