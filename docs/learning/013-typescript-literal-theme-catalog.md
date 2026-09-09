# 从只读目录推导主题联合类型

Phase 4E 没有先写一份字符串联合类型、再写一份独立主题列表。`theme.ts` 只维护一个只读目录，并从目录本身推导合法 ID：

```ts
export const heniThemes = [
  { id: "studio", label: "录音室" },
  { id: "nocturne", label: "深夜" },
  { id: "tide", label: "潮汐" },
] as const;

export type HeniThemeId = (typeof heniThemes)[number]["id"];
```

`as const` 让 `id` 保持字面量，而不是被拓宽成普通 `string`。新增或删除目录项时，`HeniThemeId` 会同步变化，不需要维护第二份容易漂移的声明。

## DOM 字符串为什么仍要收窄

原生 `<select>` 的值是 `string`，未来从设置或 SQLite 读回的值更应先视为 `unknown`。`parseHeniThemeId` 在目录中查找匹配项，找不到就回到默认主题。这样 `AppFrame` 只接收合法 `HeniThemeId`，组件内部不需要类型断言。

这次实现还触发了 `exactOptionalPropertyTypes` 的一个典型检查：可选属性未传入与显式传入 `undefined` 不是同一件事。`AppFrame` 在把可选美景地址交给背景组件前显式归一化为 `null`，让“没有图片”成为稳定的领域状态。

## 主题状态不属于播放状态

主题选择只保存在 React 外壳的局部状态中：

- 不进入 Rust `PlaybackSnapshot`；
- 不调用 playback port；
- 不复制到万能全局 store；
- 当前没有真实设置持久化用例，因此不伪造 SQLite 或文件权限层。

当后续出现“重启后恢复主题”的真实需求时，应增加独立的 settings port，用 `parseHeniThemeId` 校验外部值，而不是让组件直接访问存储。

## 缺图回退是联合状态

`SceneryBackdrop` 区分 `fallback`、`loading`、`ready` 和 `failed`。主题渐变始终存在，可选图片只是上层增强；图片失败后只移除图片节点，不会留下空白背景或把错误扩散到播放会话。

播放视图和浏览视图共享同一个根背景组件，但通过 CSS 语义变量使用不同的图片强度、模糊和遮罩。`prefers-reduced-motion` 会把主题与图片过渡压缩到近乎即时，不启动持续漂浮或脉冲动画。

## 建议阅读

- `src/features/shell/theme.ts`：从目录推导字面量联合；
- `src/features/shell/ThemeControl.tsx`：在 DOM 边界收窄字符串；
- `src/features/shell/SceneryBackdrop.tsx`：缺图回退状态；
- `src/features/shell/AppFrame.tsx`：主题、视图和背景的组合边界；
- `src/styles/global.css`：语义 token、受约束过渡和 reduced-motion。

## 小练习

为主题目录增加一个只用于 UI 的 `description` 字段，并在选择器旁显示当前描述。要求：不要新建第二份 `Record<HeniThemeId, string>`，不要把描述写入 playback snapshot，并补测试证明未知外部主题仍回退到“录音室”。
