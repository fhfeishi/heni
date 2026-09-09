# ADR-0003：单根应用与 Flutter v1 归档

- 状态：Accepted
- 日期：2026-08-31

## 背景

Heni 的 Flutter 实现原本占据仓库根目录。Tauri walking skeleton 最初放在 `apps/desktop/`，使仓库同时存在旧根工程、新子工程和只有一个消费者的 pnpm workspace。该布局在迁移期可降低碰撞，但长期会增加入口、脚本和路径认知成本。

用户明确要求保留旧源码与 Release，并允许用新代码接管整个项目。当前也不存在第二个前端应用或可复用包消费者，因此继续维持 workspace 没有实际收益。

## 决策

1. `src/`、`src-tauri/` 和根 `package.json` 构成唯一在建应用；
2. Flutter v1 源码、历史文档、生成缓存和 Windows Release 归档到 `legacy/v1-flutter/`；
3. 新应用不得在构建期或运行期依赖归档目录；
4. 历史 Release 与构建缓存保留在本地但由 Git 忽略，源码和归档说明可正常版本管理；
5. 只有出现第二个真实消费者时才引入 pnpm workspace 或 `packages/`；
6. 旧 `%APPDATA%/Heni/library.json` 仍是迁移输入，在导入器具备备份、事务和回滚验证前不覆盖。

## 后果

- 开发者从仓库根执行一套安装、测试与构建命令；
- 新旧实现的所有权清楚，Flutter v1 仍可用于行为核对和回退取证；
- Git 不承担约 76 MB 历史 Windows 运行包的分发成本；
- 若未来增加真正共享的客户端或库，需要新 ADR 重新评估 workspace，而不是提前铺设抽象。

## 未采用方案

### 长期保留 `apps/desktop/` workspace

只有一个应用时多一层路径与包配置，却没有独立发布或复用收益。

### 删除 Flutter 实现

会失去功能等价、数据格式和历史 UI 行为的证据，也不符合保留旧版本的要求。

### 将旧 Release 提交到 Git

二进制体积大、不可审查且可由归档源码重建。保留本地副本与校验值更适合作为迁移保险。
