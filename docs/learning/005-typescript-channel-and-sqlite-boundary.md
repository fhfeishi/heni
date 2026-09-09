# 005：Channel、取消与 SQLite 边界

目录扫描展示了 TypeScript 工程中很常见的一类问题：操作由 UI 发起，但工作不应该发生在 UI 线程，结果也不是一次性返回。

## 建议阅读

1. `src/contracts/library.ts`：snapshot、scan event 和 error 的 Zod 边界；
2. `src/infrastructure/tauri/libraryPort.ts`：把 Tauri Channel 包装成可替换 Port；
3. `src/features/library/useLibrary.ts`：进度状态、取消和卸载清理；
4. `src/features/library/LibraryPanel.tsx`：只接收数据和回调的展示组件；
5. `src-tauri/src/library/scanner.rs`：真正的目录遍历和有界批次；
6. `src-tauri/src/library/repository.rs`：事务、路径键与来源对账。

## TypeScript 学习点

`LibraryScanEvent` 是 discriminated union。`event === "started"` 时没有计数字段；其余分支才有 `visited/matched/unreadable`。类型收窄让 Hook 不需要断言，也不会误读不存在的字段。

Channel 被藏在 adapter 内。测试传入一个极小的假 Channel，把消息主动送进 Zod；React 和 Hook 从未依赖 Tauri 类。扫描 command 返回最终 snapshot，Channel 只承载中间进度，两者职责不同。

`useLibrary` 在卸载时取消仍活跃的 scan。这里的清理不是 UI 小细节：没有它，重新进入页面可能留下多个后台扫描和重复数据库写入。

## 小练习

给扫描状态增加 `unreadable > 0` 时的黄色提示。先写 `LibraryPanel` 组件测试，再决定提示只显示数量还是暴露路径。正确答案不应把完整用户路径发送到日志或错误横幅。
