# Phase 5：迁移验收计划

更新日期：2026-09-02

## 目标

Phase 5 不再增加未经基线支持的新产品范围，而是把 Phase 1–4 的竖切变成可发布、可回归、可解释的 Windows 产品。每一项仍遵守 `docs/task-demand.md`：自动检查不能替代真实 codec、DPI、设备、安装与用户数据证据；尚未验证的能力不得标记为“通过”。

## 5A：错误与缺失状态恢复

状态：错误展示、换路径重新定位和 Windows 资源管理器定位竖切完成，真实缺失/权限 E2E 继续待验。

已完成：

- `AppErrorContext` 保留 picker、directory picker、library、media details、playback 和 window 的来源信息；
- `presentAppError` 穷举当前有限错误码，输出稳定中文标题、说明和有限恢复动作；
- Rust/transport 的原始 `message` 不进入 DOM，测试以包含私有 Windows 路径的诊断字符串验证隔离；
- 文件选择、目录选择和曲库导航分别走真实既有用例，不用无效“重试”按钮装饰界面；
- 缺失媒体行明确说明曲库和歌单引用仍被保留，播放、下一首和入队保持禁用；
- 同一 snapshot 轮询错误被关闭后暂时静默；成功 snapshot 或主动 command 会解除静默；
- 提示使用 `role="alert"`、可访问标题/说明和明确的关闭名称，MiniPlayer 使用两列紧凑布局。
- 按用户确认的品牌决定，主窗口与 MiniPlayer 左上角统一为纯小写 `heni` 字标；移除圆形单字母 H，并让完整字标在 900px 紧凑顶栏继续可见。
- 缺失媒体行把“重新定位”作为主恢复动作；单文件 picker 按音频/视频类型限制候选并把授权路径交给 typed IPC；
- Rust 在即时事务内保留旧媒体 ID、歌单引用和来源关联，替换真实路径、标题、可用状态与快速元数据；目标路径已属于其他媒体时整体回滚；
- 播放会话新增同 ID `refresh-item` 命令：非当前项只刷新队列数据，当前项按原播放位置和状态重新加载，失败时不提交候选 session；
- 重定位后的再次手动导入或目录扫描会回查真实媒体 ID，不再错误假设 ID 永远等于最新规范化路径。
- `FileActionPort` 只接收稳定媒体 ID；React 不把本机路径交给平台 API，Tauri adapter 也不接受任意路径输入；
- Rust 从 SQLite 解析当前可用路径，先确认文件存在，再通过 `ILCreateFromPathW` 与 `SHOpenFolderAndSelectItems` 传递 UTF-16 结构化数据，不启动 shell 或拼接命令字符串；
- Windows Release 已从 201 项真实曲库定位中文文件 `阿杜 - 他一定很爱你_EM.flac`，资源管理器显示“选中 1 个项目”，且 Heni 未发送播放命令。

边界：当前实现和隔离测试已经覆盖 media identity、playlist reference、路径冲突回滚、播放边界与文件定位的可用/缺失分支，但尚未拿用户真实缺失媒体执行写入式 E2E，也尚未实机触发文件在点击前消失的错误提示。

## 5B：Windows 视觉、DPI 与可访问性

- 在 100%、125%、150% 缩放下检查 1180×760、900×620、MiniPlayer、原生标题栏、焦点和弹层；
- 使用对比度工具审计三套主题的正文、弱文本、焦点、危险态和选中态；
- 用键盘覆盖主导航、筛选、队列重排、dialog、错误恢复和 MiniPlayer；
- 记录 WebView2 下拉、拖放和多显示器坐标的真实限制，不用浏览器模拟冒充 Windows 证据。

## 5C：真实媒体与稳定性

- Release 覆盖 MP3、AAC/M4A、FLAC、WAV、OGG/Opus，以及中文、空格、特殊字符、长路径和损坏文件；
- 验证 load、play、pause、stop、seek、completed、连续切歌、repeat/shuffle、音量与静音；
- 记录首声延迟、seek 误差、CPU、内存趋势、资源释放、设备切换、休眠恢复和 WebView 重载；
- 完成 ffprobe sidecar 来源、版本、许可证、哈希和无 PATH 环境检查。

## 5D：安装、升级与数据安全

- 启用并验证 Windows 安装包前先冻结产品名、标识、安装范围和签名策略；
- 从干净环境安装，验证启动、媒体选择、曲库、重启和卸载后的数据策略；
- 从前一个 Tauri 版本升级，确认 SQLite migration、窗口状态和设置不回退；
- 真实 Flutter v1 数据只在用户批准后读取；先备份、校验、导入、复核幂等和回滚，再记录证据；
- 安装/卸载不得删除用户媒体；应用数据的保留或移除规则必须在界面和文档中一致。

## 5E：功能等价与切换门槛

- 逐行关闭 `feature-parity-matrix.md`；
- 视频必须交付独立 adapter，或由用户明确批准首版差异；
- 自定义标题栏只有在原生标题栏的系统菜单、拖动、缩放、DPI 和辅助功能证据可被保持时才启用；
- Flutter v1 保留在 `legacy/v1-flutter/`，默认实现切换和删除旧实现都需要用户单独批准。

## 当前证据

- TypeScript/React：32 个测试文件、119 项通过；
- Rust：67 项常规测试通过，3 项环境测试默认忽略且已在前序里程碑显式执行；
- lint、strict typecheck、production build、Rust fmt/clippy：通过；
- Windows no-bundle Release：16,874,496 bytes，SHA-256 `498F0BEB5A2C04E0431EC39D401E702C11A5992E64524E987273E35CC8F93FDD`；
- 本轮实机：当前 hash 在 1180×760 启动、运行时就绪并读取含 201 项的 SQLite 曲库；从可用音频的次级操作打开 `songs` 资源管理器并唯一选中中文目标文件，未触发播放。前序同日实机已完成主窗口与 420×236 MiniPlayer 往返，左上角均为完整小写 `heni` 字标且无裁切。

## 下一步顺序

1. 建立可重复的真实缺失/权限/损坏媒体 E2E 夹具，并实机验收重新定位与文件定位错误提示；
2. 执行 125%/150% DPI、对比度和键盘矩阵；
3. 执行真实 codec、长时播放、连续切歌和内存回归；
4. 冻结并验证 installer/upgrade/uninstall，再处理视频和最终矩阵。
