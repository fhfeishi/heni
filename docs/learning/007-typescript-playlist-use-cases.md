# 007：歌单用例、事务结果与组件边界

歌单看似只是一个数组，实际包含三类规则：元数据校验、媒体引用的有序集合，以及与活动播放队列互不影响的浏览状态。把这些规则全部塞进 React 组件，会很快重现旧版超大页面的问题。

## 建议阅读

1. `src/contracts/library.ts`：歌单 snapshot 和五个用例级 Port 方法；
2. `src/infrastructure/tauri/libraryPort.ts`：TypeScript 输入如何映射成单一 request DTO；
3. `src/features/library/useLibrary.ts`：`applySnapshotMutation` 如何统一处理 Result、busy、error 和 snapshot；
4. `src/features/playlist/PlaylistPanel.tsx`：只负责创建与当前浏览选择；
5. `src/features/playlist/PlaylistMetadataForm.tsx`：名称/说明草稿；
6. `src/features/playlist/PlaylistItemsEditor.tsx`：批量选择与显式提交；
7. `src-tauri/src/library/playlist_repository.rs`：真正的去重、顺序、外键检查和事务。

## TypeScript 学习点

`LibraryPort` 暴露的是 `createPlaylist`、`addPlaylistItems` 这样的领域操作，而不是通用 `execute` 或数据库表名。调用者因此无法绕过 Rust 的事务不变量，测试也能直接描述用户行为。

Hook 中的 `applySnapshotMutation` 接收一个返回 `Result<LibrarySnapshot, LibraryError>` 的异步函数。这个小型高阶函数消除了五个用例重复的 loading/error 代码，但没有抽象成无领域含义的全局框架：它只有一个真实消费者和一个清楚的返回类型。

组件使用 `ReadonlyArray` 表达“输入不可被原地修改”，选择变化总是创建新数组。列表浏览状态只留在 `PlaylistPanel`，没有进入 Rust，也没有调用 playback port，所以切换歌单不会改变当前播放。

## 小练习

给“保存歌单”按钮增加“内容未变化时禁用”的纯函数判断。先为名称首尾空白、说明变化和完全相同三种情况写测试，再决定这个判断放在 `PlaylistMetadataForm` 内还是单独的 `.ts` 文件；只有出现第二个消费者时才抽取。
