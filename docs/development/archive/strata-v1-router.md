# Heni Project Router

先从最小相关文档集合开始，避免每个任务加载整份历史。

## 当前执行基线

- 第二阶段唯一需求入口：`strata-v2.txt`；
- `docs/task-demand.md` 是第一阶段历史需求，不再作为后续工作的最高执行基线；
- 旧 Phase 0–6 进度用于追溯，当前工作按 `strata-v2.txt` 的 S2-0 → S2-5 执行。

## 必读入口

- 产品与目录：`docs/project-overview.md`；
- 依赖方向和不变量：`docs/architecture.md`；
- 第二阶段完整需求授权：`strata-v2.txt`；
- 第一阶段历史需求：`docs/task-demand.md`；
- 功能等价：`docs/migration/feature-parity-matrix.md`。

## 按任务路由

- 播放、codec、seek、设备：`docs/media-pipeline.md` →
  `docs/adr/0002-playback-engine-spike.md` →
  `docs/migration/playback-spike-results.md`；
- React/TypeScript contract：`docs/architecture.md` → `docs/learning/` →
  `src/contracts/` 和目标 feature；
- Tauri/Rust IPC：`docs/adr/0001-tauri-system-boundary.md` →
  `src/infrastructure/tauri/` → `src-tauri/src/`；
- Flutter 行为、旧数据或回退：`legacy/v1-flutter/ARCHIVE.md` →
  `legacy/v1-flutter/docs/` 和目标旧源码；
- 开源参考或许可证：`research/README.md`。

## 工作规则

- 根目录是唯一在建应用；Flutter v1 只读归档。
- 保留用户改动和 `output/` 视觉产物。
- 没有第二个真实消费者前不创建共享 package。
- UI 不直接调用 Tauri；command 不承载大块业务。
- 实际运行检查失败时记录原始结果，不把未运行项目描述为通过。
