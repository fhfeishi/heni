# TypeScript 学习 001：类型不会自动保护 IPC

Phase 1 的第一个切片只读取 Rust runtime info，看似很小，但它建立了后续所有播放、曲库和数据库调用都要遵守的边界。

## 编译期类型和运行时数据

给 `invoke<RuntimeInfo>()` 写泛型只是在告诉 TypeScript“请相信返回值”。Rust 字段改名、旧版本返回不同结构或恶意/损坏数据时，泛型不会运行，也不会验证任何东西。

Heni 因此采用两层：

1. `RuntimeInfo` 是编译期类型，让编辑器和 `tsc` 检查我们如何使用数据；
2. `runtimeInfoSchema` 是 Zod 运行时 schema，真正检查从 IPC 收到的 `unknown`。

建议阅读：

- `src/contracts/runtime.ts`；
- `src/contracts/result.ts`；
- `src/infrastructure/tauri/runtimeInfoPort.ts`；
- `src/features/runtime/useRuntimeInfo.ts`；
- 三个相邻的 `.test.ts/.test.tsx` 文件。

## Discriminated union

`Result` 使用 `ok: true | false`，视图状态使用 `status: loading | ready | failed`。它们都是 discriminated union。代码先判断判别字段，TypeScript 就能把其余字段收窄到正确分支，不需要 `as` 或非空断言。

这比 `{ data?: T; error?: E; loading?: boolean }` 更安全，因为后者允许“同时有 data 和 error”或“三个字段都没有”等无意义状态。

## Port 与依赖倒置

`App` 依赖 `RuntimeInfoPort`，默认装配真实 Tauri adapter，测试则传入一个内存实现。因此 React 测试不需要启动 Rust/WebView，Tauri 细节也没有散落进组件。

## 小练习

为 `RuntimeInfo` 增加一个经 schema 验证的 `architecture` 字段，只允许 `x86_64`、`aarch64`、`unknown`。同时修改 Rust 返回值和三层测试。不要使用 `as RuntimeInfo`。
