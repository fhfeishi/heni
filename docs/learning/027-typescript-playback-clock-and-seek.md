# 027 — 播放时钟：真实状态与平滑显示不是同一件事

## 问题

Rust 每次返回的播放位置是真实采样，但每 300 毫秒更新一次滑块会显得不连续。如果让整个 App 每帧更新，曲库、歌单和背景又会陪着进度条反复渲染。拖动结束后直接清空草稿，还会在原生 seek 返回之前短暂显示旧位置。

## 直白模型

这次保留三个各司其职的数据：

- `PlaybackSnapshot`：Rust 权威状态，包括队列、状态、位置和 `generation/sequence`。
- `PlaybackClockSample`：接收被采纳的快照时，提取当前媒体身份与少量时间字段，附上本机单调时间；不保存整份队列。
- seek 草稿：用户正在拖动或等待提交结果的局部意图，不能冒充真实播放状态。

显示位置等于“采样位置 + 采样后的短暂时间”，只有 `playing` 可以推算。暂停、停止、失败与结束均服从原生采样。`performance.now()` 使用单调时钟，避免系统时钟调整造成进度跳变。[MDN 单调时间说明](https://developer.mozilla.org/en-US/docs/Web/API/Performance/now)

## 最终选择

纯函数 `projectPlaybackClock` 只接收数据和时间，不读取系统时钟，不发播放命令。它把推算限制在 750 毫秒内，并夹紧到已知时长。IPC 停滞或窗口长时间隐藏后，前端不会凭空把整首歌曲“播放完”，更不会自行跳下一首。

`usePlaybackPosition` 把动画帧限制在进度控件内部，发布频率约不高于 30 Hz；其他工作区仍只接收低频快照。隐藏时取消帧、恢复时重新检查旧采样的有效期，卸载后取消帧和监听。浏览器常在后台暂停动画帧，因此不能把帧数当作经过时间。[MDN 动画帧说明](https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame)

首切片（91BB Release）仍保留 300 毫秒完整快照读取。后续切片已把稳定状态改为窄位置响应，状态变化才返回完整队列，详见学习 028 和 ADR 0004。两者都没有完成 Rust position event 订阅；读取次数不变，数据量优化与推送优化是两件事。

## 为什么没有引入全局 store

当前只有主窗或 Mini 中的一处进度控件被挂载，局部 Hook 足够。快照接收处原子更新 `snapshot` 与 `clockSample`，避免同一帧把新曲目配上旧时钟。现阶段没有供多个组件共同订阅的可变外部时钟，因而不为使用 `useSyncExternalStore` 而新建 store；它是未来真正出现外部订阅源时的选项。[React 外部订阅接口](https://react.dev/reference/react/useSyncExternalStore)

## 异步边界

`usePlayback` 不重叠读取。命令开始时推进请求 revision；操作前开始、操作后才返回的旧读取，即使 `generation/sequence` 相同，也不能覆盖命令结果。原生结果仍按 `generation/sequence` 判断先后，旧结果不得刷新时钟的采样时间。

并行命令使用未完成数量维护 busy，不能由较早完成的一个命令提前解锁。旧命令的错误也不能覆盖较新的成功结果。切换 port 或卸载后，原连接的迟到结果失效；意外 reject 被转换为有限 transport 错误，避免一直卡在 busy。

seek 草稿绑定 `generation + sequence + mediaId`。切歌或其他原生命令使其失效；轮询位置更新不改变 sequence，因此不会打断正常拖动。提交后保持目标位置直到 Promise 完成；失败回到权威位置，不伪装成成功。

实机还暴露了一个容易被单元测试漏掉的问题：提交时把 range 设为原生 `disabled` 会丢掉键盘焦点。因此自己的 seek 等待期间改用 `aria-disabled/aria-busy` 表达暂时不可重复操作，由事件边界拒绝新提交，而不移除焦点；无曲目、未知时长或其他命令占用时仍正常禁用。回归测试同时检查目标值、焦点和重复命令数量，而不只检查“按钮是灰色的”。

Pointer cancel、丢失捕获、失焦和 Escape 只取消尚未提交的草稿。按方向键移动一秒，PageUp/PageDown 移动十秒，Home/End 到达边界；滑块本身允许毫秒值以支持平滑显示，读屏值仍使用可理解的分秒。

## 验证边界

本切片新增 37 项自动测试，覆盖纯时间投影、帧生命周期、旧请求、并发完成、端口替换、seek 等待/失败/取消和键盘边界。它们不是实际音频误差测量；真实 Release、鼠标捕获、设备变化、长时播放和 DPI 需另记证据。

## 建议阅读与练习

1. `src/features/playback/application/playbackClock.ts`
2. `src/features/playback/usePlaybackPosition.ts`
3. `src/features/playback/usePlayback.ts`
4. `src/features/playback/PlaybackProgress.tsx`
5. `src/features/playback/usePlayback.test.tsx`

练习：先写一个测试，模拟读取得到旧 generation、但采样到达时间较晚。证明滑块和时钟都不会回到上一首。再思考：为什么单独比较时间戳不能代替媒体 generation？
