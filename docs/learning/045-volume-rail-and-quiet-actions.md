# 045 · 细轨道不等于小命中区

入口：`src/features/playback/PlaybackVolume.tsx`、`src/styles/playback.css`、`src/features/settings/DraftActions.tsx`。

参考 Apple Music 官方音量说明：https://support.apple.com/en-gb/guide/music/musa3fedf052/mac 。当前官方指南描述底部音量按钮及滑杆；它支持“音量是独立控件”的交互参考，但不能用来证明 Heni 的具体颜色、尺寸或实时音频行为。Heni 的边缘播放台已经需要展开，因此本轮选择直接可拖的短轨道，不再套一个必须点击打开的弹层。

轨道视觉为 3px，input 实际高度仍为 28px。原生 range 保留键盘、指针捕获、取消和提交逻辑，只自定义轨道/滑块外观。填充使用当前可见音量的 CSS 变量；静音改变色调，不把保存的音量值抹成 0。鼠标悬停或焦点进入时显示小滑块与数值，粗指针始终显示滑块。

设置中三组重复草稿动作收口成 DraftActions：图标只装饰，完整动作名放在 aria-label/title；禁用和回调沿用原组件。组件不保存状态、不调用数据库。主题、材质名和危险操作说明仍保留文字。

取舍：不把一切改成图标，只有重复且含义稳定的辅助动作适合精简。也不能为了视觉重写可靠的音量手势代码。本轮没有实现拖动实时试听。

练习：将音量快照 muted 设为 true，检查 range 仍显示原音量，按钮名称为“恢复声音”；然后用键盘取消未提交的变化，确认没有音量命令被发出。
