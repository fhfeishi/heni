# 051 · 背景显露的分段映射

`sceneryPresentation.ts` 保留 0–100 的旧端点；`sceneryImmersion` 将 100–300 映射为
0–1。中央内容淡出，已有背景逐渐去除阅读遮罩，不复制图片、不使用大于 1 的 opacity。

`AppFrame.tsx` 在图片成功加载、浓度大于零、非 Mini、非可见视频时才允许沉浸。
沉浸中的 main 使用 inert 与 aria-hidden；若原焦点在其中，将焦点转到顶部恢复按钮。
恢复按钮只改变本地呈现，不写设置；图片失败自动恢复内容。播放条和窗口操作位于 main 外。

Rust 的 scenery_reveal 从 u8 改为 u16，校验上限 300；JSON 整数存储格式不变，旧值仍可读。
测试入口：AppFrame.test.tsx、sceneryPresentation.test.ts、settings.test.ts、Rust settings tests。
