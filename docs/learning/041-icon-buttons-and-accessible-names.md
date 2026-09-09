# 041 · 图标按钮不是没有名字的按钮

入口：`src/components/InterfaceIcon.tsx`、`src/features/shell/AppFrame.tsx`、`src/features/playback/MiniPlayer.tsx`。

界面工具图标使用有限的名称联合类型，不接受任意 SVG 文本。播放器继续复用自己的 PlayerIcon，外壳与设置不依赖播放功能模块。两者共享描边尺寸和颜色约定，不增加图标库或注册框架。

图形只负责外观，标记 `aria-hidden`；按钮通过 `aria-label` 提供名字，通过 `title` 给鼠标用户提示。静音继续使用 `aria-pressed` 表示真实状态，窗口切换仍使用 disabled 与 aria-busy，不能用移除文字的方式丢掉状态信息。队列数量移入按钮名称和提示，不再挤占 Mini 横向空间。

取舍：只精简容易识别的工具操作。导航、主题名称、保存和清除等需要明确含义的动作保留文字。

练习：修改 MiniPlayer 测试中的静音快照为 true，验证按钮名称变为“恢复声音”，按下后发送 set-muted / false；不能只断言存在一张 SVG。
