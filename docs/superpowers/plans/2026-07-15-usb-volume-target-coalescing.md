# USB 绝对音量目标合并实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将手机音量键、应用音量条和 ReplayGain 统一为绝对音量目标，在 Android 原生层按“最新目标 + 降低锁存”规则合并请求，并为 iBasso 硬件事务保留 150ms 稳定间隔，避免密集写入导致读线程失效和音量同步失败。

**Architecture:** Dart 层不再维护按键方向队列，每次物理按键都基于当前 `volumeNotifier` 计算一个 2% 的绝对目标并立即下发。Android 原生层继续使用单线程执行器，但同时记录运行中目标和唯一待处理目标；纯函数根据总有效输出增益决定待处理目标是否可被覆盖。iBasso 每个事务完成后在同一执行器中等待 150ms，使等待期间的新请求只参与合并，不并发访问 USB；其它协议和数字音量不增加延迟。

**Tech Stack:** Flutter/Dart、Android/Kotlin、JUnit 4、Flutter Test、ADB。

---

## 执行边界

- 只修改 USB 硬件音量协调相关代码和测试，不修改播放器视觉、歌词页、`BackdropFilter`、`CoverArtWidget` 或其它非 USB 逻辑。
- 始终保留基线中用户未提交的修改，不得整体暂存这些文件：
  - `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt` 中 `initialState` 的 `playbackId` 排序改动。
  - `docs/superpowers/specs/2026-07-11-usb-cloud-exclusive-recovery-design.md` 中 Flutter 版本改动。
  - `lib/base/audio_handler.dart` 中三处既有格式化改动。
  - `lib/base/widgets/audio_output_panel.dart` 中七处既有格式化改动。
  - Linux、macOS、Windows 的 generated plugin registrant 行尾状态。
- 对同时含用户改动的文件使用 `git add -p`，逐块确认仅暂存本计划产生的代码。
- 不执行自动播放，不发送任何音量增加 ADB 命令；每次安装新 APK 或开始真机操作前，先停下并等待用户确认设备音量已处于安全范围。
- 每个任务验证通过后独立提交并推送到 `fork/usb-exclusive-volume-overlay-performance`。

## Task 1：用纯函数固定原生目标合并规则

**Files:**

- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`

- [ ] **Step 1：将旧“始终保留最新请求”测试替换为目标合并行为测试**

在 `UsbVolumeProtocolTest.kt` 中删除 `keepsOnlyLatestPendingUsbVolumeRequest`，加入以下测试。测试分别覆盖普通最新值、降低锁存、更低值覆盖、代际/模式切换，以及 DSD 补偿参与总有效输出比较：

```kotlin
@Test
fun keepsLatestPendingTargetWhenPendingDoesNotLowerOutput() {
    val running = UsbVolumeRequest(1000, 0, "dac", 0, true, 7)
    val pending = UsbVolumeRequest(2000, 0, "dac", 0, true, 7)
    val incoming = UsbVolumeRequest(3000, 0, "dac", 0, true, 7)

    assertEquals(
        incoming,
        coalescedUsbVolumeRequest(running, pending, incoming, isDsd = false),
    )
}

@Test
fun latchesPendingOutputReductionAgainstLaterIncrease() {
    val running = UsbVolumeRequest(3000, 0, "dac", 0, true, 7)
    val pending = UsbVolumeRequest(2000, 0, "dac", 0, true, 7)
    val incoming = UsbVolumeRequest(2500, 0, "dac", 0, true, 7)

    assertEquals(
        pending,
        coalescedUsbVolumeRequest(running, pending, incoming, isDsd = false),
    )
}

@Test
fun replacesLatchedReductionWithAnEvenLowerTarget() {
    val running = UsbVolumeRequest(3000, 0, "dac", 0, true, 7)
    val pending = UsbVolumeRequest(2000, 0, "dac", 0, true, 7)
    val incoming = UsbVolumeRequest(1000, 0, "dac", 0, true, 7)

    assertEquals(
        incoming,
        coalescedUsbVolumeRequest(running, pending, incoming, isDsd = false),
    )
}

@Test
fun acceptsAnIncreaseAfterTheLowerTargetBecomesRunning() {
    val loweredRunning = UsbVolumeRequest(2000, 0, "dac", 0, true, 7)
    val incoming = UsbVolumeRequest(2500, 0, "dac", 0, true, 7)

    assertEquals(
        incoming,
        coalescedUsbVolumeRequest(loweredRunning, null, incoming, isDsd = false),
    )
}

@Test
fun acceptsLatestTargetAcrossSessionOrModeChanges() {
    val running = UsbVolumeRequest(3000, 0, "dac", 0, true, 7)
    val pending = UsbVolumeRequest(2000, 0, "dac", 0, true, 7)
    val nextSession = UsbVolumeRequest(2500, 0, "dac", 0, true, 8)
    val digital = UsbVolumeRequest(2500, 0, "digital", 0, true, 7)

    assertEquals(
        nextSession,
        coalescedUsbVolumeRequest(running, pending, nextSession, isDsd = false),
    )
    assertEquals(
        digital,
        coalescedUsbVolumeRequest(running, pending, digital, isDsd = false),
    )
}

@Test
fun comparesTotalEffectiveDsdOutputWhenCoalescingTargets() {
    val running = UsbVolumeRequest(32768, 0, "dac", 0, true, 7)
    val pending = UsbVolumeRequest(32768, -1000, "dac", 0, true, 7)
    val incoming = UsbVolumeRequest(32768, -500, "dac", 6, true, 7)

    assertEquals(
        pending,
        coalescedUsbVolumeRequest(running, pending, incoming, isDsd = true),
    )
}
```

- [ ] **Step 2：运行定向测试并确认 RED**

在仓库根目录执行：

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
cd ..
```

预期：编译失败，提示 `coalescedUsbVolumeRequest` 尚未定义。失败原因必须只来自新 API，不能忽略其它失败。

- [ ] **Step 3：实现总有效输出比较和降低锁存**

在 `UsbVolumeProtocol.kt` 中用以下函数替换 `latestUsbVolumeRequest`：

```kotlin
internal fun coalescedUsbVolumeRequest(
    running: UsbVolumeRequest,
    pending: UsbVolumeRequest?,
    incoming: UsbVolumeRequest,
    isDsd: Boolean,
): UsbVolumeRequest {
    if (pending == null) return incoming
    if (
        running.sessionGeneration != pending.sessionGeneration ||
        pending.sessionGeneration != incoming.sessionGeneration ||
        running.mode != pending.mode ||
        pending.mode != incoming.mode
    ) {
        return incoming
    }
    val runningGain = effectiveHardwareVolumeGainQ16(
        running.gainQ16,
        running.replayGainMilliDb,
        running.dsdCompensationDb,
        isDsd,
    )
    val pendingGain = effectiveHardwareVolumeGainQ16(
        pending.gainQ16,
        pending.replayGainMilliDb,
        pending.dsdCompensationDb,
        isDsd,
    )
    if (pendingGain >= runningGain) return incoming
    val incomingGain = effectiveHardwareVolumeGainQ16(
        incoming.gainQ16,
        incoming.replayGainMilliDb,
        incoming.dsdCompensationDb,
        isDsd,
    )
    return if (incomingGain < pendingGain) incoming else pending
}
```

这里比较的是用户音量、ReplayGain 和 DSD 补偿共同形成的总有效输出，不以单一字段判断增减。

- [ ] **Step 4：运行定向测试并确认 GREEN**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
cd ..
```

预期：`BUILD SUCCESSFUL`。

- [ ] **Step 5：检查、提交并推送 Task 1**

```powershell
git diff --check
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git diff --cached --check
git commit -m "fix(usb): 合并硬件音量绝对目标"
git push fork usb-exclusive-volume-overlay-performance
```

确认提交中没有其它文件。

## Task 2：把合并器接入单线程事务并增加 iBasso 稳定间隔

**Files:**

- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`

- [ ] **Step 1：先加入协议稳定间隔选择测试**

在 `UsbVolumeProtocolTest.kt` 中加入：

```kotlin
@Test
fun calculatesRemainingIbassoTransactionSettleDelay() {
    val protocol = IbassoDc03ProVolumeProtocol.id

    assertEquals(0L, usbVolumeTransactionSettleDelayMs(protocol, null, 1000L))
    assertEquals(100L, usbVolumeTransactionSettleDelayMs(protocol, 1000L, 1050L))
    assertEquals(0L, usbVolumeTransactionSettleDelayMs(protocol, 1000L, 1150L))
    assertEquals(
        0L,
        usbVolumeTransactionSettleDelayMs("standardUsbAudioClass", 1000L, 1050L),
    )
    assertEquals(0L, usbVolumeTransactionSettleDelayMs(null, 1000L, 1050L))
}
```

- [ ] **Step 2：运行定向测试并确认 RED**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
cd ..
```

预期：编译失败，提示 `usbVolumeTransactionSettleDelayMs` 尚未定义。

- [ ] **Step 3：实现协议级稳定间隔选择**

在 `UsbVolumeProtocol.kt` 的请求协调函数附近加入：

```kotlin
private const val IBASSO_VOLUME_TRANSACTION_SETTLE_MS = 150L

internal fun usbVolumeTransactionSettleDelayMs(
    protocol: String?,
    lastCompletedAtMs: Long?,
    nowMs: Long,
): Long {
    if (protocol != IbassoDc03ProVolumeProtocol.id || lastCompletedAtMs == null) return 0L
    val elapsedMs = (nowMs - lastCompletedAtMs).coerceAtLeast(0L)
    return (IBASSO_VOLUME_TRANSACTION_SETTLE_MS - elapsedMs).coerceAtLeast(0L)
}
```

保持函数纯粹，便于 JVM 单元测试；首笔请求没有完成时间，因此返回 0ms。150ms 只对已识别为 iBasso DC03 Pro 协议的相邻事务生效。

- [ ] **Step 4：在引擎中记录运行中目标并合并唯一待处理目标**

在 `UsbExclusiveAudioEngine.kt` 的命令状态字段中加入：

```kotlin
private var runningVolumeRequest: UsbVolumeRequest? = null
```

修改 `setVolume`。创建请求后捕获当前会话是否为 DSD，并在锁内执行合并：

```kotlin
val isDsd = sessionDsdKind != null
val start = synchronized(volumeCommandLock) {
    if (volumeCommandRunning) {
        val running = checkNotNull(runningVolumeRequest)
        pendingVolumeRequest = coalescedUsbVolumeRequest(
            running,
            pendingVolumeRequest,
            request,
            isDsd,
        )
        UsbDiagnostics.i(tag, "USB volume request coalesced into the pending target.")
        false
    } else {
        volumeCommandRunning = true
        runningVolumeRequest = request
        true
    }
}
```

不要改变请求构造、代际失效或现有 ACK/readback/freeze 逻辑。

- [ ] **Step 5：事务完成后在同一执行器中等待，再原子读取合并后的目标**

将 `drainVolumeRequests` 改为以下循环结构：

```kotlin
private fun drainVolumeRequests(first: UsbVolumeRequest) {
    var request: UsbVolumeRequest? = first
    var lastCompletedAtMs: Long? = null
    var lastCompletedProtocol: String? = null
    while (true) {
        val settleDelayMs = usbVolumeTransactionSettleDelayMs(
            lastCompletedProtocol,
            lastCompletedAtMs,
            SystemClock.elapsedRealtime(),
        )
        if (settleDelayMs > 0) {
            SystemClock.sleep(settleDelayMs)
        }
        if (lastCompletedAtMs != null) {
            val next = synchronized(volumeCommandLock) {
                pendingVolumeRequest.also {
                    pendingVolumeRequest = null
                    if (it == null) {
                        runningVolumeRequest = null
                        volumeCommandRunning = false
                    } else {
                        runningVolumeRequest = it
                    }
                }
            }
            if (next == null) return
            request = next
        }
        val current = checkNotNull(request)
        UsbDiagnostics.i(
            tag,
            "USB volume transaction started generation=${current.sessionGeneration}.",
        )
        try {
            applyVolumeRequest(current)
        } catch (error: Exception) {
            UsbDiagnostics.w(tag, "USB volume transaction failed: ${error.message}")
        }
        UsbDiagnostics.i(
            tag,
            "USB volume transaction completed generation=${current.sessionGeneration}.",
        )
        lastCompletedProtocol = hardwareVolumeProtocol
        lastCompletedAtMs = SystemClock.elapsedRealtime()
    }
}
```

此等待发生在专用 `usb-volume-command` 线程上：首个事务因没有完成时间而立即执行；iBasso 事务完成后计算剩余间隔，等待结束后才读取 pending。等待期间 `volumeCommandRunning` 保持为 `true`，因此新请求仍可合并到唯一 pending。不要在主线程或 USB reader 线程休眠。

- [ ] **Step 6：运行 Kotlin 格式化检查和完整 Android 单元测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
```

预期：所有 Android 单元测试通过。额外检查日志字符串仍为英文。

- [ ] **Step 7：选择性暂存、审查、提交并推送 Task 2**

先检查用户在引擎文件中的未提交 hunk：

```powershell
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git add -p android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff --cached --check
git diff --cached
```

在 `git add -p` 中拒绝 `initialState` 的 `playbackId` 排序 hunk，只接受本任务字段、`setVolume` 和 drain 修改。确认缓存区无用户改动后：

```powershell
git commit -m "fix(usb): 为 iBasso 音量事务保留稳定间隔"
git push fork usb-exclusive-volume-overlay-performance
```

## Task 3：让手机音量键与滑块统一下发绝对目标

**Files:**

- Modify: `test/android_remote_volume_test.dart`
- Modify: `lib/base/audio_handler.dart`

- [ ] **Step 1：先把测试改为无在途方向队列语义**

在 `test/android_remote_volume_test.dart` 中：

1. 删除 `pendingUsbVolumeKeyDirection` 的整组测试。
2. 将 `usbExclusiveVolumeKeyDirection` 的调用全部移除 `writeInProgress` 参数。
3. 删除“在途时返回 null”的断言。
4. 增加连续绝对目标计算测试：

```dart
test('连续手机音量键基于最新绝对音量计算目标', () {
  var target = 0.5;
  target = adjustedRemoteVolume(
    target,
    audio_service.AndroidVolumeDirection.raise,
  );
  target = adjustedRemoteVolume(
    target,
    audio_service.AndroidVolumeDirection.raise,
  );
  target = adjustedRemoteVolume(
    target,
    audio_service.AndroidVolumeDirection.lower,
  );

  expect(target, closeTo(0.52, 0.000001));
});
```

- [ ] **Step 2：运行定向 Flutter 测试并确认 RED**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart
```

预期：编译失败，因为生产函数仍要求 `writeInProgress` 参数。失败原因必须与新接口一致。

- [ ] **Step 3：删除方向队列并让每次按键立即产生绝对目标**

在 `lib/base/audio_handler.dart` 中删除：

```dart
AndroidVolumeDirection pendingUsbVolumeKeyDirection(...)
bool _phoneVolumeKeyWriteInProgress = false;
AndroidVolumeDirection? _pendingPhoneVolumeDirection;
Future<void> _drainPhoneVolumeKey(...)
```

将方向判断函数改为：

```dart
AndroidVolumeDirection? usbExclusiveVolumeKeyDirection({
  required int delta,
  required bool active,
}) {
  if (delta == 0 || !active) return null;
  return delta > 0
      ? AndroidVolumeDirection.raise
      : AndroidVolumeDirection.lower;
}
```

将 `_handleUsbExclusiveVolumeKey` 改为每次事件都按当前 `volumeNotifier.value` 计算绝对目标，并保留显式的未等待 Future 处理：

```dart
void _handleUsbExclusiveVolumeKey() {
  final value = usbExclusiveVolumeKeyNotifier.value;
  final delta = value - _lastVolumeKeyValue;
  _lastVolumeKeyValue = value;
  final direction = usbExclusiveVolumeKeyDirection(
    delta: delta,
    active: _usbExclusiveActive,
  );
  if (direction == null) return;
  unawaited(_applyPhoneVolumeKey(direction));
}

Future<void> _applyPhoneVolumeKey(AndroidVolumeDirection direction) async {
  try {
    await _setUserVolumeImmediately(
      adjustedRemoteVolume(volumeNotifier.value, direction),
    );
    usbVolumeOverlayNotifier.value += 1;
  } on Object catch (error) {
    logger.output("usb volume key apply failed:$error");
  }
}
```

不修改 `_setUserVolumeImmediately`、滑块路径或 ReplayGain 路径；它们已经下发绝对目标，统一合并发生在原生层。

- [ ] **Step 4：格式化受影响 Dart 文件并运行定向测试**

```powershell
F:\software\flutter_3.44.5\bin\dart.bat format lib/base/audio_handler.dart test/android_remote_volume_test.dart
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart
```

预期：定向测试全部通过。格式化后立即检查 `audio_handler.dart`，确保没有扩大用户既有格式化 hunk。

- [ ] **Step 5：选择性暂存、审查、提交并推送 Task 3**

```powershell
git diff -- lib/base/audio_handler.dart test/android_remote_volume_test.dart
git add test/android_remote_volume_test.dart
git add -p lib/base/audio_handler.dart
git diff --cached --check
git diff --cached
```

在 `git add -p` 中只接受按键辅助函数、字段和处理函数的 hunk；拒绝用户原有三处格式化 hunk。确认后：

```powershell
git commit -m "fix(usb): 音量键直接下发绝对目标"
git push fork usb-exclusive-volume-overlay-performance
```

## Task 4：完整回归、构建和安全真机验收

**Files:**

- Verify only; do not stage build products or logs.

- [ ] **Step 1：确认工作区只剩已登记的用户修改**

```powershell
git status --short
git diff --check
git diff --stat
```

逐项与“执行边界”中的基线清单核对。若出现未登记文件，先定位来源，不得用 `reset`、`clean` 或整体 checkout 处理。

- [ ] **Step 2：运行静态禁用寄存器检查**

```powershell
rg -n "appGainToRaw\(UNITY_GAIN_Q16|writeHardwareVolume.*UNITY_GAIN_Q16|register=0" android/app/src/main/kotlin/com/afalphy/sylvakru
```

人工判断搜索结果；不得出现新增的 iBasso register 0 写入或任何自动增音实现。

- [ ] **Step 3：运行完整自动化验证**

依次执行，避免多个 Flutter/Gradle 进程争用缓存：

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
F:\software\flutter_3.44.5\bin\flutter.bat test
F:\software\flutter_3.44.5\bin\flutter.bat analyze
```

预期：Android 测试 `BUILD SUCCESSFUL`、Flutter 测试全部通过、analyze 为 `No issues found!`。

- [ ] **Step 4：只构建 arm64 Profile APK**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64
```

记录 `build/app/outputs/flutter-apk/app-profile.apk` 的大小。不得把 APK 加入 Git。

- [ ] **Step 5：安全门——停止并等待用户确认**

在安装或开始任何真机动作前明确告诉用户：

```text
新 APK 已构建完成。请先把手机和 DAC 音量降到安全范围，确认后我再安装并监听；我不会自动播放，也不会发送任何音量增加命令。
```

没有用户明确确认时，不得继续安装、启动播放或发送按键事件。

- [ ] **Step 6：用户确认后安装，但不自动播放、不调高音量**

先只读确认设备：

```powershell
adb devices -l
```

然后安装：

```powershell
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

不得执行 `adb shell input keyevent KEYCODE_VOLUME_UP`、媒体播放 keyevent 或任何自动播放命令。

- [ ] **Step 7：监听窄范围日志，由用户手动操作**

清空旧日志后，仅监听应用进程和 USB 音量关键字：

```powershell
adb logcat -c
$appPid = (adb shell pidof com.afalphy.sylvakru).Trim()
adb logcat --pid=$appPid -v threadtime | Select-String "USB volume|iBasso|hardwareVolume|sync|reader|timeout|frozen"
```

让用户按安全顺序手动验证：

1. 单次降低音量。
2. 连续降低音量。
3. 降低后立即增加。
4. 连续增加音量。
5. 手动滑动应用音量条。
6. 触发 ReplayGain 变化（仅在用户确认当前曲目和音量安全时）。

验收日志应满足：

- iBasso 相邻事务之间有约 150ms 稳定间隔。
- 稳定间隔内新请求只出现 coalesced 日志，不出现并发事务。
- 降低目标不会被随后增加覆盖；更低目标可以替换。
- 不再出现 `pending response`、ACK timeout、reader unavailable 或 command 65 timeout。
- `hardwareVolumeFrozen` 不应变为 `true`，UI 不应立即显示音量同步失败。
- 全程没有突然变大；若用户感知异常，立即停止操作并保存当前日志。

- [ ] **Step 8：最终 Git 审查和交付**

```powershell
git status --short
git log -4 --oneline
git rev-list --left-right --count fork/usb-exclusive-volume-overlay-performance...HEAD
```

最终汇报必须包含：修改内容、关键文件、自动化验证结果、APK 构建结果、真机观察、提交号、推送分支、仍保留的用户未提交修改及任何已知限制。
