# USB 硬件音量单事务协调 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让手机音量键、USB 设置页 Slider、ReplayGain 渐升和模式变化共用一个串行 HID 音量事务通道，避免拖动卡顿、密集写入、短暂回读超时和硬件音量误降级为数字音量。

**Architecture:** 不新建通用 manager/adapter。Dart 层继续在现有 `audio_handler.dart` 处理用户意图和安全步进；Android 层在现有 `UsbExclusiveAudioEngine` 内加入单执行线程、一个运行中请求和一个可覆盖的待处理绝对目标。HID 写入 ACK 超时后先按寄存器回读结果判定，不再立即击穿整个 reader；PCM 持续失联时冻结硬件音量控制但不自动切数字音量，DSD 持续失联时暂停。

**Tech Stack:** Flutter 3.44.5、Dart、Android Kotlin、MethodChannel、Android USB Host HID、JUnit、Flutter test。

---

## 交接上下文

### 仓库和 Git 状态

- 唯一仓库：`F:\Symusic\sylvakru-usb-exclusive-clean`
- 当前分支：`usb-exclusive-volume-overlay-performance`
- `origin`：`https://github.com/AfalpHy/sylvakru.git`
- `fork`：`https://github.com/huya688zdx/sylvakru.git`
- 本地 HEAD：`a80eb1b fix(usb): 禁止音量异常时恢复硬件满幅`
- 上游跟踪分支仍为：`27d7cfa fix(usb): 分开展示歌曲与端点位深`
- `a80eb1b` 因 GitHub 443 连接失败尚未推送；执行本计划前先重试普通推送，不得强推。

必须保留、不得混入本任务提交的用户修改：

```text
android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
  - 仅有 initialState 中 playbackId 字段排序修改属于用户原修改
docs/superpowers/specs/2026-07-11-usb-cloud-exclusive-recovery-design.md
lib/base/audio_handler.dart
lib/base/widgets/audio_output_panel.dart
linux/flutter/generated_plugin_registrant.cc
linux/flutter/generated_plugin_registrant.h
linux/flutter/generated_plugins.cmake
macos/Flutter/GeneratedPluginRegistrant.swift
windows/flutter/generated_plugin_registrant.cc
windows/flutter/generated_plugin_registrant.h
windows/flutter/generated_plugins.cmake
```

修改 `UsbExclusiveAudioEngine.kt` 时必须按 hunk 暂存，不能把 `playbackId` 排序一并提交。

### 当前设备和安装包

- ADB：`10.67.118.174:5555`
- 手机：`23078RKD5C`
- 应用包：`com.afalphy.sylvakru.profile`
- DAC：Macaron，USB VID/PID `9770/6667`
- 已安装的 Profile APK：包含提交 `a80eb1b` 的代码
- APK：`build/app/outputs/flutter-apk/app-profile.apk`
- APK SHA-256：`C7B3AE96EDD2B1E726ACBFA83894F23F4B6D1B5570F15258A3B0CBD33624A2E3`

真机验证不得自动开始播放、不得发送音量增加命令。由用户把音量调低并主动操作后，只抓日志。

### 已修复的满幅问题

旧日志曾出现：

```text
iBasso hardware volume set register=0
volumeGainQ16=65536
```

Macaron 的 `register=0` 是满幅。提交 `a80eb1b` 已删除硬件写失败、标准 UAC 回退和离开 DAC 音量模式时自动写满幅的三条路径，并规定设备回读音量高于应用目标时不能采纳设备值。

本任务不得恢复任何异常路径中的 `register=0` 或硬件 unity 写入。

### 本次问题的日志证据

20:05:56 起播时，ReplayGain/输出增益保护每 100ms 调用一次 USB 音量：

```text
20:05:56.677 set exclusive volume ... hardware=true, digital=false
20:05:56.777 set exclusive volume ... hardware=true, digital=false
20:05:56.881 set exclusive volume ... hardware=true, digital=false
20:05:56.979 set exclusive volume ... hardware=true, digital=false
20:05:57.077 set exclusive volume ... hardware=true, digital=false
```

随后单次写 ACK 超时直接触发 reader failure：

```text
20:05:57.480 iBasso HID command 1 response timed out
20:05:57.585 Restored the previous iBasso hardware volume
20:05:57.589 hardware=false, digital=true
```

读取器恢复后又切回硬件音量：

```text
20:05:57.782 iBasso hardware volume set register=155
20:05:57.784 hardware=true, digital=false
```

连续调音时重复发生，并最终把设备标成 write-only：

```text
20:06:44.277 iBasso HID command 1 response timed out
20:06:44.387 hardware=false, digital=true
20:06:47.263 iBasso HID command 65 response timed out
20:06:47.367 readback=unavailable, writeOnly=true
```

本次没有 `register=0`，说明 `a80eb1b` 的满幅保护有效；现在的问题是单次 ACK 超时处理过重以及所有音量来源没有共用单事务通道。

### 当前卡顿原因

- `lib/layer/audio_output_settings_layer.dart:991` 的 Slider 在每次 `onChanged` 都调用 `audioHandler.setUsbExclusiveVolume()`。
- `lib/base/audio_handler.dart:1749` 的安全渐升 Timer 每 100ms 再次调用 `_applyUsbExclusiveVolume()`。
- `lib/base/audio_handler.dart:1775` 只有手机按键自己的 `_phoneVolumeKeyWriteInProgress`，Slider、ReplayGain 和模式变化绕过该门禁。
- `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt:2302` 的 HID 调用会等待 ACK/回读；当前 MethodChannel 在 Android 主线程进入该同步逻辑，因此拖动期间会积压平台消息并卡顿。

### 已批准的行为

1. 全部音量来源共用一个 HID 串行事务，同一时间最多一个写入和校验。
2. 手机按键：事务运行中最多保留一个待处理步进，不累计多次点击；降低优先于提高。
3. Slider：界面立即跟手，只保留最新绝对目标；验证完成后只写最新值，不形成历史队列。
4. ReplayGain/安全渐升：也只能覆盖待处理绝对目标，不能和用户写入并发。
5. 单次 `command 1` ACK 超时：不切数字音量，不立即宣布 reader 整体失效；先执行 `command 65` 回读。
6. 回读等于目标：确认成功；回读等于旧可信值：本次调整失败但继续保持硬件音量；其他值或无响应：进入一次恢复校验。
7. PCM 持续失联：冻结硬件音量写入、保留最后可信目标、继续播放，不自动切数字音量。
8. DSD 持续失联：暂停，不能用 PCM 数字音量兜底。
9. 所有提高音量仍受既有 1 dB 输出保护和手机单步 2% 约束；不得因合并 Slider 最新目标而一次跳到高音量。

### 完成标准

- 连续按手机音量键时，任意时刻只有一个 HID 事务和最多一个待处理按键步进。
- 拖动 Slider 时 UI 不等待 HID；Android 只执行首个运行中目标和最后一个待处理目标。
- 单次 `command 1` 超时不会产生 `hardware=false, digital=true`。
- PCM 连续回读失败时显示硬件同步冻结状态，但不切数字音量。
- DSD 连续回读失败时暂停。
- 日志中不存在异常恢复写入 `register=0`。
- 切歌或关闭会话后，旧会话的待处理音量请求不能作用于新会话。
- Flutter 测试、Android 单元测试、`flutter analyze` 和 arm64 Profile 构建全部通过。

## 文件结构

- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
  - 保存单执行线程、运行中请求、最新待处理请求、会话代次和 HID 恢复状态。
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
  - 保存可单测的请求合并和 HID 校验决策纯逻辑。
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`
  - 覆盖最新目标覆盖、ACK 超时回读、冻结和 DSD 暂停决策。
- Modify: `lib/base/audio_handler.dart`
  - 手机按键单待处理槽；维持现有 2% 步进和提高音量保护。
- Modify: `test/android_remote_volume_test.dart`
  - 覆盖按键待处理规则，尤其“降低优先”。
- Modify: `lib/base/services/usb_audio_service.dart`
  - 映射硬件音量同步中/冻结状态。
- Modify: `lib/base/widgets/audio_output_panel.dart`
  - 在 USB 输出状态中显示“同步中”或“音量已冻结”。
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
  - 新增中英文 USB 音量同步状态文案。
- Test: `test/usb_audio_service_test.dart`
  - 覆盖新增状态字段映射。

### Task 1: 固定基线并保护用户工作区

**Files:**
- Inspect: all modified files from `git status`
- No production changes

- [ ] **Step 1: 检查分支、工作区和远程**

Run:

```powershell
git status
git branch --show-current
git remote -v
git fetch origin
git fetch fork
git log -5 --oneline
```

Expected: 当前分支为 `usb-exclusive-volume-overlay-performance`，HEAD 至少包含 `a80eb1b`；工作区仍包含交接上下文列出的用户修改。

- [ ] **Step 2: 重试推送已有安全提交**

Run:

```powershell
git push fork usb-exclusive-volume-overlay-performance
```

Expected: `a80eb1b` 推送成功；若 GitHub 443 仍不可达，记录失败但继续本地实现，不修改代理和远程地址，不强推。

- [ ] **Step 3: 保存基线差异用于逐 hunk 核对**

Run:

```powershell
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff -- lib/base/audio_handler.dart
git diff -- lib/base/widgets/audio_output_panel.dart
```

Expected: 明确哪些 hunk 是用户原修改；后续每次提交只暂存本任务 hunk。

### Task 2: 为单待处理目标和 HID 校验决策补失败测试

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 添加请求和校验决策类型**

在 `UsbVolumeProtocol.kt` 的现有 USB 音量数据类型附近添加：

```kotlin
internal data class UsbVolumeRequest(
    val gainQ16: Int,
    val replayGainMilliDb: Int,
    val mode: String,
    val dsdCompensationDb: Int,
    val smoothHandoff: Boolean,
    val sessionGeneration: Long,
)

internal enum class IbassoVolumeVerificationAction {
    ACCEPT_TARGET,
    KEEP_PREVIOUS,
    RETRY_READBACK,
    FREEZE_PCM,
    PAUSE_DSD,
}

internal fun latestUsbVolumeRequest(
    pending: UsbVolumeRequest?,
    incoming: UsbVolumeRequest,
): UsbVolumeRequest = incoming

internal fun ibassoVolumeVerificationAction(
    targetRaw: Int,
    previousRaw: Int?,
    readbackRaw: Int?,
    failureCount: Int,
    isDsd: Boolean,
): IbassoVolumeVerificationAction = when {
    readbackRaw == targetRaw -> IbassoVolumeVerificationAction.ACCEPT_TARGET
    previousRaw != null && readbackRaw == previousRaw ->
        IbassoVolumeVerificationAction.KEEP_PREVIOUS
    failureCount < 3 -> IbassoVolumeVerificationAction.RETRY_READBACK
    isDsd -> IbassoVolumeVerificationAction.PAUSE_DSD
    else -> IbassoVolumeVerificationAction.FREEZE_PCM
}
```

`latestUsbVolumeRequest` 的 `pending` 参数有意不参与返回值：它表达“待处理槽永远只保存最新绝对目标”，不是历史队列。

- [ ] **Step 2: 添加失败测试**

在 `UsbVolumeProtocolTest.kt` 添加：

```kotlin
@Test
fun keepsOnlyLatestPendingUsbVolumeRequest() {
    val first = UsbVolumeRequest(1000, 0, "dac", 0, true, 7)
    val latest = UsbVolumeRequest(2000, -3000, "dac", 0, true, 7)

    assertEquals(latest, latestUsbVolumeRequest(first, latest))
}

@Test
fun verifiesIbassoWriteBeforeChangingHardwareAuthority() {
    assertEquals(
        IbassoVolumeVerificationAction.ACCEPT_TARGET,
        ibassoVolumeVerificationAction(100, 102, 100, 1, isDsd = false),
    )
    assertEquals(
        IbassoVolumeVerificationAction.KEEP_PREVIOUS,
        ibassoVolumeVerificationAction(100, 102, 102, 1, isDsd = false),
    )
    assertEquals(
        IbassoVolumeVerificationAction.RETRY_READBACK,
        ibassoVolumeVerificationAction(100, 102, null, 1, isDsd = false),
    )
    assertEquals(
        IbassoVolumeVerificationAction.FREEZE_PCM,
        ibassoVolumeVerificationAction(100, 102, null, 3, isDsd = false),
    )
    assertEquals(
        IbassoVolumeVerificationAction.PAUSE_DSD,
        ibassoVolumeVerificationAction(100, 102, null, 3, isDsd = true),
    )
}
```

- [ ] **Step 3: 运行测试确认先失败**

Run:

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbVolumeProtocolTest
cd ..
```

Expected: 新测试在类型或函数尚未完整实现时失败；不得在未见到预期失败前修改引擎。

- [ ] **Step 4: 完成最小纯逻辑实现并重跑**

Run the same command.

Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: 提交纯逻辑和测试**

```powershell
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt
git add android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git diff --cached --check
git commit -m "test(usb): 固定硬件音量单事务决策"
```

### Task 3: 将硬件音量事务移出 Android 主线程并只保留最新目标

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 在引擎内加入单执行线程和会话代次**

在现有字段附近添加，不创建独立 manager：

```kotlin
private val volumeCommandExecutor = Executors.newSingleThreadExecutor { runnable ->
    Thread(runnable, "usb-volume-command").apply { isDaemon = true }
}
private val volumeCommandLock = Any()
private val volumeSessionGeneration = AtomicLong(0)
private var volumeCommandRunning = false
private var pendingVolumeRequest: UsbVolumeRequest? = null
```

补充 `java.util.concurrent.Executors` import；项目已有 `AtomicLong` 时复用现有 import。

- [ ] **Step 2: 把现有 setVolume 同步主体移入单事务循环**

保留公开方法签名，但让它只构造请求和调度：

```kotlin
fun setVolume(
    gainQ16: Int,
    replayGainMilliDb: Int,
    mode: String,
    dsdCompensationDb: Int,
    smoothHandoff: Boolean,
) {
    val request = UsbVolumeRequest(
        gainQ16 = gainQ16.coerceIn(0, UNITY_GAIN_Q16),
        replayGainMilliDb = replayGainMilliDb,
        mode = mode.lowercase(Locale.ROOT)
            .takeIf { it == "auto" || it == "dac" || it == "digital" || it == "raw" }
            ?: "auto",
        dsdCompensationDb = dsdCompensationDb.coerceIn(-12, 6),
        smoothHandoff = smoothHandoff,
        sessionGeneration = volumeSessionGeneration.get(),
    )
    val start = synchronized(volumeCommandLock) {
        if (volumeCommandRunning) {
            pendingVolumeRequest = latestUsbVolumeRequest(pendingVolumeRequest, request)
            false
        } else {
            volumeCommandRunning = true
            true
        }
    }
    if (start) {
        volumeCommandExecutor.execute { drainVolumeRequests(request) }
    }
}
```

把旧 `setVolume` 中 `synchronized(volumeLock)` 的内容移动到：

```kotlin
private fun applyVolumeRequest(request: UsbVolumeRequest) {
    if (request.sessionGeneration != volumeSessionGeneration.get()) return
    synchronized(volumeLock) {
        if (request.sessionGeneration != volumeSessionGeneration.get()) return
        requestedVolumeGainQ16 = request.gainQ16
        requestedReplayGainMilliDb = request.replayGainMilliDb
        dsdGainCompensationDb = request.dsdCompensationDb
        volumeSmoothHandoff = request.smoothHandoff
        volumeMode = request.mode
        val device = sessionDevice
        val target = sessionTarget
        if (device != null && target != null && connection != null) {
            applyVolumeControl(
                device,
                target,
                sessionDsdKind != null,
                UsbDacQuirks.forDevice(context, device.vendorId, device.productId),
            )
        } else {
            hardwareVolumeActive = false
            hardwareVolumeProtocol = null
            hardwareVolumeRaw = null
            hardwareVolumeGainQ16 = null
            standardHardwareVolumeReadbackVerified = false
            volumeControlEnabled = volumeMode != "raw"
            pcmVolumeGainQ16 = if (volumeControlEnabled) {
                effectiveVolumeGainQ16(requestedVolumeGainQ16, requestedReplayGainMilliDb)
            } else {
                UNITY_GAIN_Q16
            }
        }
        UsbDiagnostics.i(
            tag,
            "set exclusive volume gainQ16=$requestedVolumeGainQ16, " +
                "replayGainMilliDb=$requestedReplayGainMilliDb, mode=$volumeMode, " +
                "hardware=$hardwareVolumeActive, digital=$volumeControlEnabled",
        )
        if (currentState["active"] == true) {
            val bitPerfect = if (currentState["bitDepth"] == 1) {
                true
            } else {
                pcmBitPerfect(
                    (currentState["sourceBitDepth"] as? Number)?.toInt(),
                    (currentState["decodedBitDepth"] as? Number)?.toInt(),
                    (currentState["usbBitDepth"] as? Number)?.toInt(),
                    volumeControlEnabled,
                )
            }
            updateState(
                currentState + mapOf(
                    "hardwareVolumeActive" to hardwareVolumeActive,
                    "digitalVolumeActive" to volumeControlEnabled,
                    "bitPerfect" to bitPerfect,
                    "replayGainMilliDb" to requestedReplayGainMilliDb,
                    "hardwareVolumeProtocol" to hardwareVolumeProtocol,
                    "hardwareVolumeRaw" to hardwareVolumeRaw,
                    "hardwareVolumeGainQ16" to hardwareVolumeGainQ16,
                    "hardwareVolumeWriteOnly" to hardwareVolumeWriteOnlyState,
                    "hardwareVolumeReadbackVerified" to hardwareVolumeReadbackVerifiedState,
                ),
            )
            pendingHardwareVolumeEvent?.let(emitHardwareVolume)
            pendingHardwareVolumeEvent = null
        }
    }
}

private fun drainVolumeRequests(first: UsbVolumeRequest) {
    var request = first
    while (true) {
        applyVolumeRequest(request)
        val next = synchronized(volumeCommandLock) {
            pendingVolumeRequest.also { pendingVolumeRequest = null }
        }
        if (next == null) {
            synchronized(volumeCommandLock) {
                if (pendingVolumeRequest == null) {
                    volumeCommandRunning = false
                    return
                }
                request = pendingVolumeRequest!!
                pendingVolumeRequest = null
            }
        } else {
            request = next
        }
    }
}
```

实现时必须处理“检查到 next 为 null 后新请求刚好到达”的竞争；上面第二个同步块就是该双重检查，不能删掉。

- [ ] **Step 3: 在会话边界清空旧目标**

在新播放开始、`hardCloseSession()` 和彻底关闭引擎的既有边界调用：

```kotlin
private fun invalidatePendingVolumeRequests() {
    volumeSessionGeneration.incrementAndGet()
    synchronized(volumeCommandLock) {
        pendingVolumeRequest = null
    }
}
```

运行中的旧请求不能被强杀，但它在写入和更新状态前后都必须检查 `sessionGeneration`，不得把旧播放的结果发布给新 `playbackId`。

- [ ] **Step 4: 增加可诊断日志**

使用英文开发日志：

```kotlin
UsbDiagnostics.i(tag, "USB volume request queued as the latest pending target.")
UsbDiagnostics.i(tag, "USB volume transaction started generation=${request.sessionGeneration}.")
UsbDiagnostics.i(tag, "USB volume transaction completed generation=${request.sessionGeneration}.")
UsbDiagnostics.i(tag, "Ignored a stale USB volume request generation=${request.sessionGeneration}.")
```

日志不得包含每个 PCM 样本或敏感路径。

- [ ] **Step 5: 运行 Android 单元测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
```

Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 6: 只暂存本任务 hunk 并提交**

```powershell
git add -p android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff --cached --check
git diff --cached
git commit -m "fix(usb): 串行处理硬件音量事务"
```

检查 cached diff 中不得出现 `initialState` 的 `playbackId` 排序。

### Task 4: 让 ACK 超时先回读，PCM 不再自动降级

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 区分“命令超时”和“reader 永久失败”**

给 `transferIbassoPacket()` 增加参数：

```kotlin
private fun transferIbassoPacket(
    connection: UsbDeviceConnection,
    packet: ByteArray,
    expectedCommand: Int,
    allowDirectWhenReaderUnavailable: Boolean = false,
    failReaderOnTimeout: Boolean = true,
): ByteArray?
```

把当前无响应时无条件调用 `handleIbassoReaderFailure()` 改为：

```kotlin
if (response == null && !ibassoReaderWriteOnly && failReaderOnTimeout) {
    handleIbassoReaderFailure(
        IOException("iBasso HID command $expectedCommand response timed out."),
        connection,
        inputEndpoint,
        readerEventsEnabled,
        readerGeneration,
        reader,
    )
}
```

命令 `1`/`2` 的写 ACK 使用 `failReaderOnTimeout = false`；显式恢复校验达到失败阈值后才允许调用 reader failure。

- [ ] **Step 2: ACK 缺失后读取寄存器，不立即回滚和降级**

先在引擎字段区加入：

```kotlin
@Volatile private var hardwareVolumeSyncPending = false
@Volatile private var hardwareVolumeFrozen = false
private var ibassoVerificationFailureCount = 0
```

在 `writeIbassoDc03ProVolume()` 中保留写入前的 `previousAppliedTarget`。若 `transferIbassoVolumeTarget()` 报 ACK 失败，在单事务工作线程中最多回读三次，每次间隔 50ms，不创建延迟任务队列：

```kotlin
var readBack = readIbassoCurrentBaseRaw(controlConnection)
var verificationAction = ibassoVolumeVerificationAction(
    targetRaw = appliedTarget.baseRaw,
    previousRaw = previousAppliedTarget?.baseRaw,
    readbackRaw = readBack,
    failureCount = ibassoVerificationFailureCount + 1,
    isDsd = isDsd,
)
while (verificationAction == IbassoVolumeVerificationAction.RETRY_READBACK) {
    ibassoVerificationFailureCount += 1
    SystemClock.sleep(50)
    readBack = readIbassoCurrentBaseRaw(controlConnection)
    verificationAction = ibassoVolumeVerificationAction(
        targetRaw = appliedTarget.baseRaw,
        previousRaw = previousAppliedTarget?.baseRaw,
        readbackRaw = readBack,
        failureCount = ibassoVerificationFailureCount + 1,
        isDsd = isDsd,
    )
}
when (verificationAction) {
    IbassoVolumeVerificationAction.ACCEPT_TARGET -> {
        ibassoVerificationFailureCount = 0
        acceptVerifiedIbassoTarget(device, appliedTarget, isDsd)
        return null
    }
    IbassoVolumeVerificationAction.KEEP_PREVIOUS -> {
        ibassoVerificationFailureCount = 0
        keepVerifiedIbassoTarget(device, previousAppliedTarget!!, isDsd)
        return "iBasso write was not applied; kept the previous verified hardware volume."
    }
    IbassoVolumeVerificationAction.RETRY_READBACK -> {
        error("RETRY_READBACK must be resolved by the bounded verification loop.")
    }
    IbassoVolumeVerificationAction.FREEZE_PCM -> {
        freezeIbassoPcmVolume(previousAppliedTarget)
        return "iBasso hardware volume synchronization is frozen."
    }
    IbassoVolumeVerificationAction.PAUSE_DSD -> {
        paused.set(true)
        return "DSD playback paused because hardware volume could not be verified."
    }
}
```

在 `UsbExclusiveAudioEngine` 内添加以下私有方法，不创建 manager：

```kotlin
private fun acceptVerifiedIbassoTarget(
    device: UsbDevice,
    target: UsbVolumeTarget,
    isDsd: Boolean,
) {
    val actual = ibassoActualEventGainQ16(
        target.baseRaw,
        isDsd,
        dsdGainCompensationDb,
    )
    ibassoLastAppliedTarget = target
    ibassoLastAppliedDeviceId = device.deviceId
    synchronized(ibassoReaderHealthLock) {
        ibassoReaderHealth = ibassoReaderHealth.afterVerifiedReadback()
    }
    hardwareVolumeActive = true
    volumeControlEnabled = false
    hardwareVolumeProtocol = IbassoDc03ProVolumeProtocol.id
    hardwareVolumeRaw = actual.raw
    hardwareVolumeGainQ16 = actual.gainQ16
    hardwareVolumeSyncPending = false
    hardwareVolumeFrozen = false
}

private fun keepVerifiedIbassoTarget(
    device: UsbDevice,
    target: UsbVolumeTarget,
    isDsd: Boolean,
) {
    acceptVerifiedIbassoTarget(device, target, isDsd)
}

private fun freezeIbassoPcmVolume(previousTarget: UsbVolumeTarget?) {
    if (previousTarget == null) {
        paused.set(true)
        hardwareVolumeActive = false
        volumeControlEnabled = false
        hardwareVolumeSyncPending = false
        hardwareVolumeFrozen = true
        return
    }
    val actual = ibassoActualEventGainQ16(
        previousTarget.baseRaw,
        isDsd = false,
        dsdCompensationDb = 0,
    )
    hardwareVolumeActive = true
    volumeControlEnabled = false
    hardwareVolumeProtocol = IbassoDc03ProVolumeProtocol.id
    hardwareVolumeRaw = actual.raw
    hardwareVolumeGainQ16 = actual.gainQ16
    hardwareVolumeSyncPending = false
    hardwareVolumeFrozen = true
}
```

- [ ] **Step 3: PCM 冻结时保持硬件权威，不启用数字音量**

冻结 PCM 时：

```kotlin
hardwareVolumeActive = true
volumeControlEnabled = false
hardwareVolumeSyncPending = false
hardwareVolumeFrozen = true
hardwareVolumeProtocol = IbassoDc03ProVolumeProtocol.id
```

不得调用 `applyPcmDigitalFallbackImmediately()`，不得写 `UNITY_GAIN_Q16`，不得清除最后可信的 `hardwareVolumeRaw`/`hardwareVolumeGainQ16`。

收到新的用户音量请求时，如果 `hardwareVolumeFrozen` 为真，只更新一个待处理绝对目标并尝试一次恢复回读；恢复前不写新寄存器。

用下面的失败关闭逻辑替换 `markIbassoWriteOnly()` 中现有的数字回退，并删除不再使用的 `applyIbassoReadbackFailureFallback()`：

```kotlin
private fun markIbassoWriteOnly(message: String?) {
    synchronized(ibassoReaderHealthLock) {
        ibassoReaderHealth = ibassoReaderHealth.copy(
            restartRequested = false,
            writeOnly = true,
            readbackVerified = false,
        )
    }
    ibassoReaderRunning.set(false)
    failIbassoPendingResponses("iBasso HID reader unavailable: $message")
    val isDsd = sessionDsdKind != null
    synchronized(volumeLock) {
        if (isDsd) {
            paused.set(true)
            hardwareVolumeActive = false
            volumeControlEnabled = false
            hardwareVolumeSyncPending = false
            hardwareVolumeFrozen = true
        } else {
            freezeIbassoPcmVolume(
                trustedIbassoTargetForDevice(
                    ibassoLastAppliedTarget,
                    ibassoLastAppliedDeviceId,
                    ibassoVolumeDeviceId ?: -1,
                ),
            )
        }
        updateState(
            currentState + mapOf(
                "playing" to (currentState["active"] == true && !isDsd && !paused.get()),
                "hardwareVolumeActive" to hardwareVolumeActive,
                "digitalVolumeActive" to false,
                "hardwareVolumeWriteOnly" to true,
                "hardwareVolumeReadbackVerified" to false,
                "hardwareVolumeSyncPending" to hardwareVolumeSyncPending,
                "hardwareVolumeFrozen" to hardwareVolumeFrozen,
            ),
        )
    }
    UsbDiagnostics.w(
        tag,
        "iBasso HID reader is unavailable; hardware volume control was frozen: $message",
    )
}
```

如果当前设备没有任何可信旧目标，`freezeIbassoPcmVolume(null)` 会暂停而不是启用数字音量；这比猜测 DAC 实际寄存器更安全。

- [ ] **Step 4: DSD 维持暂停保护**

DSD 在 `PAUSE_DSD` 后必须：

```kotlin
paused.set(true)
hardwareVolumeActive = false
volumeControlEnabled = false
hardwareVolumeSyncPending = false
hardwareVolumeFrozen = true
```

恢复可信回读后不得自动播放，只解除冻结；由用户主动恢复播放。

- [ ] **Step 5: 扩充状态和诊断字段**

所有 active state 和诊断快照增加：

```kotlin
"hardwareVolumeSyncPending" to hardwareVolumeSyncPending,
"hardwareVolumeFrozen" to hardwareVolumeFrozen,
"hardwareVolumeVerificationFailures" to ibassoVerificationFailureCount,
```

并增加英文日志：

```text
iBasso write ACK timed out; verifying the current hardware register.
iBasso hardware volume kept the previous verified target.
iBasso PCM hardware volume synchronization is frozen without digital fallback.
DSD playback paused after persistent hardware volume verification failure.
```

- [ ] **Step 6: 运行 Android 测试并提交**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
git add -p android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt
git add android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git diff --cached --check
git commit -m "fix(usb): 回读确认硬件音量后再变更权威"
```

### Task 5: 手机按键只保留一个安全待处理步进

**Files:**
- Modify: `lib/base/audio_handler.dart`
- Test: `test/android_remote_volume_test.dart`

- [ ] **Step 1: 添加待处理方向纯逻辑测试**

在 `test/android_remote_volume_test.dart` 添加：

```dart
test('硬件写入期间按键最多保留一个方向且降低优先', () {
  expect(
    pendingUsbVolumeKeyDirection(null, AndroidVolumeDirection.raise),
    AndroidVolumeDirection.raise,
  );
  expect(
    pendingUsbVolumeKeyDirection(
      AndroidVolumeDirection.raise,
      AndroidVolumeDirection.raise,
    ),
    AndroidVolumeDirection.raise,
  );
  expect(
    pendingUsbVolumeKeyDirection(
      AndroidVolumeDirection.raise,
      AndroidVolumeDirection.lower,
    ),
    AndroidVolumeDirection.lower,
  );
  expect(
    pendingUsbVolumeKeyDirection(
      AndroidVolumeDirection.lower,
      AndroidVolumeDirection.raise,
    ),
    AndroidVolumeDirection.lower,
  );
});
```

- [ ] **Step 2: 运行测试确认失败**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart
```

Expected: `pendingUsbVolumeKeyDirection` 未定义而失败。

- [ ] **Step 3: 实现降低优先的单槽规则**

在 `audio_handler.dart` 现有音量纯函数附近添加：

```dart
AndroidVolumeDirection pendingUsbVolumeKeyDirection(
  AndroidVolumeDirection? pending,
  AndroidVolumeDirection incoming,
) {
  if (pending == null || identical(incoming, AndroidVolumeDirection.lower)) {
    return incoming;
  }
  return pending;
}
```

在 handler 字段中添加：

```dart
AndroidVolumeDirection? _pendingPhoneVolumeDirection;
```

用下面两个方法替换现有 `_handleUsbExclusiveVolumeKey()`；输入监听只负责生成方向，串行循环负责写入：

```dart
void _handleUsbExclusiveVolumeKey() {
  final value = usbExclusiveVolumeKeyNotifier.value;
  final delta = value - _lastVolumeKeyValue;
  _lastVolumeKeyValue = value;
  final direction = usbExclusiveVolumeKeyDirection(
    delta: delta,
    active: _usbExclusiveActive,
    writeInProgress: false,
  );
  if (direction == null) return;
  if (_phoneVolumeKeyWriteInProgress) {
    _pendingPhoneVolumeDirection = pendingUsbVolumeKeyDirection(
      _pendingPhoneVolumeDirection,
      direction,
    );
    return;
  }
  unawaited(_drainPhoneVolumeKey(direction));
}

Future<void> _drainPhoneVolumeKey(AndroidVolumeDirection first) async {
  var direction = first;
  _phoneVolumeKeyWriteInProgress = true;
  while (true) {
    try {
      await _setUserVolumeImmediately(
        adjustedRemoteVolume(volumeNotifier.value, direction),
      );
      usbVolumeOverlayNotifier.value += 1;
    } on Object catch (error) {
      logger.output("usb volume key apply failed:$error");
    }
    final pending = _pendingPhoneVolumeDirection;
    _pendingPhoneVolumeDirection = null;
    if (pending == null) {
      _phoneVolumeKeyWriteInProgress = false;
      return;
    }
    direction = pending;
  }
}
```

循环期间始终最多只有一个 pending，不能保存点击计数。降低方向覆盖待处理的提高方向；提高方向不能覆盖待处理的降低方向。

- [ ] **Step 4: 运行测试**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart
```

Expected: 全部通过，现有 2% 步进和低音量保护测试继续通过。

- [ ] **Step 5: 只暂存本任务 hunk 并提交**

```powershell
git add -p lib/base/audio_handler.dart
git add test/android_remote_volume_test.dart
git diff --cached --check
git diff --cached
git commit -m "fix(usb): 音量键只保留一个待处理步进"
```

不得暂存 `audio_handler.dart` 中用户原有格式化 hunk。

### Task 6: 映射并显示硬件音量同步状态

**Files:**
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `lib/base/widgets/audio_output_panel.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/usb_audio_service_test.dart`

- [ ] **Step 1: 先补状态映射失败测试**

在 `test/usb_audio_service_test.dart` 的独占状态映射测试中传入：

```dart
'hardwareVolumeSyncPending': true,
'hardwareVolumeFrozen': false,
```

并断言：

```dart
expect(state.hardwareVolumeSyncPending, isTrue);
expect(state.hardwareVolumeFrozen, isFalse);
```

再增加冻结用例，断言 `hardwareVolumeFrozen == true`。

- [ ] **Step 2: 运行测试确认失败**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart
```

- [ ] **Step 3: 映射不可变状态字段**

在 `UsbExclusivePlaybackState` 增加：

```dart
final bool hardwareVolumeSyncPending;
final bool hardwareVolumeFrozen;
```

`fromMap()` 使用：

```dart
hardwareVolumeSyncPending: map['hardwareVolumeSyncPending'] == true,
hardwareVolumeFrozen: map['hardwareVolumeFrozen'] == true,
```

所有构造和 inactive state 默认传 `false`。

- [ ] **Step 4: 添加中英文文案**

`app_zh.arb`：

```json
"hardwareVolumeSyncPending": "同步中",
"hardwareVolumeFrozen": "音量同步失败，控制已冻结"
```

`app_en.arb`：

```json
"hardwareVolumeSyncPending": "Syncing",
"hardwareVolumeFrozen": "Volume sync failed; controls are frozen"
```

- [ ] **Step 5: 更新 USB 输出状态显示**

在 `audio_output_panel.dart` 的 `_bitPerfectStatusLabel()` 中，仅在硬件音量状态后追加：

```dart
if (exclusive.hardwareVolumeFrozen) {
  processing = '$processing (${l10n.hardwareVolumeFrozen})';
} else if (exclusive.hardwareVolumeSyncPending) {
  processing = '$processing (${l10n.hardwareVolumeSyncPending})';
}
```

冻结优先于同步中；不得恢复“未验证”作为正常硬件状态。

- [ ] **Step 6: 生成本地化并运行测试**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart
```

Expected: 测试通过，无 ARB 键不一致。

- [ ] **Step 7: 只暂存本任务 hunk并提交**

```powershell
git add lib/base/services/usb_audio_service.dart
git add -p lib/base/widgets/audio_output_panel.dart
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb
git diff --cached --check
git diff --cached
git commit -m "feat(usb): 显示硬件音量同步状态"
```

不得提交 generated plugin registrant；`audio_output_panel.dart` 的用户原格式化 hunk必须保留在工作区。

### Task 7: 全量验证、真机低风险验收和推送

**Files:**
- Verify all task files
- Do not modify unrelated files

- [ ] **Step 1: 静态检查不存在自动硬件满幅恢复**

```powershell
rg -n "appGainToRaw\(UNITY_GAIN_Q16|writeHardwareVolume.*UNITY_GAIN_Q16|register=0" android/app/src/main/kotlin/com/afalphy/sylvakru
```

Expected: 不出现异常恢复写入；音量映射表和诊断文本中的合法 `0` 不算自动恢复路径，必须人工核对上下文。

- [ ] **Step 2: 运行 Android 完整测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
```

Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 3: 串行运行 Flutter 验证**

不要并行运行 Flutter 命令，避免 `macos/Flutter/ephemeral` 文件锁冲突：

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test
F:\software\flutter_3.44.5\bin\flutter.bat analyze
```

Expected: 全部测试通过，`No issues found!`。

- [ ] **Step 4: 构建 arm64 Profile APK**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64
```

Expected: `build/app/outputs/flutter-apk/app-profile.apk` 构建成功。

- [ ] **Step 5: 安装但不自动播放**

先确认设备仍为用户指定设备：

```powershell
adb devices -l
adb -s 10.67.118.174:5555 install -r build/app/outputs/flutter-apk/app-profile.apk
```

Expected: `Success`。安装后不要发送 `play`、`volume up/down` 或按键事件。

- [ ] **Step 6: 用户低音量操作后抓取日志**

让用户先把音量降到安全范围，然后由用户完成：

1. 连续按手机音量键 10 次。
2. 快速拖动 USB 设置页 Slider。
3. 切换一首带 ReplayGain 的 PCM 歌曲。
4. 若用户愿意，再低音量验证 DSD；不要自动执行。

抓取：

```powershell
$pid = adb -s 10.67.118.174:5555 shell pidof com.afalphy.sylvakru.profile
adb -s 10.67.118.174:5555 logcat -d --pid=$pid -v threadtime |
  Select-String -Pattern 'USB volume transaction|iBasso|hardware volume|digital|readback|writeOnly|frozen|paused'
```

Expected:

- 不出现 `register=0` 的异常恢复。
- 同时只有一个 `USB volume transaction started`。
- 密集 Slider 输入只留下最后 pending target。
- 单次 command 1 超时后先出现 readback verification，不出现 `digital=true`。
- PCM 持续失败出现 frozen，不出现数字音量降级。
- DSD 持续失败暂停。

- [ ] **Step 7: 最终差异检查**

```powershell
git status
git diff --check
git log --oneline -8
```

Expected: 用户原修改仍在工作区；每个任务对应独立提交；没有临时日志、APK 或 generated plugin 文件被提交。

- [ ] **Step 8: 推送当前分支**

```powershell
git push fork usb-exclusive-volume-overlay-performance
```

Expected: fork 分支更新成功。若 GitHub 仍不可达，如实记录本地提交 ID 和失败信息，不改远程、不强推。

## 新窗口启动提示

在新 Codex 窗口中发送：

```text
请在 F:\Symusic\sylvakru-usb-exclusive-clean 中继续 USB 硬件音量任务。
先完整阅读 AGENTS.md 和 docs/superpowers/plans/2026-07-15-usb-hardware-volume-write-coordinator.md，
然后使用 executing-plans 技能逐任务执行。不得覆盖文档列出的用户未提交修改，
不得自动播放或发送音量增加命令，真机阶段先等我把音量降到安全范围。
```
