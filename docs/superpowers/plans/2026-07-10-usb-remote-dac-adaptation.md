# USB 远程 DAC 适配 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增强 USB 诊断报告、收集硬件音量适配参数，并把内置 DAC quirk 目录按厂商分组维护。

**Architecture:** Kotlin 引擎在一次独占会话中保留只读诊断快照并解析 AudioControl Feature Unit，Dart 将其格式化为报告 v2。quirk 解析器同时读取旧版平铺条目和新版厂商分组条目，匹配优先级保持不变；硬件音量参数只采集和保存，不改变现有数字音量回退。

**Tech Stack:** Flutter/Dart、Android Kotlin、JUnit 4、JSON asset。

---

### Task 1: 厂商分组 quirk 目录

**Files:**
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDacQuirksTest.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbDacQuirks.kt`
- Modify: `android/app/src/main/assets/usb_dac_quirks.json`

- [ ] **Step 1: 写入失败的 JVM 测试**

新增一个 `vendors` JSON，断言设备 PID 和 `"*"` 厂商默认 PID 都能命中，并断言设备标签和 quirk 字段被保留。

- [ ] **Step 2: 运行测试并确认失败**

Run: `android\\gradlew.bat :app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbDacQuirksTest`

Expected: 新增的厂商分组测试因 `parseEntries` 只读取根 `devices` 而失败。

- [ ] **Step 3: 最小化实现兼容解析**

让 `parseEntries` 先读取根 `devices`，再读取 `vendors[].devices`；厂商 `match.vid` 与设备 `match.pid` 组合成既有 `vid:pid` key，标签优先取设备标签。解析可选的 `hardwareVolume.featureUnitId`、`controlInterface`、`channels`，但不把它接入播放写入。

- [ ] **Step 4: 将内置目录改为厂商分组格式**

把空的内置 JSON 改为版本 2 的 `vendors` 结构，不加入未经真实设备验证的规则。

- [ ] **Step 5: 运行 JVM 测试**

Run: `android\\gradlew.bat :app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbDacQuirksTest`

Expected: 所有 `UsbDacQuirksTest` 通过。

### Task 2: 会话与硬件音量诊断数据、报告 v2

**Files:**
- Modify: `test/usb_audio_service_test.dart`
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`

- [ ] **Step 1: 写入失败的 Dart 报告测试**

在 native diagnostics mock 中加入 `session` 和 `hardwareVolume`，断言报告版本为 v2，且包含会话、alt 选择、时钟、反馈、传输、Feature Unit 字段。

- [ ] **Step 2: 运行测试并确认失败**

Run: `F:\\software\\flutter_3.44.0\\bin\\flutter.bat test test\\usb_audio_service_test.dart`

Expected: 现有报告仍为 v1，且不包含新增会话节，测试失败。

- [ ] **Step 3: 在引擎采集会话与 Feature Unit 快照**

在独占 start、alt 选择、时钟配置、反馈读取和 ISO 提交处更新最近会话快照。解析 AudioControl Feature Unit 的标准 Volume Control 位图并探测当前/范围读请求结果；`collectDiagnostics` 始终返回该快照，不影响现有播放控制流或数字音量回退。

- [ ] **Step 4: 格式化报告 v2**

在 `buildUsbDiagnosticsReport` 中输出结构化的会话与硬件音量快照；空快照输出 `none`，开发者文本保持英文。

- [ ] **Step 5: 运行 Dart 测试**

Run: `F:\\software\\flutter_3.44.0\\bin\\flutter.bat test test\\usb_audio_service_test.dart`

Expected: USB service 测试全部通过。

### Task 3: 完整验证与交付

**Files:**
- Modify: `docs/dac-adaptation-guide.md`

- [ ] **Step 1: 更新适配指南**

说明报告 v2 的会话节、厂商分组 JSON 和“先导入验证再内置发包”的远程适配流程。

- [ ] **Step 2: 运行完整相关验证**

Run: `F:\\software\\flutter_3.44.0\\bin\\flutter.bat test test\\usb_audio_service_test.dart test\\usb_audio_preferences_test.dart`

Expected: 所有相关 Flutter 测试通过。

Run: `F:\\software\\flutter_3.44.0\\bin\\flutter.bat analyze`

Expected: `No issues found`。

Run: `android\\gradlew.bat :app:testDebugUnitTest`

Expected: Android JVM 测试通过。

- [ ] **Step 3: 检查并提交**

Run: `git diff --check` 与 `git status --short`；仅提交上述 USB 适配相关文件并推送当前 fork 分支。
