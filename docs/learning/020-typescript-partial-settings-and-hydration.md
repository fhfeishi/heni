# TypeScript：Partial 设置更新与 hydration 边界

## 问题

Heni 的设置读取返回完整 `SettingsSnapshot`，更新请求却只携带用户刚修改的字段：

```ts
type SettingsSnapshot = Readonly<{
  themeId: HeniThemeId;
  recursiveScan: boolean;
  includeVideo: boolean;
  autoplayOnLoad: boolean;
}>;

type SettingsUpdate = Readonly<Partial<Omit<SettingsSnapshot, "schemaVersion">>>;
```

完整快照保证每个消费者都拿到确定值；Partial 请求避免切换一个开关时重写其他字段。

## 为什么不能直接展开

在 `exactOptionalPropertyTypes` 下，测试中的以下写法无法证明结果仍是完整快照：

```ts
{ ...current, ...update }
```

`update.themeId` 的类型可能包含 `undefined`，展开后 TypeScript 会诚实地认为必填字段也可能
变成 `undefined`。正确做法是显式表达 merge 规则：

```ts
const next: SettingsSnapshot = {
  schemaVersion: 1,
  themeId: update.themeId ?? current.themeId,
  recursiveScan: update.recursiveScan ?? current.recursiveScan,
  includeVideo: update.includeVideo ?? current.includeVideo,
  autoplayOnLoad: update.autoplayOnLoad ?? current.autoplayOnLoad,
};
```

这里没有使用 `as SettingsSnapshot` 欺骗编译器。代码把“缺少字段时保留旧值”的业务语义写了
出来，类型检查只是验证它。

## loading 与 busy 不是同一个状态

- `loading`：应用正在读取已有偏好；
- `busy`：用户已经提交更新，正在等待持久化结果。

Heni 有安全、版本化的默认设置，因此 loading 期间仍可选择文件或导入目录。把两者都塞进
一个 `busy` 会让整个播放器因为一个很快的设置读取而失去响应。只有正在写入的具体设置控件
需要暂时禁用。

如果用户在人能感知的读取完成前触发操作，应用使用安全默认值；真实环境的 SQLite 读取通常
会在首个交互前完成。对应测试故意让读取 Promise 一直 pending，证明主操作不会被锁死。

## 防止迟到读取覆盖用户更新

`useSettings` 使用 mutation epoch：开始读取时记住 epoch；用户提交更新后 epoch 增加。旧读取
完成时若 epoch 已变化，就丢弃旧结果。这与播放的 generation/sequence 是同一类思想：异步
结果只有在仍属于当前状态时才能提交。

## 错误影响范围

设置保存失败不会破坏播放会话或曲库，因此错误留在设置入口，并保留最后一次已提交快照。
只有数据库整体不可用等真正阻断主流程的问题才应升级为全局 notice。

## 建议练习

给 `SettingsUpdate` 增加一个可选的 `sceneryOpacity` 数值：

1. 用 Zod 限制在 `0..1`；
2. 更新显式 merge 测试；
3. 写一个失败测试证明 `undefined` 不会清空已保存值；
4. 思考“恢复默认值”应使用明确 command，还是把 `null` 引入 Partial update。

