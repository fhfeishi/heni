# Phase 2：权威播放会话与 TypeScript 投影

状态：第一条队列竖切完成，完整队列用例继续进行  
更新日期：2026-09-01

## 已完成

- Rust `PlaybackSession` 是活动队列、当前项、repeat 和 shuffle 的唯一权威；
- 原生后台 monitor 每 50ms 检查 engine 状态，completed 自动续播不依赖 WebView；
- 多文件选择、显式选曲、上一首、下一首、列表循环、单曲循环和随机播放；
- 删除队列项；删除当前项时事务加载最近剩余项，失败则保持原会话；
- TypeScript 按 `generation/sequence` 合并 command 与轮询 snapshot，拒绝迟到状态；
- TypeScript/Rust 共用 `fixtures/playback/commands.json` 验证 IPC 字段命名；
- 两个生成 WAV 已通过生产 engine 的静音自动续播硬件测试。

## 尚未完成

- 拖拽重排；“下一首播放”和追加已在曲库产生真实调用方后完成；
- position event 与前端局部插值；当前约 3Hz snapshot 轮询只用于最小竖切；
- 进程重启后的队列恢复策略。WebView 重载可从存活的 Rust runtime 重新读取 snapshot，但尚无 Windows E2E；
- 连续切歌 100 次、60 分钟资源趋势、设备切换和休眠恢复；
- 真实音乐文件、特殊路径、损坏文件和完整 codec manifest。

## 下一垂直切片

进入 Phase 3 的最小曲库基座：先建立 Rust SQLite migration/repository 和只读列表 contract，再加入手动文件导入；不在同一步实现目录扫描、旧 JSON 导入和完整歌单 UI。该顺序会给“追加/下一首播放”产生真实消费者，也能先验证数据库事务与路径不变量。

## 验收证据

- TypeScript：当前 12 个测试文件，35 项测试通过；
- Rust：当前 42 项常规测试通过，2 项 Windows 音频设备测试显式执行并通过；
- `pnpm lint`、`pnpm typecheck`、`pnpm build`、Rust fmt/clippy/test 通过；
- 当前 Release 证据见 `release-evidence.md`。
