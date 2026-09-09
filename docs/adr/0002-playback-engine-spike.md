# ADR-0002：通过 Windows Spike 选择播放内核

- 状态：Accepted（音频路径定案；视频 adapter 仍是独立门槛）
- 日期：2026-08-31

## 决策问题

选择能在 Windows Release 中替代 `media_kit`、支持 Heni 音频体验并明确处理现有视频能力的播放后端。

## 候选方案

| 候选 | 预期优势 | 主要风险 | Spike 角色 |
|---|---|---|---|
| Symphonia + CPAL | Rust 原生、控制力强、音频路径清楚 | 需要自建队列/seek/设备恢复；视频另解 | 首选音频候选 |
| libmpv/mpv | codec 和视频成熟，接近现有 media_kit 底层能力 | 二进制分发、绑定稳定性、许可证/包体 | 音视频候选 |
| WebView2 audio/Web Audio | 实现快、TypeScript 直接 | codec 依赖 WebView，整文件内存、后台/重载 | 对照组，不作为默认 |

## 实验协议

建立相同的用例级 `PlaybackPort` 和观察器，用每个 adapter 跑同一组测试：

1. MP3、AAC/M4A、AAC/MP4、FLAC、WAV、Opus；
2. 至少一个带 H.264/AAC 或等价常见组合的视频；
3. 中文、空格、特殊字符、较长路径；
4. 损坏/不支持文件、文件播放中被移动；
5. play/pause/stop、前后 seek、volume、mute/restore、completed；
6. 连续切换 100 次、连续播放 60 分钟的内存/CPU 趋势；
7. 默认输出设备改变、睡眠/唤醒、窗口隐藏、WebView reload；
8. Debug、Release `--no-bundle`、正式 bundle 的依赖定位。

媒体样本只记录来源、hash、codec、container、duration 和授权，不默认把有版权音乐提交到仓库。

## 通过阈值

- 必选音频格式可打开，完成事件不会重复或丢失；
- seek 后位置落在定义的容差内，且不会继续发送旧 generation 事件；
- 连续切歌无持续线性内存增长、无明显资源泄漏；
- UI/WebView reload 不终止 Rust 持有的播放会话；
- Release 不依赖开发机偶然存在但未声明的 DLL/程序；
- capability、动态库和许可证分发义务已记录；
- 对视频能力给出通过实现或清楚的 adapter 计划。

## 定案规则

优先级依次是：可靠性/媒体兼容 > 数据与权限安全 > Release 可分发 > 可维护性 > 包体/实现速度。TypeScript 代码比例不是牺牲播放可靠性的理由。

完成 Spike 后把本 ADR 改为 Accepted，并填写选择、测量表、未选理由、许可证、已知限制和跨平台后果。在此之前只能搭建接口和实验代码，不开始全量 UI 迁移。

## 决策

Heni 的正式音频路径采用 `Symphonia + CPAL + ringbuf + rubato`：Symphonia 在普通 worker 线程中解码，rubato 只在采样率不匹配时做流式重采样，PCM 通过有界 SPSC ring buffer 送入 CPAL callback。callback 只允许无锁取样、采样格式转换、原子状态读取和静音填充。

视频不伪装成“已经支持”。保留与音频同级的独立 adapter 边界，后续用有明确二进制来源和许可证配置的 libmpv 实现；在该 adapter 通过相同 Release 门槛前，生产命令必须显式拒绝 `MediaKind::Video`。

本决策允许把最小音频依赖和单曲播放竖切迁入生产 `src-tauri/`，不代表 Phase 1 全部验收完成。设备热切换、60 分钟趋势、100 次连续切换、真实媒体和视频仍作为发布门槛继续验证。

## 选择理由

- 六种必选音频 container/codec 已在 Debug 与 Release 走通真实 WASAPI 输出；
- 44.1kHz mono 到 48kHz stereo 的流式转换、accurate seek、pause/resume/stop 已有确定性样本账目；
- 正式音频包不依赖开发机外部程序或来源不明的 DLL；
- Rust 持有播放会话，WebView reload 不必天然终止音频；
- 代价是队列推进、设备恢复、gapless 和视频必须由清晰的上层策略或独立 adapter 补齐，而不是交给一个不可见的全能播放器。

## 未选理由

- libmpv 不作为默认音频内核：本机尚无可审计 runtime，其 Windows binary 的构建选项会直接影响 LGPL/GPL 分发义务和包体。它仍是视频 adapter 候选，而不是被永久排除。
- WebView2 audio 不作为正式内核：生命周期和 codec 行为受 WebView 控制，也不满足 Rust 持有会话的目标。

## 当前证据（2026-08-31）

Symphonia + CPAL 已通过 Windows 构建、WASAPI 默认设备发现和 MP3、AAC/M4A、AAC/MP4、FLAC、WAV、Opus 的 Debug/Release 完整解码与 PCM 输出。500ms 有界 lock-free SPSC buffer 在六种格式上均为样本账目一致、0 underrun、0 stream error；一次性 500ms accurate seek，以及 deterministic pause/resume/stop 原语也通过。Rubato worker sinc 路径还把 44.1kHz mono 正确转换为设备的 48kHz stereo，仍保持 0 underrun/error。Opus 需要额外 bundled libopus adapter；AAC 合成样本显示 encoder padding，仍需 gapless/duration 策略。

当前没有完成设备切换、长时间资源、真实媒体库或视频验证，本机也没有可审计的 libmpv runtime。这些是已记录的发布风险，不再阻止最小音频竖切进入生产代码。详细证据见 `docs/migration/playback-spike-results.md`。

## 跨平台后果

CPAL 和 Symphonia 本身提供跨平台基础，但本 ADR 只接受 Windows 证据。Linux、macOS、iOS、Android 必须分别验证输出 host、文件 URI/权限、后台策略和 bundle；不得用“crate 可编译”替代平台验收。
