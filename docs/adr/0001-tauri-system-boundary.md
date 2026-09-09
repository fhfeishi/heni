# ADR-0001：Tauri 重构的 TypeScript/Rust 系统边界

- 状态：Accepted
- 日期：2026-08-31

## 背景

Heni 希望以 Tauri + TypeScript 重构并把项目作为 TypeScript 学习工程。音乐播放器同时包含 React 产品界面、长生命周期播放会话、实时音频、大目录扫描、SQLite 和 Windows 原生集成。把所有能力放在 WebView 会牺牲稳定性；把所有业务放进 Rust 又偏离学习和可移植目标。

开源审计中，Museek 证明 React/Tauri 产品切片可行，但其 Windows 整文件 WebAudio 解码、TypeScript 递归扫描、JSON 持久化和宽权限不适合 Heni。Luminous/WaveFlow 展示了后端权威播放、SQLite、scanner 和 snapshot/event 的更稳健边界。

## 决策

采用“双核心但单一权威”结构：

- TypeScript 是产品与学习核心：React、交互用例、视图模型、contracts、运行时校验、客户端状态和绝大部分测试；
- Rust 是系统核心：权威 playback session/active queue、自动续播、音频设备、SQLite、scanner、metadata 和 OS integration；
- 组件只调用 TypeScript application port；Tauri `invoke/listen` 只存在于 infrastructure facade；
- Rust command 是薄入口，内部按 playback/library/storage/platform 拆模块；
- 播放挂载采用 initial snapshot + sequenced incremental events；scan 采用 Channel；
- SQLite schema/migration/repository 由 Rust 拥有，TypeScript 不直接执行 SQL；
- Tauri/TypeScript 位于仓库根；Flutter v1 作为只读基线归档到 `legacy/v1-flutter/`，直至 Windows 验收和用户批准删除归档。

## 被否决的方案

### 纯 WebView 播放和扫描

优点是 TypeScript 比例最高；缺点是长音频内存、codec 差异、后台/重载状态、扫描性能和权限边界风险。只保留为 Spike 对照。

### Rust 仅做极薄启动壳

不能可靠承载 WebView 重载后的自动续播、设备资源和大型曲库任务，因此否决。

### 所有领域规则都放 Rust

会让 React 退化成远程模板，并削弱 TypeScript 学习目标。只让 Rust 持有需要后台持续运行的 playback session 权威状态；其他产品用例留在 TypeScript。

### 继续扩展 Flutter

短期成本最低，但不能满足本次 TypeScript 工程学习和 Tauri 重构目标。Flutter 只作为可回退基线。

## 结果

正面结果：后台播放状态稳定、数据库和路径更安全、React 可测试、TypeScript 学习范围足够大、未来可以替换播放 adapter。

代价：需要维护跨语言 contracts；播放队列行为需要共享 fixture；开发者必须掌握基础 Rust/Tauri；调试链路比纯 Web 应用更长。

## 必须保持的不变量

- Rust playback snapshot 是活动队列和实际播放状态的唯一真相；
- 所有外部数据从 `unknown`/反序列化边界验证；
- 旧 JSON 在迁移稳定前只读；
- capability 默认拒绝；
- Flutter 删除和许可证变化需要用户单独授权。
