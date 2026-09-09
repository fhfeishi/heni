# 037 · 统一外观，同时保留平台职责

入口：`PreferencesControl.tsx`、`shell/theme.ts`、`styles/tokens.css`、`src-tauri/tauri.conf.json`。

主题色卡把用户点击转成 `SettingsUpdate` 的 themeId 部分更新，Rust 校验并保存，成功快照再驱动整窗 data-theme。色卡不是另一份主题状态，失败时不会显示一个实际上没有保存的选择。

六套主题分别定义底色、表面、文字、强调、焦点与场景色，而不是只更换主按钮。新增 ID 同时加入 TS 契约和 Rust 枚举，不开放任意字符串。当前 schema 版本不变，但旧二进制不认识新增 ID，因此不能声称选择新主题后仍兼容降级到旧程序。

设置面板沿用原生 details 的展开语义与现有功能组件，扩大布局并按职责分区。Esc/关闭按钮会返回焦点到 summary；点击外部收起时不抢走用户正在点击的焦点。它是非模态面板，不添加不真实的 aria-modal 或不必要的焦点陷阱。

窗框先使用 Tauri 已有的 Dark 原生主题配置，继续保留 Windows 拖动、缩放和窗口按钮。没有贸然移除 decorations 或实现自制标题栏，因此没有把 Windows Snap、命中测试等平台工作搬进 React。是否彻底消除特定 Windows 主题下的白边仍要实际检查。

练习：给 PreferencesControl 测试增加 busy=true 时色卡禁用的断言，再检查新主题 partial update 只包含 themeId；运行 `pnpm test`。视觉色卡和测试不替代六主题实际对比度与 DPI 检查。
