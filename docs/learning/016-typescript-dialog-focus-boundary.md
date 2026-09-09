# TypeScript 学习：让详情抽屉拥有清楚的焦点边界

Phase 4G 没有为媒体详情引入全局 modal store。`MediaDetailsPanel` 仍只接收已经验证的 `MediaDetails` 和一个 `onClose` 回调，但组件现在对自己的交互生命周期负责：挂载时保存当前焦点并聚焦 dialog，Esc 发出关闭意图，Tab 不越过 dialog 边界，卸载时把焦点还给仍存在的触发控件。

## 类型帮助我们守住什么

`useRef<HTMLElement>(null)` 明确表达“元素在首次渲染前不存在”。键盘处理函数使用 `KeyboardEvent<HTMLElement>`，因此 `key`、`shiftKey` 和 `preventDefault` 都来自 React 的受控事件类型，而不是用 `any` 猜测浏览器对象。`querySelectorAll<HTMLElement>` 将焦点候选收窄为具有 `focus()` 的元素；数组首尾仍可能不存在，所以代码显式处理空集合，没有用非空断言绕过边界。

焦点还原还检查 `previousFocus.isConnected`。这是一个小但重要的不变量：如果触发按钮因为视图切换已经从 DOM 移除，组件不会把焦点送回失效节点。

## 为什么状态留在组件内

“当前焦点是谁”只在 dialog 存活期间有意义。把它提升到 `App`、Context 或 Rust 不会增加可靠性，反而会制造跨渲染的陈旧 DOM 引用。组件 effect 的清理函数与 dialog 卸载同寿命，是最小且足够的所有权边界。

建议阅读：

- `src/features/library/MediaDetailsPanel.tsx`：effect、ref、键盘收窄与焦点循环；
- `src/features/library/MediaDetailsPanel.test.tsx`：以用户可观察结果验证焦点；
- `src/features/library/useMediaDetails.ts`：详情数据请求与 dialog 交互为何分离；
- `src/features/shell/AppFrame.tsx`：overlay 组合位置和稳定 aria 名称。

小练习：给详情 dialog 增加第二个可聚焦按钮，再补两项测试：从最后一个按钮按 Tab 回到第一个，从第一个按钮按 Shift+Tab 回到最后一个。不要读取组件内部 state，只断言 `document.activeElement`。
