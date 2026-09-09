# Phase 3：曲库与数据

状态：核心曲库、旧数据迁移、歌单与元数据竖切完成  
更新日期：2026-09-02

## 已完成

- rusqlite 0.40.2 + bundled SQLite，以 Rust 管理连接、migration 和事务；
- 初始 schema 覆盖 `media`、`library_roots`、`manual_imports`、`root_media`、`playlists`、`playlist_items`、`settings`、`schema_migrations` 和 `import_history`；
- 手动选择文件先事务写曲库，再进入活动播放队列；
- SQLite 中的已授权媒体可在 WebView/进程状态变化后重新加入播放队列；
- 目录选择、递归和视频扩展名开关；
- 后台扫描、Tauri Channel 有序进度、取消令牌、组件卸载清理；
- 128 项有界批次写库，符号链接跳过，路径顺序稳定；
- root/media 来源映射与 scan token 对账；仅成功完成时标记未见媒体 unavailable，取消不破坏旧记录；
- 曲库项目可立即播放、设为下一首或加入队列；
- 固定查找 `%APPDATA%/Heni/library.json`，启动只检测，用户显式确认后才导入；
- `deny_unknown_fields` + schemaVersion 1 + 32 MiB 上限，拒绝未知字段、错误类型和未来 schema；
- 导入前在新应用数据目录创建字节一致、带时间戳的只读备份；
- 目录来源、手动文件、已知时长、歌单路径引用和可迁移设置在单个 SQLite `IMMEDIATE` 事务写入；
- 缺失歌单引用保留为 unavailable media；任一外键/数据库失败会回滚全部写入；
- `import_history` + SHA-256 指纹留证，同一 Flutter v1 来源成功后重复调用成为无写入成功；
- React 只展示检测状态和显式导入按钮，adapter 用 Zod 校验 status/outcome。
- `LibrarySnapshot` 同时返回有顺序的歌单与媒体路径引用，缺失媒体仍可显示；
- 歌单新建、名称/说明更新、删除、批量加入和移除均由 Rust repository 执行；
- 加入操作按请求顺序去重追加，重复调用不改变已有顺序；移除后在同一事务重写连续 position；
- 任一媒体或歌单不存在时整批回滚，单次变更最多接受 10,000 个媒体 ID；
- TypeScript Hook 统一投影事务后的完整 snapshot，组件按元数据、曲目选择、外壳三类职责拆分；
- 浏览歌单只修改 React 局部选择，不向 playback port 发命令。
- SQLite migration v3 为媒体补充 `pending/indexed/failed` 状态与快速字段，重复 pending 导入不会擦除已有 indexed 结果；
- 手动导入和目录扫描用 Symphonia 读取音频容器头，不解码整首文件、不读取封面；视频保持待详细探测；
- 快速索引覆盖时长、codec、采样率、声道、位深、文件大小和明确标注的估算码率；
- `ffprobe` 只在用户请求媒体详情时执行，路径由 SQLite media id 解析，不接受前端任意路径；
- 外部进程不经 shell，限制 30 秒、8 MiB stdout、128 KiB stderr，并限制流/章节数量；
- 容器、音视频流、章节、标签和精确码率映射为 Rust/TypeScript 类型，Zod 在进入 React 前验证；
- 详情 Hook 使用请求 epoch 丢弃迟到结果，查看详情不会改变活动播放队列；
- 真实生成 MP4 已通过 production process runner；FFmpeg 尚未进入 Heni 分发物。

## 下一步

1. 大目录压力、权限错误、中文/长路径与 Windows E2E；
2. 在用户批准且有可恢复副本的环境中执行一次真实 Flutter v1 导入验收；
3. 安装包阶段审计 FFmpeg 来源/许可证并配置受控 sidecar，不依赖用户 `PATH`。

## 当前限制

当前扫描会保存视频候选，但纯音频 adapter 会禁用其播放按钮；这不代表视频等价已完成。完整详情当前从 `PATH` 查找 `ffprobe`，安装包尚未自包含该能力。迁移链路只用隔离测试夹具验证，未读取或修改用户的真实 Flutter JSON。当前 Release 是无安装器里程碑。
