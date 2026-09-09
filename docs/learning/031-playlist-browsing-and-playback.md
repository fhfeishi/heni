# 031 · 浏览状态不等于播放状态

本次入口：`src/features/playlist/PlaylistListeningView.tsx`、`src/features/shell/RetainedView.tsx`、`src/app/App.tsx`。

## 类型如何流动

`LibraryPlaylist.itemIds` 表达持久化顺序，`projectPlaylistMembers` 产生搜索结果。点击播放时传完整 `LibraryPlaylist`，不传过滤后的 rows。App 按 ID 查找可播放媒体，再调用已有 `PlaybackPort.dispatch`；真正队列仍由 Rust 管理。

组件回调 `onPlay(playlist): void` 表达用户意图，端口返回 `Promise<boolean>` 表达工作流是否成功。界面只能在成功之后切舞台，失败时保留用户所在位置。

## 为什么保留部分界面

React 条件卸载会销毁组件内的搜索和编辑草稿。选中歌单 ID 由 App 持有，让侧栏与主区共享同一个选择；RetainedView 只在访问后保留浏览子树，通过 hidden/inert 阻止隐藏交互，独立容器保留滚动位置。它没有保存另一份曲库，更没有复制播放会话。

代价是已访问页面仍占内存，依然可能因父状态更新而重新渲染。因此只能用于有限、没有时钟等活跃工作的浏览页；不是无限页面缓存。若大曲库实测出现压力，再提升必要浏览状态或局部优化，不预建全局 store。

## 一个并发取舍

播放请求发出时记住导航 revision。如果用户等待期间已主动去了别处，迟到成功仍代表播放命令的结果，但不应该再次强行导航。同步 ref 阻止同一拍重复提交，React busy 状态负责呈现，两者用途不同。

## 小练习

阅读 `App.test.tsx` 中 `retains playlist context...` 测试，将过滤词改成完全不匹配的文本：验证“播放歌单”仍提交完整顺序。再给一个条目标记 available=false，补充测试验证提示的跳过数量与实际提交队列一致。

运行：`pnpm test`（当前环境通过项目脚本运行 Vitest）。
不要把合成播放端口的通过解释为真实音频已经验收。
