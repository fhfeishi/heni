# Heni

Heni 是一个 Windows 优先、local-first 的本地音乐播放器，正在以 Tauri 2 + React + TypeScript 重构。仓库根是新的唯一开发入口；Flutter v1 已完整归档到 `legacy/v1-flutter/`。

## 当前状态

当前开发以 [Strata 开发工作台](docs/development/README.md) 为唯一入口，不再以 V2 为执行基线。
请先读 [当前任务与接续信息](docs/development/status.md)，按需查阅
[已实现功能](docs/development/features.md)。构建与校验值保存在变更记录中。

近期已实现六主题/玻璃与场景控制、顶部视图工具栏、设置分区、视频统一输出及歌单行播放、
跨歌单添加、定位和多选移除。视频真实连续播放、背景显露 100–300、实时音量试听与发布矩阵
仍未完成，不能宣布已全面替代旧版。

### 早期阶段记录（历史快照，不代表当前验收）

Phase 0–3 的核心竖切已完成；Phase 4A–4G 产品框架、播放台、曲库、歌单、活动队列、主题、窗口体验和首轮可访问性收口已经落地：

- Tauri/React/strict TypeScript 工具链可运行；
- React ↔ Rust typed IPC 边界已建立；
- 播放 command、snapshot、error 和 generation/sequence 竞态规则已有测试；
- Rust `PlaybackController` 以事务方式协调权威 session 与原生音频 adapter；
- Symphonia + CPAL 已作为正式音频路径接入，支持本地多选、播放/暂停/停止、seek、音量和静音；
- Rust 是活动播放队列的唯一权威，已支持选曲、上一首/下一首、repeat、shuffle、移除和 completed 自动续播；
- TypeScript 会按 `generation/sequence` 拒绝迟到的 snapshot，IPC command fixture 由两端共同验证；
- 播放进度采用独立的有界显示时钟，仅在进度控件局部插值；拖动等待原生结果时保留目标和键盘焦点，取消不跳转，连续方向键仍按一秒移动；真实 FLAC 的暂停/seek、Mini 往返与自动续播已按 Release 留证；
- 稳定播放时的后台读取不再反复传输整条队列，状态变化后仍由 Rust 返回完整结果；采样不打断拖动，自动续播和错误状态不会由前端计时器猜测；
- 音量、静音和上次非零音量由 Rust 成组保存，加载首曲前恢复；坏设置静音回退，保存失败不假装成功。音量滑块先预览、松开才应用，拖动中实时试听仍待补齐；
- Rust SQLite 已接入：手动文件与目录扫描可持久化，扫描支持 Channel 进度、取消、批次写入和缺失文件对账；
- 曲库写入有同步防重入和连接生命周期保护，退出后晚开始的扫描仍会请求取消；扫描失败或结束通知缺失时不再一直显示运行中。播放、设置、曲库、扫描和详情入口的阻塞操作已移入后台工作池，Windows 平台入口与真实负载继续审查；
- Flutter v1 JSON 支持严格检测、显式导入、只读备份、SQLite 单事务和幂等历史；
- 歌单支持新建、改名/说明、删除、批量加入/移除，并保持独立于活动播放队列；
- 音频导入/扫描会用 Symphonia 快速索引时长、codec、采样率、声道、位深、文件大小和估算码率；
- 媒体完整详情通过按需 `ffprobe` adapter 读取，TypeScript 会校验返回契约并拒绝迟到结果；
- 正在播放、曲库、歌单和播放队列已迁入互斥主视图，响应式侧栏与底部播放条跨视图常驻；
- 当前媒体可从播放台打开按需详情抽屉，播放条会在 900px compact 与宽屏时间布局间切换；
- 曲库支持本地只读搜索、音频/视频、可用/缺失筛选和标题排序，次级操作不再挤占每一行；
- 歌单主区以摘要和成员浏览为主，元数据按需编辑；成员与候选曲目可独立搜索，删除必须二次确认；
- 活动队列可搜索、定位当前项、突出下一首、确认清空，并用 Rust 权威命令支持拖放或键盘重排；筛选与重排都不会形成第二套前端队列真相；
- 外壳提供录音室、深夜、潮汐三套语义主题，单一背景层按播放/浏览切换处理强度，图片缺失时始终回退主题渐变；
- 主题、递归扫描、视频扫描和导入后自动播放已通过 typed settings port 持久化到 Rust SQLite；设置读取不阻塞主操作，保存失败只在设置入口提示；
- 设置中的“美景背景”可选择本地静态 PNG/JPEG，验证后保存选择；取消/失败保留原偏好，源图不可读时回退主题，清除不删除原图；图片不上传；
- 官方 Tauri 窗口状态插件负责主窗口跨重启恢复；Heni 在当前会话保存主窗口几何，从 MiniPlayer 返回或直接退出时先恢复，避免小窗覆盖普通窗口状态；
- 媒体详情以 modal dialog 呈现，具备初始焦点、Esc 关闭、Tab 边界和焦点回还；900px 顶栏会收起重复文字但保留可访问名称；
- Phase 5A 已把结构化错误码投影成稳定中文提示与真实恢复动作，底层诊断和本机路径不会直接进入界面；重复轮询错误关闭后不会持续弹回；
- 缺失媒体可从曲库行选择新的同类型文件；Rust 在事务内保留稳定媒体 ID 和歌单引用、替换路径与快速元数据，活动播放队列按同一 ID 刷新；
- 曲库可按稳定媒体 ID 请求“在资源管理器中显示”；Rust 从 SQLite 解析已授权路径并通过 Windows Shell API 以 UTF-16 结构化参数定位文件，React 不接收或拼接系统路径；
- 文件选择、曲库导入与活动队列替换，以及目录选择与扫描，已收敛为可独立测试的具名应用工作流；`App.tsx` 继续只做清楚的顶层装配，没有引入万能 manager 或全局 store；
- 应用内左上品牌统一为纯小写 `heni` 文字，不使用单字母 H/h 徽标；普通、紧凑和 MiniPlayer 模式保持同一字标；
- 1180×760、900×620、420×236 和 360×220 浏览器视口已完成视觉与溢出检查；
- Windows Release 已实际验证 1180×760 主窗口、420×236 MiniPlayer、返回几何恢复和 Mini 中退出后的重启恢复；
- Windows Release 已标记为 PE `Windows GUI` 子系统，直接运行 `heni-desktop.exe` 不再附带命令行窗口；
- 六种合成格式、重采样、底层控制原语和生产 WAV 硬件冒烟已通过；
- 设备变化、长时压力、真实媒体矩阵、真实旧数据验收、`ffprobe` 安装包 sidecar 和 libmpv 视频 adapter 尚未完成。

Strata V2 的 S2-0 绿色基线已经恢复；S2-1 的导入 workflow、启动状态投影和样式拆分已落地，浏览器截图/DOM 与 125%/150% DPI 验收仍待补齐。S2-2 已落地品牌/中文文案、曲库密度和美景设置切片：应用内只保留完整 `heni` 字标，次要路径按需展开，本地图片选择通过独立 port 与 Rust 验证/持久化连接。普通窗口矩形和最大化状态已分开保存，避免 Mini 切换污染恢复尺寸。当前仍未完成整体视觉重建。真实缺失媒体 E2E、完整背景/主题/DPI 矩阵、自定义 Windows 标题栏、对比度工具审计和完整真实媒体/错误状态 E2E 尚未达到 Flutter 功能等价。精确产物和实机范围见 `docs/migration/release-evidence.md`。原生标题栏会保留到自定义 chrome 的拖动、DPI 和系统行为有可靠证据之后。

## 技术栈

- Tauri 2、Rust；
- React 19、TypeScript 6、Vite；
- Zod runtime validation；
- Vitest、Testing Library、ESLint；
- pnpm，依赖由 lockfile 固定。

SQLite 已由 Rust 按真实曲库用例引入；客户端状态库仍只在出现明确消费者时再加入。

## 快速开始

需要 Node.js 22+、pnpm 11+、Rust 1.95+ 和 Tauri Windows prerequisites。

完整媒体详情当前还要求 `ffprobe` 可从 `PATH` 找到；快速音频索引与播放不依赖它。正式安装包不会在许可证和二进制来源审计前静默捆绑本机 FFmpeg。

```powershell
pnpm install
pnpm dev
```

质量检查：

```powershell
pnpm lint
pnpm typecheck
pnpm test
pnpm build
cd src-tauri
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
cd ..
pnpm tauri build --no-bundle
```

## 顶层目录

```text
src/                 TypeScript/React 产品代码
src-tauri/           Rust 系统核心
docs/                当前架构、ADR、迁移与学习记录
spikes/              与生产隔离的技术实验
research/            固定提交的开源项目研究
legacy/v1-flutter/   Flutter v1 源码、历史记录和本地 Release
```

现行执行基线见 [Strata V3](docs/development/strata-v3.txt)，完整依赖方向和设计约束见
`docs/architecture.md`。

## 文档入口

- 开发入口：[docs/development/README.md](docs/development/README.md)；
- 第二阶段历史需求：[Strata V2](docs/development/archive/strata-v2.txt)；
- 第一阶段历史需求：[Task Demand V1](docs/development/archive/task-demand-v1.md)；
- 项目结构：`docs/project-overview.md`；
- 顶层架构：`docs/architecture.md`；
- 媒体管线：`docs/media-pipeline.md`；
- 功能等价矩阵：`docs/migration/feature-parity-matrix.md`；
- 播放 Spike 结果：`docs/migration/playback-spike-results.md`；
- 架构决策：`docs/adr/`；
- TypeScript 学习记录：`docs/learning/`；
- Phase 4 UI 重构计划：`docs/migration/phase-4-plan.md`；
- Flutter v1 归档说明：`legacy/v1-flutter/ARCHIVE.md`。

## 数据保护

Flutter v1 的 `%APPDATA%/Heni/library.json` 仍是用户数据基线。Tauri 启动只检测它；用户显式点击后才会在新应用数据目录创建只读备份并通过事务导入，任何时候都不覆盖或删除旧文件。
