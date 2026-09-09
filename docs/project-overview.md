# Project Overview

Heni 仓库根现在是 Tauri 2 + React + TypeScript 的 Windows 应用。Flutter v1 已归档，不再占用根目录产品入口。

```text
src/                 React、TypeScript contracts、features 和 Tauri adapters
src-tauri/           Rust 系统核心与 Tauri 配置
docs/                当前需求、架构、ADR、迁移和学习记录
spikes/              不进入生产依赖的播放实验
research/            开源研究；upstream checkout 被 Git 忽略
legacy/v1-flutter/   可追溯的 Flutter 旧实现和本地 Windows Release
output/              用户已有的视觉设计产物，不由本次迁移清理
```

## 当前可观察能力

- React ↔ Rust runtime-info 握手；
- 只读启动状态投影区分启动中、就绪、部分可用和核心不可用，浏览器预览不再伪装成桌面核心故障；
- 文件/目录导入的具名跨 feature 工作流，以及有序 CSS 入口和单一主题 token 源；
- S2-2 首切片：完整小写 `heni` 字标、无单字母占位的唱片纹理、中文工作区/启动/详情文案；真实编码名称与测量值不被翻译或改写；
- SQLite settings runtime：主题、递归扫描、视频扫描和导入后自动播放跨重启保存；
- settings hydration 使用安全默认值且不阻塞选择文件/导入目录，保存失败留在设置局部；
- S2-2 美景：独立 port、Rust 原生选图/限额解码、SQLite 保存选择、取消/清除、重启恢复和坏图回退；只显示文件名，不上传或改写源图；
- 曲库默认聚焦标题与音频信息，完整路径和次要操作按需展开；窗口普通矩形与最大化状态分离，并按工作区边界恢复；
- Zod 校验的播放 command/snapshot/error contract；
- Rust 权威 `PlaybackSession` 与失败回滚的 `PlaybackController`；
- generation/sequence 快照投影与匹配媒体身份的位置采样；
- 只开放文件选择的 capability、非空 CSP、900 × 620 最小窗口；
- Windows Release `--no-bundle` 构建和启动冒烟；
- Windows Release 使用 GUI 子系统，直接启动不再附带命令行窗口；
- 正式 Symphonia/CPAL 多曲播放 adapter；
- Rust 权威播放队列、repeat/shuffle、移除与后台 completed 自动续播；
- TypeScript generation/sequence snapshot 投影与共享 IPC command fixture；
- Rust SQLite migration/repository、来源合并、目录扫描/取消/缺失对账；
- Flutter v1 JSON 检测、严格解析、只读备份、单事务导入和幂等历史；
- 歌单 CRUD、批量加入/移除、连续顺序和独立于播放队列的浏览状态；
- SQLite v3 快速元数据索引、状态保留与扫描重试不降级规则；
- 受超时/输出上限保护的 Rust `ffprobe` 详细探测，以及 Zod/React 按需详情投影；
- Phase 4A–4G 互斥主视图、响应式侧栏、状态化播放台、带焦点边界的详情 dialog、wide/compact 播放条、只读曲库投影、浏览优先歌单编辑、活动队列搜索/定位/确认清空与权威重排、三套语义主题与缺图回退背景，以及经过真实 Windows 验证的普通窗口几何恢复与同会话 MiniPlayer；
- Phase 5A 结构化错误展示防火墙、缺失媒体单文件重新定位、SQLite 稳定 ID/歌单引用事务与活动播放队列同 ID 刷新；
- 稳定媒体 ID 驱动的 typed file-action port、Rust Windows Shell adapter，以及真实中文文件的资源管理器选中验证；
- 1180×760 和 900×620 无页面级溢出的浏览器视觉证据；
- 本机可直接启动的 5173 开发端口；Vite、Tauri dev URL 和开发 CSP 保持一致；
- Windows 文件选择、播放/暂停/停止、seek、音量、静音和完成状态界面；
- S2-3 播放显示时钟：接收权威快照时采样单调时间，仅进度控件局部插值；推算上限 750ms，不自行结束或切歌；seek 等待/取消/键盘焦点与迟到请求保护已有测试，Rust 事件订阅仍待实现；
- S2-3 条件读取：稳定播放只传位置/时长/版本，状态变化才传完整队列；TypeScript 与 Rust 共用响应夹具。5,000 项合成队列的响应实测为 133 bytes 对 551,874 bytes，不代表整机性能或原生推送已验收；
- S2-3 音量恢复：Rust 启动前恢复音量、静音与上次非零音量；SQLite 成组保存，失败不改变输出，坏数据静音回退并提示。主窗滑块预览、松开才应用，与 Flutter 实时试听尚有差异；重启和听感按发布记录分别留证；
- 播放/设置五条、曲库/歌单/旧库/扫描/详情十二条 I/O 命令入口移到显式后台工作池；曲库客户端补齐同步防重入、连接换代、迟到结果和扫描取消保护，不回滚已提交数据；Windows 平台入口与真实负载仍待审查和实测；
- 独立 Spike 与生产 adapter 的本机 WASAPI 硬件冒烟。

尚未完成真实缺失/权限 E2E、自定义标题栏的真实 Windows E2E、美景全主题/DPI/异常源图的完整验收、视频、安装器、`ffprobe` sidecar 分发和真实用户数据迁移验收。实机与自动测试分开留证，当前精确产物见 `docs/migration/release-evidence.md`。

## 开发命令

```powershell
pnpm install
pnpm dev
pnpm lint
pnpm typecheck
pnpm test
pnpm build
pnpm tauri build --no-bundle
```

Rust 检查在 `src-tauri/` 执行：

```powershell
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
```

## 归档版本

Flutter 源码、测试、平台工程、历史日志和本地 Windows x64 Release 位于 `legacy/v1-flutter/`。详情及可执行文件 hash 见其中的 `ARCHIVE.md`。
