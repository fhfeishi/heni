# 028 — 用判别联合表达“完整状态或位置采样”

## 问题与模型

播放位置每 300ms 更新一次，但同一时刻的 5,000 首队列通常没有变化。把整个 snapshot 每次都传过边界，会反复复制和校验与本次变化无关的数据。

这不是把播放状态拆成多个权威来源。Rust 仍持有完整状态，只根据前端已知版本选择响应形状：

```ts
type PlaybackUpdate =
  | Readonly<{ type: "snapshot"; snapshot: PlaybackSnapshot }>
  | Readonly<{ type: "position"; position: PlaybackPosition }>;
```

生产类型从 `playbackUpdateSchema` 推导；上面只是方便理解的等价表达，不在代码里重复维护。

## 为什么不是一个全是可选字段的对象

`queue?`、`status?`、`positionMs?` 会允许很多无法解释的组合。判别联合让 `update.type` 收窄可用字段：拿到 position 分支时，不可能直接读取 `update.snapshot.queue`。外部输入仍从 `unknown` 开始，Zod 通过后才进入应用层。

## 状态版本与请求顺序

Rust 比较 `generation/sequence` 前先同步引擎，包含自动续播、完成和失败。因此不能为了返回“小包”漏掉一次切歌。

普通位置响应不改变 sequence。前端投影必须同时核对版本、状态与媒体 ID，只更新 position/duration；使用对象展开创建新 snapshot，同时保留 `queue` 原引用。seek 草稿也绑定同一状态版本，所以正常采样不会取消拖动。

请求顺序由另一层负责：一个连接只允许一个未完成读取，命令开始时增加本地 revision。旧读取在 seek/暂停之后才返回时，即使版本相等，也必须丢弃。`latestSnapshot` 是上一次被接受的对象引用，供下一次请求携带版本；它不是另一份可修改队列。换 port 或卸载后，旧连接不能更新新界面。

响应不匹配时不要试着拼出新队列：保留当前投影，下一次请求完整 snapshot。窗口重新可见时也使用完整读取恢复。原生事件尚未启用；以后同时存在推送与命令回包时，需另外解决采样排序，不能把这里的串行读取保证直接套过去。

## 实际验证与取舍

TypeScript 和 Rust 共享 `fixtures/playback/updates.json`。Rust 测试实际序列化生产响应，TypeScript 测试解析同一文件。JSON 数值进入 JavaScript 后没有整数/浮点两套类型，Rust 的断言对声明为 `f64` 的 volume 作对应数值归一，不忽略其他字段差异。

5,000 项合成队列实测：完整响应 551,874 bytes，稳定位置响应 133 bytes。读取间隔仍为 300ms；没有据此宣称 CPU、内存或帧率改善。没有增加 npm 依赖、全局 store、事件总线或新的数据库表。

本次增加 28 项 TypeScript 测试，替换 3 项旧未接入事件投影测试，净增 25 项；另有 8 项 Rust 测试。契约、竞态、恢复和数据量测试不替代真实 Windows 音频验收。

## 阅读路径与练习

1. `src/contracts/playback.ts`：判别联合与推导类型。
2. `src/infrastructure/tauri/playbackPort.ts`：unknown 与有限错误边界。
3. `src/features/playback/application/projectPlaybackPosition.ts`：纯投影与共享 queue 引用。
4. `src/features/playback/usePlayback.ts`：条件读取、revision 和生命周期。
5. `src/features/playback/usePlayback.test.tsx`：可控 Promise 与假时钟。

练习：模拟一条状态版本正确、但媒体 ID 错误的位置响应。证明时钟不被重新采样，下一次完整读取能恢复；再比较错误时强行覆盖 mediaId 会造成什么交互问题。
