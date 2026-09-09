# 006：把旧数据当成 unknown

旧版本留下的 JSON 不是“可信的 TypeScript 对象”。它可能被旧程序、手工编辑、截断写入或未来版本改变。安全迁移的第一步不是类型断言，而是在系统边界证明它符合哪一个 schema。

## 建议阅读

1. `src/contracts/library.ts`：`LegacyImportStatus` 与 `LegacyImportOutcome` 的 discriminated union；
2. `src/infrastructure/tauri/libraryPort.ts`：所有 Rust 返回值先从 `unknown` 进入 Zod；
3. `src/features/library/useLibrary.ts`：检测状态、显式导入和成功后的 snapshot 投影；
4. `src/features/library/LibraryPanel.tsx`：`state === "ready"` 后 TypeScript 自动收窄计数字段；
5. `src-tauri/src/library/legacy_import.rs`：真正读取旧文件的 Rust 边界；
6. `src-tauri/src/library/repository.rs`：目录、媒体、歌单、设置与历史的一次事务。

## TypeScript 学习点

`LegacyImportStatus` 不是几个互相独立的可选字段，而是三个互斥状态：`not-found`、`ready`、`imported`。只有 `ready` 分支拥有 `mediaCount` 和 `playlistCount`。组件判断 `state` 后，编译器就能证明这些字段存在，不需要 `as` 或非空断言。

Port 返回 `Result`，因此“运输失败”“Rust 拒绝 schema”和“可正常显示的状态”不会混在异常控制流里。React Hook 只决定何时展示、何时提交；文件读取、备份权限和 SQLite 原子性不应被搬到 TypeScript。

这也展示了一个重要边界：TypeScript 是产品应用层的核心，但桌面文件和数据库安全仍由小而明确的 Rust 模块负责。类型安全不是要求所有代码使用同一种语言，而是让每个跨语言边界都可验证。

## 小练习

为旧数据提示增加“稍后处理”按钮，只在当前进程隐藏提示，不写入 SQLite，也不修改旧 JSON。先为 `LibraryPanel` 写组件测试，再决定这个状态应该留在组件还是 Hook；它不应进入 Rust repository，因为它不是持久化领域事实。
