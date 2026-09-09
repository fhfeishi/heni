# 039 · 换一套控制外观，不换播放规则

入口：`PlaybackModeControl.tsx`、`PlaybackTransport.tsx`、`PlayerIcon.tsx`。

播放器已有两个独立维度：shuffle 决定顺序，repeatMode 决定曲尾。新面板保留这两个维度：

- 顺序/随机分别发送 set-shuffle false/true。
- 播完停止/列表循环/单曲循环分别发送 set-repeat-mode none/all/one。

每次动作只发送一条命令，不用两个顺序请求假装原子切换。按钮选中态来自原生快照，失败不伪造新状态。同步 ref 阻止重复请求；等待期间禁用操作，卸载后迟到结果不更新本地 pending。

图标是统一 viewBox、描边和 currentColor 的本地 SVG，不增加依赖。按钮继续保留原有 aria-label，隐藏图标语义，避免读屏重复播报。音量滑杆沿用拖动草稿/松开提交，不声称实现了实时试听；百分比保留在 title 和 aria-valuetext 中。

练习：给模式面板测试增加“列表循环”的命令断言，再以 shuffle=true 的快照渲染，确认循环点击不发送 set-shuffle。运行 `pnpm test`。真实布局、弹层是否越界和 Mini 尺寸仍要人工检查。
