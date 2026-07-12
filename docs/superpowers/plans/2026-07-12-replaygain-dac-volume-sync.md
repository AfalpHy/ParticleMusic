# ReplayGain 与 DAC 双向音量同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为全部播放来源接入标准 ReplayGain，并让 USB DAC、应用音量和 Android 后台物理按键保持真实一致。

**Architecture:** 工作拆为三个可独立验收的子计划，依次完成元数据与统一增益、DAC 协议与双向同步、Android 媒体会话与适配文档。每个子计划均采用测试先行、独立提交；主项目只暂存计划明确列出的文件，保留工作区既有未提交改动。

**Tech Stack:** Flutter 3.44、Dart、Drift、audio_tags_lofty/Lofty Rust FFI、media_kit/libmpv、Android Kotlin USB Host、audio_service MediaSession、JUnit 4。

---

## 执行顺序

1. [ReplayGain 元数据与全部播放路径](2026-07-12-replaygain-metadata-playback.md)
2. [DAC 协议适配与双向同步](2026-07-12-dac-volume-protocol-sync.md)
3. [Android 后台音量键与通用适配手册](2026-07-12-android-background-volume-and-adaptation-guide.md)

三个计划共享设计文档：`docs/superpowers/specs/2026-07-12-replaygain-dac-volume-sync-design.md`。

## 工作区保护

开始每个任务前运行：

```powershell
git status --short
git diff --name-only
```

已存在的 `UsbExclusiveAudioEngine.kt`、`audio_handler.dart`、`audio_output_panel.dart`、旧设计文档及 generated registrant 改动属于工作区既有内容。编辑这些文件时使用补丁合并，提交时逐个指定路径；禁止 `git add .`。

## 总体验收

三个子计划完成后执行：

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.0\bin\flutter.bat test
F:\software\flutter_3.44.0\bin\flutter.bat analyze
F:\software\flutter_3.44.0\bin\flutter.bat build apk --profile --target-platform android-arm64
```

预期：本地化生成成功、全部测试通过、`No issues found`，并产出 `build\app\outputs\flutter-apk\app-profile.apk`。安装前重新运行 `adb devices`，只对当时在线的目标设备安装。
