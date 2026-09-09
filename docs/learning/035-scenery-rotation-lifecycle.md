# 035 · 自动轮换是可暂停的任务，不是永久 interval

入口：`src/features/scenery/useSceneryRotation.ts`、`useScenery.ts`、`src/contracts/settings.ts`。

轮换开关属于持久设置，默认 false；计时器属于界面生命周期，不写入数据库。只有多张图片、当前图片可用、没有加载/操作/错误时，useScenery 才启用轮换。next 用 useCallback 保持稳定，普通播放状态刷新不会不断重置计时器。

调度使用一个 11 秒 timeout。完成一次切换后才允许下一次计时；加载期间不会堆积切换请求。隐藏、失焦、减少动态效果会清除定时器，回来后重新等待完整间隔，不追赶后台错过的轮次。暂停不会改变用户保存的开关。

effect 清理会移除事件监听并取消 timeout；active 标记使卸载后迟到的成功不能再次启动计时。已进入原生的切图不能强制撤销，但停止后不再发下一条命令。切图仍使用现有原生事务保存位置，不增加第二份场景状态。

设置读取给旧数据补 false，部分更新不附带默认值，避免用户调整主题时偷偷改变轮换开关。保存失败仍显示已提交状态和既有设置错误，不能假装保存成功。

小练习：在 `useSceneryRotation.test.tsx` 增加隐藏后重新可见的场景：恢复后推进 10,999ms 应无新命令，再推进 1ms 才切换。运行 `pnpm test`，确认卸载后 timer count 为 0。

测试模拟 WebView 的 focus/visibility 与媒体查询，不能证明 Windows 最小化一定按预期发出这些事件。真实最小化、恢复及减少动态设置切换仍要用新可执行候选验收。
