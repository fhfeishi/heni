# 032 · 导入不等于播放

入口：`src/app/workflows/useLocalImportWorkflows.ts`、`src/app/App.tsx`、`src/contracts/settings.ts`。

## 用依赖边界表达规则

文件选择器返回 `Result<ReadonlyArray<PlaybackItem>, PlaybackError>`。工作流先处理取消或错误，再调用曲库的 `importFiles`；只有收录成功才通知 App 展示曲库。这里复用既有媒体描述类型，不为同一份数据增加转换层。

工作流不再接收 `dispatch`。因此“导入不能替换队列”不只是一个条件分支：这个模块没有发送播放命令的能力。播放仍由用户明确点击歌曲或歌单触发，原生端继续持有唯一播放会话。

`Pick<SettingsSnapshot, "recursiveScan" | "includeVideo">` 将设置依赖限制在目录扫描实际需要的两个字段。以后误读 `settings.autoplayOnLoad` 会产生类型错误。

## 兼容不等于继续使用旧行为

设置协议保留 `autoplayOnLoad` 字段，以兼容已有存储和原生协议；导入工作流不消费它，设置面板也不再提供这个开关。为移除一项旧行为立刻迁移数据库，会增加与当前目标无关的数据风险。未来统一清理协议时再处理字段，而不是现在添加一套版本迁移框架。

## 回归与小练习

`App.test.tsx` 对旧字段 true / false 分别运行同一测试：已有歌曲正在播放，导入另一首后新歌曲出现在曲库，播放命令未被调用，播放条仍显示原歌曲。工作流测试另外覆盖取消、选择器失败、收录失败，确保这些结果不触发成功导航。

小练习：给上述参数化测试中的文件选择器返回空数组，验证既不收录，也不发送播放命令；运行 `pnpm test`。注意这些模拟端口测试只能验证控制流程，不能证明真实音频没有中断，后者需要 Windows 播放验收。
