# 049 · 顶部工具栏与设置分区

App 持有 activeView/browseView，AppFrame 只负责布局。将 ListeningViewSwitch 作为
viewControls 插槽移入顶部，不复制路由状态、不重新挂载媒体输出。背景按钮调用同一个
scenery.choose，并通过 loading/busy/preview 状态限制操作，不建立第二套文件选择流程。

设置分区是组件内部的临时界面状态，不进入持久化设置契约。使用短标签的普通按钮组与
aria-pressed，不冒充缺少完整键盘协议的 tablist。隐藏分区使用 hidden + inert，
保留草稿组件实例，同时避免键盘进入隐藏内容；样式显式保证 hidden 不被 grid 覆盖。

保存失败提示位于分区外，不能因用户切换到另一分区而消失。关闭和 Escape 恢复 summary
焦点，外部点击不抢焦点。固定头部和分区导航、仅内容区滚动，让关闭按钮始终可达。

验证关注单一入口、委托次数、不可用状态、切换分区后草稿节点身份及保存错误可见性。
这些测试不替代真实 WebView 的玻璃观感、窗口尺寸和鼠标边缘命中验证。
