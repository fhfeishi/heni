# 019：用稳定 ID 隔离 TypeScript 与操作系统路径

## 问题

“在资源管理器中显示”看起来只需要把路径交给 Windows，但让 React 传任意路径会扩大 IPC 权限，也会让展示层知道本不需要知道的系统细节。路径中还可能包含空格、中文、逗号或其他会让命令行转义变脆弱的字符。

## TypeScript 只表达用例

`FileActionPort` 的公开方法是：

```ts
revealMedia(mediaId: string): Promise<Result<void, FileActionError>>;
```

它没有 `path` 参数。`LibraryItemRow` 只发出“定位这条媒体”的意图，`useFileAction` 管理当前忙碌的媒体 ID 和有限错误，Tauri adapter 再把 `{ mediaId }` 送到 Rust。组件测试可以注入 mock port，因此验证文件定位时不需要真的打开资源管理器。

这个接口把三类变化隔开：

- React 布局或按钮文案变化，不影响 Windows 调用；
- SQLite 路径迁移或媒体重新定位，不改变 UI 调用方式；
- 未来 Linux/macOS adapter 可以保留同一个 TypeScript 用例契约。

## 为什么 Rust 要重新解析路径

Rust 持有 SQLite 和文件系统边界。command 收到媒体 ID 后，从曲库查询当前路径，并在平台调用前再次确认文件仍然存在。这样旧的前端 snapshot 即使已经过期，也不会让 Windows 打开一个已失效路径。

Windows adapter 使用 `ILCreateFromPathW` 和 `SHOpenFolderAndSelectItems`。路径作为 UTF-16 数据进入 Shell API，而不是拼成 `explorer.exe /select,...` 命令字符串，因此空格、中文和标点不需要自己设计转义规则。

## 错误也是契约

Rust 只返回 `not-found`、`file-unavailable`、`file-manager-unavailable` 等有限错误码。TypeScript 用 Zod 校验 IPC 错误，再由 `presentAppError` 生成稳定中文提示。底层数据库诊断和本机路径不会直接进入 DOM。

这形成了一条清晰的路径：

```text
用户意图 → stable mediaId → typed port → Rust 查询 → Windows Shell
                               ↓
                         有限错误码 → 安全文案
```

## 建议阅读

- `src/contracts/fileAction.ts`：最小用例契约；
- `src/infrastructure/tauri/fileActionPort.ts`：IPC 返回与错误校验；
- `src/features/library/useFileAction.ts`：局部异步状态；
- `src/features/library/LibraryItemRow.tsx`：不直接接触 Tauri 的 UI；
- `src-tauri/src/platform/file_action.rs`：SQLite 路径解析后的 Windows adapter。

## 小练习

为 `useFileAction` 增加一个迟到请求测试：先定位 A，再定位 B，让 A 最后返回。思考 Hook 应该禁止并发、记录请求 epoch，还是让上层全局 `busy` 保证一次只触发一个操作；把选择和理由写成一个短 ADR，而不是直接堆状态字段。
