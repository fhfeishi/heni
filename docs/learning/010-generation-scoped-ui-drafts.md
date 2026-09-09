# TypeScript 学习 010：让临时 UI 状态绑定播放代际

拖动播放进度条时，Heni 需要暂时显示用户正在选择的位置，直到抬手再发送 seek。这是局部 UI 草稿，不是 Rust 播放状态。

只保存一个 `number` 会有竞态：用户拖动第一首歌时，后台可能切到第二首；如果旧草稿仍在，第二首会短暂显示第一首的目标位置，甚至提交错误 seek。

Phase 4B 把草稿建模为：

```ts
type SeekDraft = Readonly<{
  generation: number;
  positionMs: number;
}>;
```

渲染和提交前都要求 `draft.generation === snapshot.generation`。新播放源会增加 generation，所以旧草稿无需额外 effect 就会失效。

## 为什么不监听 current item 后清空

在 effect 中观察曲目再 `setState(null)` 也能工作，但会产生一次带旧值的中间渲染，并把正确性依赖在清理时机上。把代际写进数据本身后，合法性检查是同步纯表达式，更容易测试，也与 Rust snapshot 已有的竞态协议一致。

## 这不是第二套播放状态

草稿只描述“用户当前拖到了哪里”，不决定真实播放位置。最终 seek 仍通过 typed `PlaybackCommand` 交给 Rust；下一份 snapshot 才是权威结果。类似地，媒体详情抽屉的打开状态和请求 epoch 属于前端交互状态，完整媒体信息仍来自 Rust `ffprobe` adapter。

## 建议阅读

- `src/features/playback/PlaybackBar.tsx`
- `src/features/playback/PlaybackBar.test.tsx`
- `src/features/library/useMediaDetails.ts`
- `src/features/player/NowPlayingView.tsx`
- `src/app/App.tsx`

## 小练习

在 `PlaybackBar.test.tsx` 增加一个场景：generation 不变但 sequence 增加，确认尚未提交的 seek 草稿仍然保留。思考为什么这里应绑定 generation 而不是 sequence。
