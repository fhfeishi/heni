# TypeScript 学习 009：用联合类型约束应用主视图

Phase 4A 没有引入路由库或全局 store，而是用一个很小的联合类型表达 Heni 当前允许的主视图：

```ts
type AppView = "now-playing" | "library" | "playlists" | "queue";
```

这个类型比任意字符串更有价值：组件属性、标签映射和切换函数必须处理同一组合法值，拼写错误会在编译期暴露。它又比通用路由配置更直白，因为 Heni 目前没有 URL、嵌套路由或第二个窗口消费者。

## 数据如何流动

1. `App` 保存局部 `activeView`；
2. `Sidebar` 只发出 `onSelect(view)` 用户意图；
3. `App` 根据联合类型只渲染一个主视图；
4. `AppFrame` 始终组合相同的顶栏、侧栏和 `PlaybackBar`；
5. 导航不会调用 `PlaybackPort`，真正的播放按钮才发送 typed command。

这里最重要的边界是：`AppView` 不是领域状态。它不写 SQLite，也不复制 Rust 的 playback snapshot。当前曲目、队列和播放状态依然只有 Rust runtime 一份权威真相。

## 为什么使用 slot 组合

`AppFrame` 接收 `children`、`playbackBar` 和可选 `notice`。它只负责稳定空间关系，不知道如何扫描曲库或播放媒体。这样既能让外壳保持简单，也让各 feature 继续通过 typed port 测试。

`PlaybackBar` 使用 `PlaybackSnapshot | null` 明确表达“本地核心尚未返回状态”，而不是用伪造的默认播放状态掩盖加载边界。按钮的 `disabled` 条件集中由真实 snapshot、当前项和 busy 状态推导。

## 无障碍名称也是契约

侧栏视觉上显示曲库数量，但按钮通过 `aria-label` 保持稳定名称“曲库”。计数被标记为只提供视觉信息，避免按钮在零首时变成“曲库0”。这让键盘/读屏用户和 Testing Library 使用同一套产品语义。

## 建议阅读

- `src/features/shell/appView.ts`
- `src/features/shell/AppFrame.tsx`
- `src/features/shell/Sidebar.tsx`
- `src/features/playback/PlaybackBar.tsx`
- `src/app/App.test.tsx`

## 小练习

为 `AppView` 增加一个临时的 `"settings"` 成员，观察 TypeScript 会提示哪些标签映射和图标分支尚未处理。不要提交这个成员；练习目标是理解联合类型如何把“所有分支都已覆盖”变成编译期反馈，而不是增加一个空设置页。
