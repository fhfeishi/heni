# Media Pipeline

状态：正式音频与 V3 视频统一输出已接入；视频流式修正版待完整实机验收（2026-09-10）

## 控制面和数据面

Heni 把播放拆为两个责任：

- 控制面：queue、current item、repeat/shuffle、play/pause/seek 命令、snapshot 和错误；
- 数据面：读取容器、解码 packet、重采样/声道映射、PCM ring buffer、CPAL callback 或 libmpv 输出。

控制面已有 TypeScript/Rust contract、Rust session 和事务 controller。数据面已把经过 Spike 验证的 Symphonia/rubato/ringbuf/CPAL 最小链路接入正式应用；多文件选择、队列 load、play/pause/stop、seek、volume、mute、repeat/shuffle 和 completed 自动续播可经 Tauri command 使用。自动续播仍由 Rust 后台 monitor 决策；原生音频无需 WebView 提供播放时钟，视频则依赖唯一 WebView 视频元素报告结束、真实位置与错误，不能将两种输出的生命周期保证混为一谈。

## V3 视频输出

HybridEngine 保留同一个权威队列和控制器。MP4/M4V/MOV/WebM 容器可进入视频路径；实际编码支持由 WebView 决定，尚未完成完整格式验证。前端只有一个 video 元素，舞台/浏览/Mini 隐藏它时不另起声音源。切回音频前先暂停并确认视频输出，过期 epoch/revision 报告被丢弃。

视频文件先经过既有 picker/library 授权。tiny_http 0.12.0 仅按需监听 127.0.0.1，系统随机临时令牌加 epoch 作为 URL，不接受磁盘路径。GET/HEAD 支持单段 Range，完整声明响应长度，持续进行不超过 64 KiB 的读取，停止或换文件后撤销旧资源；不将整个视频放入 IPC/内存。4 个流读取工作线程不占播放监控或 UI 线程；video_exchange 的锁等待同样进入阻塞任务池。

09-09 自定义协议第一候选显示画面，但约 20 秒停止推进；已移除该传输实现。09-10 流式实现通过真实 TCP 的 3MiB+17 字节完整读取及 Range/撤销用例；这不是声音同步或 WebView 连续播放的最终证明。实机辅助工具故障使复核未完成，具体证据见 Strata V3 进度。

## 候选

### Symphonia + CPAL

ADR-0002 已选择该路径。worker 负责解码与必要的 sinc 重采样，500ms 有界 SPSC ring buffer 提供背压，CPAL callback 不等待、不分配、不记录日志。六种合成格式、一次性 accurate seek、44.1kHz mono → 48kHz stereo、确定性控制原语均已验证；正式 adapter 又通过了本机静音 WASAPI WAV 完成冒烟。下一门槛是运行中反复 seek、设备变化、真实媒体和长时间资源测试。

### libmpv

优势是成熟 codec 和视频能力，主要风险是 Windows runtime 来源、动态库定位、包体及 LGPL/GPL 分发义务。本机尚无已审计的 libmpv runtime，因此没有进入生产依赖。

### Web Audio

只作对照。不得使用把整首长音频读入 `ArrayBuffer` 的方式作为正式 Windows 后端。

## 不变量

- 音频 callback 不阻塞、不分配、不访问数据库、不发 IPC、不写日志；
- decoder 与 callback 通过有界 buffer 通信并有背压；
- 新媒体 generation 生效后丢弃旧媒体所有迟到事件；
- 高频 position 不驱动 React 全树重渲染；
- 文件路径作为结构化参数传递，不拼 shell；
- 播放队列只接受系统对话框临时 scope 或 SQLite 曲库中仍标记 available 的路径；
- 未经真实 Release 样本验证，不宣称 codec 兼容或 bit-perfect。

## 元数据平面

元数据不进入实时播放数据面。音频扫描只打开容器头，跳过封面分配，并用与播放 adapter 相同的只读 codec registry 生成快速索引；目录中的每个文件不会启动外部进程。完整详情是独立的按需请求，Rust 从 SQLite media id 解析已授权路径后，以结构化参数执行 `ffprobe`，并限制执行时间和输出大小。前端只消费 Zod 校验后的容器、流、章节与标签 DTO。

本机生成 MP4 已通过真实 `ffprobe` 进程测试，但 no-bundle Release 尚未携带 sidecar；因此快速索引是自包含能力，完整详情目前属于“环境具备 ffprobe 时可用”的竖切，而不是已完成的安装包能力。

详细测试证据见 `docs/migration/playback-spike-results.md`。Flutter v1 的历史媒体说明保存在 `legacy/v1-flutter/docs/media-pipeline.md`。
