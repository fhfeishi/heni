# 用只读投影保护权威队列索引

Phase 4D 给队列和歌单加入了本地搜索，但搜索结果不能成为新的业务真相。Rust `PlaybackSession` 仍持有完整活动队列，SQLite 仍持有歌单成员；React 只负责把它们投影成当前可见的行。

## 为什么可见下标不能直接发给 Rust

假设权威队列是 `[A, B, C]`，用户搜索后只看到 `[C]`。如果点击这行时发送可见下标 `0`，Rust 会播放 A。`projectQueueRows` 因此同时保存项目和它在权威队列中的 `queueIndex`：

```ts
interface QueueProjectionRow {
  item: PlaybackItem;
  queueIndex: number;
  isCurrent: boolean;
  isNext: boolean;
}
```

搜索只删除不可见的投影行，不重排或改写源数组。播放和移除命令始终发送 `queueIndex`。这是一种很实用的 TypeScript 建模方法：让类型携带执行操作所需的身份，而不是在事件发生时重新猜测。

## `ReadonlyArray` 表达什么

`projectQueueRows`、`projectPlaylistMembers` 和 `projectPlaylistCandidates` 都接收 `ReadonlyArray`。它不是运行时权限系统，但能让编译器阻止 `push`、`splice` 等原地修改，并向调用者说明函数只读取 snapshot。

投影允许返回新数组，因为新数组只是 UI 结果，不会替代 Rust 或 SQLite 的状态。测试还会保存输入副本，确认筛选后顺序和成员关系没有变化。

## 缺失引用为什么仍然保留

歌单成员可能引用已经不在当前曲库 snapshot 中的媒体。`PlaylistMemberRow.item` 因此是 `LibraryItem | null`，而不是用非空断言掩盖问题：

```ts
interface PlaylistMemberRow {
  mediaId: string;
  playlistIndex: number;
  item: LibraryItem | null;
}
```

UI 会显示“曲库中已缺失”，用户仍可从歌单移除这个引用。这与旧数据迁移的原则一致：缺失文件不应导致歌单成员被静默删除。

## 确认状态也需要新鲜度

清空队列的确认框保存打开时的 `generation:sequence`。如果等待确认期间播放 snapshot 已改变，旧确认会自动失效，避免用户确认的是旧队列、实际清掉的却是新队列。

这和 seek 草稿绑定 `generation` 是同一类规则：临时 UI 状态必须说明它属于哪一份权威状态。

## 建议阅读

- `src/features/playback/queueProjection.ts`：保留权威索引的队列投影；
- `src/features/playback/QueueView.tsx`：搜索、定位与新鲜确认；
- `src/features/playlist/playlistProjection.ts`：成员顺序、缺失引用和候选过滤；
- `src/features/playlist/PlaylistItemsEditor.tsx`：局部搜索与批量选择；
- 对应的 `*.test.ts` / `*.test.tsx`：行为边界如何转成可执行证据。

## 小练习

给 `projectQueueRows` 增加一个仅在 UI 使用的 `displayPosition`（从 1 开始），然后补一项测试证明：搜索到原队列第 20 项时，`displayPosition` 可以是 1，但发送给 Rust 的 `queueIndex` 仍必须是 19。不要修改 `PlaybackCommand`，也不要把搜索状态写入 playback snapshot。
