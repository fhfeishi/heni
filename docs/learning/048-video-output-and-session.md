# 048 · 视频是一个输出，不是另一套播放器

入口：`features/playback/videoOutput.ts`、`VideoStage.tsx`、`playback/engine/hybrid.rs` 和 `playback/video.rs`。

原有 Rust PlaybackController 继续管理队列、循环、音量、暂停、定位和下一项。HybridEngine 在原生音频输出与一个 WebView 视频输出之间选择，不复制队列。VideoStage 始终挂载同一个 video 元素；歌曲/舞台切换只改变显示，不重新加载媒体。

TypeScript 的 VideoOutput 把 Rust 的播放意图应用到元素，再报告真实位置、结束或失败。epoch 标识一次加载（包括 seek），revision 标识暂停/音量等更新；旧事件不得写回新意图。切换输出前必须暂停视频并确认静音输出状态；确认失败就不启动原生音频。此处 quiet 是“输出已暂停”，不是修改用户静音设置。

设计取舍：不把视频整文件编码为 base64。第一候选使用返回有限字节的自定义协议，真实视频在约 20 秒处停住；改用 tiny_http 的流式响应，完整声明请求范围、以不超过 64 KiB 的磁盘读取持续供给。HTTP 只绑定 127.0.0.1，URL 使用系统随机令牌和播放 epoch，不接受文件路径；停止/切歌撤销旧资源。没有云端视频服务。

练习：给 videoOutput.test.ts 加一个“暂停期间更换媒体，旧 play Promise 才拒绝”的测试，确认不会把新视频标为失败；运行 `pnpm test`。

参考：
- https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/play
- https://docs.rs/tiny_http/0.12.0/tiny_http/struct.Response.html
- https://docs.rs/crate/getrandom/0.3.4/source/README.md

自动化用例通过不代表编解码或音画同步已验收。实机结果与剩余格式边界见 Strata 进度记录。
