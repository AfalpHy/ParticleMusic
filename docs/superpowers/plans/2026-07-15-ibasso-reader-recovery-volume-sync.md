# iBasso HID Reader Recovery Volume Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将厂商音量协议直接通用化为 `ibassoHid`，由精确设备 quirk 管理适配范围，并让 PCM 音量事务在 HID reader 有界重启期间保留最后可信 DAC 音量等待恢复。

**Architecture:** 先把型号化协议对象、协议 ID、引擎函数和状态测试直接迁移为通用 iBasso HID 命名，不保留旧 ID；设备是否适配只由精确 VID/PID quirk 决定。随后在现有 `IbassoReaderHealth` 与 `IbassoVolumeVerificationAction` 旁增加纯状态决策，复用单线程音量执行器、唯一待处理目标和 reader 既有 250ms 重启期限；恢复后沿用寄存器验证，超时或未知值仍安全冻结，DSD 路径不变。

**Tech Stack:** Android Kotlin、USB Host API、JUnit 4、Flutter 3.44.5、ADB。

---

## 文件边界

- 修改 `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`：定义唯一的 `IbassoHidVolumeProtocol` / `ibassoHid`，并承载可单测的 reader 恢复决策。
- 修改 `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`：使用通用 iBasso HID 命名，复用现有 reader 健康状态、会话 generation 和单线程音量执行器完成有界等待与取消。
- 修改 `android/app/src/main/assets/usb_dac_quirks.json`：已适配设备的精确 VID/PID 条目改用 `ibassoHid`，不新增厂商通配协议。
- 修改 `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`：覆盖协议硬迁移、等待、恢复、超时、只写、DSD 和会话取消状态。
- 修改 `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDacQuirksTest.kt`：覆盖多个精确设备共享通用协议，以及未知设备不误启用。
- 修改 `test/usb_audio_service_test.dart`：状态与事件 fixture 只接受新的 `ibassoHid` 协议 ID。
- 不修改 Dart 音量目标、滑条、按键步进、系统音量条、自绘浮层、iBasso 报文和寄存器映射。

## Task 1：修改前检查与用户修改保护

**Files:**
- Inspect only: repository status and remotes
- Preserve: all existing unstaged files

- [ ] **Step 1: 确认分支、工作区和远程**

```powershell
git status --short
git branch --show-current
git remote -v
git fetch origin
git fetch fork
git rev-list --left-right --count fork/usb-exclusive-volume-overlay-performance...HEAD
```

预期：当前分支为 `usb-exclusive-volume-overlay-performance`，fork 与 HEAD 为 `0 0`。记录所有既有未提交文件；不得执行 reset、clean、merge、rebase 或切换分支。

- [ ] **Step 2: 确认本轮允许修改的六个文件差异**

```powershell
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff -- android/app/src/main/assets/usb_dac_quirks.json
git diff -- android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git diff -- android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDacQuirksTest.kt
git diff -- test/usb_audio_service_test.dart
```

预期：`UsbExclusiveAudioEngine.kt` 仍包含用户未提交的 `initialState` 中 `playbackId` 排序修改；后续只暂存本计划新增的协议重命名和 reader 恢复 hunk。其余五个文件若出现未知修改，停止并先区分归属。

---

## Task 2：以 TDD 将协议身份直接迁移为通用 iBasso HID

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt:336-400`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt:1201,1673-1912,2363-2397`
- Modify: `android/app/src/main/assets/usb_dac_quirks.json:1-18`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt:14,140-200,341,877-879`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDacQuirksTest.kt`
- Test: `test/usb_audio_service_test.dart:461-829`

- [ ] **Step 1: 写通用协议身份和精确设备管理的失败测试**

把 `UsbVolumeProtocolTest` 的协议 fixture 与选择测试改为：

```kotlin
private val protocol = IbassoHidVolumeProtocol

@Test
fun selectsOnlyTheGenericIbassoHidProtocolId() {
    assertEquals("ibassoHid", protocol.id)
    assertSame(IbassoHidVolumeProtocol, usbVolumeProtocolFor("ibassoHid"))
    assertNull(usbVolumeProtocolFor("ibassoDc03Pro"))
    assertEquals(
        VendorUsbVolumeProtocol(IbassoHidVolumeProtocol),
        usbVolumeProtocolSelection("ibassoHid"),
    )
    assertEquals(
        UnsupportedUsbVolumeProtocol("ibassoDc03Pro"),
        usbVolumeProtocolSelection("ibassoDc03Pro"),
    )
    assertEquals(StandardUsbVolumeProtocol, usbVolumeProtocolSelection(null))
    assertEquals(StandardUsbVolumeProtocol, usbVolumeProtocolSelection("uac1"))
    assertEquals(StandardUsbVolumeProtocol, usbVolumeProtocolSelection("uac2"))
    assertEquals(
        UnsupportedUsbVolumeProtocol("unknownProtocol"),
        usbVolumeProtocolSelection("unknownProtocol"),
    )
}
```

同时把该测试文件其余 `IbassoDc03ProVolumeProtocol` 和 `ibassoDc03Pro` 期望改为 `IbassoHidVolumeProtocol` 与 `ibassoHid`。

在 `UsbDacQuirksTest` 中加入：

```kotlin
@Test
fun enablesIbassoHidOnlyForExplicitDeviceEntries() {
    val entries = UsbDacQuirks.parseEntries(
        """
            {
              "version": 2,
              "vendors": [
                {
                  "match": { "vid": "0x262a", "label": "iBasso" },
                  "devices": [
                    {
                      "match": { "pid": "0x1001", "label": "adapted-a" },
                      "hardwareVolume": { "protocol": "ibassoHid" }
                    },
                    {
                      "match": { "pid": "0x1002", "label": "adapted-b" },
                      "hardwareVolume": { "protocol": "ibassoHid" }
                    },
                    {
                      "match": { "pid": "*" }
                    }
                  ]
                }
              ]
            }
        """.trimIndent(),
    )

    assertEquals(
        "ibassoHid",
        UsbDacQuirks.matchQuirk(entries, 0x262a, 0x1001)?.hardwareVolumeProtocol,
    )
    assertEquals(
        "ibassoHid",
        UsbDacQuirks.matchQuirk(entries, 0x262a, 0x1002)?.hardwareVolumeProtocol,
    )
    assertNull(UsbDacQuirks.matchQuirk(entries, 0x262a, 0x9999)?.hardwareVolumeProtocol)
    assertNull(UsbDacQuirks.matchQuirk(entries, 0x1234, 0x9999))
}
```

- [ ] **Step 2: 运行测试并确认按预期失败**

```powershell
Set-Location android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest" --tests "com.afalphy.sylvakru.UsbDacQuirksTest"
Set-Location ..
```

预期：编译失败，错误包含 `Unresolved reference 'IbassoHidVolumeProtocol'`。如果直接通过，说明测试未验证协议身份硬迁移，必须修正后继续。

- [ ] **Step 3: 直接替换协议对象和唯一协议 ID**

在 `UsbVolumeProtocol.kt` 中将协议声明和选择器改为：

```kotlin
internal object IbassoHidVolumeProtocol : UsbVolumeProtocol {
    override val id = "ibassoHid"
```

协议对象的 `capabilities`、音量映射和事件解码函数体保持现有实现不变。选择器必须是：

```kotlin
internal fun usbVolumeProtocolFor(id: String?): UsbVolumeProtocol? =
    when (id?.trim()) {
        "ibassoHid" -> IbassoHidVolumeProtocol
        else -> null
    }

internal fun usbVolumeProtocolSelection(id: String?): UsbVolumeProtocolSelection {
    val normalized = id?.trim()?.takeIf { it.isNotEmpty() }
    return when (normalized) {
        null, "uac1", "uac2" -> StandardUsbVolumeProtocol
        "ibassoHid" -> VendorUsbVolumeProtocol(IbassoHidVolumeProtocol)
        else -> UnsupportedUsbVolumeProtocol(normalized)
    }
}
```

不得加入 `ibassoDc03Pro` 分支、别名常量或迁移逻辑。

- [ ] **Step 4: 通用化引擎命名并迁移精确设备配置和 Dart fixture**

在 `UsbExclusiveAudioEngine.kt` 中执行以下精确替换：

```text
IbassoDc03ProVolumeProtocol -> IbassoHidVolumeProtocol
writeIbassoDc03ProVolume -> writeIbassoHidVolume
protocol=ibassoDc03Pro -> protocol=ibassoHid
```

把 `usb_dac_quirks.json` 中已适配设备的协议字段改为：

```json
"hardwareVolume": {
  "enabled": true,
  "protocol": "ibassoHid",
  "dsdSupported": true
}
```

保留现有精确 VID/PID 与设备标签，不新增 `pid: "*"` 的 `hardwareVolume.protocol`。把 `test/usb_audio_service_test.dart` 中所有状态和事件 fixture 的 `ibassoDc03Pro` 改为 `ibassoHid`。

- [ ] **Step 5: 确认生产代码和测试不再引用旧协议身份**

```powershell
$catalog = Get-Content -Raw -Encoding UTF8 `
  'android/app/src/main/assets/usb_dac_quirks.json' | ConvertFrom-Json
$devices = @($catalog.vendors | ForEach-Object { $_.devices })
$adapted = @($devices | Where-Object { $_.match.pid -ne '*' -and $_.hardwareVolume.enabled })
$wildcardProtocols = @(
  $devices | Where-Object { $_.match.pid -eq '*' -and $_.hardwareVolume.protocol }
)
if ($adapted.Count -eq 0 -or @($adapted | Where-Object {
    $_.hardwareVolume.protocol -ne 'ibassoHid'
  }).Count -ne 0) {
  throw 'Every explicitly adapted iBasso HID device must use ibassoHid.'
}
if ($wildcardProtocols.Count -ne 0) {
  throw 'Vendor wildcard entries must not enable iBasso HID writes.'
}

rg -n 'IbassoDc03ProVolumeProtocol|writeIbassoDc03ProVolume' `
  android/app/src/main android/app/src/test test
rg -n 'ibassoDc03Pro' android/app/src/main test
$legacyRejectionCount = @(
  rg -o 'ibassoDc03Pro' `
    android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
).Count
if ($legacyRejectionCount -ne 3) {
  throw 'The removed protocol ID may appear only in its three rejection assertions.'
}
```

预期：PowerShell 断言不抛错，前两条 `rg` 无输出，旧协议 ID 只在 Kotlin 测试的三处拒绝断言中出现。设备 quirk 的识别标签可以保留具体设备名称，但协议对象、函数名、生产状态和配置中不得残留旧型号化身份。

- [ ] **Step 6: 运行 Android 与 Dart 定向测试**

```powershell
Set-Location android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest" --tests "com.afalphy.sylvakru.UsbDacQuirksTest"
Set-Location ..
& 'F:\software\flutter_3.44.5\bin\flutter.bat' test test/usb_audio_service_test.dart
```

预期：Android 显示 `BUILD SUCCESSFUL`，Flutter 测试全部通过。

- [ ] **Step 7: 检查、暂存、提交并推送协议迁移**

```powershell
git diff --check
git diff --stat
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff -- android/app/src/main/assets/usb_dac_quirks.json
git diff -- android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git diff -- android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDacQuirksTest.kt
git diff -- test/usb_audio_service_test.dart
git add -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt
git add -- android/app/src/main/assets/usb_dac_quirks.json
git add -- android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git add -- android/app/src/test/kotlin/com/afalphy/sylvakru/UsbDacQuirksTest.kt
git add -- test/usb_audio_service_test.dart
git add -p -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff --cached --check
git diff --cached --stat
git diff --cached
git commit -m "refactor(usb): 通用化 iBasso HID 音量协议"
git status --short
git log -1 --oneline
git push fork usb-exclusive-volume-overlay-performance
git fetch fork
git rev-list --left-right --count fork/usb-exclusive-volume-overlay-performance...HEAD
```

交互暂存引擎文件时只选择协议对象、函数和日志字符串重命名，拒绝用户已有 `playbackId` 排序 hunk。预期提交只包含六个文件，用户修改仍保留，远端比较为 `0 0`。

---

## Task 3：以 TDD 接入 reader 恢复状态决策和有界等待

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt:44-114`
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt:74-80,832,1034,1153,1201,1673-1889`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt:353-375`

- [ ] **Step 1: 写 reader 恢复状态的失败测试**

在 `UsbVolumeProtocolTest` 的 `verifiesIbassoWriteBeforeChangingHardwareAuthority` 附近加入：

```kotlin
@Test
fun waitsForPcmReaderRestartWithoutVerifyingOrFreezing() {
    assertEquals(
        IbassoReaderRecoveryAction.WAIT,
        ibassoReaderRecoveryAction(
            isDsd = false,
            health = IbassoReaderHealth(restartRequested = true),
            readerRunning = false,
            generationMatches = true,
            waitExpired = false,
        ),
    )
}

@Test
fun verifiesPcmAsSoonAsTheRestartedReaderIsReady() {
    assertEquals(
        IbassoReaderRecoveryAction.VERIFY_NOW,
        ibassoReaderRecoveryAction(
            isDsd = false,
            health = IbassoReaderHealth().afterFailure().afterRestart(),
            readerRunning = true,
            generationMatches = true,
            waitExpired = false,
        ),
    )
}

@Test
fun freezesPcmWhenReaderRecoveryExpiresOrBecomesWriteOnly() {
    assertEquals(
        IbassoReaderRecoveryAction.FREEZE_PCM,
        ibassoReaderRecoveryAction(
            isDsd = false,
            health = IbassoReaderHealth(restartRequested = true),
            readerRunning = false,
            generationMatches = true,
            waitExpired = true,
        ),
    )
    assertEquals(
        IbassoReaderRecoveryAction.FREEZE_PCM,
        ibassoReaderRecoveryAction(
            isDsd = false,
            health = IbassoReaderHealth(writeOnly = true),
            readerRunning = false,
            generationMatches = true,
            waitExpired = false,
        ),
    )
}

@Test
fun keepsDsdVerificationImmediateAndCancelsStaleSessions() {
    assertEquals(
        IbassoReaderRecoveryAction.VERIFY_NOW,
        ibassoReaderRecoveryAction(
            isDsd = true,
            health = IbassoReaderHealth(restartRequested = true),
            readerRunning = false,
            generationMatches = true,
            waitExpired = false,
        ),
    )
    assertEquals(
        IbassoReaderRecoveryAction.CANCEL,
        ibassoReaderRecoveryAction(
            isDsd = false,
            health = IbassoReaderHealth(restartRequested = true),
            readerRunning = false,
            generationMatches = false,
            waitExpired = false,
        ),
    )
}
```

- [ ] **Step 2: 运行测试并确认按预期失败**

```powershell
Set-Location android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
Set-Location ..
```

预期：编译失败，错误包含 `Unresolved reference 'IbassoReaderRecoveryAction'` 或 `Unresolved reference 'ibassoReaderRecoveryAction'`。如果测试直接通过，说明没有验证新增行为，必须修正测试后再继续。

- [ ] **Step 3: 在协议文件加入最小纯状态决策**

在 `IbassoVolumeVerificationAction` 后加入：

```kotlin
internal enum class IbassoReaderRecoveryAction {
    VERIFY_NOW,
    WAIT,
    FREEZE_PCM,
    CANCEL,
}

internal fun ibassoReaderRecoveryAction(
    isDsd: Boolean,
    health: IbassoReaderHealth,
    readerRunning: Boolean,
    generationMatches: Boolean,
    waitExpired: Boolean,
): IbassoReaderRecoveryAction = when {
    !generationMatches -> IbassoReaderRecoveryAction.CANCEL
    isDsd -> IbassoReaderRecoveryAction.VERIFY_NOW
    health.writeOnly -> IbassoReaderRecoveryAction.FREEZE_PCM
    readerRunning && !health.restartRequested -> IbassoReaderRecoveryAction.VERIFY_NOW
    waitExpired -> IbassoReaderRecoveryAction.FREEZE_PCM
    else -> IbassoReaderRecoveryAction.WAIT
}
```

保持 `ibassoVolumeVerificationAction` 不变：它仍只负责 reader 可用后的目标值、旧可信值、重试、PCM 冻结和 DSD 暂停判断。

- [ ] **Step 4: 运行状态决策测试并确认通过**

```powershell
Set-Location android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
Set-Location ..
```

预期：`UsbVolumeProtocolTest` 全部通过。

- [ ] **Step 5: 为引擎定义与既有重启窗口一致的等待上限**

在 reader 重启常量后加入：

```kotlin
private const val IBASSO_READER_RECOVERY_WAIT_MS =
    IBASSO_READER_RESTART_INITIAL_DELAY_MS +
        IBASSO_READER_RESTART_RETRY_DELAY_MS * (IBASSO_READER_RESTART_EXIT_CHECKS - 1)
```

该值必须由现有 `50ms + 8 × 25ms = 250ms` 重启窗口推导，不新增可独立漂移的魔法超时。

- [ ] **Step 6: 把请求 generation 传入硬件音量调用链**

将两个 `applyVolumeControl` 调用和函数签名改为：

```kotlin
applyVolumeControl(
    device,
    target,
    dsdReader != null,
    quirk,
    volumeSessionGeneration.get(),
)
```

```kotlin
applyVolumeControl(
    device,
    target,
    sessionDsdKind != null,
    UsbDacQuirks.forDevice(context, device.vendorId, device.productId),
    request.sessionGeneration,
)
```

```kotlin
private fun applyVolumeControl(
    device: UsbDevice,
    target: OutputTarget,
    isDsd: Boolean,
    quirk: DacQuirk,
    requestSessionGeneration: Long,
) {
```

调用 `writeIbassoHidVolume` 时追加 `requestSessionGeneration`，并在该函数签名中接收同名参数。不得在写入结束后重新读取当前 generation 充当请求 generation，否则切歌期间会把旧请求误认为新请求。

- [ ] **Step 7: 在引擎加入非主线程的有界条件等待**

在 `writeIbassoHidVolume` 前加入：

```kotlin
private fun awaitIbassoReaderForVolumeVerification(
    isDsd: Boolean,
    requestSessionGeneration: Long,
): IbassoReaderRecoveryAction {
    val deadlineMs = SystemClock.elapsedRealtime() + IBASSO_READER_RECOVERY_WAIT_MS
    while (true) {
        val health = synchronized(ibassoReaderHealthLock) { ibassoReaderHealth }
        val action = ibassoReaderRecoveryAction(
            isDsd = isDsd,
            health = health,
            readerRunning = ibassoReaderRunning.get(),
            generationMatches = requestSessionGeneration == volumeSessionGeneration.get(),
            waitExpired = SystemClock.elapsedRealtime() >= deadlineMs,
        )
        if (action != IbassoReaderRecoveryAction.WAIT) {
            return action
        }
        SystemClock.sleep(IBASSO_READER_RESTART_RETRY_DELAY_MS)
    }
}
```

该函数只能从 `volumeCommandExecutor` 当前事务调用；不得从主线程调用，也不得新增线程、锁或第二套 reader 计时器。

- [ ] **Step 8: 在每次寄存器回读前处理 reader 恢复状态**

给验证循环加标签，并在增加 `ibassoVerificationFailureCount` 之前插入：

```kotlin
verificationLoop@ do {
    when (
        awaitIbassoReaderForVolumeVerification(
            isDsd = isDsd,
            requestSessionGeneration = requestSessionGeneration,
        )
    ) {
        IbassoReaderRecoveryAction.VERIFY_NOW -> Unit
        IbassoReaderRecoveryAction.WAIT ->
            error("WAIT must be resolved by the bounded reader recovery loop.")
        IbassoReaderRecoveryAction.FREEZE_PCM -> {
            verificationAction = IbassoVolumeVerificationAction.FREEZE_PCM
            break@verificationLoop
        }
        IbassoReaderRecoveryAction.CANCEL ->
            throw java.util.concurrent.CancellationException(
                "USB volume verification cancelled because the session changed.",
            )
    }

    ibassoVerificationFailureCount += 1
    readBack = readIbassoCurrentBaseRaw(
        controlConnection,
        failReaderOnTimeout = ibassoVerificationFailureCount >= 3,
    )
    verificationAction = ibassoVolumeVerificationAction(
        targetRaw = appliedTarget.baseRaw,
        previousRaw = previousAppliedTarget?.baseRaw,
        readbackRaw = readBack,
        failureCount = ibassoVerificationFailureCount,
        isDsd = isDsd,
    )
    if (verificationAction == IbassoVolumeVerificationAction.RETRY_READBACK) {
        SystemClock.sleep(50)
    }
} while (verificationAction == IbassoVolumeVerificationAction.RETRY_READBACK)
```

结果语义保持不变：恢复后读到本次目标走 `ACCEPT_TARGET`；读到旧可信目标走 `KEEP_PREVIOUS` 并让合并器随后执行唯一最新目标；第三个值或恢复失败走 `FREEZE_PCM`。DSD 的状态决策始终返回 `VERIFY_NOW`，继续使用原有三次验证和 `PAUSE_DSD`。

- [ ] **Step 9: 运行定向与完整 Android 测试**

```powershell
Set-Location android
.\gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
.\gradlew.bat app:testDebugUnitTest
Set-Location ..
```

预期：两条命令均 `BUILD SUCCESSFUL`。若任何现有 DSD、reader health、目标合并或 150ms 间隔测试失败，停止并修正本任务，不进入提交。

- [ ] **Step 10: 检查差异并只暂存本任务 hunk**

```powershell
git diff --check
git diff --stat
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt
git diff -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff -- android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git add -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt
git add -- android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt
git add -p -- android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt
git diff --cached --check
git diff --cached --stat
git diff --cached
```

交互暂存 `UsbExclusiveAudioEngine.kt` 时，只选择 reader 恢复、generation 参数和验证循环 hunk；拒绝用户已有 `playbackId` 排序 hunk。缓存差异必须只有上述三个文件。

- [ ] **Step 11: 创建独立提交并推送**

```powershell
git commit -m "fix(usb): 等待 iBasso reader 恢复后验证音量"
git status --short
git log -1 --oneline
$env:GIT_TERMINAL_PROMPT='0'
git -c http.lowSpeedLimit=1 -c http.lowSpeedTime=30 push fork usb-exclusive-volume-overlay-performance
git fetch fork
git rev-list --left-right --count fork/usb-exclusive-volume-overlay-performance...HEAD
```

预期：提交只包含三个实现文件；用户未提交修改仍显示在工作区；远端比较为 `0 0`。

---

## Task 4：自动回归、静态检查与 arm64 构建

**Files:**
- Verify: Kotlin and Flutter tests
- Build: `build/app/outputs/flutter-apk/app-profile.apk`

- [ ] **Step 1: 运行相关 Flutter 回归测试**

```powershell
& 'F:\software\flutter_3.44.5\bin\flutter.bat' test `
  test/android_remote_volume_test.dart `
  test/usb_volume_safety_test.dart `
  test/usb_audio_service_test.dart
```

预期：全部测试通过。虽然本任务不修改 Dart，这些测试用于确认手机按键、绝对目标和原生通道行为没有回归。

- [ ] **Step 2: 运行 Flutter analyze**

```powershell
& 'F:\software\flutter_3.44.5\bin\flutter.bat' analyze
```

预期：`No issues found!`。

- [ ] **Step 3: 构建 arm64 Profile APK**

```powershell
& 'F:\software\flutter_3.44.5\bin\flutter.bat' build apk --profile --target-platform android-arm64
Get-Item -LiteralPath 'build\app\outputs\flutter-apk\app-profile.apk' |
  Select-Object FullName,Length,LastWriteTime
```

预期：构建成功，输出 `app-profile.apk`。不得在 Gradle 中加入 ABI 过滤，也不得构建其它架构。

- [ ] **Step 4: 构建后重新检查工作区**

```powershell
git status --short
git diff --check
git rev-list --left-right --count fork/usb-exclusive-volume-overlay-performance...HEAD
```

预期：没有新增应提交的 generated 文件；既有用户修改保持不变；远端为 `0 0`。

---

## Task 5：真机安全验收

**Files:**
- Install only: `build/app/outputs/flutter-apk/app-profile.apk`
- No repository changes

- [ ] **Step 1: 等待用户确认安全音量和设备连接**

在用户明确表示 DAC 音量已降到安全范围且设备已连接前停止。不得自动播放，不得发送 `KEYCODE_VOLUME_UP`、`KEYCODE_VOLUME_DOWN`、`media volume` 或任何 DAC 音量写入命令。

- [ ] **Step 2: 安装但不自动播放**

```powershell
adb devices -l
adb -s 10.67.118.174:5555 get-state
adb -s 10.67.118.174:5555 install -r 'build\app\outputs\flutter-apk\app-profile.apk'
```

预期：设备状态为 `device`，安装结果为 `Success`。不通过 ADB 启动播放；由用户手动打开应用和选择安全测试曲目。

- [ ] **Step 3: 清空并监听必要日志**

```powershell
adb -s 10.67.118.174:5555 logcat -c
adb -s 10.67.118.174:5555 logcat -v threadtime |
  Select-String -Pattern 'UsbExclusiveAudioEngine.*(volume|iBasso|HID|reader|frozen|freeze|transaction|command|ACK)|VolumePanelViewController.*(showH|showDialog|mVolumeView.isShown: true|onShow)'
```

保持监听，由用户手动完成：单次降低、连续降低、降低后增加、连续增加、音量条拖动。每轮先降低再增加，且增加只在用户确认当前音量安全后进行。

- [ ] **Step 4: 验收 reader 恢复行为**

发生 ACK 超时或 `scheduling one reader-thread restart` 时，日志必须满足：

- 250ms 有界窗口内没有把 reader 不可用重复计为三次寄存器失败。
- reader 恢复后读到旧可信值时记录保留旧目标，随后只执行最新合并目标。
- reader 恢复后读到本次目标时接受目标，不重复写同值。
- 相邻 iBasso 事务仍保持约 150ms 间隔。
- 没有 `register=0`、PCM 数字 unity 裸露、系统音量条实际显示或突然增大。
- reader 确实无法恢复、进入只写或读到未知值时仍会冻结。

如果未自然出现 reader 重启，不通过未知 USB 命令或破坏性操作强制制造故障；继续有限次数手动操作后如实记录“恢复分支未触发”。

- [ ] **Step 5: 停止监听并记录用户主观结果**

停止本轮 `adb logcat` 进程，确认没有遗留监听。询问用户是否出现系统音量条、突然增大、卡顿或冻结；日志结果与用户听感必须同时记录。

若再次在 reader 正在恢复时冻结，停止实施并回到系统化诊断，不叠加第二个猜测性修复。若验收通过，更新执行计划状态并汇报提交、推送、测试、构建和真机结果。
