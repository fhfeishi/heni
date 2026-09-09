# 018：路径会变化，媒体身份不应变化

## 问题

缺失文件重新定位看起来只是“选择一个新路径”，但 Heni 的歌单和活动播放队列引用的是媒体身份。如果把新路径当成一条新媒体记录，旧歌单引用会继续指向缺失项；如果前端直接改对象，又会绕过 SQLite 与 Rust 权威播放会话。

## TypeScript 只编排意图

界面没有直接访问文件系统或数据库。`LibraryItemRow` 只调用 `onRelocate(item)`，`LibraryRelocatePickerPort` 负责取得一个系统授权路径，`LibraryPort.relocateMedia` 再把 `{ mediaId, newPath }` 作为一个完整请求交给 Rust。

这两个值不能合并成一个 `PlaybackItem` 直接覆盖：

- `mediaId` 回答“仍然是哪一条媒体”；
- `newPath` 回答“现在从哪里读取”；
- 返回的 `LibrarySnapshot` 才是事务提交后的新事实。

`useLibrary` 只有在端口返回 `ok` 后才替换 snapshot，并把同一 ID 的已提交媒体返回给 `App`。如果该 ID 已在播放队列中，`App` 发送 `refresh-item`，而不是在 React state 中修改队列。

## 为什么需要两个 Rust 事务边界

SQLite relocate 用一个 `IMMEDIATE` transaction 完成路径冲突检查、媒体更新和手动来源登记。媒体 ID 不变，因此 `playlist_items.media_id` 不需要重写，引用自然保留。

播放会话不是 SQLite 表，而是另一个权威状态机。`PlaybackController` 先在 session 副本中应用 `refresh-item`：非当前项只更新队列 DTO；当前项才让 engine 按原位置与播放状态重新加载。加载失败时不提交候选 session。这不是跨数据库和音频设备的伪“全局事务”，而是两个边界各自保证不出现半提交的内部状态。

## 一个容易遗漏的后续导入问题

初次导入时，Heni 用规范化路径生成媒体 ID，所以早期代码把两者当成永远相等。重新定位后这个假设失效：新路径命中 `normalized_path` 冲突更新时，真实 ID 仍是旧 ID。导入/扫描逻辑必须回查该 ID，再写 `manual_imports` 或 `root_media`，否则会触发外键错误。

这体现了一个常见工程原则：数据库中的唯一查找键可以变化，但被其他聚合引用的身份键应保持稳定。

## 建议阅读

- `src/contracts/library.ts`：relocate 输入和 picker/库端口；
- `src/infrastructure/tauri/libraryRelocatePicker.ts`：系统选择器 adapter；
- `src/features/library/useLibrary.ts`：只投影已提交 snapshot；
- `src/contracts/playback.ts`：`refresh-item` discriminated union；
- `src-tauri/src/library/repository.rs`：稳定 ID、冲突回滚和来源关联；
- `src-tauri/src/playback/session.rs`：同 ID 队列刷新；
- 对应测试：从 UI 意图一直覆盖到 SQLite 和播放 controller。

## 小练习

给 `refresh-item` 增加一项 TypeScript contract 测试：验证空 `id` 或空 `path` 会在调用 Tauri 前被拒绝。然后为 Rust session 增加一个冲突用例：替代路径与队列中的另一项仅大小写不同，命令应返回 `duplicate-queue-item`，并证明原 snapshot 完全不变。
