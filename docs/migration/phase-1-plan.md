# Phase 1：Windows Walking Skeleton（首个 1–2 周）

状态：音频竖切已完成，发布级媒体门槛继续执行  
目标：得到一个严格 TypeScript、最小权限、可测试的 Tauri 壳，并用真实证据选择播放后端。

## 进度（2026-09-01）

- [x] pnpm 单根应用、React/Vite/Tauri 和依赖 lockfile；
- [x] Flutter v1 源码与 Windows Release 归档到 `legacy/v1-flutter/`；
- [x] strict TypeScript、ESLint、Vitest/Testing Library；
- [x] typed runtime contract、Zod 校验、唯一 Tauri facade；
- [x] 最小文件选择 capability、非空 CSP、900 × 620 最小窗口；
- [x] Rust command 单元测试、Clippy 和 Windows Release `--no-bundle`；
- [x] Release 可执行文件短时启动驻留冒烟；
- [x] playback command/snapshot/event contracts 与 generation/sequence 投影；
- [x] Symphonia + CPAL 音频 Spike、测量结果和 ADR-0002 定案；
- [x] “选择文件 → load → play/pause/stop → seek → volume/mute → completed”单曲竖切；
- [x] Windows `--no-bundle` Release 构建、SHA-256 记录和生产音频硬件测试；
- [ ] libmpv 视频 adapter、真实媒体 manifest、设备/长时/连续切换发布验证。

Phase 1 已把正式 Tauri/Rust 音频链路打通。Phase 2 已在其上增加多选队列和后台自动续播；曲库、SQLite、视频和完整 UI 仍未完成。功能等价矩阵只对实际证据标记“竖切通过”。

## 交付物

1. 仓库根可启动的 Tauri 2 + React + TypeScript 工程；
2. pnpm 单根应用、lockfile、strict TypeScript、lint、Vitest；
3. 无散落 `invoke/listen` 的 typed Tauri facade；
4. playback command/snapshot/event/error contracts；
5. 最小 capability 和非空 CSP；
6. Symphonia + CPAL、libmpv、WebAudio 对照的 Spike 记录；
7. “选择文件 → load → play/pause → seek → volume → completed”最小界面；
8. Windows Release `--no-bundle` 和真实媒体结果；
9. 更新后的 ADR-0002、等价矩阵和 TypeScript 学习笔记。

## 建议节奏

### 第 1–2 天：工程壳

- 建立单根应用、React/Vite/Tauri、严格 TS 和测试；
- 建立 app shell、依赖装配、错误边界；
- 配置 Windows 原生窗口、900 × 620 最小尺寸和最小 capability；
- 验证 dev、typecheck、test、Rust check、前端 build。

### 第 3–4 天：契约和观测

- 定义 `PlaybackCommand`、`PlaybackSnapshot`、`PlaybackEvent`、`AppError`；
- 建立 Zod schema 和 facade mock；
- 建立 generation/sequence、snapshot rehydrate、position clock 测试；
- 写第一篇 `docs/learning/`：discriminated union 与 runtime validation。

### 第 5–8 天：播放候选

- 先做最小 Symphonia + CPAL adapter；
- 并行或随后验证 libmpv 的音频/视频、动态库和许可证；
- 用 WebAudio 仅测对照指标，不沿用整文件 `arrayBuffer` 作为正式设计；
- 每个候选通过同一 manifest 和命令序列。

### 第 9–10 天：Windows 证据和定案

- Debug/Release、连续切歌、seek、设备/重载冒烟；
- 收集结果，更新 ADR-0002；
- 关闭或列出阻塞项，更新功能等价矩阵；
- 给出 Phase 2 的最小垂直切片。

## 首次骨架的范围限制

- 不迁移完整 Flutter UI；
- 不写 SQLite 正式 schema；
- 不导入旧 JSON；
- 不实现歌词、在线内容、均衡器或移动端；
- 不提交未经许可的音乐样本；
- 不让新代码依赖 `legacy/v1-flutter/`，不覆盖旧 Release 或旧用户数据。

## 验收命令

```text
pnpm lint
pnpm typecheck
pnpm test
pnpm build
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
pnpm tauri build --no-bundle
```

第一天不要求所有未来命令立即存在，但新增工程骨架必须至少通过 lint、typecheck、Vitest、前端 build、Rust fmt/check/test。native playback 和 Release 构建在 Spike 定案前完成。

## TypeScript 学习目标

- 理解 `unknown` 与 Zod runtime schema 的关系；
- 用 discriminated union 表达命令、事件和错误；
- 用 readonly snapshot 避免 UI 隐式改写权威状态；
- 理解 port/adapter 如何让 React 测试不启动 Tauri；
- 理解订阅清理、异步竞态与 generation token。

建议用户优先阅读：contracts、Tauri facade、playback clock、一个 use case、对应的 Vitest。阶段结束时给一个“新增 buffering 事件并补测试”的小练习。
