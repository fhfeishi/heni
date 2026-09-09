# 队列重排为什么必须由 Rust 定案

Phase 4D 的搜索可以是 TypeScript 只读投影，但重排会真正改变后续播放顺序，因此不能只交换 React 列表。Heni 新增了共享命令：

```ts
{ type: "reorder-queue"; fromIndex: number; toIndex: number }
```

`fromIndex` 是移动前的权威下标，`toIndex` 是移动后的最终下标。TypeScript 的 Zod contract、共享 JSON fixture 和 Rust serde enum 使用同一组字段；前端不发送整份重排后队列，避免用旧 snapshot 覆盖 Rust 刚收到的其他命令。

## 当前媒体不能因为排序而重载

重排只改变队列顺序，不代表用户选择了另一首歌。Rust session 在移动元素后重新计算当前媒体所在位置：

- 移动的就是当前媒体：`currentIndex = toIndex`；
- 前面的项目跨到当前媒体之后：当前下标减 1；
- 后面的项目跨到当前媒体之前：当前下标加 1；
- 其他情况：当前下标不变。

`generation` 代表播放源。重排不改变正在解码的媒体，因此 generation、position、duration 和 status 都保持不变，只增加 `sequence`。`PlaybackController` 对该命令不调用 engine.load；测试通过已加载媒体 ID 证明没有隐藏重载。

## 为什么拖动状态也绑定 snapshot

拖动开始时，`QueueView` 保存 `fromIndex` 与当时的 `generation:sequence`。如果拖动过程中队列被其他命令改变，drop 会被丢弃，而不是把旧下标应用到新队列。

搜索状态下不允许重排。虽然搜索投影保留了权威下标，但把一个可见结果拖到另一个可见结果，并不能清楚表达它应放在被隐藏项目的哪一侧。先要求清除搜索，比猜测用户意图更可靠。

## 可访问交互不是拖放的附属品

每行同时提供稳定 aria 名称的“上移”和“下移”按钮。鼠标用户可以拖放，键盘和读屏用户使用同一个 `reorder-queue` 命令；两种入口没有第二套排序逻辑。

## 建议阅读

- `src/contracts/playback.ts`：Zod discriminated union 的新命令；
- `fixtures/playback/commands.json`：TypeScript/Rust 共享 wire fixture；
- `src-tauri/src/playback/session.rs`：权威下标调整和不变量；
- `src-tauri/src/playback/controller.rs`：重排不触碰音频 engine；
- `src/features/playback/QueueView.tsx`：拖动新鲜度与键盘入口。

## 小练习

为 Rust session 增加一个表格驱动测试，覆盖 5 个元素中从右向左跨越当前项、从左向右跨越当前项、移动当前项和同位置 no-op。每个 case 都断言当前媒体 ID、generation 和 position 不变；不要在 TypeScript 中复制 Rust 的下标调整公式。
