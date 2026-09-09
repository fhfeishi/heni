# ADR 0004 — 显示时钟与权威状态分离，先收窄读取载荷

日期：2026-09-03
状态：已采纳；Windows 实机证据按发布记录中的具体 hash 追踪

## 问题

播放条需要平滑移动，但曲库和队列不应每帧重建。旧版每 300ms 获取完整 snapshot，队列再大也会被反复克隆、序列化和解析。旧的 TypeScript `PlaybackEvent` 草案还把每次位置变化映射成更大的状态 sequence；该草案从未接入运行时，却会让绑定状态版本的 seek 草稿和队列确认持续失效。

## 决策

1. Rust session 仍是唯一权威。`generation` 标记换源，`sequence` 标记同代状态变更；位置采样和持续解码不推进它们。
2. 进度显示使用收到采样时的单调时间，最多推算 750ms。动画帧只影响进度控件，不推导完成或下一首。
3. 加入 `playback_poll(knownVersion)`。在同一 controller 锁内先 tick、后比较版本，返回 `snapshot | position` 判别联合。版本不同时返回全量；相同时只读少量标量和当前媒体 ID，不克隆 queue。
4. TypeScript 通过 Zod 校验响应。position 必须匹配已知版本、状态和媒体身份，只更新 position/duration，保留 queue 引用；不匹配就丢弃并用完整读取恢复。
5. 读取不重叠；命令开始时增加请求 revision，拒绝更早开始的读取。首次连接、可见性恢复和不匹配后的恢复使用完整 snapshot。连接换代/卸载后迟到结果无效。
6. 删除未消费且语义错误的 `PlaybackEvent/projectPlaybackEvent` 草案，由生产使用的条件响应契约与纯位置投影代替。不改变音频引擎、数据库、目录授权或 capability。

## 为什么暂不同时引入推送

本切片保持 300ms 调度，只缩小传输内容。原生事件/Channel 还需单独证明订阅准备与首次读取的先后、卸载/reload 清理、丢失恢复以及命令响应与推送的跨通道排序。不能用状态 sequence 给连续位置采样编号；启用多通道时必须另设采样顺序。目前串行读取与请求 revision 已覆盖现有并发来源，没有预建不用的事件总线或 store。

Tauri 官方区分小型事件与有序流式 Channel；未来选择依据是实际传输和生命周期需求，不是为了移除一个定时器而扩大系统。[Tauri 前端通信说明](https://v2.tauri.app/develop/calling-frontend/)

## 证据与代价

- 两端共同验证 `fixtures/playback/updates.json`，Rust 实际序列化结果与 TypeScript 解析形状对应。
- 5,000 项合成队列：稳定位置响应 133 bytes，完整响应 551,874 bytes。只说明该夹具的 JSON 数据量，不是 CPU、内存或帧率基准。
- 自动测试覆盖状态版本不变、未知时长变为已知、自动下一首、末曲完成、下一首加载失败、旧读取、错误恢复和拖动草稿保持。
- 仍有约 3.3 次/秒的读取与低频 React 更新。原生推送、后台节流、长时性能、设备变化和完整音频验收没有因此完成。
