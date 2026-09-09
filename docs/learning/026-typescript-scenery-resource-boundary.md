# 026 — 美景背景：把资源权限和界面状态分开

## 问题

`<img>` 能显示图片，不等于桌面应用已经具备可维护的背景设置。还要处理本地选择权限、重启、取消、坏图、源文件移动和数据库写入失败。

## 直白模型

界面只认识三个状态：

- `empty`：用户没有选择图片，显示主题渐变。
- `ready`：已验证并读取图片，带文件名和受限的 data URL。
- `unavailable`：仍保留选择，但原图已丢失或不能显示；显示主题渐变，并允许重新选择或清除偏好。

这比 `hasImage`、`isMissing`、`url` 等可以互相矛盾的布尔值更清楚。TypeScript 的 discriminated union 让分支内部只能读取存在的字段。

## 最终选择

`SceneryPort` 只有 `read`、`choose`、`clear`。选择器在 Rust 打开，前端不能传任意文件路径，也不需要扩大 asset protocol 或文件系统权限。系统选择器关闭后的 `null` 表示取消，不等于 `empty`。

Rust 在后台线程读取文件，限制文件为 8 MiB、单边 8192 像素、2400 万像素以内，并设置 128 MiB 解码分配预算；只接受 PNG/JPEG，拒绝动画 PNG，实际解码成功后才提交偏好。图片库的分配限制不是整个进程的硬内存上限，不能这样宣传。尺寸和文件上限是额外的明确边界。

SQLite 只保存 `ui.sceneryPath`，复用现有 settings 连接、迁移和事务，不创建第二份数据库或资源管理系统。重启只读取已保存的选择。清除把该偏好改为 `null`，从不删除原图；图片不会上传，也不随应用安装包分发。

前端接收数据从 `unknown` 开始，用 Zod 收窄为有限状态。图片只能是有长度限制的 PNG/JPEG data URL，不接受远程地址、SVG 或原始系统路径。

`useScenery` 的 ref 同步挡住重复点击；只有这项设置在初始读取期间不可操作，不影响播放/导入。生命周期 epoch 拒绝旧 port 和卸载后的迟到结果。取消和失败保留最后提交的 snapshot；WebView 解码失败只影响匹配的当前图片。

## 为什么暂时使用 data URL

当前只有一张不频繁更换的背景，限制明确。data URL 避免重新授权任意本地路径，但有约三分之一的编码体积开销和 IPC/内存复制。当前不轮询图片，也不把图片放进播放 snapshot。若实测需要多图轮播或更大资源，再评估受控资源 ID、缓存文件和流式 asset protocol；现在不预建它们。

没有引入前端全局 store，也没有让播放器负责背景生命周期。

## 验证和边界

契约、adapter、Hook、组件、App 集成测试覆盖取消/清除的区别、重复操作、迟到结果、错误隔离和背景回退。Rust 验证真实 PNG/JPEG、损坏/超大图片、只读源文件、数据库重开、清除持久化与失败回滚。Windows 图片选择器和视觉效果必须另做实机验收，见 `docs/migration/release-evidence.md`，单元测试不能代替。

首切片不支持网络图、SVG、动画、图片库轮播或手动调节不透明度。播放/浏览的背景处理强度仍由样式统一控制。

## 建议阅读

1. `src/contracts/scenery.ts`
2. `src/infrastructure/tauri/sceneryPort.ts`
3. `src/features/scenery/useScenery.ts`
4. `src/features/scenery/SceneryControl.tsx`
5. `src/features/scenery/useScenery.test.tsx`

练习：增加一个“重新读取原图”用例。先写失败测试，要求重新读取失败时仍能清除偏好、不能接收任意路径、不能重置播放队列；再决定是否真的值得增加一个按钮。

实现参考（接口核对，未复制源码）：[Tauri 原生文件选择器](https://docs.rs/tauri-plugin-dialog/2.7.2/tauri_plugin_dialog/struct.FileDialogBuilder.html)、[image 解码限制](https://docs.rs/image/0.25.10/image/struct.Limits.html)。
