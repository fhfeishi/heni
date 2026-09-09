# 003：从文件选择到播放——一条 TypeScript 垂直切片

这次竖切适合用来学习 TypeScript 工程，不是因为 TypeScript 负责解码，而是因为它把用户意图可靠地送到系统边界，并把结果重新投影成可测试的 UI。

## 阅读顺序

1. `src/contracts/localMedia.ts`：只有能力接口，没有 Tauri；
2. `src/infrastructure/tauri/localMediaPicker.ts`：把官方 dialog API 适配成领域对象；
3. `src/contracts/playback.ts`：command、snapshot、error 的 discriminated union 与 Zod 校验；
4. `src/features/playback/usePlayback.ts`：异步读取、轮询清理、命令 busy/error 状态；
5. `src/app/App.tsx`：组件只组合端口和用例，不直接 `invoke`；
6. 对应的 `*.test.ts(x)`：用普通对象替换桌面环境。

## 为什么使用 Port

`LocalMediaPickerPort` 和 `PlaybackPort` 描述的是 Heni 需要什么，而不是 Tauri 提供什么。因此 React 测试可以注入一个返回固定 `Result` 的对象，不启动窗口、文件对话框或音频设备。只有 `src/infrastructure/tauri/` 知道第三方 API 的参数形状。

这不是为了“接口越多越高级”。两个 Port 都有真实的第二实现：测试替身。若某个能力只有一行纯函数且不碰外部系统，就没有必要照搬这个结构。

## 为什么不抛异常穿过 React

文件选择、IPC 和解码都可能失败。adapter 在边界捕获 `unknown`，转成 `Result<Value, PlaybackError>`；Hook 再把它变成显式的 `error` 状态。组件无需用到处散落的 `try/catch` 猜测错误形状。

`unknown` 很重要：来自插件或 IPC 的值在验证前不值得信任。snapshot 通过 Zod 后才成为 `PlaybackSnapshot`；Rust 返回的结构意外变化时，前端得到 `invalid-contract`，不会把错误数据放进 UI。

## 状态所有权

React 保存的是 Rust snapshot 的只读投影。按钮不会先乐观写成“正在播放”，而是等待 command 成功后的 snapshot。Rust controller 同样先在 session 副本上执行命令，再让音频 engine 应用；engine 失败时不提交候选状态。两端共同避免“UI 说在播，设备其实失败”的分裂状态。

## 当前结果

“选择多个音频”练习已进入正式实现：Port 返回 `readonly PlaybackItem[]`，adapter 先消除同一次对话框中的重复路径，Rust session 再在权威边界拒绝重复队列。UI 不负责自动续播；completed 由 Rust monitor 推进。

## 新的小练习

为当前队列增加“确认清空”交互，但不改变 Rust 的原子命令模型：

1. 先写组件测试，确认取消不会 dispatch；
2. 确认后可以复用空 `replace-queue`，不要新增只为一个调用服务的抽象；
3. 观察返回的 `generation` 为什么必须高于旧播放源；
4. 思考确认框属于 React 视图状态还是 Rust 领域状态。

练习重点是区分短暂 UI 状态与权威播放状态。
