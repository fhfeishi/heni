# TypeScript 学习 002：状态版本不是位置采样序号

播放器有两类常见竞态：切到 B 曲后，A 曲的异步读取才到；同一首歌中，seek 前开始的读取在 seek 后才到。如果前端无条件接收，进度会回跳。完成与切歌始终由 Rust 负责。

Heni 用两个字段描述权威状态版本：

- `generation`：每次替换播放源时增长；旧 generation 的结果失效；
- `sequence`：同一 generation 内的命令/状态变化时增长；同代更旧 sequence 失效。位置采样不增加它，等版本的位置响应是正常情况。

`projectPlaybackSnapshot` 拒绝旧状态；`projectPlaybackPosition` 只接受同时匹配版本、媒体 ID 与状态的采样。两者都是纯函数。`usePlayback` 另用请求 revision 拒绝命令之前开始的读取；不依赖 React 何时完成渲染来判断请求的有效性。

S2-3 校正：早期示例曾让 position event 增加状态 sequence，这段草案从未接入运行时，现已由真实使用的条件读取替代。不能照搬旧规则，否则 seek 草稿和队列确认会被每次采样取消；见 ADR 0004、学习 028。

建议阅读：

- `src/contracts/playback.ts`；
- `src/features/playback/application/projectPlaybackSnapshot.ts`；
- `src/features/playback/application/projectPlaybackPosition.ts`；
- `src/infrastructure/tauri/playbackPort.ts`；
- `src/features/playback/usePlayback.ts`。

TypeScript schema 和 Rust serde 类型仍是两份描述；`fixtures/playback/commands.json` 与 `updates.json` 已由两端共同测试，不能靠“看起来一样”保证契约。

## 小练习

先写一个测试：同一 generation 内，旧读取晚于 seek 返回；再写等版本的普通位置采样测试。解释为什么前者应丢弃、后者应接受，以及为什么只比较 sequence 不足以区分它们。
