# TypeScript 学习 011：把曲库筛选建模为只读投影

Phase 4C 的搜索、媒体类型、文件状态和排序不是数据库操作。SQLite snapshot 已经在内存中，用户改变筛选条件只需要把同一份数据投影成当前可见列表。

```ts
projectLibraryItems(
  items: ReadonlyArray<LibraryItem>,
  options: LibraryProjectionOptions,
): ReadonlyArray<LibraryItem>
```

输入和输出都标为只读，函数内部先 `filter` 得到新数组，再对新数组排序，因此不会改变 snapshot 的原始顺序。测试会保存 5,000 项输入的 id 顺序并在投影后逐项比较，这比只检查结果数量更能锁定“不修改来源”的约束。

## 联合类型限制筛选空间

类型、可用性和排序各自是小型字符串联合类型。DOM `<select>` 返回普通 `string`，所以组件通过直白的 `readKindFilter`、`readAvailabilityFilter` 和 `readSort` 收窄，而不是直接断言“它肯定正确”。即使未来选项值写错，也会回退到安全的默认投影。

## 派生数据不进入 state

组件只保存用户输入的四个小值；`visibleItems` 使用 `useMemo` 从 `items + options` 派生。把结果数组也放进 state 会带来同步问题：snapshot 更新时很容易忘记重算，形成第二份陈旧曲库。

搜索只读取标题、路径和快速索引 codec。它不调用 `LibraryPort` 或 `PlaybackPort`，组件测试也明确验证输入和筛选不会触发导入、播放、详情、下一首或入队回调。

## 5,000 项测试意味着什么

5,000 项纯投影通过，证明数据规则可控，但不等于 5,000 个 React 行同时渲染一定流畅。Heni 暂不引入虚拟列表；只有真实 Windows 渲染/滚动证据显示问题时，才为这个真实消费者增加依赖或窗口化逻辑。

## 建议阅读

- `src/features/library/libraryProjection.ts`
- `src/features/library/libraryProjection.test.ts`
- `src/features/library/LibraryPanel.tsx`
- `src/features/library/LibraryItemRow.tsx`
- `src/features/library/LibraryPanel.test.tsx`

## 小练习

新增一个“标题包含数字优先”的排序选项，先在纯函数测试中写清楚 `Track 2` 与 `Track 10` 的顺序，再修改联合类型和 `<select>`。不要把排序写进组件事件处理器。
