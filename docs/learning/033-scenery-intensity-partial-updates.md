# 033 · 读取默认值，不等于写入默认值

入口：`src/contracts/settings.ts`、`src/app/App.tsx`、`src-tauri/src/settings/mod.rs`。

背景强度的流向是：滑块 → React 草稿 → 背景 CSS 变量。拖动不调用原生设置；点击保存才提交 `sceneryIntensity`，Rust 校验 0–100 的整数并写入既有 settings 表。成功清除草稿，失败保留预览值供重试，取消恢复已保存值。

旧设置没有该字段，读取时默认 100 可以保持此前外观。但不能把读取 schema 的默认值原样继承给部分更新：测试发现，直接 `.partial()` 后，当前 Zod 行为仍会补入默认值，使仅修改主题的请求带上 `sceneryIntensity: 100`。

现在复用一个没有默认值的数值 schema：读取加 `.default(100)`，更新先覆盖成无默认值的字段，再 `.partial()`。不新建设置框架，也不复制数值规则。

回归分三层：契约验证旧字段缺失、非法值和部分更新；App 验证拖动不写入、取消、失败重试；Rust 使用独立临时数据库验证重新打开后恢复 0/35/100，使用失败触发器验证整个设置事务回滚。没有操作用户数据库。

小练习：在 `src/contracts/settings.test.ts` 增加仅修改 `recursiveScan` 的断言，确认解析结果不包含强度；运行 `pnpm test`。再暂时移除更新 schema 的 extend，观察这项回归为何失败，最后恢复正确实现。

这证明状态和存储规则，不证明图片实际观感、对比度或 Windows 缩放已经验收。
