# 004：权威队列与迟到 Snapshot

队列切片最值得学习的不是按钮，而是“谁拥有真相”。Heni 把活动队列、当前索引、播放模式和自动续播放在 Rust；TypeScript 只发送意图并投影只读 snapshot。这样即使 WebView 重载、页面暂时卡住，歌曲播完后仍能切到下一首。

## 建议阅读顺序

1. `src/contracts/playback.ts`：discriminated union 如何约束所有 command；
2. `fixtures/playback/commands.json`：语言无关的 IPC 样例；
3. `src/infrastructure/tauri/playbackPort.ts`：`unknown` 如何经 Zod 变成可信 snapshot；
4. `src/features/playback/application/projectPlaybackSnapshot.ts`：很小但关键的抗乱序纯函数；
5. `src/features/playback/usePlayback.ts`：轮询与 command 结果如何走同一个投影入口；
6. `src-tauri/src/playback/session.rs`：真正执行队列不变量的 Rust 会话。

## 为什么同时需要 generation 和 sequence

`generation` 表示播放源身份。换歌、删除当前项并加载下一项时，它增长；旧歌曲即使晚返回一个更大的 position，也不能覆盖新歌曲。

`sequence` 表示同一播放源内的状态顺序。pause、volume、repeat 等命令增长 sequence；较早的轮询结果不能撤销较新的命令结果。position 轮询可能使用相同 sequence，因此投影函数接受“相同 generation、相同 sequence”的新 snapshot，让进度继续变化。

这次测试捕获了一个真实竞态：页面启动的空 snapshot 比文件加载结果更晚返回，导致 UI 从“正在播放”退回“等待选择”。修复不是在测试里等待更久，而是把时序规则写成纯函数并让所有入口复用。

## 为什么 TypeScript 不再实现一套播放顺序

React 只需要显示队列和发送 `next`、`previous`、`set-repeat-mode`。若 TypeScript 也自行计算下一首，就会产生两个状态机。共享 fixture 验证 JSON command 在两端字段一致；repeat/shuffle 的业务测试放在 Rust 权威实现中。

## 小练习

给 `projectPlaybackSnapshot` 增加一项表驱动测试：列出旧 generation、旧 sequence、相同 sequence 和新 sequence 四种输入。不要先改实现，先用类型明确每个 case 的预期引用是否应保持不变。
