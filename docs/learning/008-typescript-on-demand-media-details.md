# 008：按需媒体详情、运行时校验与迟到结果

元数据切片刻意分成“列表需要的快速索引”和“用户点开后才需要的完整详情”。前者属于持久化 snapshot，后者是短生命周期的查询结果。它们如果共用一个巨大对象，扫描速度、SQLite schema、React 列表渲染和外部进程错误就会互相耦合。

## 建议阅读

1. `src/contracts/library.ts`：快速元数据、详细流/章节 DTO 和错误码；
2. `src/infrastructure/tauri/libraryPort.ts`：`unknown` 如何经 Zod 成为 `MediaDetails`；
3. `src/features/library/useMediaDetails.ts`：异步请求 epoch 如何拒绝迟到结果；
4. `src/features/library/MediaDetailsPanel.tsx`：组件只渲染已经验证的只读数据；
5. `src-tauri/src/library/metadata/mod.rs`：扫描期的 Symphonia 快索引；
6. `src-tauri/src/library/metadata/ffprobe.rs`：外部进程、资源上限和 JSON 映射边界。

## TypeScript 学习点

`LibraryItem` 中的 `metadataStatus` 是有限字符串联合：`pending | indexed | failed`。它比 `hasMetadata: boolean` 更能表达状态，也让 UI 可以穷举不同文案。`fastMetadata` 仍然允许为 `null`，因为“状态已知”和“每个字段都有值”是两件不同的事。

完整详情从 Rust 到达 TypeScript 时仍是 `unknown`。静态类型不会自动验证 IPC 数据，所以 adapter 必须执行 `mediaDetailsSchema.safeParse`，只有成功后才返回 `Result<MediaDetails, LibraryError>`。React 因而不需要类型断言，也不需要在每个字段访问处重新防御任意对象。

`useMediaDetails` 每次请求递增 `requestEpoch`。响应返回时只有 epoch 仍等于最新值才更新状态：如果用户先点 A、立即点 B，而 A 更晚返回，A 会被丢弃。这是处理异步竞态的简单状态机，不需要引入全局 store 或取消框架。

## 小练习

给详情面板增加“只看音频流 / 只看视频流 / 全部”筛选。先写一个接收 `ReadonlyArray<MediaStreamDetails>` 的纯函数和三组测试，再把筛选选择保留在 `MediaDetailsPanel` 局部状态中；不要把它写回 Rust 或 SQLite。
