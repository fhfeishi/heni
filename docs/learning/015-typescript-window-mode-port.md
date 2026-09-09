# TypeScript 学习：把 MiniPlayer 建模为窗口模式，而不是第二个播放器

Phase 4F 最重要的取舍，是 `WindowMode` 只有 `"main" | "mini-player"`，而播放状态没有新增任何分支。MiniPlayer 继续接收同一份 `PlaybackSnapshot`，所有按钮仍调用同一个 `PlaybackPort`。因此切换窗口不会复制队列、重新载入音频或制造第二套当前曲目。

## 从 `unknown` 到可用窗口状态

`src/contracts/window.ts` 用 Zod 定义 Rust 返回的窗口快照：模式、最大化、置顶、客户区尺寸和缩放因子。`src/infrastructure/tauri/windowPort.ts` 是唯一知道 command 名称的模块；解析失败返回 `invalid-contract`，Tauri 调用失败返回结构化错误。React 不需要知道 `invoke`、Rust 枚举或操作系统 API。

这里值得观察的 TypeScript 技巧：

1. `WindowMode` 从 Zod schema 推导，运行时校验和编译期联合类型不会各维护一份；
2. `WindowPort` 只暴露用例级的 `read` 和 `setMode`，没有把几十个底层窗口 getter/setter 泄漏给组件；
3. `Result<WindowSnapshot, WindowError>` 迫使调用者显式处理成功与失败；
4. `useWindowMode` 把不可用、忙碌和操作错误分开，初次读取失败会安全保留普通界面，而不会让整个播放器崩溃。

## 为什么几何持久化不放在 React

窗口位置、DPI、多显示器工作区和最大化属于操作系统边界。TypeScript 只表达用户要进入哪种模式；Rust 保存普通窗口几何、计算当前显示器右下角位置并执行恢复。这样浏览器组件测试可以替换 `WindowPort`，而真实系统规则仍只有一个实现。

特别要注意：官方插件会持续观察 resize/move，不能把只在插件初始化时求值的 filter 当成动态模式开关。Heni 进入 MiniPlayer 前把主窗口几何保存到 Rust runtime；返回主界面或在小窗中关闭时先恢复几何，再让插件保存普通窗口状态。启动时还会修复早期版本留下的非法小窗主界面。这个不变量由 Rust 管理，React 无需记住一份可能过期的几何副本。

## 建议阅读

- `src/contracts/window.ts`：schema 与联合类型；
- `src/infrastructure/tauri/windowPort.ts`：unknown、Zod、Result 和依赖倒置；
- `src/features/shell/useWindowMode.ts`：异步端口如何变成局部 UI 状态；
- `src/features/playback/MiniPlayer.tsx`：同一播放端口的第二种投影；
- `src-tauri/src/platform/window.rs`：系统几何和持久化不变量。

小练习：给 `WindowMode` 增加一个仅改变 UI、不改变操作系统几何的 `compact-main` 草案。先只写 TypeScript schema 和纯投影测试，思考它是否真的应进入 Rust；如果没有系统行为，就不应为了“类型统一”把它塞进原生层。
