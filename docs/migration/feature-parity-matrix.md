# Flutter → Tauri 功能等价矩阵

更新日期：2026-09-03

状态定义：`基线已记录` 表示 Flutter 行为已有代码/测试证据；`待实现` 表示 Tauri 尚未交付；`竖切通过` 表示范围受限但有自动检查或 Windows 硬件证据；`通过` 只能在完整验收后填写；`批准差异` 必须链接用户决定或 ADR。

| 区域 | Flutter 基线 | Tauri 责任 | 阶段 | 验收证据 | 状态 |
|---|---|---|---:|---|---|
| 选择多个文件 | 音频/视频白名单并加入曲库 | React use case + Tauri dialog/scope | 2–3 | picker、组件、IPC 测试 | 音频队列竖切通过 / 曲库与特殊路径 E2E 待验 |
| 选择目录 | 可配置递归扫描 | Rust scanner + Channel + blocking worker | 3/S2-4 | fixture、取消、组件/Channel 测试；连接换代、晚到 started 清理、取消去重/重试、无终止事件/失败展示与工作线程回归 | 曲库与客户端生命周期代码竖切通过 / 新产物、大目录与实际取消 E2E 待验 |
| 扫描视频开关 | `includeVideo` 默认 true | SettingsPort + Rust SQLite + scanner contract | 3/S2-0 | contract、adapter、Hook、组件与 Rust repository 测试 | 跨重启持久化和扫描消费通过 / 真实重启 E2E 待验 |
| 自动播放开关 | `autoplayOnLoad` 默认 true | SettingsPort + TS import use case + playback command | 2–3/S2-0 | hydration、Partial update 与 App 行为测试 | 持久化消费通过；hydration 不阻塞主操作 / 真实重启 E2E 待验 |
| 曲库来源合并 | 目录和手动文件合并 | SQLite repository | 3 | source mapping/reconcile 测试 | 曲库竖切通过 |
| 曲库搜索/筛选/排序 | 浏览、媒体类型与状态筛选 | TypeScript readonly projection | 4 | 1/100/5,000 项纯函数、组件与 900×620 数据夹具 | 4C 核心竖切通过 / 真实大库性能待验 |
| 路径去重 | 以路径识别媒体 | Rust normalized path key | 2–3 | TS/Rust 大小写和分隔符测试 | 队列、曲库与旧数据导入竖切通过 |
| 缺失文件 | 现有引用仍可能保留 | unavailable + relocate | 3–5 | scan reconcile、稳定 ID/playlist reference、路径冲突回滚、picker/IPC/组件/队列刷新测试 | unavailable/引用保留和事务化换路径 relocate 通过 / 真实 Windows 缺失与权限 E2E 待验 |
| 错误与恢复体验 | 错误状态可关闭并能返回有效操作 | coded error + user-facing presentation | 4–5 | 错误码投影、原始诊断隔离、恢复动作、轮询关闭测试 | 5A 结构化中文提示和文件/目录/曲库恢复竖切通过 / 真实错误 E2E 待验 |
| 新建/改名/描述/删除歌单 | 已实现 | TS use case + Rust repository | 3–4 | repository、Hook、组件测试 | 4D 核心竖切通过，删除二次确认已验 / Windows E2E 待验 |
| 批量加入/移出歌单 | 已实现多选流程 | React selection + Rust transaction | 3–4 | 去重/顺序/回滚、组件测试 | 核心竖切通过 / 大批量 E2E 待验 |
| 曲库与活动队列分离 | 浏览不打断播放 | Rust session + TS projection | 2–3 | App 组件隔离测试 | 浏览隔离竖切通过 / 重载 E2E 待验 |
| 立即播放/下一首播放/加入队列 | 已实现 | typed playback commands | 2–3 | shared contract、session、组件测试 | 核心竖切通过 |
| 上一首/下一首 | 由 playback order 控制 | Rust authoritative session | 2 | order/session/controller + 组件测试 | 队列竖切通过 |
| 当前队列移除 | 删除当前项时播放最近剩余项 | Rust transactional session | 2–4 | session/controller + 组件测试 | 移除、插入与权威重排竖切通过 |
| 列表循环 | repeat all | Rust session | 2 | 首尾 order 测试 | 队列竖切通过 |
| 单曲循环 | repeat one | Rust session | 2 | completed/manual-next 测试 | 队列竖切通过 |
| 随机播放 | 当前项优先，其余洗牌，repeat all | Rust session | 2 | permutation/current-first 测试 | 队列竖切通过 / 确定性压力待验 |
| 播放/暂停/停止 | media_kit adapter | Rust audio adapter + typed playback port | 1/S2-3 | 生产 WAV 硬件冒烟、controller/Hook 测试、91BB Release 真实 FLAC 静音操作 | 多曲与 FLAC 交互竖切通过 / 全格式听感待验 |
| seek/position/duration | stream + slider | 条件快照/位置读取 + 有界局部时钟 + seek 草稿 | 1–2/S2-3 | 时钟/帧生命周期、竞态/恢复、连续按键/焦点/取消测试；91BB 原生 FLAC 拖动、条外松开、连续秒级按键与 Mini 往返；响应共享夹具和 5,000 项 wire-size 测试 | 显示/交互与轻量读取代码竖切通过 / 原生推送、全模式格式与毫秒误差待验；新产物证据见 release-evidence |
| completed 自动续播 | controller 订阅 | Rust session + native monitor | 1–2/S2-3 | controller、两个 WAV 硬件测试、条件读取的续播/末曲/加载失败测试，91BB 真实 FLAC 曲尾跨曲 | 队列与真实 FLAC 竖切通过 / 完整模式和长时待验 |
| 音量/静音恢复 | 0–100，保存 audible volume，拖动中实时试听 | Rust 权威偏好 + SQLite 原子保存 + TS 手势草稿 | 1–2/S2-3 | 数据库重开/坏值/事务回滚、引擎首次加载/失败不变、取消/焦点/旧草稿不复活与错误保持测试；CB8E 仅启动观察 | 持久化代码竖切通过 / 最新源码待重建 exe，重启与听感待验；本切片松开才应用，实时试听差异未获批准，见 ADR 0005 |
| 音频格式 | AAC/AIFF/ALAC/FLAC/M4A/MP3/OGG/Opus/WAV/WMA 候选 | playback backend | 1/5 | codec manifest + Release | 六格式 Spike 通过 / 完整基线待验 |
| 视频播放 | media_kit_video 真正渲染 | libmpv 或独立 video adapter | 1/4 | 真实视频 Release | 基线已记录 / 待实现 |
| 快速元数据 | 扫描后显示已知时长/信息 | Symphonia header index + SQLite v3 | 3 | 六格式扫描、migration、重试保留测试 | 音频索引竖切通过 / 大目录压力待验 |
| 媒体详情 | ffprobe typed model | Rust on-demand detail probe | 3–4 | parser、结构化参数、真实生成 MP4、Zod/Hook/App 测试 | 曲库/播放台按需抽屉竖切通过 / 安装包 sidecar 待审计 |
| 资源管理器定位 | Windows file action | stable media ID + typed port + Rust Windows Shell adapter | 4–5 | IPC/Hook/组件、文件缺失 Rust 测试、真实中文文件选择 E2E | 竖切与真实 Windows 资源管理器选中通过 / 缺失文件实机错误 E2E 待验 |
| 应用框架/常驻播放条 | 主视图切换、底部控制常驻 | React local view state + AppFrame | 4 | App 契约测试、1180×760/900×620 浏览器检查 | 4A 竖切通过 / Windows DPI E2E 待验 |
| 主题和 UI 风格 | 多 palette、美景/歌曲 | CSS variables + SettingsPort + Rust SQLite | 4/S2-0 | 主题契约、adapter/Hook、组件、三主题两档浏览器检查 | 录音室/深夜/潮汐与主题持久化通过 / Windows 重启与 DPI 待验 |
| 美景图片/不透明度 | 多本地图片、全窗口 backdrop | 独立 SceneryPort + Rust 原生选择/限额解码 + SQLite preference | 4/S2-2 | Zod/adapter/Hook/App、源图只读、坏图/超限、数据库重开与回滚测试；分产物实测选图/取消、保存背景恢复、三主题切换和最小窗设置，见 release-evidence | 单图代码切片与部分 Windows 竖切通过；实机清除/源图丢失及完整视觉/DPI 待验，多图与手动不透明度未实现，不视为完整 legacy 等价 |
| 响应式侧栏 | 展开/紧凑、阈值和滞回 | CSS shell breakpoint，模式状态后续接入 | 4 | App 测试 + resize E2E | 4A 84px 紧凑竖切通过 / 模式与滞回待实现 |
| 播放进度响应式 | 狭窄时隐藏时间但保留 seek | React component | 4 | component + 两档 browser resize | 4B wide/compact 竖切通过 / Windows DPI 待验 |
| MiniPlayer | 小窗继续操作当前播放会话 | 同一 PlaybackPort + typed WindowPort + Rust window adapter | 4 | Zod/adapter/App/组件测试、420×236 与 360×220 浏览器检查、真实 Release 往返 | 同会话切换、置顶、返回、关闭后重启与普通几何隔离通过 / 多显示器和 DPI 待验 |
| 队列定位 | 搜索状态下定位/高亮当前项 | readonly projection + local view state | 4 | projection、组件、两档浏览器夹具 | 4D 搜索/定位/当前与下一首/确认清空竖切通过 / Windows E2E 待验 |
| 队列重排 | 拖动队列项并保持当前播放 | Rust authoritative reorder + TS interaction | 4 | shared fixture、session/controller、组件、两档浏览器夹具 | 拖放/键盘权威重排竖切通过 / Windows 指针 E2E 待验 |
| 中文、字体和品牌字标 | 中文 UI、Microsoft YaHei；用户确认纯小写 `heni` | i18n-ready copy + CSS stack + text wordmark | 4–5 | 组件语义、普通/紧凑/MiniPlayer Windows visual smoke | 中文和字体栈已接；单字母徽标已移除，`heni` 字标竖切通过 / Windows 缩放待验 |
| 自定义标题栏 | 拖动/最小化/最大化/关闭 | typed Tauri window facade | 1/4 | Windows E2E | 4F 已建立最小窗口 facade，但故意保留原生标题栏；自定义控制、拖动冲突与系统菜单待 Windows E2E 后启用 |
| 最小窗口 | 普通窗口 900 × 620；MiniPlayer 360 × 220 逻辑客户区 | Tauri config/window API + mode-aware CSS root | 1/4 | 四档 browser resize + Windows DPI smoke | 900×620、420×236、360×220 浏览器竖切通过 / Windows DPI 待验 |
| 窗口状态 | 保存位置/大小/最大化，MiniPlayer 不覆盖普通几何 | official Rust window-state plugin + Heni session geometry | 4/S2-2 | Rust 负坐标/小工作区测试、adapter/App 测试、分产物真实 restart 与最大化/Mini/还原 E2E | 普通矩形/最大化标志分离、边界限位、最大化退出重启与 Mini 往返竖切通过 / Snap、多显示器和真实 DPI 待验 |
| JSON 配置恢复 | `%APPDATA%/Heni/library.json`, v1 | one-time importer + SQLite | 3 | strict schema、exact readonly backup、rollback、idempotence、TS IPC/UI | 隔离夹具竖切通过 / 真实用户数据验收待批准 |
| Windows 图标/Release | 已有 ico 与 Release 记录 | Tauri bundle resources + GUI subsystem entry | 1/5/S2-0 | `--no-bundle` hash、PE subsystem、桌面启动 + 安装包 smoke | unsigned no-bundle GUI Release 通过且无附带控制台 / bundle 待实现 |
| Linux/macOS | Flutter scaffold 暂停 | 后续 adapter 验证 | 6+ | 平台专属计划 | 暂停 |
| iOS/Android | Flutter scaffold 暂停 | 重新评估媒体/权限/后台音频 | 6+ | 独立 ADR | 暂停 |

## 使用规则

- 每个垂直切片完成后更新对应行，不批量乐观标记。
- 自动化证据优先；codec、设备、DPI 和安装包可同时记录人工冒烟。
- 若目标行为与 Flutter 不同，先更新 ADR/用户决定，再标记“批准差异”。
- Flutter 默认实现切换要求所有 Windows 核心行是“通过”或“批准差异”。
