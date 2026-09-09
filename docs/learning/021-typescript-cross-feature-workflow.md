# TypeScript：用具名工作流收敛跨 feature 编排

## 问题

选择本地音乐不是单一组件动作。成功后需要先把文件写入持久曲库，再用同一批媒体替换
Rust 权威播放队列，并使用已保存的“导入后自动播放”偏好。选择目录也需要把 picker 结果与
递归、视频扫描偏好交给曲库扫描。

如果这些步骤全部留在 `App.tsx`，装配、视图和用户用例会有多个独立变化原因；如果立刻建立
`useAppManager` 或全局 store，又会把无关状态和副作用聚成新的大对象。

## 直白模型

Heni 使用窄而具名的 `useLocalImportWorkflows`：

```ts
type LocalImportWorkflow = {
  pickingFiles: boolean;
  pickingDirectory: boolean;
  error: LocalImportError | null;
  chooseFiles(): Promise<void>;
  chooseDirectory(): Promise<void>;
  clearError(): void;
};
```

它通过参数接收 picker、feature 操作和设置快照。这样工作流知道“按什么顺序调用”，却不知道
Tauri `invoke`、SQLite 或 React 页面如何实现。`App.tsx` 仍负责选择真实 adapter 并连接视图。

## 为什么使用 discriminated union

`LocalImportError` 用 `source` 区分文件 picker 与目录 picker：

```ts
type LocalImportError =
  | { source: "picker"; error: PlaybackError }
  | { source: "directory-picker"; error: LibraryError };
```

这让既有错误展示函数可以穷举来源，不需要依靠错误字符串猜测恢复动作。它也没有吞掉曲库或
播放 feature 自己的错误：工作流只拥有 picker 这一层失败。

## 测试关注行为，不复制实现

工作流测试注入很小的 fake port，验证关键不变量：

1. 文件成功写入曲库后才替换队列，并使用保存的 autoplay 值；
2. 目录扫描使用保存的 recursive/includeVideo 值。
3. 取消选择、picker 失败和曲库写入失败都不会替换队列；调用顺序通过明确的步骤记录验证。

测试不启动 Tauri，也不检查 Hook 内部 state 变量名称，因此以后可以改变实现而不破坏用例
契约。

## 何时不应继续抽取

只有动作确实跨越多个 feature，或存在需要独立验证的调用顺序时，才放进 `app/workflows`。
单个组件的展开状态、搜索词、当前视图仍应留在局部。没有第二个消费者和真实复杂度时，不建立
通用 command bus、service container 或全局 store。

## 建议练习

为目录 picker 写一个失败后恢复的测试：第一次返回结构化错误，调用 `clearError` 后第二次
选择成功；验证错误被清除且只启动一次扫描。不要依赖错误 message 来区分结果。
