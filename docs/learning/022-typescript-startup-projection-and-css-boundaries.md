# TypeScript：启动投影与稳定样式边界

## 问题

“运行时握手成功”不代表曲库和播放快照已经读取完成；浏览器里没有 Tauri 也不代表桌面产品
故障。一个 `loading` 布尔值不能完整表达这些差别。

## 直白模型

Heni 使用判别联合 `AppBootState`：

| 状态 | 含义 |
| --- | --- |
| booting | 正在等待运行时或必要快照 |
| ready | 运行时、曲库和播放初始快照可用 |
| degraded | 浏览器预览，或部分必要快照不可用 |
| blocked | 桌面握手失败或返回契约不匹配 |

`reason` 只出现在需要说明原因的分支。TypeScript 必须先通过 `status` 收窄，才能读取对应
原因，避免“ready 但同时附带致命错误”这类非法组合。

## 最终选择：派生，不复制

`projectAppBootState` 每次由现有 runtime、library 和 playback Hook 的只读状态计算结果。
没有新增 React state、effect、全局 store 或启动管理器，因此没有另一份状态需要同步。
设置拥有安全默认值，不加入必要快照条件；已有快照后的一次用户操作失败也不等同于重新启动。

环境识别留在 Tauri adapter：官方 `isTauri()` 返回 false 时产生明确的 `browser-preview`
原因。App 仅在这个条件下抑制预期自动读取错误，不通过检查错误 message 猜测环境。
共享视图类型位于 runtime feature，外壳不反向引用 app 装配层。

## 样式为什么先拆分再重画

`global.css` 现在只保留有序导入。默认变量与三套主题覆盖全部在 `tokens.css`，功能样式只
消费语义变量。拆分首先保持声明值和功能规则顺序；视觉调整留到 S2-2，避免把结构改动与视觉
变化混在同一回归里。

这里没有引入 CSS Modules、CSS-in-JS 或大型组件库：现有局部类名已能表达职责，增加工具
不能代替清晰边界。响应式规则仍集中放在最后，后续出现真实独立变化原因时再继续细分。

## 验证与限制

纯投影测试覆盖所有状态；App 集成测试证明浏览器预览不显示预期 IPC 错误，桌面握手失败
仍显示核心不可用。Windows Release 已检查主要窗口尺寸。浏览器工具缺少内部文件，本轮
浏览器截图/DOM 与 DPI 验收没有记为通过。

## 阅读与练习

建议依次阅读 `features/runtime/appBootState.ts`、`app/boot/projectAppBootState.ts`、
`infrastructure/tauri/runtimeInfoPort.ts` 和对应测试。

练习：为“播放已失败、曲库仍在加载”的组合写测试，说明希望先显示 booting 还是 degraded，
再修改纯投影实现；不要通过新增 effect 同步一个独立的 boot state。
