# 已实现功能与未完成边界

更新：2026-09-10。这是实现清单，不是全部验收通过清单。路径均相对仓库根。

| 功能 | 已实现 | 主要源码入口 | 待验证/未完成 |
| --- | --- | --- | --- |
| 曲库 | 文件/目录导入、扫描/取消、搜索筛选、缺失重定位、详情与资源管理器定位 | src/features/library/、src/app/workflows/ | 真实坏文件/旧库/大库矩阵 |
| 歌单 | 创建、说明/改名、删除；整单/行播放、双击起播；跨歌单或曲库多选加入；定位当前项；单项/批量移除 | src/features/playlist/、src/app/App.tsx | 最新交互实机、重启后成员一致性回归 |
| 队列与音频 | 唯一 Rust 会话、播放/暂停/seek、顺序/循环/随机、增删/重排及曲尾续播 | src/features/playback/、src-tauri/src/playback/ | 当前版本声音/设备变化/长时验证 |
| 视频 | HybridEngine 与唯一 video 输出、受控本机连续流、MP4/M4V/MOV/WebM 资格判断 | src-tauri/src/playback/video/、src/features/playback/ | 编码实际支持、连续播放/音画同步/切换释放未完整验收 |
| 浏览与舞台 | 保留浏览来源、搜索/滚动；顶部唯一歌曲/舞台双选；中央视频呈现 | src/app/App.tsx、src/features/shell/ | 最新版本真实声音及 Mini 连续性 |
| 外壳 | 小写 heni、同背景窗口控制栏、主玻璃与顶/左/底边缘工具面板、固定模式 | src/features/shell/、src/styles/edge-glass.css | Snap/系统菜单/DPI/边缘命中完整矩阵 |
| 设置与主题 | 外观/导入分区、六主题、固定头部与滚动内容、隐藏分区保留草稿、错误常显 | src/features/settings/ | 六主题与最小窗实机复核 |
| 场景 | PNG/JPEG 单/多图、轮换恢复、强度草稿；显露 0–300，中央淡出与顶部恢复操作 | src/features/scenery/、src/features/shell/SceneryBackdrop.tsx | 100–300 代码完成，明暗图/极值实机待验 |
| 玻璃 | 清透/柔雾/磨砂预设、通透度预览/保存/取消 | src/features/settings/、src/features/shell/glass.ts | 独立雾度微调与完整视觉验收 |
| 音量 | 音量/静音恢复、细轨道、拖动草稿与松开应用 | src/features/playback/ | 实时试听未实现，不等同于滑块已有 |
| Mini | 同会话切换、返回主窗与几何恢复、关闭清理 | src/features/shell/、src/features/playback/ | 当前视频/多 DPI 回归 |


移除歌单成员不删磁盘文件、不改变当前队列。未完成项按 [当前任务](status.md) 推进。
