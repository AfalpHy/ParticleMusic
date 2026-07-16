# USB 跨参数切歌静音重锁 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除 USB 独占手动跨采样率、位深、声道及 PCM/DoP/Native 类型切歌时的小音爆，并保证硬件音量回读异常时 PCM 不会无界冻结、DSD 不会绕过安全门。

**Architecture:** Dart 将“当前独占会话由下一首独占会话替换”作为显式请求传给现有 MethodChannel；`UsbExclusiveAudioEngine` 在旧会话仍可用时计算完整会话签名。签名相同继续原有热复用，签名变化则在同一引擎内执行旧流合法收尾、URB 有界排空、重新配置、新流合法静音预卷。硬件音量只在同设备、同协议、读回可信时跨重配置保留；PCM 回读失败时最多保留旧硬件值并施加只减不增的临时数字补偿，DSD 继续严格等待验证。

**Tech Stack:** Flutter/Dart、Android Kotlin、Android USB Host、MediaCodec/MediaExtractor、JUnit、Flutter Test、ADB 真机日志。

---

## 交接约束

- 仓库：`F:\Symusic\sylvakru-usb-exclusive-clean`
- 分支：`usb-exclusive-volume-overlay-performance`
- 设计：`docs/superpowers/specs/2026-07-16-usb-cross-format-switch-pop-design.md`
- 不创建额外 worktree；`F:\Symusic\AGENTS.md` 指定只能使用当前仓库。
- 开始每个任务前重新执行 `git status --short`，保留全部用户未提交修改。
- 当前已知用户修改包含：
  - `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
  - `docs/superpowers/specs/2026-07-11-usb-cloud-exclusive-recovery-design.md`
  - `lib/base/audio_handler.dart`
  - `lib/base/widgets/audio_output_panel.dart`
  - Linux/macOS/Windows generated plugin 文件
- 修改脏文件时必须先保存 `git diff -- <file>`，提交时使用 `git add -p -- <file>`，再用 `git diff --cached -- <file>` 确认只包含本任务 hunk。若用户 hunk 与计划 hunk重叠，停止该任务并请用户确认；不得 reset、checkout、clean 或整文件覆盖。
- 不修改非 USB UI、歌词、背景、共享输出视觉，也不改协议 ID、设备型号匹配或 ReplayGain 计算规则。
- 每个任务独立验证、提交并推送到 `fork/usb-exclusive-volume-overlay-performance`，不得强推。
- 真机阶段不得由执行者自动播放、切歌或发送任何音量命令。安装后先监听，等待用户明确确认音量已降到安全范围，再由用户手动操作。

## 文件结构

- Create: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbStreamTransition.kt`
  - 会话签名、切换决策、PCM 收尾样本、URB 排空、硬件音量保留和安全补偿的纯逻辑。
- Create: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbStreamTransitionTest.kt`
  - 覆盖所有纯逻辑边界。
- Modify: `lib/base/services/usb_audio_service.dart`
  - 在独占启动请求中增加 `replaceActive`。
- Modify: `test/usb_audio_service_test.dart`
  - 固定 MethodChannel 请求映射和状态解析。
- Modify: `lib/base/audio_handler.dart`
  - 手动换歌时先尝试替换当前独占会话，失败后才停止并回退共享输出。
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
  - 接入签名决策、双端静音、排空、诊断、硬件音量会话隔离和只衰减补偿。

### Task 1: 用纯逻辑测试固定切换、安全和时间边界

**Files:**
- Create: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbStreamTransitionTest.kt`
- Create: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbStreamTransition.kt`

- [ ] **Step 1: 添加会话签名与切换决策失败测试**

创建 `UsbStreamTransitionTest.kt`，先加入：

```kotlin
package com.afalphy.sylvakru

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UsbStreamTransitionTest {
    private val pcm441 = UsbStreamSignature(7, 44100, 2, 24, null, null)

    @Test
    fun reusesOnlyAnExactReplacementSignature() {
        assertEquals(
            UsbStreamTransitionAction.REUSE,
            usbStreamTransitionAction(pcm441, pcm441, replaceActive = true),
        )
        assertEquals(
            UsbStreamTransitionAction.SILENT_RECONFIGURE,
            usbStreamTransitionAction(
                pcm441,
                pcm441.copy(sampleRate = 96000),
                replaceActive = true,
            ),
        )
        assertEquals(
            UsbStreamTransitionAction.SILENT_RECONFIGURE,
            usbStreamTransitionAction(
                pcm441,
                pcm441.copy(dsdKind = "dop", bitDepth = null),
                replaceActive = true,
            ),
        )
    }

    @Test
    fun opensFreshWhenTheRequestIsNotReplacingAnActiveSession() {
        assertEquals(
            UsbStreamTransitionAction.OPEN_FRESH,
            usbStreamTransitionAction(pcm441, pcm441, replaceActive = false),
        )
        assertEquals(
            UsbStreamTransitionAction.OPEN_FRESH,
            usbStreamTransitionAction(null, pcm441, replaceActive = true),
        )
    }

    @Test
    fun doesNotPublishInactiveStateForAnUncommittedReplacementFailure() {
        assertFalse(shouldPublishUsbStartFailure(true, false, true))
        assertTrue(shouldPublishUsbStartFailure(true, true, true))
        assertTrue(shouldPublishUsbStartFailure(false, false, true))
        assertTrue(shouldPublishUsbStartFailure(true, false, false))
    }
}
```

- [ ] **Step 2: 添加 PCM 单调收尾、静音帧和排空失败测试**

在同一个测试类中加入：

```kotlin
@Test
fun fadesEveryPcmChannelMonotonicallyToZero() {
    val tail = pcmFadeToSilence(
        lastSamples = intArrayOf(8_000_000, -4_000_000),
        fadeFrames = 5,
        silenceFrames = 2,
    )
    assertEquals(
        listOf(
            8_000_000, -4_000_000,
            6_000_000, -3_000_000,
            4_000_000, -2_000_000,
            2_000_000, -1_000_000,
            0, 0,
            0, 0,
            0, 0,
        ),
        tail.toList(),
    )
}

@Test
fun fades16And24And32BitDomainSamplesWithoutOverflow() {
    for (last in intArrayOf(32767, -32767, 8_388_607, -8_388_607, Int.MAX_VALUE, -Int.MAX_VALUE)) {
        val tail = pcmFadeToSilence(intArrayOf(last), fadeFrames = 9, silenceFrames = 1)
        assertEquals(last, tail.first())
        assertEquals(0, tail.last())
        assertTrue(
            tail.zipWithNext().all { (left, right) ->
                kotlin.math.abs(right.toLong()) <= kotlin.math.abs(left.toLong())
            },
        )
    }
}

@Test
fun computesBoundedSilenceFramesForEveryPcmWidth() {
    assertEquals(706, usbSilenceFrames(44100, 16))
    assertEquals(1536, usbSilenceFrames(96000, 16))
    assertEquals(9600, usbSilenceFrames(96000, 100))
}

@Test
fun makesOutputDrainBounded() {
    assertEquals(OutputDrainAction.DRAINED, outputDrainAction(0, 0, 220))
    assertEquals(OutputDrainAction.WAIT, outputDrainAction(4, 219, 220))
    assertEquals(OutputDrainAction.TIMED_OUT, outputDrainAction(4, 220, 220))
}
```

- [ ] **Step 3: 添加硬件音量保留与只衰减补偿失败测试**

继续加入：

```kotlin
@Test
fun preservesTrustedHardwareTargetOnlyForTheSameDeviceAndProtocol() {
    assertTrue(
        shouldPreserveTrustedHardwareVolume(
            currentDeviceId = 7,
            nextDeviceId = 7,
            currentProtocol = "ibassoHid",
            nextProtocol = "ibassoHid",
            readbackVerified = true,
            writeOnly = false,
        ),
    )
    assertFalse(
        shouldPreserveTrustedHardwareVolume(7, 8, "ibassoHid", "ibassoHid", true, false),
    )
    assertFalse(
        shouldPreserveTrustedHardwareVolume(7, 7, "ibassoHid", "uac2", true, false),
    )
    assertFalse(
        shouldPreserveTrustedHardwareVolume(7, 7, "ibassoHid", "ibassoHid", false, false),
    )
    assertFalse(
        shouldPreserveTrustedHardwareVolume(7, 7, "ibassoHid", "ibassoHid", true, true),
    )
}

@Test
fun frozenPcmCompensationCanOnlyReduceTotalOutput() {
    assertEquals(32768, frozenPcmCompensationGainQ16(65536, 32768))
    assertEquals(65536, frozenPcmCompensationGainQ16(32768, 65536))
    assertEquals(65536, frozenPcmCompensationGainQ16(32768, 32768))
    assertEquals(0, frozenPcmCompensationGainQ16(65536, 0))
}

@Test
fun staleOrDsdVerificationCannotMutateTheNewPcmSession() {
    assertEquals(
        PreservedVolumeVerificationAction.IGNORE,
        preservedVolumeVerificationAction(false, false, 20, 20),
    )
    assertEquals(
        PreservedVolumeVerificationAction.KEEP_FROZEN,
        preservedVolumeVerificationAction(true, true, 20, 20),
    )
    assertEquals(
        PreservedVolumeVerificationAction.ACCEPT,
        preservedVolumeVerificationAction(true, false, 20, 20),
    )
    assertEquals(
        PreservedVolumeVerificationAction.KEEP_FROZEN,
        preservedVolumeVerificationAction(true, false, null, 20),
    )
}
```

- [ ] **Step 4: 运行目标测试并确认 RED**

Run:

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbStreamTransitionTest
cd ..
```

Expected: 因 `UsbStreamTransition` 类型和函数尚不存在而编译失败。保存 RED 输出后再写生产代码。

- [ ] **Step 5: 实现纯逻辑**

创建 `UsbStreamTransition.kt`：

```kotlin
package com.afalphy.sylvakru

internal const val USB_TRANSITION_FADE_MS = 16
internal const val USB_TRANSITION_OLD_SILENCE_MS = 24
internal const val USB_TRANSITION_PREROLL_MS = 100
internal const val USB_TRANSITION_DRAIN_TIMEOUT_MS = 220L

internal data class UsbStreamSignature(
    val deviceId: Int,
    val sampleRate: Int?,
    val channels: Int,
    val bitDepth: Int?,
    val dsdKind: String?,
    val nativeFormat: String?,
)

internal enum class UsbStreamTransitionAction {
    REUSE,
    SILENT_RECONFIGURE,
    OPEN_FRESH,
}

internal fun usbStreamTransitionAction(
    current: UsbStreamSignature?,
    next: UsbStreamSignature,
    replaceActive: Boolean,
): UsbStreamTransitionAction = when {
    !replaceActive || current == null -> UsbStreamTransitionAction.OPEN_FRESH
    current == next -> UsbStreamTransitionAction.REUSE
    else -> UsbStreamTransitionAction.SILENT_RECONFIGURE
}

internal fun shouldPublishUsbStartFailure(
    replaceActive: Boolean,
    transitionCommitted: Boolean,
    currentActive: Boolean,
): Boolean = !replaceActive || transitionCommitted || !currentActive

internal fun pcmFadeToSilence(
    lastSamples: IntArray,
    fadeFrames: Int,
    silenceFrames: Int,
): IntArray {
    require(lastSamples.isNotEmpty())
    require(fadeFrames > 0)
    require(silenceFrames >= 0)
    val result = IntArray((fadeFrames + silenceFrames) * lastSamples.size)
    val denominator = (fadeFrames - 1).coerceAtLeast(1)
    for (frame in 0 until fadeFrames) {
        val numerator = (fadeFrames - 1 - frame).coerceAtLeast(0)
        for (channel in lastSamples.indices) {
            result[frame * lastSamples.size + channel] =
                ((lastSamples[channel].toLong() * numerator) / denominator).toInt()
        }
    }
    return result
}

internal fun usbSilenceFrames(sampleRate: Int, durationMs: Int): Int =
    ((sampleRate.toLong() * durationMs + 999L) / 1000L).coerceAtLeast(1L).toInt()

internal enum class OutputDrainAction { WAIT, DRAINED, TIMED_OUT }

internal fun outputDrainAction(
    pendingPackets: Long,
    elapsedMs: Long,
    timeoutMs: Long,
): OutputDrainAction = when {
    pendingPackets <= 0L -> OutputDrainAction.DRAINED
    elapsedMs >= timeoutMs -> OutputDrainAction.TIMED_OUT
    else -> OutputDrainAction.WAIT
}

internal fun shouldPreserveTrustedHardwareVolume(
    currentDeviceId: Int?,
    nextDeviceId: Int,
    currentProtocol: String?,
    nextProtocol: String?,
    readbackVerified: Boolean,
    writeOnly: Boolean,
): Boolean = currentDeviceId == nextDeviceId &&
    currentProtocol != null &&
    currentProtocol == nextProtocol &&
    readbackVerified &&
    !writeOnly

internal fun frozenPcmCompensationGainQ16(
    trustedHardwareGainQ16: Int,
    requestedTotalGainQ16: Int,
): Int {
    if (trustedHardwareGainQ16 <= 0) return 0
    if (requestedTotalGainQ16 >= trustedHardwareGainQ16) return 65536
    return ((requestedTotalGainQ16.toLong() shl 16) / trustedHardwareGainQ16)
        .coerceIn(0L, 65536L)
        .toInt()
}

internal enum class PreservedVolumeVerificationAction {
    ACCEPT,
    KEEP_FROZEN,
    IGNORE,
}

internal fun preservedVolumeVerificationAction(
    generationMatches: Boolean,
    isDsd: Boolean,
    readbackRaw: Int?,
    trustedRaw: Int,
): PreservedVolumeVerificationAction = when {
    !generationMatches -> PreservedVolumeVerificationAction.IGNORE
    isDsd -> PreservedVolumeVerificationAction.KEEP_FROZEN
    readbackRaw == trustedRaw -> PreservedVolumeVerificationAction.ACCEPT
    else -> PreservedVolumeVerificationAction.KEEP_FROZEN
}
```

- [ ] **Step 6: 重跑测试确认 GREEN**

Run 同 Step 4。Expected: `BUILD SUCCESSFUL`，目标类全部通过。

- [ ] **Step 7: 提交并推送**

```powershell
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbStreamTransition.kt
git add android/app/src/test/kotlin/com/afalphy/sylvakru/UsbStreamTransitionTest.kt
git diff --cached --check
git diff --cached --stat
git commit -m "test(usb): 固定跨参数静音切换规则"
git push fork usb-exclusive-volume-overlay-performance
```

### Task 2: 让 Dart 使用替换式独占启动

**Files:**
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `test/usb_audio_service_test.dart`
- Modify: `lib/base/audio_handler.dart`

- [ ] **Step 1: 用失败测试固定 `replaceActive` 映射**

在 `startExclusivePlayback sends playback request to native layer` 测试的请求中加入：

```dart
replaceActive: true,
```

并在预期参数 Map 中加入：

```dart
'replaceActive': true,
```

- [ ] **Step 2: 运行 Flutter 目标测试并确认 RED**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart
```

Expected: `UsbExclusivePlaybackRequest` 尚无 `replaceActive` 命名参数而编译失败。

- [ ] **Step 3: 扩展请求对象**

在 `UsbExclusivePlaybackRequest` 中加入字段、默认参数和映射：

```dart
final bool replaceActive;

const UsbExclusivePlaybackRequest({
  // 保留现有参数
  this.replaceActive = false,
});

Map<String, Object?> toMap() {
  return {
    // 保留现有键
    'replaceActive': replaceActive,
  };
}
```

必须把字段和键合并进现有构造函数与 Map，不能用第二个构造函数或 wrapper。

- [ ] **Step 4: 调整 `load()` 的停止顺序**

在 `load()` 进入 `try` 后保存旧会话状态；当前没有独占会话时仍沿用原停止逻辑，存在独占会话时先保留它：

```dart
final replacingUsbExclusive = _usbExclusiveActive;
if (!replacingUsbExclusive) {
  await _stopExclusiveIntentionally();
  _usbExclusiveActive = false;
  _usbExclusivePosition = Duration.zero;
}
```

调用 `_tryOpenUsbExclusive` 时传入：

```dart
final openedExclusive = await _tryOpenUsbExclusive(
  currentSong,
  generation: generation,
  replaceActive: replacingUsbExclusive,
);
```

在 `openedExclusive == false` 的共享输出分支最前面补上：

```dart
if (replacingUsbExclusive) {
  await _stopExclusiveIntentionally();
  _usbExclusiveActive = false;
  _usbExclusivePosition = Duration.zero;
}
```

这样权限、路径或格式预检失败时旧会话只在确定回退共享输出后停止；generation 已变化时直接返回，让较新的 `load()` 接管，不得由旧请求停止当前会话。

- [ ] **Step 5: 将替换语义传到原生层并隔离状态回调**

给 `_tryOpenUsbExclusive` 增加参数：

```dart
Future<bool> _tryOpenUsbExclusive(
  MyAudioMetadata song, {
  int? generation,
  bool replaceActive = false,
}) async {
```

构造请求时加入：

```dart
replaceActive: replaceActive,
```

仅在等待替换式 `startExclusivePlayback` 时临时标记 intentional stop：

```dart
if (replaceActive) {
  _intentionalExclusiveStop = true;
}
try {
  state = await usbAudioService.startExclusivePlayback(request);
} finally {
  if (replaceActive) {
    _intentionalExclusiveStop = false;
  }
}
```

把现有内联请求先赋给 `final request`，再放入上述 `try/finally`。现有异常路径必须继续恢复 `_appliedOutputGain` 和共享音量。

- [ ] **Step 6: 格式化并验证**

```powershell
F:\software\flutter_3.44.5\bin\dart.bat format lib/base/services/usb_audio_service.dart lib/base/audio_handler.dart test/usb_audio_service_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart
```

Expected: 测试通过；默认请求映射为 `replaceActive=false`，目标测试映射为 `true`。

- [ ] **Step 7: 只暂存本任务 hunk，提交并推送**

```powershell
git add lib/base/services/usb_audio_service.dart
git add test/usb_audio_service_test.dart
git add -p -- lib/base/audio_handler.dart
git diff --cached --check
git diff --cached -- lib/base/audio_handler.dart
git commit -m "fix(usb): 保留独占会话直到替换预检完成"
git push fork usb-exclusive-volume-overlay-performance
```

Expected: `audio_handler.dart` 的 cached diff 只包含停止顺序、`replaceActive` 传递和 intentional stop 隔离；不包含用户原有修改。

### Task 3: 在原生层按完整签名选择热复用或静音重配置

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbStreamTransitionTest.kt`

- [ ] **Step 1: 先保存脏文件基线**

```powershell
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
```

将输出保存到执行记录。后续不得整文件暂存。

- [ ] **Step 2: 隔离替换预检失败，不能误停旧会话**

在 `start()` 最前面保存请求语义，并提供局部失败函数：

```kotlin
val requestedPlaybackId = arguments["playbackId"] as? String
val replaceActive = arguments["replaceActive"] == true
var transitionCommitted = false

fun failStart(message: String): Map<String, Any?> {
    val failedState = inactiveState(message) + mapOf("playbackId" to requestedPlaybackId)
    return if (
        shouldPublishUsbStartFailure(
            replaceActive,
            transitionCommitted,
            currentState["active"] == true,
        )
    ) {
        updateState(failedState)
    } else {
        failedState
    }
}
```

从设备、权限、文件、格式、DSD header 到签名决策之前的所有 `return updateState(inactiveState(message))` 改为 `return failStart(message)`。替换预检尚未提交时，失败 Map 只返回给 MethodChannel 调用方，让 Dart 得到 `active=false` 后主动停止并回退；不得调用 `updateState`，旧 worker 和监听状态继续有效。

删除 `start()` 顶部针对已有 `connection` 的提前 `scheduleDeferredClose()`。只有 worker 已停止且连接成为待关闭残留时才允许安排 deferred close，不能给仍播放的旧会话埋入 4 秒关闭任务。

- [ ] **Step 3: 把新请求值先解析为局部变量**

在 `start()` 顶部删除立即执行的 `invalidatePendingVolumeRequests()` 和 `stopWorkerKeepingSession()`；旧 worker 必须保持运行直到签名决策完成。

将以下会影响旧 worker 的赋值先改为局部值：

```kotlin
val nextVolumeMode = (arguments["volumeMode"] as? String)
    ?.lowercase(Locale.ROOT)
    ?.takeIf { it == "auto" || it == "dac" || it == "digital" || it == "raw" }
    ?: "auto"
val nextRequestedVolumeGainQ16 =
    ((arguments["volumeGainQ16"] as? Number)?.toInt() ?: UNITY_GAIN_Q16)
        .coerceIn(0, UNITY_GAIN_Q16)
val nextRequestedReplayGainMilliDb =
    (arguments["replayGainMilliDb"] as? Number)?.toInt() ?: 0
val nextDsdGainCompensationDb =
    ((arguments["dsdGainCompensationDb"] as? Number)?.toInt() ?: 0).coerceIn(-12, 6)
val nextVolumeSmoothHandoff = arguments["smoothHandoff"] as? Boolean ?: true
var nextTargetBufferMs =
    ((arguments["targetBufferMs"] as? Number)?.toInt() ?: 200).coerceIn(50, 1000)
if (streaming) nextTargetBufferMs = maxOf(nextTargetBufferMs, 1000)
```

DSD reader、采样率、位深、声道和 `wantDsdKind` 仍按现有代码解析；解析失败统一调用 `failStart()`，旧会话保持运行且不安排 deferred close。

- [ ] **Step 4: 构造完整新旧签名并选择动作**

在 `wantDsdKind` 得出后加入：

```kotlin
val currentSignature = if (connection != null && sessionTarget != null && sessionDeviceId != null) {
    UsbStreamSignature(
        deviceId = sessionDeviceId!!,
        sampleRate = sessionSampleRate,
        channels = sessionChannels ?: 2,
        bitDepth = sessionBitDepth,
        dsdKind = sessionDsdKind,
        nativeFormat = sessionNativeFormat,
    )
} else {
    null
}
val nextSignature = UsbStreamSignature(
    deviceId = device.deviceId,
    sampleRate = requestedSampleRate,
    channels = requestedChannels,
    bitDepth = requestedSessionBitDepth,
    dsdKind = wantDsdKind,
    nativeFormat = nativeFormat,
)
val requestedTransitionAction = usbStreamTransitionAction(
    current = currentSignature,
    next = nextSignature,
    replaceActive = replaceActive,
)
val transitionAction = if (
    requestedTransitionAction == UsbStreamTransitionAction.REUSE &&
    wantDsdKind == "native" &&
    nativeFormat == null
) {
    UsbStreamTransitionAction.SILENT_RECONFIGURE
} else {
    requestedTransitionAction
}
```

Native DSD 尚需描述符才能确定 `nativeFormat` 时，`nextSignature.nativeFormat == null` 不得热复用；上述二次决策会强制静音重配置。

- [ ] **Step 5: 决策后再停止旧 worker 并应用新请求值**

加入：

```kotlin
invalidatePendingVolumeRequests()
transitionCommitted = true
val sessionUsable = when (transitionAction) {
    UsbStreamTransitionAction.REUSE -> stopWorkerKeepingSession()
    UsbStreamTransitionAction.SILENT_RECONFIGURE -> stopWorkerForSilentReconfigure()
    UsbStreamTransitionAction.OPEN_FRESH -> {
        stopWorkerKeepingSession()
        false
    }
}
playbackId = requestedPlaybackId
pendingHardwareVolumeEvent = null
volumeMode = nextVolumeMode
requestedVolumeGainQ16 = nextRequestedVolumeGainQ16
requestedReplayGainMilliDb = nextRequestedReplayGainMilliDb
dsdGainCompensationDb = nextDsdGainCompensationDb
volumeSmoothHandoff = nextVolumeSmoothHandoff
targetBufferMs = nextTargetBufferMs
```

把现有 `reuseSession` 条件替换为：

```kotlin
val reuseSession = transitionAction == UsbStreamTransitionAction.REUSE &&
    sessionUsable &&
    connection != null &&
    sessionTarget != null &&
    (dsdReader == null || nativeDsd || sessionTarget!!.usbBytesPerSample >= 3)
```

保留现有热复用路径全部行为，不加收尾、预卷或延迟。

- [ ] **Step 6: 增加切换停止标记和有界排空**

在 worker 状态字段附近加入：

```kotlin
private val silentReconfigureRequested = AtomicBoolean(false)
```

在 `stopWorkerKeepingSession()` 后加入：

```kotlin
private fun stopWorkerForSilentReconfigure(): Boolean {
    val startedAtMs = SystemClock.elapsedRealtime()
    silentReconfigureRequested.set(true)
    updateSessionDiagnostics("transitionStage", "old-tail-started")
    return try {
        val usable = stopWorkerKeepingSession()
        if (usable) awaitOldOutputDrain(startedAtMs)
        usable
    } finally {
        silentReconfigureRequested.set(false)
    }
}

private fun awaitOldOutputDrain(startedAtMs: Long) {
    while (true) {
        val pendingPackets = UsbExclusiveNative.transportTelemetry().getOrNull(0) ?: 0L
        val elapsedMs = SystemClock.elapsedRealtime() - startedAtMs
        when (outputDrainAction(pendingPackets, elapsedMs, USB_TRANSITION_DRAIN_TIMEOUT_MS)) {
            OutputDrainAction.DRAINED -> {
                updateSessionDiagnostics("transitionStage", "old-output-drained")
                return
            }
            OutputDrainAction.TIMED_OUT -> {
                UsbDiagnostics.w(
                    tag,
                    "USB transition output drain timed out pendingPackets=$pendingPackets elapsedMs=$elapsedMs",
                )
                return
            }
            OutputDrainAction.WAIT -> SystemClock.sleep(10)
        }
    }
}
```

- [ ] **Step 7: 编译验证原生决策接线**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbStreamTransitionTest
cd ..
```

Expected: `BUILD SUCCESSFUL`。此任务尚未写实际尾部，因此不得真机验收或声称音爆已修复。

- [ ] **Step 8: 只暂存本任务 hunk，提交并推送**

```powershell
git add -p -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff --cached --check
git diff --cached -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git commit -m "fix(usb): 区分热复用与跨参数重配置"
git push fork usb-exclusive-volume-overlay-performance
```

### Task 4: 实现旧流合法收尾和新流静音预卷

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbStreamTransitionTest.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDsdTest.kt`

- [ ] **Step 1: 先用失败测试固定热复用和重配置的静音计划**

在 `UsbStreamTransitionTest.kt` 加入：

```kotlin
@Test
fun addsSilenceOnlyForCrossParameterReconfiguration() {
    assertEquals(
        UsbTransitionSilencePlan(0, 0, 0),
        usbTransitionSilencePlan(UsbStreamTransitionAction.REUSE),
    )
    assertEquals(
        UsbTransitionSilencePlan(16, 24, 100),
        usbTransitionSilencePlan(UsbStreamTransitionAction.SILENT_RECONFIGURE),
    )
    assertEquals(
        UsbTransitionSilencePlan(0, 0, 0),
        usbTransitionSilencePlan(UsbStreamTransitionAction.OPEN_FRESH),
    )
}
```

Run:

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbStreamTransitionTest
cd ..
```

Expected: 因 `UsbTransitionSilencePlan` 尚不存在而编译失败。

- [ ] **Step 2: 实现静音计划并让引擎统一使用**

在 `UsbStreamTransition.kt` 加入：

```kotlin
internal data class UsbTransitionSilencePlan(
    val oldFadeMs: Int,
    val oldSilenceMs: Int,
    val newPreRollMs: Int,
)

internal fun usbTransitionSilencePlan(
    action: UsbStreamTransitionAction,
): UsbTransitionSilencePlan = if (action == UsbStreamTransitionAction.SILENT_RECONFIGURE) {
    UsbTransitionSilencePlan(
        oldFadeMs = USB_TRANSITION_FADE_MS,
        oldSilenceMs = USB_TRANSITION_OLD_SILENCE_MS,
        newPreRollMs = USB_TRANSITION_PREROLL_MS,
    )
} else {
    UsbTransitionSilencePlan(0, 0, 0)
}
```

`UsbExclusiveAudioEngine.start()` 只调用一次 `usbTransitionSilencePlan(transitionAction)`。新增：

```kotlin
@Volatile
private var activeTransitionSilencePlan = UsbTransitionSilencePlan(0, 0, 0)
```

把 Task 3 的 `stopWorkerForSilentReconfigure()` 改为接收 `silencePlan`，设置 `activeTransitionSilencePlan` 后再停止 worker，并在 join 与排空完成后恢复零计划。后续 PCM/DSD 收尾和新流预卷均读取该对象，不能各自复制时间常量。

- [ ] **Step 3: 让 PCM packetizer 记录已转换的最后一帧**

在 `PcmIsoPacketizer` 中把构造参数 `channels` 改为属性，并增加：

```kotlin
private val lastUsbSamples = IntArray(channels)
private var hasLastUsbFrame = false
```

在 `convertPcmToUsbSlots()` 中先按当前 `gainQ16` 计算最后一帧在 USB bit-resolution 域的每声道样本，再执行现有零拷贝或转换。使用现有 `readSignedLittleEndian`，每个声道保存经过数字增益和位深移位后的 `shifted`；不得从未经增益的源字节保存。

加入：

```kotlin
fun writeTransitionTail(fadeMs: Int, silenceMs: Int) {
    val fadeFrames = usbSilenceFrames(sampleRate, fadeMs)
    val silenceFrames = usbSilenceFrames(sampleRate, silenceMs)
    if (!hasLastUsbFrame) {
        writeUsbSilence(fadeFrames + silenceFrames)
        return
    }
    val samples = pcmFadeToSilence(lastUsbSamples, fadeFrames, silenceFrames)
    val bytes = ByteArray(samples.size * usbBytesPerSample)
    samples.forEachIndexed { index, sample ->
        writeLittleEndian(bytes, index * usbBytesPerSample, usbBytesPerSample, sample)
    }
    pending.write(bytes)
    drain(fullPacketsOnly = false)
}

fun writeUsbSilence(frames: Int) {
    pending.write(ByteArray(frames * bytesPerFrame))
    drain(fullPacketsOnly = false)
}
```

`reset()` 必须同时清零 `lastUsbSamples` 和 `hasLastUsbFrame`，避免 seek 后使用 seek 前样本。

- [ ] **Step 4: 仅在跨参数停止时写 PCM 尾部**

增加引擎辅助函数：

```kotlin
private fun finishPcmPacketizer(packetizer: PcmIsoPacketizer) {
    if (silentReconfigureRequested.get()) {
        val plan = activeTransitionSilencePlan
        packetizer.writeTransitionTail(plan.oldFadeMs, plan.oldSilenceMs)
    } else {
        packetizer.flush()
    }
}
```

将 `decodeAndWrite()` 和 `writeRawPcm()` 退出路径上的最终 `packetizer.flush()` 替换为 `finishPcmPacketizer(packetizer)`。seek、自然 EOF 和普通 stop 不设置 `silentReconfigureRequested`，因此行为保持不变。

- [ ] **Step 5: 让 DSD 收尾保持格式和相位合法**

在 `dsdDecodeAndWrite()` 的 worker 循环退出后、清理 packetizer 前加入：

```kotlin
if (silentReconfigureRequested.get()) {
    val plan = activeTransitionSilencePlan
    val tailFrames = usbSilenceFrames(frameRate, plan.oldFadeMs + plan.oldSilenceMs)
    packetizer.write(encoder.encodeSilence(tailFrames))
    packetizer.flush()
}
```

必须复用当前会话的 `encoder`，不得新建 DoP marker phase；Native DSD 继续使用当前 `nativeFormat` 和 frame alignment。

先运行已有的 `UsbDsdTest.dopSilenceUses0x69AndKeepsMarkerPhase`、`nativeSilenceAndDrainUse0x69`，再完成接线后重跑；它们固定复用 encoder 时的 DoP phase 和 Native slot 对齐。

- [ ] **Step 6: 给新会话传入预卷时长**

在 `start()` 计算：

```kotlin
val silencePlan = usbTransitionSilencePlan(transitionAction)
val preRollMs = silencePlan.newPreRollMs
```

把它传给 `decodeAndWrite()`、`writeRawPcm()` 和 `dsdDecodeAndWrite()`。PCM packetizer 第一次创建后、提交真实音频前执行：

```kotlin
if (preRollMs > 0) {
    packetizer.writeUsbSilence(usbSilenceFrames(sampleRate, preRollMs))
    updateSessionDiagnostics("transitionStage", "new-silence-preroll")
}
```

解码路径若因 output format change 重建 packetizer，使用局部 `preRollPending` 保证每个新会话只预卷一次。Raw PCM 在进入读取循环前预卷一次。

DSD 必须在硬件音量安全检查成功之后、第一段真实 DSD 数据之前执行：

```kotlin
if (preRollMs > 0) {
    packetizer.write(encoder.encodeSilence(usbSilenceFrames(frameRate, preRollMs)))
    packetizer.flush()
    updateSessionDiagnostics("transitionStage", "new-silence-preroll")
}
```

若 DSD 音量尚未验证，不得调用这段代码，也不得提交任何 USB DSD 静音。

- [ ] **Step 7: 补齐阶段诊断**

在对应成功点记录以下英文阶段：

```text
reuse
old-tail-started
old-output-drained
old-session-closed
new-clock-configured
new-silence-preroll
new-audio-started
```

使用现有 `updateSessionDiagnostics("transitionStage", stage)`；只记录阶段和耗时，不记录完整媒体路径，也不逐包打印。

- [ ] **Step 8: 运行目标与完整 Android 测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbStreamTransitionTest
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbDsdTest
.\gradlew.bat app:testDebugUnitTest
cd ..
```

Expected: 两条命令均 `BUILD SUCCESSFUL`；现有 DoP/Native、PCM 位深和硬件音量测试无回归。

- [ ] **Step 9: 只暂存本任务 hunk，提交并推送**

```powershell
git add android/app/src/test/kotlin/com/afalphy/sylvakru/UsbStreamTransitionTest.kt
git add -p -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff --cached --check
git diff --cached --stat
git commit -m "fix(usb): 为跨参数切歌添加双端静音护栏"
git push fork usb-exclusive-volume-overlay-performance
```

### Task 5: 跨重配置保留可信硬件值并安全处理回读失败

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbStreamTransitionTest.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbHardwareVolumeTest.kt`

- [ ] **Step 1: 让 hard close 可选择保留可信目标**

将签名改为：

```kotlin
private fun hardCloseSession(
    reason: String,
    preserveTrustedHardwareTarget: Boolean = false,
) {
```

关闭 HID 时改为：

```kotlin
closeIbassoVolumeControl(
    resetReaderHealth = true,
    clearTrustedTarget = !preserveTrustedHardwareTarget,
)
```

设备拔出、普通 release、idle timeout、worker failure 和 write-only 路径继续使用默认 `false`，不得跨设备保留。

- [ ] **Step 2: 在重配置前计算保留条件**

在清空旧状态前捕获：

```kotlin
val preserveTrustedHardwareTarget =
    transitionAction == UsbStreamTransitionAction.SILENT_RECONFIGURE &&
        shouldPreserveTrustedHardwareVolume(
            currentDeviceId = sessionDeviceId,
            nextDeviceId = device.deviceId,
            currentProtocol = hardwareVolumeProtocol,
            nextProtocol = quirk.hardwareVolumeProtocol,
            readbackVerified = hardwareVolumeReadbackVerifiedState,
            writeOnly = hardwareVolumeWriteOnlyState,
        )
```

跨参数分支关闭旧会话时调用：

```kotlin
hardCloseSession(
    "device or stream parameters changed",
    preserveTrustedHardwareTarget = preserveTrustedHardwareTarget,
)
updateSessionDiagnostics("transitionStage", "old-session-closed")
```

- [ ] **Step 3: 用 generation 隔离一次只读恢复验证**

在音量状态字段附近加入：

```kotlin
private data class PendingPreservedPcmVerification(
    val volumeGeneration: Long,
    val deviceId: Int,
    val target: UsbVolumeTarget,
)

@Volatile
private var pendingPreservedPcmVerification: PendingPreservedPcmVerification? = null
```

每次 `invalidatePendingVolumeRequests()`、设备变化和 release 都清除该字段。在 `writeIbassoHidVolume()` 得到 `readBaseRaw` 后、计算 handoff 和发送任何写包之前，加入以下早退；它只适用于 PCM 新连接首次回读失败且 `previousAppliedTarget != null`：

```kotlin
if (newConnection && shouldReadInitialVolume && readBaseRaw == null &&
    previousAppliedTarget != null && !isDsd
) {
    freezeIbassoPcmVolume(
        previousAppliedTarget,
        effectiveVolumeGainQ16(requestedVolumeGainQ16, requestedReplayGainMilliDb),
    )
    pendingPreservedPcmVerification = PendingPreservedPcmVerification(
        volumeGeneration = volumeSessionGeneration.get(),
        deviceId = device.deviceId,
        target = previousAppliedTarget,
    )
    updateSessionDiagnostics("transitionStage", "hardware-volume-frozen")
    return "iBasso hardware volume readback is pending; kept the trusted PCM target."
}
```

不得在此分支写新硬件目标，也不得发送音量增加命令。

PCM 静音预卷已提交后，在现有 volume executor 上执行一次只读 `command 65` 恢复检查。应用结果前必须同时验证 volume generation、device ID、connection 和 target 仍一致；调用 `preservedVolumeVerificationAction()`：`ACCEPT` 才解除冻结，`KEEP_FROZEN` 保持播放和冻结，`IGNORE` 不更新任何字段。不得循环重试。

- [ ] **Step 4: 冻结时应用只允许衰减的 PCM 补偿**

扩展 `freezeIbassoPcmVolume` 接收本次请求的总目标：

```kotlin
private fun freezeIbassoPcmVolume(
    previousTarget: UsbVolumeTarget?,
    requestedTotalGainQ16: Int,
) {
```

有可信目标时计算：

```kotlin
val compensationGainQ16 = frozenPcmCompensationGainQ16(
    trustedHardwareGainQ16 = actual.gainQ16,
    requestedTotalGainQ16 = requestedTotalGainQ16,
)
pcmVolumeGainQ16 = minOf(pcmVolumeGainQ16, compensationGainQ16)
hardwareVolumeActive = true
volumeControlEnabled = compensationGainQ16 < UNITY_GAIN_Q16
hardwareVolumeFrozen = true
```

所有现有 PCM 调用点必须显式传入 `effectiveVolumeGainQ16(requestedVolumeGainQ16, requestedReplayGainMilliDb)`；不得只传用户音量而漏掉 ReplayGain。不得把 `pcmVolumeGainQ16` 提高到当前值以上。

把 `applyVolumeControl()` 末尾的冻结分支改为保留该负增益状态：

```kotlin
volumeControlEnabled = if (hardwareVolumeFrozen) {
    !isDsd && pcmVolumeGainQ16 < UNITY_GAIN_Q16
} else {
    shouldUsePcmDigitalVolumeFallback(
        isDsd = isDsd,
        volumeMode = volumeMode,
        hardwareVolumeActive = hardwareVolumeActive,
        readbackVerified = hardwareVolumeReadbackVerifiedState,
        writeOnly = hardwareVolumeWriteOnlyState,
    )
}
```

可信回读恢复后，使用现有安全 volume ramp 逐步交还硬件和数字增益；撤销补偿时每一步的硬件与数字组合总增益不得超过前一步。DSD/DoP/Native 不调用此补偿函数，仍在验证前暂停或拒绝启动。

- [ ] **Step 5: 补充状态测试**

在 `UsbStreamTransitionTest` 增加 requested gain 高于旧硬件 gain 时结果仍为 unity、低于旧硬件 gain 时结果严格小于 unity、零硬件 gain 不产生除零。保留并运行 `UsbHardwareVolumeTest`，确保没有可信旧目标时仍暂停、DSD 仍使用严格安全门、旧 generation 不改变新会话。

- [ ] **Step 6: 运行 Android 测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbStreamTransitionTest
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbHardwareVolumeTest
.\gradlew.bat app:testDebugUnitTest
cd ..
```

Expected: 全部 `BUILD SUCCESSFUL`。日志字符串使用英文，状态中冻结且可信时 `hardwareVolumeActive=true`，不得落到 `hardware=false/digital=false` 的原始数字电平组合。

- [ ] **Step 7: 只暂存本任务 hunk，提交并推送**

```powershell
git add android/app/src/test/kotlin/com/afalphy/sylvakru/UsbStreamTransitionTest.kt
git add -p -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff --cached --check
git diff --cached --stat
git commit -m "fix(usb): 隔离跨参数切歌硬件音量状态"
git push fork usb-exclusive-volume-overlay-performance
```

### Task 6: 执行静态检查、全量回归和 arm64 Profile 构建

**Files:**
- Verify only; 除格式化本任务文件外不新增修改。

- [ ] **Step 1: 检查工作区与提交边界**

```powershell
git status --short
git log -5 --oneline
git diff --check
```

确认用户原有未提交文件仍存在且未进入前述提交；确认没有 generated plugin、日志、APK 或临时文件被暂存。

- [ ] **Step 2: 运行 Flutter USB 回归**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_volume_safety_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat analyze
```

- [ ] **Step 3: 运行 Android 完整测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
```

- [ ] **Step 4: 构建 arm64 Profile APK**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64
```

不得在 Gradle 中加入 ABI filter。构建产物不提交。

- [ ] **Step 5: 复核并推送遗漏提交**

```powershell
git status --short
git diff --check
git log -5 --oneline
git push fork usb-exclusive-volume-overlay-performance
```

若格式化产生本任务代码差异，按所属任务单独暂存、验证并创建准确提交；不得把用户修改或 generated plugin 文件带入。

### Task 7: 安装后只监听，等待安全音量确认再做真机验收

**Files:**
- Verify only; 不修改、不提交设备日志。

- [ ] **Step 1: 确认设备并安装 Profile APK**

```powershell
adb devices
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

安装不会自动启动应用。不得使用会触发播放或音量变化的 intent、media key 或 shell volume 命令。

- [ ] **Step 2: 清理并启动只读日志监听**

```powershell
adb logcat -c
adb logcat -v threadtime UsbExclusiveAudioEngine:D UsbDiagnostics:D flutter:I *:S
```

监听开始后暂停执行，明确告诉用户：应用已安装并正在监听，请先把 DAC/系统音量降到安全范围并回复确认。未收到确认不得要求用户开始切歌。

- [ ] **Step 3: 用户确认安全音量后手动验收**

只让用户手动执行：

1. 同签名 PCM → PCM：确认无新增静音和延迟，日志为 `reuse`。
2. 44.1/48/96/192 kHz 任意不同采样率 PCM 互切：允许约 150–300ms 静音，无小音爆，新曲恢复播放。
3. PCM ↔ DoP/Native DSD：允许短静音，无小音爆；DSD 硬件音量未验证时保持暂停。
4. 网络源已缓存/流式独占的跨参数手动切歌：不出现永久暂停或重复“音量同步失败”。
5. HID 首次回读超时：有可信旧目标的 PCM 保持播放并显示硬件音量同步失败；必要数字补偿只衰减。无可信旧目标和 DSD 仍安全暂停。

- [ ] **Step 4: 核对日志阶段和安全不变量**

跨参数成功路径应按顺序出现：

```text
old-tail-started
old-output-drained
old-session-closed
new-clock-configured
hardware-volume-verified 或 hardware-volume-frozen
new-silence-preroll
new-audio-started
```

同签名路径只出现 `reuse`，不得出现 tail 或 preroll。任何旧 reader/generation 错误不得在新会话后写入 paused/frozen 状态。不得出现自动硬件音量增加命令。

- [ ] **Step 5: 最终汇报**

汇报必须包含：修改文件、用户可见行为、每条实际验证命令及结果、未执行验证、提交列表、推送分支、真机日志结论和已知限制。设备日志、APK 和本地诊断文件不得提交。

## 计划自检

- 同签名热复用与跨参数重配置有互斥决策，前者没有静音或额外延迟。
- PCM 旧尾部、DSD 合法静音、URB 有界排空和新流预卷均有明确接入点。
- DSD 在硬件音量验证前不提交任何 USB 音频数据。
- 可信硬件目标只在同设备、同协议、非 write-only 且已读回验证时保留。
- PCM 临时数字补偿只能衰减，不能提高硬件或数字总输出；DSD 不使用数字兜底。
- generation、device ID、connection 和 target 四重检查阻止旧异步失败污染新会话。
- 所有脏文件均要求 `git add -p` 和 cached diff 复核，没有 reset、clean、整文件覆盖或强推。
- 真机阶段明确禁止自动播放和音量命令，并设置安全音量确认门禁。
- 文档中不存在待补内容标记、占位文件名或未定义的测试期望。
