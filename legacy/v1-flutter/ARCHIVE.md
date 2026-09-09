# Heni Flutter v1 Archive

归档日期：2026-08-31  
状态：只读基线；保留用于行为对照、回退和数据迁移验证。

## 内容

- Flutter/Dart 源码：`lib/`、`test/`；
- Windows、Android、iOS、macOS、Linux 平台工程；
- `pubspec.yaml`、`pubspec.lock` 和 Flutter 工具配置；
- 原架构、产品、实施计划与历史日志；
- 本地 Windows x64 Release：`releases/windows-x64/`（由仓库根 `.gitignore` 排除，不提交约 76.3 MiB 二进制）。

## Windows Release 记录

- 主程序：`releases/windows-x64/heni.exe`；
- Release 文件数：25；
- Release 总大小：80,059,360 bytes；
- `heni.exe` 大小：289,792 bytes；
- `heni.exe` SHA-256：`F160FE6CB6BE7F339640251FCAA65DD876E98805DCB3F843B566CF2078F84E1B`；
- 原构建时间：2026-08-30 12:43:21 +08:00。

二进制是本机暂存资产，不依赖 Git 恢复。迁移或清理工作区前应另行备份 `releases/`。

## 构建

在本目录执行：

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

该版本继续使用 Flutter、Riverpod、media_kit、media_kit_video 和 ffprobe。它不再是仓库根默认实现，除修复迁移阻塞或验证历史行为外，不在此目录继续开发新功能。

## 数据保护

旧版本使用 `%APPDATA%/Heni/library.json`。新 Tauri 版本完成只读导入、备份、回滚和幂等验证前，不得覆盖或删除此文件。

