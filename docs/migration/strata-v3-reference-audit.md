# Strata V3 参考审计

审计日期：2026-09-08。范围：参考源码、旧版截图及 UI 实现、当前关键边界、V2 历史记录。不是完整安全审计，也不是本轮原生运行验收。

## 结论

现有 Tauri + React/TypeScript + Rust + SQLite 的方向合理，不应再次整体重写。主要缺口是产品组织：当前歌单管理、正在播放和单图背景尚未形成旧版那种连续的“选歌—聆听—舞台—返回”体验。专业化应优先改善这个闭环，而不是增加框架、参数、状态面板或歌词。

## Museek：取边界与交互，不复制整个产品

本地实际核验提交：`83c547df1525a7a2b6de66f5151b458a1abe04fb`，MIT，位于 `research/upstream/Museek`。此次重新阅读这个固定快照，并访问了 [上游页面](https://github.com/aeroray/Museek)。没有更新快照，也没有把网页内容当作最新 HEAD 的源码审计。

| 证据（相对 Museek 根目录） | 观察与 Heni 决策 |
| --- | --- |
| `src/components/layout/RootLayout.tsx` | Sidebar / 主内容 / 常驻 PlayerBar，Mini 复用播放状态。借鉴稳定壳层，不要求引入其路由体系。 |
| `src/lib/playback/clock.ts` | 时间订阅独立于粗粒度播放状态。借鉴更新隔离，不带入歌词订阅。 |
| `src/lib/audio.ts` 的 `decodeWebAudio` | 存在完整读取并解码 AudioBuffer 的路径；不能据此证明所有播放均如此，但不适合作为 Heni 大型本地文件的默认方案。保留当前 Rust 原生播放。 |
| `src/lib/localMusic/scan.ts` | 前端通过 fs 插件递归读取目录。Heni 已有原生扫描与取消边界，不为模仿参考而迁回前端。 |
| `src-tauri/tauri.conf.json` | 快照关闭 CSP、资产范围宽泛。不可照搬安全配置；按 Heni 实际授权范围开放。 |

上游定位是音乐聚合器，并非纯本地播放器。在线来源、下载、歌词和多窗口能力不构成 Heni 的需求清单；本轮不评价其全部实现质量。参考源码保持只读；若未来复用 MIT 代码，应保留声明并记录来源。

## Flutter Heni：保留什么、修正什么

实际阅读：`legacy/v1-flutter/lib/design/app_theme.dart`、`heni_shell_theme.dart`、`features/player/presentation/player_view_switcher.dart`、`player_screen.dart` 的歌单/舞台装配段，以及 `features/scenery/presentation/scenery_stage.dart`。

实际查看截图（均为历史截图，不是本轮运行结果）：

- `legacy/v1-flutter/build-cache/visual-check/final-normal-workspace-release-retry.png`：歌单侧栏、暖珊瑚与青绿呼应、整窗透景、底部播放台。
- `legacy/v1-flutter/build-cache/visual-check/player-controls-default-1280x720.png`：深青黑底、金色主动作、“播放中 / 歌曲”切换、安静的舞台空态。
- `legacy/v1-flutter/logs/visual-qa/wide.png`：较早版本且画面截断，仅作历史辅助；其中 H 标志不符合用户后来的明确要求，不恢复。

源码表明旧版两种视图采用保留子树、200ms 淡入与微位移，隐藏视图禁用指针和语义；场景支持多图、11秒轮换及缩放/淡入。这些机制解释了“灵动”，但静态截图无法证明运行流畅性。

保留：小写 heni、可辨认的主题种子色与辅助暖色、统一场景空间、歌单的个人收藏感、返回时保留浏览位置、播放不中断。

修正：厚重套层和全局灰雾、低对比次要文字、过多路径信息、隐藏页面仍可能运行的定时工作。旧场景的轮换定时器主要随图片变化重启，不能直接作为隐藏/减少动态效果处理的范本。新实现应按可见性、用户动效偏好暂停，不机械复制时长或动画。

## 商业播放器：仅参考公开体验

- [Apple Music Windows MiniPlayer 指南](https://support.apple.com/guide/music-windows/use-the-miniplayer-mus71d7dcfce/windows)：小窗仍提供音量、播放控制和接下来播放列表。Heni 借鉴控制连续性与紧凑布局，不复制歌词、订阅或品牌样式。
- [腾讯 ISUX《QQ音乐 V5：星设定》](https://developer.cloud.tencent.com/article/1154333?from=15425&frompage=seopage)：腾讯云页面发布日期为 2018-06-29，是历史移动设计案例，不是当前 Windows 版审计。其音乐感、冷暖层次、通透背景与有意义的过渡，可支持 Heni 的视觉方向。
- [腾讯音乐官方业务介绍](https://www.tencentmusic.com/zh-cn/business.html)用于核对产品定位，不据此推断内部架构或性能。

以上没有访问 Apple Music / QQ音乐的闭源实现，没有进行两款软件的实机横向测试；“专业播放器”在 V3 中转化为 Heni 自己可检验的体验标准。

## 当前 Heni 复核与 V2 调整

| 当前证据 | V3 处理 |
| --- | --- |
| `src/app/App.tsx`、`src/contracts`、`src/infrastructure/tauri` | 已有组合根和端口边界，保留；App 只针对有独立职责的编排拆分。 |
| `src/features/shell/appView.ts`、`features/playlist/PlaylistPanel.tsx` | 当前四视图和独立歌单管理还不是旧版连续工作区；建立浏览上下文与舞台展示的正交关系，避免另增一个重复页面。 |
| `src/contracts/scenery.ts` | 当前为单张 PNG/JPEG 背景接口，不等于场景集、轮换与舞台体验完成。 |
| `src/features/playback/PlaybackVolume.tsx` | 拖动草稿、松开提交；不能宣称已经具备实时试听。V3 要求单独设计声音预览与持久化边界。 |
| `src-tauri/src/lib.rs` 的 setup | 曲库/设置打开失败仍可能在前端出现前终止。应验证并建立可恢复错误入口，不只完善前端空态。 |
| V2、ADR 0004–0006 | 条件轮询和局部时钟已有实现。取消“必须改事件”的机制性门槛，以真实开销、时序正确性和体验决定是否升级。 |

V2 记载的 47 个 TS 测试文件 / 271 项测试、114 项 Rust 通过 / 3 项忽略，以及 CB8E62D6 前缀的 Release 均为历史证据，本轮没有重跑或重建。V2 明确记载该 exe 不含部分后续源码修复；后续必须重新建立源码—构建—验收对应关系。

本轮仅新增本审计与 `strata-v3.txt`，不更改产品代码、旧数据、参考快照或 V2 历史。V3 将规范与进度分开，并明确视频兼容缺口不能静默忽略，但不能借该缺口无限扩大本地音乐版本范围。
