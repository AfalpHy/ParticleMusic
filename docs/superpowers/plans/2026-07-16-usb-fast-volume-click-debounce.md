# USB 快速连续音量点击防抖 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让单次 USB 音量点击立即执行，快速连续点击只在安静 300ms 后执行最新绝对目标，避免持续 iBasso HID 事务触发 reader 冻结。

**Architecture:** 保留 `UsbExclusiveAudioEngine` 现有单执行线程、一个运行中请求和一个待处理请求。纯逻辑层统一计算 iBasso HID 的 150ms 事务间隔与 300ms 尾部防抖剩余时间；引擎在取出待处理目标前循环重算，并让同一待处理槽始终采用最新绝对目标。

**Tech Stack:** Android Kotlin、Android USB Host HID、JUnit、Flutter 3.44.5、ADB 真机日志。

---

## 交接约束

- 仓库：`F:\Symusic\sylvakru-usb-exclusive-clean`
- 分支：`usb-exclusive-volume-overlay-performance`
- 设计：`docs/superpowers/specs/2026-07-16-usb-fast-volume-click-debounce-design.md`
- 不创建额外 worktree；`F:\Symusic\AGENTS.md` 指定只能使用当前仓库。
- 不修改 Flutter UI、网络播放、ReplayGain 算法、协议 ID、设备 quirk 或非 USB 页面。
- 必须保留工作区中既有的用户未提交修改，尤其是 `UsbExclusiveAudioEngine.kt` 中 `initialState` 的 `playbackId` 排序 hunk。
- 真机阶段不得自动播放，不得发送任何音量命令；安装后只监听，由用户确认安全音量并手动操作。

## 文件结构

- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
  - 保存最新待处理绝对目标语义和防抖剩余时间纯逻辑。
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`
  - 覆盖最终目标、事务间隔、安静窗口和协议边界。
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
  - 记录待处理目标更新时间，并在单事务循环中有条件等待和重新检查。

### Task 1: 用失败测试固定最新目标和组合等待规则

**Files:**
- Modify: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`

- [ ] **Step 1: 将旧的降低优先测试改为最终绝对目标测试**

把 `latchesPendingOutputReductionAgainstLaterIncrease` 改为：

```kotlin
@Test
fun keepsOnlyTheLatestPendingAbsoluteTarget() {
    val running = UsbVolumeRequest(3000, 0, "dac", 0, true, 7)
    val pending = UsbVolumeRequest(2000, 0, "dac", 0, true, 7)
    val incoming = UsbVolumeRequest(2500, 0, "dac", 0, true, 7)

    assertEquals(
        incoming,
        coalescedUsbVolumeRequest(running, pending, incoming, isDsd = false),
    )
}
```

保留 session/mode 变化测试；把 DSD 合并测试的预期值从 `pending` 改为 `incoming`，证明待处理槽不再保存历史降低目标。

- [ ] **Step 2: 添加组合等待时间测试**

用以下测试替换 `calculatesRemainingIbassoTransactionSettleDelay`：

```kotlin
@Test
fun waitsForIbassoSettleAndLatestPendingQuietWindow() {
    val protocol = IbassoHidVolumeProtocol.id

    assertEquals(
        100L,
        usbVolumePendingDelayMs(protocol, 1000L, pendingUpdatedAtMs = null, nowMs = 1050L),
    )
    assertEquals(
        200L,
        usbVolumePendingDelayMs(protocol, 1000L, pendingUpdatedAtMs = 1100L, nowMs = 1200L),
    )
    assertEquals(
        50L,
        usbVolumePendingDelayMs(protocol, 1000L, pendingUpdatedAtMs = 1100L, nowMs = 1350L),
    )
    assertEquals(
        0L,
        usbVolumePendingDelayMs(protocol, 1000L, pendingUpdatedAtMs = 1100L, nowMs = 1400L),
    )
}

@Test
fun skipsPendingDebounceOutsideAnActiveIbassoSequence() {
    assertEquals(0L, usbVolumePendingDelayMs(null, null, 1000L, 1100L))
    assertEquals(
        0L,
        usbVolumePendingDelayMs("standardUsbAudioClass", 1000L, 1050L, 1100L),
    )
}
```

- [ ] **Step 3: 运行测试并确认按预期失败**

Run:

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbVolumeProtocolTest
cd ..
```

Expected: `keepsOnlyTheLatestPendingAbsoluteTarget` 因仍返回旧降低目标而失败，组合等待测试因 `usbVolumePendingDelayMs` 尚不存在而编译失败。必须保存这次 RED 输出后才能修改生产代码。

- [ ] **Step 4: 实现最新目标和组合等待纯逻辑**

将 `coalescedUsbVolumeRequest` 简化为待处理槽永远返回 `incoming`；保留现有签名以避免扩大引擎改动：

```kotlin
internal fun coalescedUsbVolumeRequest(
    running: UsbVolumeRequest,
    pending: UsbVolumeRequest?,
    incoming: UsbVolumeRequest,
    isDsd: Boolean,
): UsbVolumeRequest = incoming
```

将 `usbVolumeTransactionSettleDelayMs` 替换为：

```kotlin
private const val IBASSO_VOLUME_TRANSACTION_SETTLE_MS = 150L
private const val IBASSO_VOLUME_PENDING_QUIET_MS = 300L

internal fun usbVolumePendingDelayMs(
    protocol: String?,
    lastCompletedAtMs: Long?,
    pendingUpdatedAtMs: Long?,
    nowMs: Long,
): Long {
    if (protocol != IbassoHidVolumeProtocol.id || lastCompletedAtMs == null) return 0L
    val settleElapsedMs = (nowMs - lastCompletedAtMs).coerceAtLeast(0L)
    val settleDelayMs =
        (IBASSO_VOLUME_TRANSACTION_SETTLE_MS - settleElapsedMs).coerceAtLeast(0L)
    val quietDelayMs = pendingUpdatedAtMs?.let {
        val quietElapsedMs = (nowMs - it).coerceAtLeast(0L)
        (IBASSO_VOLUME_PENDING_QUIET_MS - quietElapsedMs).coerceAtLeast(0L)
    } ?: 0L
    return maxOf(settleDelayMs, quietDelayMs)
}
```

不得修改 ACK 超时、reader 失败计数或硬件音量映射。

- [ ] **Step 5: 重跑目标测试确认 GREEN**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbVolumeProtocolTest
cd ..
```

Expected: `BUILD SUCCESSFUL`，`UsbVolumeProtocolTest` 全部通过。

- [ ] **Step 6: 提交纯逻辑和测试**

```powershell
git add android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt
git add android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git diff --cached --check
git diff --cached --stat
git commit -m "test(usb): 固定快速音量点击防抖规则"
```

Expected: 提交只包含上述两个文件。

### Task 2: 在单事务协调器中执行尾部防抖

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 添加待处理更新时间状态**

在 `pendingVolumeRequest` 附近添加：

```kotlin
private var pendingVolumeRequestUpdatedAtMs: Long? = null
```

- [ ] **Step 2: 合并请求时记录最新输入时间**

在 `setVolume` 的 `volumeCommandRunning` 分支更新待处理目标后添加：

```kotlin
pendingVolumeRequestUpdatedAtMs = SystemClock.elapsedRealtime()
```

空闲分支仍立即启动首个请求，不设置 300ms 延迟。

- [ ] **Step 3: 在取出待处理请求前循环重算等待时间**

把 `drainVolumeRequests` 中旧的 `usbVolumeTransactionSettleDelayMs` 调用和一次性取值逻辑改为以下结构：

```kotlin
private fun drainVolumeRequests(first: UsbVolumeRequest) {
    var request: UsbVolumeRequest? = first
    var lastCompletedAtMs: Long? = null
    var lastCompletedProtocol: String? = null
    while (true) {
        if (lastCompletedAtMs != null) {
            var next: UsbVolumeRequest? = null
            while (next == null) {
                var delayMs = 0L
                var hasPending = true
                synchronized(volumeCommandLock) {
                    delayMs = usbVolumePendingDelayMs(
                        lastCompletedProtocol,
                        lastCompletedAtMs,
                        pendingVolumeRequestUpdatedAtMs,
                        SystemClock.elapsedRealtime(),
                    )
                    if (delayMs == 0L) {
                        next = pendingVolumeRequest
                        pendingVolumeRequest = null
                        pendingVolumeRequestUpdatedAtMs = null
                        if (next == null) {
                            runningVolumeRequest = null
                            volumeCommandRunning = false
                            hasPending = false
                        } else {
                            runningVolumeRequest = next
                        }
                    }
                }
                if (!hasPending) return
                if (next == null) {
                    SystemClock.sleep(delayMs)
                }
            }
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

注意：即使事务刚完成时还没有待处理目标，也必须先保留 150ms settle 窗口；该窗口内到达的请求会进入待处理槽，不能绕过间隔立即另起线程。

- [ ] **Step 4: 会话失效时同时清除时间戳**

在 `invalidatePendingVolumeRequests` 的锁内改为：

```kotlin
synchronized(volumeCommandLock) {
    pendingVolumeRequest = null
    pendingVolumeRequestUpdatedAtMs = null
}
```

- [ ] **Step 5: 运行 Android 目标测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbVolumeProtocolTest
cd ..
```

Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 6: 运行完整 Android 单元测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest
cd ..
```

Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 7: 仅暂存本任务 hunk 并提交**

`UsbExclusiveAudioEngine.kt` 含有用户的 `playbackId` 排序修改。使用交互式暂存，只选择防抖字段、调度和失效清理 hunk：

```powershell
git add -p android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff --cached --check
git diff --cached --stat
git diff --cached
git commit -m "fix(usb): 防抖快速连续硬件音量点击"
```

Expected: 缓存差异不包含 `initialState` 的 `playbackId` 排序；提交后该用户 hunk 仍显示为未提交修改。

### Task 2.5: 补齐切歌直达路径和失败事务门控

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

- [ ] **Step 1: 用失败测试固定“请求预期协议”规则**

新增纯逻辑测试：`auto`、`dac` 模式保留 quirk 配置的协议；`digital`、`raw` 模式返回空。先运行 `UsbVolumeProtocolTest`，确认因新函数不存在而失败。

- [ ] **Step 2: 让失败事务继续使用预期协议参与尾部防抖**

增加纯函数，根据请求模式和 quirk 协议返回本次可能尝试的硬件协议。协调器在调用 `applyVolumeRequest` 前保存该值，事务结束后不再依赖可能被失败路径清空的 `hardwareVolumeProtocol`。

- [ ] **Step 3: 给所有 iBasso 硬件尝试增加共享 150ms 门控**

在 `volumeLock` 保护下记录最后一次 iBasso 硬件尝试完成时间。`applyVolumeControl` 进入 vendor HID 分支后，先等待剩余 settle 时间，再执行写入和读回，并在 `finally` 中更新时间。这样同步的 `start()` / 热切歌路径、异步音量协调器和失败重试共用同一门控；300ms 静默窗口仍只属于连续待处理输入。

- [ ] **Step 4: 运行目标测试与完整 Android 单元测试**

```powershell
cd android
.\gradlew.bat app:testDebugUnitTest --tests com.afalphy.sylvakru.UsbVolumeProtocolTest
.\gradlew.bat app:testDebugUnitTest
cd ..
```

- [ ] **Step 5: 分块暂存并提交**

继续排除 `UsbExclusiveAudioEngine.kt` 中用户已有的 `playbackId` 排序 hunk，提交信息：

```text
fix(usb): 统一硬件音量事务间隔门控
```

### Task 3: 自动化回归、构建和推送

**Files:**
- Test only; no source changes expected

- [ ] **Step 1: 运行 Flutter USB 回归测试**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart test/usb_volume_safety_test.dart test/usb_audio_service_test.dart
```

Expected: 全部测试通过。

- [ ] **Step 2: 运行静态分析**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat analyze
```

Expected: `No issues found!`。

- [ ] **Step 3: 构建 arm64 Profile APK**

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64
```

Expected: 生成 `build/app/outputs/flutter-apk/app-profile.apk`。

- [ ] **Step 4: 检查工作区和提交边界**

```powershell
git status --short
git diff --check
git log -3 --oneline
git rev-list --left-right --count HEAD...fork/usb-exclusive-volume-overlay-performance
```

Expected: 只剩交接中列出的用户未提交修改；实现提交完整且没有 generated 或构建产物进入提交。

- [ ] **Step 5: 推送当前 USB 分支**

```powershell
git push fork usb-exclusive-volume-overlay-performance
```

Expected: 普通推送成功，禁止 force push。

### Task 4: 真机安全验收

**Files:**
- No source changes

- [ ] **Step 1: 等待用户确认安全音量和设备连接**

不得自动开始播放或发送音量命令。只有用户明确确认音量已经降到安全范围后，才能继续安装。

- [ ] **Step 2: 安装 APK 但不自动启动播放**

```powershell
adb devices -l
adb -s 10.67.118.174:5555 install -r build/app/outputs/flutter-apk/app-profile.apk
```

Expected: `Success`。

- [ ] **Step 3: 清空日志并只读监听**

监听以下关键事件：

```text
USB volume request coalesced into the pending target.
USB volume transaction started
iBasso HID reader failed
iBasso hardware volume synchronization is frozen
VolumePanelViewController
AndroidRuntime
```

由用户手动快速连续点击音量键。预期一个点击序列最多出现首个事务和停止输入 300ms 后的最终事务，不出现 reader 重启、冻结、系统音量面板或突然增大。

- [ ] **Step 4: 完成验收记录**

记录用户对“是否突然变大、是否冻结、最终音量是否与 UI 一致”的反馈。若仍失败，保留日志并返回系统化调试，不得继续叠加猜测性修复。
