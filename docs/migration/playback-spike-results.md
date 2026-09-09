# Playback Spike Results

更新日期：2026-08-31  
状态：音频内核已选择，发布级验证继续进行

## 本轮结论

Symphonia + CPAL 已通过 Windows 编译、默认输出设备发现、六种合成格式完整解码、Debug/Release PCM 输出和一次性准确 seek。输出路径使用 500ms 有界 SPSC ring buffer，六种格式均做到 produced/consumed 样本数相等、0 次 underrun callback、0 次 stream error。

确定性 play/pause/resume/stop、一次性 seek、44.1kHz mono → 48kHz stereo 重采样/声道映射已经通过。基于这些证据，ADR-0002 接受 Symphonia + CPAL 路径进入最小生产竖切；设备切换、长时间内存、多次运行中 seek、真实媒体和视频仍是发布门槛，不能把这一结果描述为“播放器完成”。

本机没有 `mpv` 命令或已声明的 libmpv runtime。本轮没有为了赶进度把来源和许可证不明的 Windows mpv binary 放入工程；libmpv 音视频候选仍待受控下载、动态库定位和分发审计。

## 环境

- Windows x86_64；
- Rust 1.95.0；
- Symphonia 0.6.1；
- CPAL 0.18.2；
- symphonia-adapter-libopus 0.3.0，默认 bundled libopus；
- ringbuf 0.4.8，有界 lock-free SPSC PCM 队列；
- rubato 5.0.0，worker 线程 sinc 重采样，默认 feature 未开启 log；
- FFmpeg 2026-01-07 build，仅用于生成测试音，不进入正式内核；
- CPAL 默认 host：WASAPI；
- 默认设备：`扬声器 (Realtek(R) Audio)`；
- 默认格式：2 channels / 48,000 Hz / F32。

设备查询本身不播放声音；随后独立的 `pcm_output` harness 才负责实际输出。

## 合成样本

样本是 FFmpeg 生成的一秒 440 Hz、48 kHz、双声道测试音，保存在忽略目录 `spikes/media-fixtures/generated/`。

| 文件 | 大小 | SHA-256 |
|---|---:|---|
| `tone.mp3` | 16,748 | `B7A975D72BB69B082D74488F10A606566D60B83EA375F5FFFA212D88BCED6783` |
| `tone.m4a` | 17,350 | `98CD57490B01B8BEA834D53CCF0483AD783ED3E5C510C239BD0DA8D63F979EC8` |
| `tone.mp4` | 17,370 | `4D55F3B57569101575CFB66FE8E87BE63BBCF364F6B9D9FBDC9167DDB35CB025` |
| `tone.flac` | 21,699 | `DAFA5C1FD338FEB327E900D5A8472E499910D84231904273AF8E3018406D4335` |
| `tone.wav` | 192,078 | `9973C368DDCDF6DEE71E72A3FC307CD6A2BEEBA0198F2E5B870AF93D50F6FC1E` |
| `tone.opus` | 14,178 | `9FBB8E7D4A34C4BB0F7B69593909B289CF95687FB8BD4B3AD5EA750E9080B787` |
| `tone-44100-mono.wav` | 88,278 | `BA705CA9153EBBD82C2FC70D8A88674AE4FF1027999B44D353E39C5A5385C356` |

这些 hash 只对应当前本机 FFmpeg 产物；用不同 encoder build 重建后应重新记录。

## Debug 与 Release 解码结果

| container/codec | sample rate | channels | decoded frames | 结果 |
|---|---:|---:|---:|---|
| MP3 | 48,000 | 2 | 48,000 | 通过 |
| M4A/AAC | 48,000 | 2 | 49,152 | 通过；包含约 24 ms encoder padding，gapless/duration 需继续验证 |
| MP4/AAC | 48,000 | 2 | 49,152 | 通过；同上 |
| FLAC | 48,000 | 2 | 48,000 | 通过 |
| WAV/PCM S16 | 48,000 | 2 | 48,000 | 通过 |
| Ogg Opus | 48,000 | 2 | 48,000 | 通过；依赖额外 libopus adapter |

Debug 和 Release 均完成完整 packet decode。Release spike 可执行文件约 3.18 MiB；该数字不代表最终播放器包体，也不包含 Tauri、数据库、图标和可能的 mpv runtime。

## PCM 输出与 seek 结果

`pcm_output` 在普通 worker 线程中解码、转换和等待背压，通过 500ms 有界 SPSC ring buffer 把 `f32` PCM 交给 CPAL callback。callback 只执行无锁 `try_pop`、固定增益采样转换、原子计数和静音填充；不分配、不等待、不写日志。启动前预填充 100ms，harness 超时或失败时有显式取消和线程回收路径。

Debug 与 Release 在本机 WASAPI 48kHz/双声道/F32 输出的结果一致：

| container/codec | 完整输出样本 | 500ms seek 后样本 | underrun callbacks | stream errors | 结果 |
|---|---:|---:|---:|---:|---|
| FLAC | 96,000 | 48,000 | 0 | 0 | 通过 |
| M4A/AAC | 98,304 | 50,302 | 0 | 0 | 通过；仍含 encoder padding |
| MP3 | 96,000 | 47,998 | 0 | 0 | 通过 |
| MP4/AAC | 98,304 | 50,302 | 0 | 0 | 通过；仍含 encoder padding |
| Ogg Opus | 96,000 | 48,624 | 0 | 0 | 通过；pre-skip/尾部语义仍需真实媒体验证 |
| WAV/PCM S16 | 96,000 | 48,000 | 0 | 0 | 通过 |

seek 使用 Symphonia accurate mode。harness 记录容器返回的 actual/required timestamp，并丢弃 actual 到 required 之间的已解码帧。例如 WAV 请求 500ms 时容器落点为 480ms，裁剪后从 500ms 输出。该结果证明“一次加载前 seek”成立，还不能替代正在播放时反复 seek 和 generation 竞态测试。

同一 harness 还在 Debug/Release 做了确定性控制验证：250ms 发出 pause，等待 callback 确认后保持 200ms 再 resume，暂停窗口消耗样本增量为 0，最终仍完整输出 96,000 个 WAV 交错样本；750ms 发出 stop 后 callback 转为静音、decoder 收到取消并正常 join，Release 输出在 73,152/96,000 个已生产样本处终止。两项均为 0 underrun、0 stream error。这里验证的是底层控制原语，不代表 Tauri command、snapshot 和 UI 已接入。

另用一秒 44.1kHz 单声道 WAV 验证 worker 线程的 rubato sinc 流式重采样与单声道→双声道映射。Debug/Release 均向 48kHz 双声道设备输出 96,000 个交错样本，produced/consumed 相等，0 underrun、0 stream error。重采样按 1,024 帧 chunk 运行并裁剪 filter delay；未定义的多声道布局转换会显式拒绝，不静默猜测声道语义。

## 许可证发现

- Symphonia 0.6.1 为 MPL-2.0。以未修改依赖使用可与 Heni 独立代码分开，但发布时必须保留相应 notices/source availability 义务；不能简单写成“MIT 依赖”。
- CPAL 0.18.2 为 Apache-2.0。
- Opus adapter 为 MIT OR Apache-2.0；其 bundled libopus 使用 Opus license。
- ringbuf 为 MIT OR Apache-2.0。
- rubato 及其 audioadapter 组件为 MIT OR Apache-2.0。
- libmpv2 binding 为 LGPL-2.1；真正决定 Heni 分发义务的是选择的 mpv/libmpv binary 如何构建（LGPL 或 GPL 组件），尚未定案。

## 未完成门槛

- [x] 把 decoded PCM 通过有界 ring buffer 交给 CPAL callback；
- [x] callback 无锁/无分配/无日志代码审计；
- [x] deterministic harness 的 play/pause/resume/stop 原语；
- [ ] Tauri command 驱动的交互式 play/pause/stop；
- [x] 加载前一次性 accurate seek 与 completed drain；
- [ ] 播放中反复 seek、generation 切换和 completed 事件接入；
- [x] 44.1kHz mono → 48kHz stereo 的 worker sinc 重采样/明确映射；
- [ ] 多声道 layout、更多 rate pair 和重采样质量/CPU 量化；
- [ ] 音量、静音恢复和爆音检查；
- [ ] 连续切换 100 次、60 分钟内存/CPU；
- [ ] 默认设备改变、休眠/唤醒；
- [ ] 特殊/长路径、损坏文件、真实标签和 cover art；
- [ ] WebView reload 后 Rust session 保持；
- [ ] libmpv 音频、视频、seek、动态库和 license 对照；
- [ ] WebAudio 对照（不得用整文件 arrayBuffer 作为正式实现）。

## 可复现命令

```text
cargo run --bin output_device
cargo run --bin heni-native-audio-spike -- <sample paths...>
cargo run --release --bin heni-native-audio-spike -- <sample paths...>
cargo run --bin pcm_output -- <audio-path> [seek-ms] [pause-at-ms pause-duration-ms] [stop-at-ms]
cargo run --release --bin pcm_output -- <audio-path> [seek-ms] [pause-at-ms pause-duration-ms] [stop-at-ms]
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
```

Spike 代码位于 `spikes/native-audio`。ADR-0002 已定案，生产实现只提取经验证的最小模块；Spike 继续保留为可重复的硬件证据工具，不成为产品运行时依赖。
