# 047 · 一体化窗口栏：外观与系统职责

入口：`src/features/shell/WindowChrome.tsx`、`src/infrastructure/tauri/windowChrome.ts`。

组件只管理显示、命令在途互斥及错误提示；小端口将最小化、最大化、拖动和关闭交给 Tauri。关闭使用正常 close 请求，继续经过 Rust 现有 CloseRequested 清理，不调用进程强退。浏览器预览端口为空，不显示假窗口按钮。

最大化图标读取系统真实状态，并在 WebView resize 后刷新。异步读取序号避免旧 resize 结果回写；effect 代际避免组件卸载后写状态。Mini 的尺寸/置顶仍归原来的窗口模式控制器，不复制一份逻辑。

取舍：窗口栏常驻，与可隐藏的音乐工具栏分离；这多占 36px，但关闭和拖动永远可达。Mini 隐藏旧的重复栏，并将返回按钮并入新栏，保持原有窗口最小尺寸。仅给 main 窗口开放五项必要权限，不授予全部窗口能力。

练习：在 WindowChrome.test.tsx 中让 isMaximized 的两个 resize 请求反序完成，断言最终图标跟随最新请求，而非最后完成的旧请求。运行 `pnpm test`。

参考：https://v2.tauri.app/learn/window-customization/ 。自定义栏不能自动等价于全部 Windows 原生标题栏能力，Snap、系统菜单、多屏 DPI 和边缘缩放须真实验收。
