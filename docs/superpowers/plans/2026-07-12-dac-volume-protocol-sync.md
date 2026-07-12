# DAC 协议适配与双向同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将标准 UAC 与 Macaron 厂商音量统一到小型协议边界，并把 DAC 外置按键变化同步回应用。

**Architecture:** 独占引擎保留会话与回退决策，协议类只处理能力、映射、读写和事件解码。HID IN 端点由单一读取循环拥有，命令响应和主动事件在同一入口分流；Dart 收到规范化实际增益后反推基础用户音量。

**Tech Stack:** Android Kotlin、USB Host API、JUnit 4、Flutter MethodChannel、Dart ValueNotifier。

---

## 文件映射

- 新建：`android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`。
- 修改：`UsbExclusiveAudioEngine.kt`、`MainActivity.kt`、`usb_dac_quirks.json`。
- Dart：`usb_audio_service.dart`、`audio_handler.dart`、`audio_output_panel.dart`。
- 测试：`UsbHardwareVolumeTest.kt`、新建 `UsbVolumeProtocolTest.kt`、`usb_audio_service_test.dart`、`replay_gain_test.dart`。

### Task 1: 定义协议值对象与纯映射

**Files:**
- Create: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Create: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 写失败测试**

测试 `IbassoDc03ProVolumeProtocol`：0、23、90、100 的原始映射；DSD 0.5 dB 步进；原生事件 `FE 01 ... left right` 解码；普通命令响应不误判为主动事件；相同原始值被识别为写入确认。

- [ ] **Step 2: 运行测试确认失败**

```powershell
Set-Location android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbVolumeProtocolTest
```

预期：FAIL，协议类型尚不存在。

- [ ] **Step 3: 写最小协议类型**

值对象只表达引擎需要的信息：

```kotlin
internal data class UsbVolumeCapabilities(
    val readable: Boolean,
    val unsolicitedEvents: Boolean,
    val dsdGain: Boolean,
)

internal data class UsbVolumeEvent(
    val leftRaw: Int,
    val rightRaw: Int,
)

internal interface UsbVolumeProtocol {
    val id: String
    val capabilities: UsbVolumeCapabilities
    fun appGainToRaw(gainQ16: Int, replayGainMilliDb: Int, dsdCompensationDb: Int): Int
    fun rawToLinearGainQ16(raw: Int): Int
    fun decodeEvent(packet: ByteArray): UsbVolumeEvent?
}
```

Macaron 实现复用现有已验证表和包构造函数；不要把 USB 连接或线程生命周期放进协议接口。

- [ ] **Step 4: 运行测试并提交**

```powershell
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbVolumeProtocolTest
git add app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git commit -m "refactor(usb): isolate DAC volume protocol mapping"
```

### Task 2: 让独占引擎通过协议选择器工作

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbHardwareVolumeTest.kt`
- Modify: `android/app/src/main/assets/usb_dac_quirks.json`

- [ ] **Step 1: 写选择与回退测试**

断言：精确 quirk 的 `ibassoDc03Pro` 覆盖通用探测并选择厂商协议；没有协议 quirk 时，唯一可写 Feature Unit 使用 UAC；未知协议返回明确错误并进入现有 PCM 数字回退；DSD 不允许数字回退。

- [ ] **Step 2: 运行测试确认失败**

```powershell
Set-Location android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbHardwareVolumeTest
```

预期：新增选择测试失败。

- [ ] **Step 3: 替换引擎中的协议字符串分支**

`applyVolumeControl` 只做以下顺序：解析精确 quirk；quirk 指定协议时调用对应实现，否则探测标准 UAC；失败时依据 PCM/DSD 和 `volumeMode` 回退。把 Macaron 映射与数据包生成移动到新文件，引擎只保留连接、claim、transfer 和状态更新。

ReplayGain 使用 `replayGainMilliDb` 合成目标；硬件范围限制后记录实际应用 dB。状态新增 `replayGainMilliDb`、`hardwareVolumeProtocol`、`hardwareVolumeRaw`、`hardwareVolumeGainQ16`。

- [ ] **Step 4: 运行全部 Android 单元测试并提交**

```powershell
.\gradlew.bat app:testDebugUnitTest
git add app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt app/src/main/assets/usb_dac_quirks.json app/src/test/kotlin/com/afalphy/sylvakru/UsbHardwareVolumeTest.kt
git commit -m "refactor(usb): select hardware volume protocols by capability"
```

### Task 3: 建立单一 HID 读取循环

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 写响应/事件分流测试**

给分流器依次输入主动事件、错误命令响应、正确命令响应，断言主动事件进入事件回调，只有匹配 command id 的响应完成等待者，未知包只记录诊断。

- [ ] **Step 2: 运行测试确认失败**

```powershell
Set-Location android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbVolumeProtocolTest
```

- [ ] **Step 3: 实现读取所有权**

为已 claim 的 Macaron HID 连接启动一个后台循环，循环是 IN endpoint 唯一调用者。写命令只发送 OUT report 并通过 command id 的 `CompletableFuture<ByteArray>` 等待响应。循环退出条件为 stop、设备 id 改变或连接关闭；连续异常只重建一次，再降级只写并更新诊断。

- [ ] **Step 4: 增加回环抑制**

保存最后写入的左右原始值和时间。相同原始值的主动包作为确认，不发布；不同值经 50ms 去抖后发布一次。左右不一致时使用两者中较低增益作为安全实际值，同时在诊断保留左右原始值。

- [ ] **Step 5: 测试并提交**

```powershell
.\gradlew.bat app:testDebugUnitTest
git add app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git commit -m "feat(usb): listen for DAC hardware volume events"
```

### Task 4: 把设备真实音量同步到 Dart

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt`
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `lib/base/audio_handler.dart`
- Modify: `test/usb_audio_service_test.dart`
- Modify: `test/replay_gain_test.dart`

- [ ] **Step 1: 写 MethodChannel 与反推测试**

`usb_audio_service_test.dart` 模拟 `onUsbHardwareVolumeChanged`，断言事件包含 `gainQ16`、左右 raw 和 protocol。纯逻辑测试验证：实际线性增益除以 ReplayGain 与 DSD 补偿后，再按 USB 音量曲线逆变换得到 0–1 基础音量并正确 clamp。

- [ ] **Step 2: 运行测试确认失败**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\usb_audio_service_test.dart test\replay_gain_test.dart
```

- [ ] **Step 3: 发布并消费设备事件**

引擎通过回调把规范化实际 `gainQ16` 和原始诊断值交给 `MainActivity`，后者调用 `onUsbHardwareVolumeChanged`。Dart service 发布不可变 `UsbHardwareVolumeEvent`。

`MyAudioHandler` 只在当前独占会话、协议和 playback id 仍匹配时消费事件：反推基础音量；更新 `volumeNotifier` 并触发现有音量浮层；刷新远程音量媒体会话；调用 `savePlayState()`。由当前歌曲偏移造成的写入确认不得再次调用 `setVolume`。

重新连接支持读取时先取得设备当前值；`volumeSmoothHandoff` 开启时从该值接管并更新应用，关闭时写回应用保存值。只写设备继续沿用应用保存值。

- [ ] **Step 4: 测试并提交**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\usb_audio_service_test.dart test\replay_gain_test.dart
F:\software\flutter_3.44.0\bin\flutter.bat analyze
git add android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt lib/base/services/usb_audio_service.dart lib/base/audio_handler.dart test/usb_audio_service_test.dart test/replay_gain_test.dart
git commit -m "feat(usb): synchronize DAC hardware volume to the app"
```

### Task 5: 显示真实控制状态并扩展诊断

**Files:**
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `lib/base/widgets/audio_output_panel.dart`
- Modify: `lib/layer/audio_output_settings_layer.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/usb_audio_service_test.dart`

- [ ] **Step 1: 扩展状态解析测试**

断言硬件、数字、原始、DSD 未应用四种状态，以及当前 ReplayGain dB 和协议 id 能从原生 map 解析；诊断报告包含 protocol、raw、normalized、last command、readback、event support 和 fallback reason。

- [ ] **Step 2: 更新真实文案**

信号输出区域以 `hardwareVolumeActive`、`digitalVolumeActive` 和 DSD 能力为准显示，不再根据用户选择推测。ReplayGain 生效时追加格式化 dB；DSD/DoP 无硬件能力时使用本地化说明。厂商寄存器信息只进入英文诊断报告。

- [ ] **Step 3: 生成、测试并提交**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.0\bin\flutter.bat test test\usb_audio_service_test.dart
F:\software\flutter_3.44.0\bin\flutter.bat analyze
git add lib/base/services/usb_audio_service.dart lib/base/widgets/audio_output_panel.dart lib/layer/audio_output_settings_layer.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated test/usb_audio_service_test.dart
git commit -m "feat(usb): report actual volume processing state"
```
