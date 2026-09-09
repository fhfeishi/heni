# 017：用 TypeScript 建立错误展示防火墙

## 问题

端口返回的 `PlaybackError`、`LibraryError` 和 `WindowError` 都包含 `code` 与 `message`。`code` 是稳定协议；`message` 是给诊断使用的底层信息，可能包含 Rust/CPAL/SQLite 文案和用户完整文件路径。若 React 直接渲染 `error.message`，界面文案会随底层实现漂移，也可能泄露本机信息。

Heni 以前把多个 Hook 的 `.message` 用 `??` 串起来直接放进 `role="alert"`。这看似简单，却把诊断协议错误地当成了产品文案。

## 直白模型：来源与错误保持关联

`AppErrorContext` 是 discriminated union：

```ts
type AppErrorContext =
  | { source: "picker" | "playback"; error: PlaybackError }
  | {
      source: "directory-picker" | "library" | "media-details";
      error: LibraryError;
    }
  | { source: "window"; error: WindowError };
```

它比 `PlaybackError | LibraryError | WindowError` 多保存了“错误从哪里来”。同一个 `path-not-authorized` 发生在音频选择器时应重新选择文件，发生在目录选择器时应重新选择文件夹。来源是恢复语义的一部分，不能在转成字符串时丢掉。

`pickerError` 也直接保存 `AppErrorContext | null`，而不是保存 `string | null`。这样 React state 不会过早抹掉结构，后续代码仍能被 TypeScript 检查。

## 纯函数只输出用户可见模型

`presentAppError(context)` 是纯函数，返回：

```ts
interface AppErrorPresentation {
  title: string;
  message: string;
  action?: {
    kind: "choose-audio" | "choose-directory" | "open-library";
    label: string;
  };
}
```

这里故意没有 diagnostic `message` 字段。测试把带有私有 Windows 路径的原始诊断传入，再断言序列化后的展示模型不包含它。安全约束因此成为可回归行为，而不是代码评审中的口头约定。

`switch` 穷举错误码，`assertNever` 让新增协议错误码时产生编译压力。它不保证开发者一定写出完美文案，但能阻止“后端增加错误码、前端悄悄落入未知分支”。

## 恢复意图不是副作用

展示函数只返回 `choose-audio` 等有限意图，不直接打开对话框或改变视图。`AppNotice` 只渲染并回传意图，`App` 才调用已有 use case。这样：

- 纯映射可以快速单元测试；
- 组件不依赖 Tauri；
- 文件与目录恢复不会误走同一个 picker；
- 不会为了几个按钮建立全局 toast store。

这也是依赖倒置的一个小例子：展示层依赖稳定意图，不依赖 OS 操作细节。

## 为什么关闭轮询错误需要 `useRef`

播放 snapshot 每约 300ms 刷新。若连接持续失败，用户关闭提示后下一次轮询会立刻再次 `setError`。只把 state 设为 `null` 不足以表达“用户已看过当前这次持续故障”。

`suppressedRefreshError` 保存当前被关闭的 `code:message` 指纹：

- 同一轮询故障继续发生时不重复打扰；
- 成功 snapshot 会清空指纹；
- 用户主动发送新 playback command 时也清空，因此新故障仍能显示。

它用 `useRef` 而不是 state，因为这个指纹只控制异步轮询，不参与渲染。若以后错误协议增加稳定 incident id，应改用 incident id，而不是永久依赖完整 message。

## 一个容易忽略的收窄细节

可选 `presentation.action` 先保存到局部 `const action`，再在 JSX 条件内使用。这样 TypeScript 能在回调闭包中保持 `action !== undefined` 的收窄，不需要非空断言 `!`。当一个非空断言只是为了让编译器安静时，优先检查能否调整数据流让收窄自然成立。

## 建议阅读

- `src/features/shell/appErrorPresentation.ts`
- `src/features/shell/AppNotice.tsx`
- `src/app/App.tsx`
- `src/features/playback/usePlayback.ts`
- `src/features/shell/appErrorPresentation.test.ts`

## 小练习

新增一个结构化错误码 `media-busy`：先只修改契约，观察展示映射的编译错误；再为 playback 与 media details 设计不同的中文说明。要求不渲染原始 `message`，不增加 `any`、类型断言或全局状态，并各写一个映射测试。
