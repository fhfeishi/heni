# 034 · 场景集合不等于图片缓存

入口：`src-tauri/src/scenery/collection.rs`、`src/contracts/scenery.ts`、`src/features/scenery/useScenery.ts`。

Rust 持有一个简单的有序路径数组和当前下标，不引入场景引擎。SQLite 的既有 settings 表保存整个集合 JSON，替换或切换位置是一项事务写入。旧单图路径只在没有新集合设置时读取；明确保存空集合后，不再回退旧路径，避免清除后旧图复活。

前端只收到当前图、文件名、index/count，不收到所有私人路径，也不保存整组 base64。选择新集合时逐张串行验证并释放临时结果；平时切换只加载当前图，没有预加载缓存。数量上限 12，源文件合计上限 64 MiB，单图仍有既有文件与解码预算。源文件体积不是解码内存，不能据此承诺进程内存低于 64 MiB。

选择器顺序即初始顺序，重复规范化路径只保留第一次。手动前后切换首尾循环。丢图保留集合位置并返回 unavailable，UI 使用主题底色，仍能切下一张；不删除记录，也不循环扫描所有文件试图找到能显示的图片。

Hook 使用同步 busy ref 阻止同一拍重复提交；成功才接收新快照，失败保留原快照。组件显示位置和前后按钮，不计算另一份权威下标。可选 step 仅用于兼容单图预览端口，正式桌面适配器提供该命令。

练习：在 `useScenery.test.tsx` 给 step 返回 unavailable 和合法 collection 位置，验证 imageUrl 为 null、canStep 仍为 true；运行 `pnpm test`。不要把这个测试解释为真实窗口或自动轮换已经通过。
