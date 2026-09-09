# 036 · 视觉状态不必成为新业务状态

入口：`src/features/player/NowPlayingView.tsx` 与 `src/styles/now-playing.css`。

空舞台的样式直接由已有 `currentItem === null` 派生为 data-empty，不再创建另一个可变状态。这样歌曲载入后自然进入有内容的布局，不需要额外 effect 同步，播放端口和队列规则不变。

空态使用小唱片与居中的导入动作；有内容时保留歌曲、媒体详情和下一首。空态的重复页面标题仅在视觉上收起，仍用于区域的可访问名称。样式选择器限定在舞台空态，不波及 Mini 的唱片或其他页面。

这一轮也发现 `.preferences-control input` 原先把所有输入都限制为 16×16，适合复选框但不适合 range。用类型限定的覆盖给滑块完整宽度，而不是在组件里写固定像素。

练习：在 NowPlayingView 的组件测试里分别传空曲目与真实曲目，断言 data-empty 分别为 true / false；再人工检查键盘访问和窄窗口。DOM 测试不能证明留白、对比度或背景观感合格。
