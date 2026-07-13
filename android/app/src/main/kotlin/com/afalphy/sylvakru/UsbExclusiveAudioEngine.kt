package com.afalphy.sylvakru

import android.content.Context
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.media.MediaCodec
import android.media.MediaCodecList
import android.media.MediaDataSource
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.SystemClock
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.util.Locale
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.log10
import kotlin.math.roundToInt

object UsbExclusiveNative {
    init {
        System.loadLibrary("sylvakru_usb_exclusive")
    }

    external fun open(
        fd: Int,
        interfaceNumber: Int,
        alternateSetting: Int,
        endpointAddress: Int,
        maxPacketSize: Int,
        feedbackEndpointAddress: Int,
        feedbackMaxPacketSize: Int,
        interfaceAlreadyClaimed: Boolean,
    ): String?

    external fun writePcm(bytes: ByteArray, length: Int): String?

    external fun writeIsoPackets(bytes: ByteArray, packetLengths: IntArray, packetCount: Int): String?

    external fun setIsoPacketSize(packetSize: Int)

    external fun feedbackFramesPerPacketQ16(): Int

    external fun transportTelemetry(): LongArray

    external fun setMaxPendingOutputUrbs(maxPendingUrbs: Int)

    external fun flushOutput(): String?

    external fun close()
}

private const val NATIVE_USB_EXCLUSIVE_STREAMING_ENABLED = true
private const val NATIVE_USB_EXCLUSIVE_DISABLED_MESSAGE =
    "真独占 USB 流式输出暂未启用，已回退到系统 USB 输出。"
private const val USB_RECIP_INTERFACE = 0x01
private const val USB_RECIP_ENDPOINT = 0x02
private const val IBASSO_READER_TIMEOUT_MS = 100
private const val IBASSO_EVENT_DEBOUNCE_MS = 50L
private const val IBASSO_WRITE_CONFIRMATION_WINDOW_MS = 500L

// 数字音量线性增益的 Q16.16 定点满刻度（1.0），低于此值即衰减，等于此值为位完美直通。
private const val UNITY_GAIN_Q16 = 65536

internal fun shouldFlushOutputOnStop(_dsdKind: String?): Boolean = false

internal data class HardwareVolumeFeature(
    val protocol: String,
    val controlInterface: Int,
    val unitId: Int,
    val sourceId: Int,
    val channel: Int,
    val writable: Boolean,
    val recipient: String = "interface",
) {
    fun description(): String =
        "interface=$controlInterface/unit=$unitId/source=$sourceId/channel=$channel/" +
            "volume=${if (writable) "read-write" else "read-only"}/protocol=$protocol/" +
            "recipient=$recipient"
}

internal data class HardwareVolumeRange(
    val minQ8_8: Int,
    val maxQ8_8: Int,
    val stepQ8_8: Int,
    val muteQ8_8: Int = Short.MIN_VALUE.toInt(),
)

internal fun hardwareVolumeRequestType(direction: Int, recipient: String): Int =
    direction or UsbConstants.USB_TYPE_CLASS or
        if (recipient == "device") 0 else USB_RECIP_INTERFACE

internal fun hardwareVolumeRequiresInterfaceClaim(recipient: String): Boolean =
    recipient != "device"

internal fun hardwareVolumeRequiresDedicatedConnection(recipient: String): Boolean =
    recipient == "device"

internal fun hardwareVolumeRangeOverride(quirk: DacQuirk): HardwareVolumeRange? {
    val min = quirk.hardwareVolumeMinQ8_8 ?: return null
    val max = quirk.hardwareVolumeMaxQ8_8 ?: return null
    val step = quirk.hardwareVolumeStepQ8_8 ?: return null
    return HardwareVolumeRange(
        minQ8_8 = min,
        maxQ8_8 = max,
        stepQ8_8 = step,
        muteQ8_8 = quirk.hardwareVolumeMuteQ8_8 ?: Short.MIN_VALUE.toInt(),
    ).takeIf { min <= max && step > 0 }
}

internal fun uniformHardwareVolumeRange(
    ranges: List<HardwareVolumeRange>,
    expectedCount: Int,
): HardwareVolumeRange? = ranges.firstOrNull()?.takeIf {
    ranges.size == expectedCount && ranges.all { range -> range == it }
}

internal fun selectHardwareVolumeFeatures(
    features: List<HardwareVolumeFeature>,
    terminalLink: Int?,
    outputTerminalSources: Set<Int>,
    quirk: DacQuirk,
): List<HardwareVolumeFeature>? {
    if (quirk.hardwareVolumeEnabled == false) {
        return null
    }
    val featureUnitId = quirk.hardwareVolumeFeatureUnitId
    val controlInterface = quirk.hardwareVolumeControlInterface
    if (featureUnitId != null && controlInterface != null) {
        val matching = features.filter {
            it.unitId == featureUnitId && it.controlInterface == controlInterface
        }
        val channels = quirk.hardwareVolumeChannels
        val selected = if (channels.isEmpty()) {
            matching.firstOrNull { it.channel == 0 }?.let(::listOf)
                ?: matching.sortedBy { it.channel }
        } else {
            channels.mapNotNull { channel -> matching.firstOrNull { it.channel == channel } }
        }
        return selected.takeIf {
            it.isNotEmpty() && (channels.isEmpty() || it.size == channels.size)
        }
    }

    val linkedTerminal = terminalLink ?: return null
    val candidates = features
        .filter {
            it.writable &&
                it.sourceId == linkedTerminal &&
                it.unitId in outputTerminalSources
        }
        .groupBy { Triple(it.protocol, it.controlInterface, it.unitId) }
    if (candidates.size != 1) {
        return null
    }
    val group = candidates.values.single()
    return group.firstOrNull { it.channel == 0 }?.let(::listOf)
        ?: group.sortedBy { it.channel }
}

internal fun hardwareVolumeQ8_8(gainQ16: Int, range: HardwareVolumeRange): Int {
    if (gainQ16 <= 0) {
        return range.muteQ8_8
    }
    val gain = gainQ16.coerceAtMost(UNITY_GAIN_Q16).toDouble() / UNITY_GAIN_Q16
    val raw = (20.0 * log10(gain) * 256.0).roundToInt()
        .coerceIn(range.minQ8_8, range.maxQ8_8)
    if (range.stepQ8_8 <= 0) {
        return raw
    }
    val steps = ((raw - range.minQ8_8).toDouble() / range.stepQ8_8).roundToInt()
    return (range.minQ8_8 + steps * range.stepQ8_8)
        .coerceIn(range.minQ8_8, range.maxQ8_8)
}

internal fun hardwareVolumeReadbackMatches(targetQ8_8: Int, actualQ8_8: Int, stepQ8_8: Int): Boolean {
    if (targetQ8_8 == Short.MIN_VALUE.toInt()) {
        return actualQ8_8 == targetQ8_8
    }
    return kotlin.math.abs(actualQ8_8 - targetQ8_8) <= stepQ8_8.coerceAtLeast(1)
}

class UsbExclusiveAudioEngine(
    private val context: Context,
    private val emitState: (Map<String, Any?>) -> Unit,
    private val emitTelemetry: (Map<String, Any?>) -> Unit,
) {
    private val tag = "UsbExclusiveAudioEngine"
    private var worker: Thread? = null
    private var connection: UsbDeviceConnection? = null
    private val paused = AtomicBoolean(false)
    private val stopped = AtomicBoolean(false)
    private val pendingSeekMs = AtomicLong(-1L)

    @Volatile private var playbackId: String? = null
    @Volatile private var currentState = inactiveState()
    private var targetBufferMs = 200
    private var minimumBufferLevelMs: Long? = null
    private var lastTelemetryEmitMs = 0L
    private var lastTelemetryBufferMs: Long? = null
    private var zeroBufferUnderruns = 0L
    private var lastTelemetryUnderrunCount = 0L
    private var lastUnderrunAtMs: Long? = null
    private var activePacketsPerSecond = 0

    // 热切换：切歌时设备与端点参数（时钟/声道/位深）不变就保留已打开的 USB
    // 会话，不重新 claim 接口/设 altsetting/配时钟，DAC 不会重新锁定（重新锁定
    // 就是切歌"咔嗒/电流"声的来源）。会话在停播后延迟关闭，短时间内没有新的
    // start 才真正拆链路。
    private val mainHandler = Handler(Looper.getMainLooper())
    private val deferredCloseRunnable = Runnable { hardCloseSession("idle timeout") }
    private var sessionDeviceId: Int? = null
    private var sessionSampleRate: Int? = null
    private var sessionChannels: Int? = null
    private var sessionBitDepth: Int? = null
    private var sessionTarget: OutputTarget? = null
    private var sessionDevice: UsbDevice? = null
    @Volatile private var sessionBroken = false

    // DSD 编码相位/帧对齐跨曲目/跨空窗延续：编码器（DoP 或 native）与打包器提升到
    // 会话级，写线程与空窗静音线程（互斥，先 join 再启动）共用。DAC 看到的 DSD 流
    // 一旦中断就会掉回 PCM 模式再重新锁定（指示灯蓝→绿→蓝），伴随继电器咔嗒声。
    @Volatile private var sessionDsd: DsdStreamEncoder? = null
    @Volatile private var sessionPacketizer: PcmIsoPacketizer? = null
    // 会话输出类别："dop" / "native" / null=PCM，热复用必须同类同排列
    private var sessionDsdKind: String? = null
    private var sessionNativeFormat: String? = null
    @Volatile private var workerEndedAtEof = false
    private val idleFillerRunning = AtomicBoolean(false)
    private var idleFillerThread: Thread? = null
    // 数字音量：PCM 打包器逐样本读取此增益（Q16.16）。enabled=false（原始数字电平）时
    // 恒为满刻度直通；DSD/DoP 打包器不读此值，始终位完美。
    @Volatile private var pcmVolumeGainQ16 = UNITY_GAIN_Q16
    @Volatile private var volumeControlEnabled = false
    @Volatile private var volumeMode = "auto"
    @Volatile private var requestedVolumeGainQ16 = UNITY_GAIN_Q16
    @Volatile private var requestedReplayGainMilliDb = 0
    @Volatile private var dsdGainCompensationDb = 0
    @Volatile private var volumeSmoothHandoff = true
    @Volatile private var hardwareVolumeActive = false
    @Volatile private var hardwareVolumeProtocol: String? = null
    @Volatile private var hardwareVolumeRaw: Int? = null
    @Volatile private var hardwareVolumeGainQ16: Int? = null
    private var volumeRampGeneration = 0
    private val volumeLock = Any()
    private var hardwareVolumeControl: HardwareVolumeControl? = null
    private var ibassoVolumeConnection: UsbDeviceConnection? = null
    private var ibassoVolumeInterface: UsbInterface? = null
    private var ibassoVolumeDeviceId: Int? = null
    private val ibassoPendingResponses = ConcurrentHashMap<Int, CompletableFuture<ByteArray>>()
    private val ibassoReaderRunning = AtomicBoolean(false)
    @Volatile private var ibassoReaderThread: Thread? = null
    @Volatile private var ibassoReaderConnection: UsbDeviceConnection? = null
    @Volatile private var ibassoReaderEndpoint: UsbEndpoint? = null
    private val ibassoReaderHealthLock = Any()
    @Volatile private var ibassoReaderHealth = IbassoReaderHealth()
    private val ibassoReaderWriteOnly: Boolean
        get() = ibassoReaderHealth.writeOnly
    private val ibassoReadbackVerified: Boolean
        get() = ibassoReaderHealth.readbackVerified
    @Volatile private var ibassoLastWrittenRaw: Int? = null
    @Volatile private var ibassoLastWrittenAtMs = 0L
    private val ibassoEventLock = Any()
    private var ibassoEventGeneration = 0
    private var ibassoPendingEvent: UsbVolumeEvent? = null

    private val diagnosticsLock = Any()
    private var sessionSequence = 0L
    private var sessionStartedAtMs = 0L
    private var sessionFeedbackIgnoredCount = 0L
    private val sessionSubmittedBytes = AtomicLong()
    @Volatile private var latestSessionDiagnostics: Map<String, Any?> = emptyMap()

    fun capabilities(usbManager: UsbManager, device: UsbDevice?): Map<String, Any?> {
        if (!NATIVE_USB_EXCLUSIVE_STREAMING_ENABLED) {
            return capability(
                available = false,
                permissionGranted = device?.let { usbManager.hasPermission(it) } ?: false,
                device = device,
                target = null,
                message = NATIVE_USB_EXCLUSIVE_DISABLED_MESSAGE,
            )
        }

        if (device == null) {
            return capability(
                available = false,
                permissionGranted = false,
                device = null,
                target = null,
                message = "No USB Audio Class output endpoint was found.",
            )
        }

        val target = findOutputTarget(device)
        return capability(
            available = target != null,
            permissionGranted = usbManager.hasPermission(device),
            device = device,
            target = target,
            message = if (target != null) {
                "USB exclusive endpoint is available."
            } else {
                "USB Audio device was found, but no isochronous OUT endpoint was exposed."
            },
        )
    }

    private fun beginSessionDiagnostics(
        reused: Boolean,
        device: UsbDevice,
        sourceFormat: String?,
        dsdMode: String?,
        sampleRate: Int?,
        channels: Int,
        bitDepth: Int?,
        streaming: Boolean,
    ) {
        val input = mapOf(
            "sourceFormat" to sourceFormat,
            "mode" to dsdMode,
            "sampleRate" to sampleRate,
            "channels" to channels,
            "bitDepth" to bitDepth,
            "streaming" to streaming,
            "targetBufferMs" to targetBufferMs,
        )
        synchronized(diagnosticsLock) {
            if (!reused || latestSessionDiagnostics.isEmpty()) {
                sessionSequence += 1
                sessionStartedAtMs = SystemClock.elapsedRealtime()
                sessionSubmittedBytes.set(0)
                sessionFeedbackIgnoredCount = 0
                latestSessionDiagnostics = mapOf(
                    "id" to "usb-${System.currentTimeMillis()}-$sessionSequence",
                    "startedAtMs" to System.currentTimeMillis(),
                    "reused" to false,
                    "input" to input,
                    "outputSelections" to emptyList<Map<String, Any?>>(),
                )
            } else {
                latestSessionDiagnostics = latestSessionDiagnostics + mapOf(
                    "reused" to true,
                    "input" to input,
                    "updatedAtMs" to System.currentTimeMillis(),
                )
            }
        }
    }

    private fun addOutputSelectionDiagnostics(selection: Map<String, Any?>) {
        synchronized(diagnosticsLock) {
            if (latestSessionDiagnostics.isEmpty()) {
                return
            }
            val attempts = (latestSessionDiagnostics["outputSelections"] as? List<*>)
                ?.filterIsInstance<Map<String, Any?>>()
                ?.toMutableList()
                ?: mutableListOf()
            attempts += selection
            latestSessionDiagnostics = latestSessionDiagnostics + mapOf(
                "outputSelections" to attempts,
                "updatedAtMs" to System.currentTimeMillis(),
            )
        }
    }

    private fun updateSessionDiagnostics(section: String, value: Any?) {
        synchronized(diagnosticsLock) {
            if (latestSessionDiagnostics.isEmpty()) {
                return
            }
            latestSessionDiagnostics = latestSessionDiagnostics + mapOf(
                section to value,
                "updatedAtMs" to System.currentTimeMillis(),
            )
        }
    }

    private fun sessionDiagnosticsSnapshot(): Map<String, Any?> = synchronized(diagnosticsLock) {
        latestSessionDiagnostics
    }

    fun start(
        usbManager: UsbManager,
        device: UsbDevice?,
        arguments: Map<String, Any?>,
    ): Map<String, Any?> {
        // 停掉上一首的写线程但先不拆 USB 会话，后面参数匹配时热复用
        val sessionUsable = stopWorkerKeepingSession()
        playbackId = arguments["playbackId"] as? String
        if (connection != null) {
            // 下面任一校验失败提前返回时，兜底延迟关闭残留会话
            scheduleDeferredClose()
        }

        if (!NATIVE_USB_EXCLUSIVE_STREAMING_ENABLED) {
            return updateState(inactiveState(NATIVE_USB_EXCLUSIVE_DISABLED_MESSAGE))
        }

        if (device == null) {
            return updateState(inactiveState("No USB Audio Class device was found."))
        }
        if (!usbManager.hasPermission(device)) {
            return updateState(inactiveState("USB permission is required before exclusive playback."))
        }

        val filePath = arguments["filePath"] as? String
        val sourceFormat = (arguments["sourceFormat"] as? String)
            ?.lowercase(Locale.ROOT)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        if (filePath.isNullOrBlank()) {
            return updateState(inactiveState("Exclusive playback requires a local audio file path."))
        }

        val file = File(filePath)
        if (!file.exists()) {
            return updateState(inactiveState("Exclusive playback file does not exist: $filePath"))
        }
        UsbDiagnostics.i(
            tag,
            "start exclusive playback file=${file.name}, sourceFormat=$sourceFormat, size=${file.length()}",
        )

        if (!isSupportedFile(filePath, sourceFormat)) {
            return updateState(inactiveState("This audio format cannot be decoded for USB exclusive playback."))
        }

        // 流式独占：file 是仍在下载增长的 .part 文件，下载完成时会被改名为正式
        // 缓存名（已打开的 fd 不受影响）。数据没跟上时按"暂停"处理，绝不断流爆音。
        val streaming = arguments["streaming"] == true
        // 流式独占的完整文件大小估算：让 GrowingFileDataSource.getSize() 返回它，
        // MediaExtractor 才能对增长中的 .part 正确 seek（0 表示未知，退回旧的 -1）
        val streamTotalBytes = (arguments["totalBytes"] as? Number)?.toLong() ?: 0L

        // 该设备的 quirk 生效值（vid:pid 精确 → vid:* 厂商 → 默认）
        val quirk = UsbDacQuirks.forDevice(context, device.vendorId, device.productId)
        volumeMode = (arguments["volumeMode"] as? String)
            ?.lowercase(Locale.ROOT)
            ?.takeIf { it == "auto" || it == "dac" || it == "digital" || it == "raw" }
            ?: "auto"
        requestedVolumeGainQ16 = ((arguments["volumeGainQ16"] as? Number)?.toInt() ?: UNITY_GAIN_Q16)
            .coerceIn(0, UNITY_GAIN_Q16)
        requestedReplayGainMilliDb =
            (arguments["replayGainMilliDb"] as? Number)?.toInt() ?: 0
        dsdGainCompensationDb = ((arguments["dsdGainCompensationDb"] as? Number)?.toInt() ?: 0)
            .coerceIn(-12, 6)
        volumeSmoothHandoff = arguments["smoothHandoff"] as? Boolean ?: true

        // DSD 输出模式：dop / native；pcm 模式在 Dart 侧直接走共享路径，不会到这里
        val dsdMode = (arguments["dsdMode"] as? String)?.lowercase(Locale.ROOT)
        var dsdReader: DsdFileReader? = null
        // native 的字节排列：quirk 指定或沿用同设备会话；都没有就等描述符解析出 RAW_DATA alt
        var nativeDsd = false
        var nativeFormat: String? = null
        var nativeFallbackReason: String? = null

        // native 判定失败回退 DoP 前的门槛（DoP 自身的 quirk 限制照常适用）；
        // 返回非 null 表示连 DoP 也不可用，只能整体回退
        fun dopGateError(multiple: Int?): String? {
            if (quirk.dopSupported == false) {
                return "Device is marked as not supporting DoP (quirk" +
                    "${quirk.label?.let { ": $it" } ?: ""})."
            }
            if (quirk.dopMaxDsd != null && multiple != null && multiple > quirk.dopMaxDsd) {
                return "DSD$multiple exceeds this device's DoP limit (DSD${quirk.dopMaxDsd}, quirk)."
            }
            return null
        }

        if (isDsdFile(filePath, sourceFormat)) {
            if (dsdMode != "dop" && dsdMode != "native") {
                return updateState(
                    inactiveState(
                        "DSD over USB exclusive requires DoP or native mode (current: ${dsdMode ?: "unset"}).",
                    ),
                )
            }
            dsdReader = try {
                DsdFileReader.open(file, streaming)
            } catch (error: IOException) {
                return updateState(inactiveState(error.message ?: "Failed to parse DSD file."))
            }
            val multiple = dsdReader.dsdMultiple
            if (dsdMode == "native") {
                nativeFormat = quirk.nativeDsdFormat
                    ?: sessionNativeFormat.takeIf { sessionDeviceId == device.deviceId }
                if (quirk.nativeDsdMaxDsd != null && multiple != null && multiple > quirk.nativeDsdMaxDsd) {
                    nativeFallbackReason =
                        "DSD$multiple exceeds native DSD limit DSD${quirk.nativeDsdMaxDsd} (quirk)"
                } else {
                    nativeDsd = true
                }
            }
            if (!nativeDsd) {
                // DoP 模式，或 native 上限超标回退 DoP
                dopGateError(multiple)?.let { gateError ->
                    dsdReader.close()
                    return updateState(inactiveState(gateError))
                }
                nativeFallbackReason?.let {
                    UsbDiagnostics.w(tag, "native DSD unavailable, falling back to DoP: $it")
                }
            }
            UsbDiagnostics.i(
                tag,
                "DSD source rate=${dsdReader.sampleRate} (DSD${dsdReader.dsdMultiple ?: "?"}), " +
                    "channels=${dsdReader.channels}, container=${dsdReader.formatName}, " +
                    "mode=${if (nativeDsd) "native(${nativeFormat ?: "by-descriptor"})" else "dop"}, " +
                    "quirk dop=${quirk.dopSupported}, nativeDsd=${quirk.nativeDsdFormat}",
            )
        }

        // 输出帧率：DoP = DSD速率÷16（24-bit 帧）；native = DSD速率÷8÷每采样字节数
        //（字节排列未定时置 null：禁用热复用，等描述符解析后再定）；PCM 由 Dart 下发
        var requestedSampleRate = when {
            dsdReader == null -> (arguments["sampleRate"] as? Number)?.toInt()
            nativeDsd -> nativeDsdBytesPerSample(nativeFormat)?.let { dsdReader.sampleRate / 8 / it }
            else -> dsdReader.dopFrameRate
        }
        var requestedBitDepth = when {
            dsdReader == null -> (arguments["bitDepth"] as? Number)?.toInt()
            nativeDsd -> nativeDsdBytesPerSample(nativeFormat)?.let { it * 8 }
            else -> null
        }
        targetBufferMs = ((arguments["targetBufferMs"] as? Number)?.toInt() ?: 200).coerceIn(50, 1000)
        if (streaming) {
            // 流式播放用更深的 USB 水位吸收下载抖动
            targetBufferMs = maxOf(targetBufferMs, 1000)
        }
        minimumBufferLevelMs = null
        lastTelemetryEmitMs = 0L
        lastTelemetryBufferMs = null
        zeroBufferUnderruns = 0L
        lastTelemetryUnderrunCount = 0L
        lastUnderrunAtMs = null
        activePacketsPerSecond = 0
        val requestedChannels = dsdReader?.channels ?: 2
        val wantDsdKind = when {
            dsdReader == null -> null
            nativeDsd -> "native"
            else -> "dop"
        }
        // 设备与端点参数都没变时热复用已打开的会话；输出类别（PCM/DoP/native
        // 及 native 字节排列）必须一致，DoP 复用还要确认既有 slot ≥ 24-bit
        val reuseSession = sessionUsable &&
            connection != null &&
            sessionTarget != null &&
            sessionDeviceId == device.deviceId &&
            sessionSampleRate == requestedSampleRate &&
            sessionChannels == requestedChannels &&
            sessionBitDepth == requestedBitDepth &&
            sessionDsdKind == wantDsdKind &&
            (wantDsdKind != "native" || sessionNativeFormat == nativeFormat) &&
            (dsdReader == null || nativeDsd || sessionTarget!!.usbBytesPerSample >= 3)
        val target: OutputTarget
        if (reuseSession) {
            beginSessionDiagnostics(
                reused = true,
                device = device,
                sourceFormat = sourceFormat,
                dsdMode = wantDsdKind,
                sampleRate = requestedSampleRate,
                channels = requestedChannels,
                bitDepth = requestedBitDepth,
                streaming = streaming,
            )
            target = sessionTarget!!
            mainHandler.removeCallbacks(deferredCloseRunnable)
            stopDopIdleFiller()
            // 热复用切歌一律不 flush：丢在途 URB 会瞬断 ISO 流——DSD 会让 DAC 掉出
            // DSD 模式重锁（咔嗒），PCM 会瞬间欠载出小音爆。旧缓冲（约一个水位）
            // 放完无缝续上新曲，与自然播完切歌（workerEndedAtEof）行为一致。
            UsbDiagnostics.i(
                tag,
                "reusing exclusive USB session sampleRate=$requestedSampleRate, " +
                    "channels=$requestedChannels, bitDepth=${requestedBitDepth ?: "auto"}",
            )
        } else {
            hardCloseSession("device or stream parameters changed")
            beginSessionDiagnostics(
                reused = false,
                device = device,
                sourceFormat = sourceFormat,
                dsdMode = wantDsdKind,
                sampleRate = requestedSampleRate,
                channels = requestedChannels,
                bitDepth = requestedBitDepth,
                streaming = streaming,
            )
            val openedConnection = usbManager.openDevice(device)
                ?: run {
                    dsdReader?.close()
                    return updateState(inactiveState("Failed to open USB device for exclusive playback."))
                }
            val descriptors = openedConnection.rawDescriptors
            val streamingFormats = parseStreamingFormatInfo(descriptors)

            val enteredNative = nativeDsd
            if (nativeDsd && nativeFormat == null) {
                // 无 quirk 时按描述符声明的 RAW_DATA alt 推断字节排列（subslot 宽度，默认小端）
                val rawSlot = streamingFormats.values
                    .filter { it.isRawData }
                    .mapNotNull { info -> info.subslotSize?.takeIf { it == 1 || it == 2 || it == 4 } }
                    .maxOrNull()
                if (rawSlot != null) {
                    nativeFormat = if (rawSlot == 1) "u8" else "u${rawSlot * 8}le"
                    UsbDiagnostics.i(
                        tag,
                        "native DSD alt declared by descriptor, subslot=$rawSlot -> $nativeFormat",
                    )
                } else {
                    nativeDsd = false
                    nativeFallbackReason = "device declares no RAW_DATA alt and no nativeDsd quirk"
                }
            }

            var resolvedTarget: OutputTarget? = null
            if (nativeDsd) {
                val nativeBps = nativeDsdBytesPerSample(nativeFormat)!!
                requestedSampleRate = dsdReader!!.sampleRate / 8 / nativeBps
                requestedBitDepth = nativeBps * 8
                resolvedTarget = findOutputTarget(
                    device,
                    streamingFormats = streamingFormats,
                    sampleRate = requestedSampleRate,
                    channels = requestedChannels,
                    bitDepth = requestedBitDepth,
                    requireRawData = streamingFormats.values.any { it.isRawData },
                    reportSelection = true,
                )
                // 选中的 alt 必须与字节排列同宽：native 数据不允许任何位深转换（会破坏 DSD 流）
                if (resolvedTarget == null ||
                    resolvedTarget.usbBytesPerSample != nativeBps ||
                    (resolvedTarget.usbBitResolution != null &&
                        resolvedTarget.usbBitResolution != nativeBps * 8)
                ) {
                    nativeDsd = false
                    nativeFallbackReason =
                        "no fitting alt for native DSD $nativeFormat at ${requestedSampleRate}Hz"
                    resolvedTarget = null
                }
            }
            if (enteredNative && !nativeDsd) {
                // native 在描述符/alt 层面落空，降级 DoP（此时才需要补查 DoP 的 quirk 门槛）
                UsbDiagnostics.w(tag, "native DSD unavailable, falling back to DoP: $nativeFallbackReason")
                dopGateError(dsdReader!!.dsdMultiple)?.let { gateError ->
                    openedConnection.close()
                    dsdReader!!.close()
                    return updateState(
                        inactiveState("Native DSD unavailable ($nativeFallbackReason); $gateError"),
                    )
                }
                requestedSampleRate = dsdReader!!.dopFrameRate
                requestedBitDepth = null
            }
            if (resolvedTarget == null) {
                resolvedTarget = findOutputTarget(
                    device,
                    streamingFormats = streamingFormats,
                    sampleRate = requestedSampleRate,
                    channels = requestedChannels,
                    bitDepth = requestedBitDepth,
                    reportSelection = true,
                )
            }
            if (resolvedTarget == null) {
                openedConnection.close()
                dsdReader?.close()
                return updateState(inactiveState("No isochronous USB Audio OUT endpoint was found."))
            }
            if (dsdReader != null && !nativeDsd && resolvedTarget.usbBytesPerSample < 3) {
                // 16-bit slot 无法承载 DoP 的 8 位标记 + 16 位数据
                openedConnection.close()
                dsdReader.close()
                return updateState(
                    inactiveState(
                        "DoP requires a 24/32-bit output slot, but the device only exposes " +
                            "${resolvedTarget.usbBitResolution ?: resolvedTarget.usbBytesPerSample * 8}-bit at " +
                            "${requestedSampleRate}Hz.",
                    ),
                )
            }
            UsbDiagnostics.i(
                tag,
                "exclusive target interface=${resolvedTarget.usbInterface.id}, alt=${resolvedTarget.alternateSetting}, " +
                    "endpoint=0x${resolvedTarget.endpoint.address.toString(16)}, maxPacket=${resolvedTarget.endpoint.maxPacketSize}, " +
                    "feedback=${resolvedTarget.feedbackEndpointLabel}, " +
                    "requestedSampleRate=$requestedSampleRate, requestedBitDepth=${requestedBitDepth ?: "auto"}, " +
                    "usbFormat=${resolvedTarget.formatInfo}",
            )

            val openError = UsbExclusiveNative.open(
                openedConnection.fileDescriptor,
                resolvedTarget.usbInterface.id,
                resolvedTarget.alternateSetting,
                resolvedTarget.endpoint.address,
                resolvedTarget.endpoint.maxPacketSize,
                resolvedTarget.feedbackEndpoint?.address ?: 0,
                resolvedTarget.feedbackEndpoint?.maxPacketSize ?: 0,
                false,
            )
            if (openError != null) {
                openedConnection.close()
                dsdReader?.close()
                return updateState(inactiveState(openError))
            }
            UsbDiagnostics.i(tag, "native USB exclusive endpoint opened.")

            // 时钟：native DSD 与 DoP/PCM 一样按容器帧率 SET_CUR（与 ALSA runtime rate
            // 语义一致，DSD128 u32le → 176400）。真机教训：设成字节率（速率÷8）会被
            // Macaron 无视，DAC 停在别的时钟上按错误节奏消耗数据，输出持续电流声
            if (requestedSampleRate != null) {
                val clockError = configureUsbAudioClock(
                    openedConnection,
                    device,
                    resolvedTarget,
                    requestedSampleRate,
                    quirk,
                )
                if (clockError != null) {
                    UsbExclusiveNative.close()
                    openedConnection.close()
                    dsdReader?.close()
                    return updateState(inactiveState(clockError))
                }
            }

            connection = openedConnection
            sessionDeviceId = device.deviceId
            sessionSampleRate = requestedSampleRate
            sessionChannels = requestedChannels
            sessionBitDepth = requestedBitDepth
            sessionTarget = resolvedTarget
            sessionDevice = device
            sessionDsdKind = when {
                dsdReader == null -> null
                nativeDsd -> "native"
                else -> "dop"
            }
            sessionNativeFormat = if (nativeDsd) nativeFormat else null
            target = resolvedTarget
        }
        sessionDevice = device
        applyVolumeControl(device, target, dsdReader != null, quirk)
        sessionBroken = false
        workerEndedAtEof = false
        paused.set(arguments["startPaused"] == true)
        stopped.set(false)
        pendingSeekMs.set(-1L)

        // DSD 激活时 state 报 DSD 语义：sampleRate=DSD 速率、bitDepth=1、
        // format 带 (DoP)/(Native) 后缀；native 判定失败回退 DoP 时把原因写进 message
        val reader = dsdReader
        val dsdSuffix = if (nativeDsd) "Native" else "DoP"
        val initialState = mapOf(
            "active" to true,
            "playing" to !paused.get(),
            "positionMs" to 0,
            "playbackId" to playbackId,
            "durationMs" to reader?.durationMs,
            "sampleRate" to (reader?.sampleRate ?: arguments["sampleRate"]),
            "bitDepth" to if (reader != null) 1 else arguments["bitDepth"],
            "hardwareVolumeActive" to hardwareVolumeActive,
            "digitalVolumeActive" to volumeControlEnabled,
            "replayGainMilliDb" to requestedReplayGainMilliDb,
            "hardwareVolumeProtocol" to hardwareVolumeProtocol,
            "hardwareVolumeRaw" to hardwareVolumeRaw,
            "hardwareVolumeGainQ16" to hardwareVolumeGainQ16,
            "hardwareVolumeWriteOnly" to ibassoReaderWriteOnly,
            "hardwareVolumeReadbackVerified" to ibassoReadbackVerified,
            "format" to if (reader != null) {
                "${reader.formatName}($dsdSuffix)"
            } else {
                sourceFormat ?: file.extension.lowercase(Locale.ROOT)
            },
            "message" to if (reader != null && nativeFallbackReason != null) {
                "USB exclusive playback prepared (native DSD unavailable: " +
                    "$nativeFallbackReason; using DoP)."
            } else if (reader != null && requestedReplayGainMilliDb != 0 && !hardwareVolumeActive) {
                "USB exclusive playback prepared; ReplayGain is not applied to the DSD bitstream."
            } else {
                "USB exclusive playback prepared."
            },
        )
        updateState(initialState)
        emitTransportTelemetry(target.packetsPerSecond, force = true)

        val workerNativeFormat = if (nativeDsd) nativeFormat else null
        worker = Thread({
            runCatching { Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO) }
                .onFailure { UsbDiagnostics.w(tag, "Failed to set USB audio thread priority: ${it.message}") }
            if (reader != null) {
                dsdDecodeAndWrite(reader, target, if (streaming) file else null, workerNativeFormat)
            } else {
                decodeAndWrite(file, target, streaming, streamTotalBytes)
            }
        }, "SylvakruUsbExclusive")
        worker?.start()
        return currentState
    }

    fun pause(): Map<String, Any?> {
        UsbDiagnostics.i(tag, "pause exclusive playback.")
        paused.set(true)
        return updateState(currentState + mapOf("playing" to false, "message" to "Paused."))
    }

    fun resume(): Map<String, Any?> {
        if (currentState["active"] != true) {
            UsbDiagnostics.w(tag, "resume ignored because exclusive playback is not active: $currentState")
            return updateState(inactiveState("No exclusive playback is active."))
        }
        UsbDiagnostics.i(
            tag,
            "resume exclusive playback position=${currentState["positionMs"]}, wasPaused=${paused.get()}",
        )
        paused.set(false)
        return updateState(currentState + mapOf("playing" to true, "message" to "Playing."))
    }

    fun seek(positionMs: Long): Map<String, Any?> {
        if (currentState["active"] != true) {
            UsbDiagnostics.w(tag, "seek ignored because exclusive playback is not active: $currentState")
            return updateState(inactiveState("No exclusive playback is active."))
        }
        val safePositionMs = positionMs.coerceAtLeast(0L)
        pendingSeekMs.set(safePositionMs)
        return updateState(
            currentState + mapOf(
                "message" to "Seeking.",
                "positionMs" to safePositionMs,
            ),
        )
    }

    fun setVolume(
        gainQ16: Int,
        replayGainMilliDb: Int,
        mode: String,
        dsdCompensationDb: Int,
        smoothHandoff: Boolean,
    ) {
        requestedVolumeGainQ16 = gainQ16.coerceIn(0, UNITY_GAIN_Q16)
        requestedReplayGainMilliDb = replayGainMilliDb
        dsdGainCompensationDb = dsdCompensationDb.coerceIn(-12, 6)
        volumeSmoothHandoff = smoothHandoff
        volumeMode = mode.lowercase(Locale.ROOT)
            .takeIf { it == "auto" || it == "dac" || it == "digital" || it == "raw" }
            ?: "auto"
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
            updateState(
                currentState + mapOf(
                    "hardwareVolumeActive" to hardwareVolumeActive,
                    "digitalVolumeActive" to volumeControlEnabled,
                    "replayGainMilliDb" to requestedReplayGainMilliDb,
                    "hardwareVolumeProtocol" to hardwareVolumeProtocol,
                    "hardwareVolumeRaw" to hardwareVolumeRaw,
                    "hardwareVolumeGainQ16" to hardwareVolumeGainQ16,
                    "hardwareVolumeWriteOnly" to ibassoReaderWriteOnly,
                    "hardwareVolumeReadbackVerified" to ibassoReadbackVerified,
                ),
            )
        }
    }

    fun isVolumeControlEngaged(): Boolean =
        currentState["active"] == true &&
            (hardwareVolumeActive || (volumeControlEnabled && currentState["bitDepth"] != 1))

    private fun applyVolumeControl(
        device: UsbDevice,
        target: OutputTarget,
        isDsd: Boolean,
        quirk: DacQuirk,
    ) {
        synchronized(volumeLock) {
            val wasHardwareActive = hardwareVolumeActive
            hardwareVolumeActive = false
            hardwareVolumeProtocol = null
            hardwareVolumeRaw = null
            hardwareVolumeGainQ16 = null
            val wantsHardware = volumeMode == "auto" || volumeMode == "dac"
            val vendorProtocol = quirk.hardwareVolumeProtocol
            val protocolSelection = usbVolumeProtocolSelection(vendorProtocol)
            val effectiveGainQ16 = effectiveVolumeGainQ16(
                requestedVolumeGainQ16,
                requestedReplayGainMilliDb,
            )
            val effectiveHardwareGainQ16 = effectiveHardwareVolumeGainQ16(
                requestedVolumeGainQ16,
                requestedReplayGainMilliDb,
                dsdGainCompensationDb,
                isDsd,
            )
            var fallbackReason: String? = null
            if (wantsHardware && quirk.hardwareVolumeEnabled != false) {
                if (isDsd && quirk.hardwareVolumeDsdSupported == false) {
                    fallbackReason = "DSD hardware volume is disabled by quirk."
                } else if (protocolSelection is VendorUsbVolumeProtocol) {
                    val volumeTarget = protocolSelection.protocol.appGainToRaw(
                        requestedVolumeGainQ16,
                        requestedReplayGainMilliDb,
                        if (isDsd) dsdGainCompensationDb else 0,
                    )
                    fallbackReason = writeIbassoDc03ProVolume(
                        device,
                        volumeTarget,
                        if (isDsd) volumeTarget.dsdRaw else volumeTarget.baseRaw,
                    )
                    hardwareVolumeActive = fallbackReason == null
                    if (hardwareVolumeActive) {
                        hardwareVolumeProtocol = protocolSelection.protocol.id
                        hardwareVolumeRaw = if (isDsd) volumeTarget.dsdRaw else volumeTarget.baseRaw
                        hardwareVolumeGainQ16 = effectiveHardwareGainQ16
                    } else if (wasHardwareActive) {
                        val recovery = hardwareVolumeRecovery(
                            fallbackReason ?: "Hardware volume write failed.",
                            writeIbassoDc03ProVolume(
                                device,
                                protocolSelection.protocol.appGainToRaw(UNITY_GAIN_Q16, 0, 0),
                                0,
                            ),
                        )
                        hardwareVolumeActive = recovery.hardwareActive
                        fallbackReason = recovery.fallbackReason
                        if (hardwareVolumeActive) {
                            hardwareVolumeProtocol = protocolSelection.protocol.id
                        }
                    }
                } else if (protocolSelection is UnsupportedUsbVolumeProtocol) {
                    fallbackReason = "Unsupported hardware volume protocol: ${protocolSelection.id}."
                } else {
                    val activeConnection = connection
                    val control = if (activeConnection == null) {
                        null
                    } else {
                        hardwareVolumeControl ?: resolveHardwareVolumeControl(
                            activeConnection,
                            device,
                            target,
                            quirk,
                        )?.also { hardwareVolumeControl = it }
                    }
                    if (control == null) {
                        fallbackReason = "No unique writable playback Feature Unit passed probing."
                    } else if (activeConnection != null) {
                        fallbackReason = writeHardwareVolume(
                            activeConnection,
                            device,
                            control,
                            effectiveHardwareGainQ16,
                        )
                        hardwareVolumeActive = fallbackReason == null
                        if (hardwareVolumeActive) {
                            hardwareVolumeProtocol = control.features.firstOrNull()?.protocol
                            hardwareVolumeGainQ16 = effectiveHardwareGainQ16
                        }
                        if (!hardwareVolumeActive && wasHardwareActive) {
                            val recovery = hardwareVolumeRecovery(
                                fallbackReason ?: "Hardware volume write failed.",
                                writeHardwareVolume(
                                    activeConnection,
                                    device,
                                    control,
                                    UNITY_GAIN_Q16,
                                ),
                            )
                            hardwareVolumeActive = recovery.hardwareActive
                            fallbackReason = recovery.fallbackReason
                            if (hardwareVolumeActive) {
                                hardwareVolumeProtocol = control.features.firstOrNull()?.protocol
                            }
                        }
                    }
                }
            } else if (wasHardwareActive) {
                if (volumeSmoothHandoff && !isDsd) {
                    pcmVolumeGainQ16 = effectiveGainQ16
                }
                val restoreError = if (protocolSelection is VendorUsbVolumeProtocol) {
                    writeIbassoDc03ProVolume(
                        device,
                        protocolSelection.protocol.appGainToRaw(UNITY_GAIN_Q16, 0, 0),
                        0,
                    )
                } else {
                    val activeConnection = connection
                    val control = hardwareVolumeControl
                    if (activeConnection != null && control != null) {
                        writeHardwareVolume(activeConnection, device, control, UNITY_GAIN_Q16)
                    } else {
                        "Active hardware volume control is unavailable."
                    }
                }
                hardwareVolumeActive = restoreError != null
                fallbackReason = restoreError?.let { "Failed to restore hardware volume: $it" }
            } else {
                hardwareVolumeActive = false
            }

            volumeControlEnabled = !hardwareVolumeActive && !isDsd && volumeMode != "raw"
            val targetPcmGain = if (volumeControlEnabled) effectiveGainQ16 else UNITY_GAIN_Q16
            setPcmVolumeGain(
                targetPcmGain,
                volumeSmoothHandoff && !isDsd && wasHardwareActive != hardwareVolumeActive,
            )
            if (fallbackReason != null) {
                UsbDiagnostics.w(
                    tag,
                    "hardware volume fallback: $fallbackReason, mode=$volumeMode, " +
                        "source=${hardwareVolumeControl?.source ?: vendorProtocol}",
                )
            }
            updateSessionDiagnostics(
                "hardwareVolume",
                mapOf(
                    "mode" to volumeMode,
                    "active" to hardwareVolumeActive,
                    "digitalFallback" to volumeControlEnabled,
                    "isDsd" to isDsd,
                    "gainQ16" to requestedVolumeGainQ16,
                    "effectiveGainQ16" to effectiveGainQ16,
                    "replayGainMilliDb" to requestedReplayGainMilliDb,
                    "hardwareVolumeProtocol" to hardwareVolumeProtocol,
                    "hardwareVolumeRaw" to hardwareVolumeRaw,
                    "hardwareVolumeWriteOnly" to ibassoReaderWriteOnly,
                    "hardwareVolumeReadbackVerified" to ibassoReadbackVerified,
                    "dsdGainCompensationDb" to dsdGainCompensationDb,
                    "smoothHandoff" to volumeSmoothHandoff,
                    "source" to (hardwareVolumeControl?.source ?: vendorProtocol),
                    "features" to hardwareVolumeControl?.features?.map { it.description() },
                    "range" to hardwareVolumeControl?.range?.let {
                        mapOf(
                            "minQ8_8Db" to it.minQ8_8,
                            "maxQ8_8Db" to it.maxQ8_8,
                            "stepQ8_8Db" to it.stepQ8_8,
                            "muteQ8_8Db" to it.muteQ8_8,
                        )
                    },
                    "fallbackReason" to fallbackReason,
                ),
            )
        }
    }

    private fun resolveHardwareVolumeControl(
        connection: UsbDeviceConnection,
        device: UsbDevice,
        target: OutputTarget,
        quirk: DacQuirk,
    ): HardwareVolumeControl? {
        val descriptors = connection.rawDescriptors
        val parsed = parseHardwareVolumeFeatures(descriptors).toMutableList()
        val quirkUnitId = quirk.hardwareVolumeFeatureUnitId
        val quirkInterface = quirk.hardwareVolumeControlInterface
        if (quirkUnitId != null && quirkInterface != null) {
            val protocol = quirk.hardwareVolumeProtocol
                ?.takeIf { it == "uac1" || it == "uac2" } ?: if (
                findAudioControlInterface(device, quirkInterface)?.interfaceProtocol == 0x20
            ) {
                "uac2"
            } else {
                "uac1"
            }
            val matching = parsed.filter {
                it.unitId == quirkUnitId && it.controlInterface == quirkInterface
            }
            val channels = quirk.hardwareVolumeChannels.ifEmpty {
                if (matching.isEmpty()) listOf(0) else emptyList()
            }
            parsed += channels.filter { channel ->
                matching.none { it.channel == channel }
            }.map { channel ->
                HardwareVolumeFeature(
                    protocol = protocol,
                    controlInterface = quirkInterface,
                    unitId = quirkUnitId,
                    sourceId = target.formatInfo?.terminalLink ?: -1,
                    channel = channel,
                    writable = true,
                    recipient = quirk.hardwareVolumeRecipient,
                )
            }
        }
        val selected = selectHardwareVolumeFeatures(
            features = parsed,
            terminalLink = target.formatInfo?.terminalLink,
            outputTerminalSources = parseOutputTerminalSources(descriptors),
            quirk = quirk,
        ) ?: run {
            UsbDiagnostics.w(tag, "hardware volume resolve failed: no unique feature selected.")
            return null
        }
        if (
            quirkUnitId == null &&
            parsed.map { it.controlInterface }.distinct().size != 1
        ) {
            UsbDiagnostics.w(tag, "hardware volume resolve failed: ambiguous control interfaces.")
            return null
        }
        val controlInterface = findAudioControlInterface(device, selected.first().controlInterface)
            ?: run {
                UsbDiagnostics.w(
                    tag,
                    "hardware volume resolve failed: control interface " +
                        "${selected.first().controlInterface} is unavailable.",
                )
                return null
            }
        val dedicatedConnection = hardwareVolumeRequiresDedicatedConnection(selected.first().recipient)
        val transferConnection = if (dedicatedConnection) {
            context.getSystemService(UsbManager::class.java).openDevice(device)
        } else {
            connection
        } ?: run {
            UsbDiagnostics.w(tag, "hardware volume resolve failed: dedicated connection is unavailable.")
            return null
        }
        val requiresClaim = hardwareVolumeRequiresInterfaceClaim(selected.first().recipient)
        val claimResult = if (requiresClaim) {
            runCatching { transferConnection.claimInterface(controlInterface, true) }
        } else {
            Result.success(true)
        }
        if (!claimResult.getOrDefault(false)) {
            UsbDiagnostics.w(
                tag,
                "hardware volume resolve failed: claim interface ${controlInterface.id} failed" +
                    (claimResult.exceptionOrNull()?.let { ": ${it.message}" } ?: "."),
            )
            if (dedicatedConnection) {
                runCatching { transferConnection.close() }
            }
            return null
        }
        return try {
            val overrideRange = hardwareVolumeRangeOverride(quirk)
            val ranges = selected.mapNotNull {
                overrideRange ?: readHardwareVolumeRangeValue(transferConnection, it)
            }
            val range = uniformHardwareVolumeRange(ranges, selected.size)
            if (range == null) {
                null
            } else if (
                overrideRange != null &&
                selected.any { readHardwareVolumeCurrent(transferConnection, it) == null }
            ) {
                UsbDiagnostics.w(
                    tag,
                    "hardware volume resolve failed: GET_CUR verification failed for " +
                        "${selected.map { it.description() }}.",
                )
                null
            } else {
                HardwareVolumeControl(
                    features = selected,
                    range = range,
                    source = if (quirkUnitId != null && quirkInterface != null) "quirk" else "descriptor",
                )
            }
        } finally {
            if (requiresClaim) {
                runCatching { transferConnection.releaseInterface(controlInterface) }
            }
            if (dedicatedConnection) {
                runCatching { transferConnection.close() }
            }
        }
    }

    private fun writeHardwareVolume(
        connection: UsbDeviceConnection,
        device: UsbDevice,
        control: HardwareVolumeControl,
        gainQ16: Int,
    ): String? {
        val controlInterface = findAudioControlInterface(device, control.features.first().controlInterface)
            ?: return "AudioControl interface is unavailable."
        val dedicatedConnection = hardwareVolumeRequiresDedicatedConnection(
            control.features.first().recipient,
        )
        val transferConnection = if (dedicatedConnection) {
            context.getSystemService(UsbManager::class.java).openDevice(device)
        } else {
            connection
        } ?: return "Dedicated hardware volume connection is unavailable."
        val requiresClaim = hardwareVolumeRequiresInterfaceClaim(control.features.first().recipient)
        val claimed = !requiresClaim ||
            runCatching { transferConnection.claimInterface(controlInterface, true) }.getOrDefault(false)
        if (!claimed) {
            if (dedicatedConnection) {
                runCatching { transferConnection.close() }
            }
            return "Failed to claim the AudioControl interface."
        }
        val previous = mutableMapOf<HardwareVolumeFeature, Int>()
        val written = mutableListOf<HardwareVolumeFeature>()
        val targetQ8_8 = hardwareVolumeQ8_8(gainQ16, control.range)
        return try {
            for (feature in control.features) {
                val current = readHardwareVolumeCurrent(transferConnection, feature)
                if (current == null) {
                    return "Failed to read hardware volume channel ${feature.channel}."
                }
                previous[feature] = current
            }
            for (feature in control.features) {
                if (!writeHardwareVolumeValue(transferConnection, feature, targetQ8_8)) {
                    rollbackHardwareVolume(transferConnection, written, previous)
                    return "Failed to set hardware volume channel ${feature.channel}."
                }
                written += feature
                val readBack = readHardwareVolumeCurrent(transferConnection, feature)
                if (
                    readBack == null ||
                    !hardwareVolumeReadbackMatches(targetQ8_8, readBack, control.range.stepQ8_8)
                ) {
                    rollbackHardwareVolume(transferConnection, written, previous)
                    return "Hardware volume readback mismatch on channel ${feature.channel}: " +
                        "targetQ8_8=$targetQ8_8, actualQ8_8=${readBack ?: "unavailable"}."
                }
            }
            UsbDiagnostics.i(
                tag,
                "hardware volume SET_CUR targetQ8_8=$targetQ8_8, " +
                    "channels=${control.features.map { it.channel }}, " +
                    "recipient=${control.features.first().recipient}, source=${control.source}",
            )
            null
        } finally {
            if (requiresClaim) {
                runCatching { transferConnection.releaseInterface(controlInterface) }
            }
            if (dedicatedConnection) {
                runCatching { transferConnection.close() }
            }
        }
    }

    private fun rollbackHardwareVolume(
        connection: UsbDeviceConnection,
        written: List<HardwareVolumeFeature>,
        previous: Map<HardwareVolumeFeature, Int>,
    ) {
        written.asReversed().forEach { feature ->
            previous[feature]?.let { writeHardwareVolumeValue(connection, feature, it) }
        }
    }

    private fun writeIbassoDc03ProVolume(
        device: UsbDevice,
        target: UsbVolumeTarget,
        activeRaw: Int,
    ): String? {
        val hidInterface = (0 until device.interfaceCount)
            .map { device.getInterface(it) }
            .firstOrNull {
                it.interfaceClass == UsbConstants.USB_CLASS_HID &&
                    it.interfaceSubclass == 0 &&
                    it.interfaceProtocol == 0
            } ?: return "iBasso HID interface is unavailable."
        val inputEndpoint = (0 until hidInterface.endpointCount)
            .map { hidInterface.getEndpoint(it) }
            .firstOrNull { it.direction == UsbConstants.USB_DIR_IN }
            ?: return "iBasso HID input endpoint is unavailable."
        if (ibassoVolumeDeviceId != device.deviceId || ibassoVolumeConnection == null) {
            closeIbassoVolumeControl()
            val controlConnection = context.getSystemService(UsbManager::class.java).openDevice(device)
                ?: return "iBasso control connection is unavailable."
            if (!controlConnection.claimInterface(hidInterface, true)) {
                controlConnection.close()
                return "Failed to claim the iBasso HID interface."
            }
            ibassoVolumeConnection = controlConnection
            ibassoVolumeInterface = hidInterface
            ibassoVolumeDeviceId = device.deviceId
            startIbassoVolumeReader(
                controlConnection,
                inputEndpoint,
                IbassoDc03ProVolumeProtocol.capabilities.unsolicitedEvents,
            )
        }
        val controlConnection = ibassoVolumeConnection
            ?: return "iBasso control connection is unavailable."

        val value = target.baseRaw
        val dsdValue = target.dsdRaw
        val packets = listOf(
            ibassoI2cWritePacket(1, 0x60, 9, 1, value),
            ibassoI2cWritePacket(2, 0x60, 9, 2, value),
            ibassoI2cWritePacket(3, 0x62, 9, 1, value),
            ibassoI2cWritePacket(4, 0x62, 9, 2, value),
            ibassoI2cWritePacket(9, 0x60, 7, 0, dsdValue),
            ibassoI2cWritePacket(10, 0x60, 7, 1, dsdValue),
            ibassoRoomWritePacket(19, 16, value),
            ibassoI2cWritePacket(11, 0x62, 7, 0, dsdValue),
            ibassoI2cWritePacket(12, 0x62, 7, 1, dsdValue),
            ibassoRoomWritePacket(20, 17, value),
        )
        ibassoLastWrittenRaw = activeRaw
        ibassoLastWrittenAtMs = SystemClock.elapsedRealtime()
        synchronized(ibassoReaderHealthLock) {
            ibassoReaderHealth = ibassoReaderHealth.copy(readbackVerified = false)
        }
        for (packet in packets) {
            val command = packet[0].toInt() and 0xff
            val response = transferIbassoPacket(
                controlConnection,
                packet,
                command,
            )
            if (response == null) {
                closeIbassoVolumeControl()
                return "iBasso volume command $command failed."
            }
            val responseCommand = response.getOrNull(6)?.toInt()?.and(0xff)
            if (responseCommand != command) {
                closeIbassoVolumeControl()
                return "iBasso volume command $command returned response $responseCommand."
            }
            SystemClock.sleep(10)
        }
        if (ibassoReaderWriteOnly) {
            UsbDiagnostics.w(
                tag,
                "iBasso hardware volume applied with readback=unavailable, writeOnly=true, " +
                    "register=$value, dsdRegister=$dsdValue.",
            )
            return null
        }
        val response = transferIbassoPacket(
            controlConnection,
            ibassoVolumeReadPacket(),
            65,
        )
        if (response == null) {
            closeIbassoVolumeControl()
            return "Failed to read iBasso hardware volume."
        }
        val readBack = response.getOrNull(8)?.toInt()?.and(0xff)
        if (readBack != value) {
            closeIbassoVolumeControl()
            return "iBasso hardware volume readback mismatch: target=$value, actual=$readBack."
        }
        ibassoLastWrittenRaw = activeRaw
        ibassoLastWrittenAtMs = SystemClock.elapsedRealtime()
        synchronized(ibassoReaderHealthLock) {
            ibassoReaderHealth = ibassoReaderHealth.afterVerifiedReadback()
        }
        UsbDiagnostics.i(
            tag,
            "iBasso hardware volume set register=$value, dsdRegister=$dsdValue, " +
                "protocol=ibassoDc03Pro",
        )
        return null
    }

    private fun startIbassoVolumeReader(
        controlConnection: UsbDeviceConnection,
        inputEndpoint: UsbEndpoint,
        eventsEnabled: Boolean,
        restarted: Boolean = false,
    ) {
        if (ibassoReaderRunning.getAndSet(true)) return
        ibassoReaderConnection = controlConnection
        ibassoReaderEndpoint = inputEndpoint
        synchronized(ibassoReaderHealthLock) {
            ibassoReaderHealth = if (restarted) {
                ibassoReaderHealth.afterRestart()
            } else {
                IbassoReaderHealth()
            }
        }
        lateinit var reader: Thread
        reader = Thread({
            val buffer = ByteArray(inputEndpoint.maxPacketSize.coerceAtLeast(16))
            try {
                while (ibassoReaderRunning.get() &&
                    ibassoReaderConnection === controlConnection &&
                    ibassoReaderEndpoint === inputEndpoint
                ) {
                    val length = controlConnection.bulkTransfer(
                        inputEndpoint,
                        buffer,
                        buffer.size,
                        IBASSO_READER_TIMEOUT_MS,
                    )
                    if (length > 0) {
                        routeIbassoReaderPacket(
                            buffer.copyOf(length),
                            controlConnection,
                            eventsEnabled,
                        )
                    } else {
                        SystemClock.sleep(20)
                    }
                }
            } catch (error: Exception) {
                handleIbassoReaderFailure(
                    error,
                    controlConnection,
                    inputEndpoint,
                    eventsEnabled,
                )
            } finally {
                if (ibassoReaderThread === reader) {
                    ibassoReaderRunning.set(false)
                    ibassoReaderThread = null
                }
            }
        }, "ibasso-volume-reader")
        reader.isDaemon = true
        ibassoReaderThread = reader
        reader.start()
    }

    private fun handleIbassoReaderFailure(
        error: Exception,
        controlConnection: UsbDeviceConnection,
        inputEndpoint: UsbEndpoint,
        eventsEnabled: Boolean,
    ) {
        ibassoReaderRunning.set(false)
        failIbassoPendingResponses("iBasso HID reader failed: ${error.message}")
        val health = synchronized(ibassoReaderHealthLock) {
            ibassoReaderHealth = ibassoReaderHealth.afterFailure()
            ibassoReaderHealth
        }
        if (!health.restartRequested) {
            markIbassoWriteOnly(error.message)
            return
        }
        UsbDiagnostics.w(
            tag,
            "iBasso HID reader failed; scheduling one reader-thread restart: ${error.message}",
        )
        mainHandler.postDelayed({
            if (ibassoReaderConnection === controlConnection &&
                ibassoReaderEndpoint === inputEndpoint &&
                ibassoVolumeConnection === controlConnection &&
                !ibassoReaderRunning.get() &&
                ibassoReaderHealth.restartRequested
            ) {
                startIbassoVolumeReader(
                    controlConnection,
                    inputEndpoint,
                    eventsEnabled,
                    restarted = true,
                )
            }
        }, 50L)
    }

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
        updateState(
            currentState + mapOf(
                "hardwareVolumeReader" to "writeOnly",
                "hardwareVolumeWriteOnly" to true,
                "hardwareVolumeReadbackVerified" to false,
            ),
        )
        UsbDiagnostics.w(
            tag,
            "iBasso HID reader failed after one restart; hardware volume is write-only: $message",
        )
    }

    private fun routeIbassoReaderPacket(
        packet: ByteArray,
        readerConnection: UsbDeviceConnection,
        eventsEnabled: Boolean,
    ) {
        val nowMs = SystemClock.elapsedRealtime()
        val recentWrittenRaw = recentIbassoWrittenRaw(
            ibassoLastWrittenRaw,
            ibassoLastWrittenAtMs,
            nowMs,
            IBASSO_WRITE_CONFIRMATION_WINDOW_MS,
        )
        when (
            val route = routeIbassoVolumePacket(
                packet,
                ibassoPendingResponses.keys,
                recentWrittenRaw,
            )
        ) {
            is IbassoVolumePacketRoute.CommandResponse ->
                ibassoPendingResponses[route.command]?.complete(route.packet)
            is IbassoVolumePacketRoute.Event -> {
                if (!eventsEnabled) {
                    UsbDiagnostics.w(tag, "Ignored an unsupported iBasso unsolicited HID event.")
                } else if (route.isWriteConfirmation) {
                    UsbDiagnostics.i(
                        tag,
                        "iBasso hardware volume write confirmation raw=${route.event.leftRaw}.",
                    )
                } else {
                    queueIbassoVolumeEvent(route.event, readerConnection)
                }
            }
            IbassoVolumePacketRoute.Unknown -> UsbDiagnostics.w(
                tag,
                "Unknown iBasso HID packet: " +
                    packet.joinToString(separator = "") { "%02x".format(it.toInt() and 0xff) },
            )
        }
    }

    private fun queueIbassoVolumeEvent(
        event: UsbVolumeEvent,
        readerConnection: UsbDeviceConnection,
    ) {
        val generation = synchronized(ibassoEventLock) {
            ibassoPendingEvent = event
            ++ibassoEventGeneration
        }
        mainHandler.postDelayed({
            val pendingEvent = synchronized(ibassoEventLock) {
                if (generation != ibassoEventGeneration) {
                    null
                } else {
                    ibassoPendingEvent.also { ibassoPendingEvent = null }
                }
            } ?: return@postDelayed
            if (!ibassoReaderRunning.get() || ibassoReaderConnection !== readerConnection) {
                return@postDelayed
            }
            val leftGainQ16 = IbassoDc03ProVolumeProtocol.rawToLinearGainQ16(pendingEvent.leftRaw)
            val rightGainQ16 = IbassoDc03ProVolumeProtocol.rawToLinearGainQ16(pendingEvent.rightRaw)
            val actualGainQ16 = minOf(leftGainQ16, rightGainQ16)
            val actualRaw = if (leftGainQ16 <= rightGainQ16) {
                pendingEvent.leftRaw
            } else {
                pendingEvent.rightRaw
            }
            hardwareVolumeProtocol = IbassoDc03ProVolumeProtocol.id
            hardwareVolumeRaw = actualRaw
            hardwareVolumeGainQ16 = actualGainQ16
            currentState = currentState + mapOf(
                "hardwareVolumeProtocol" to hardwareVolumeProtocol,
                "hardwareVolumeRaw" to actualRaw,
                "hardwareVolumeGainQ16" to actualGainQ16,
                "hardwareVolumeLeftRaw" to pendingEvent.leftRaw,
                "hardwareVolumeRightRaw" to pendingEvent.rightRaw,
            )
            UsbDiagnostics.i(
                tag,
                "iBasso unsolicited hardware volume leftRaw=${pendingEvent.leftRaw}, " +
                    "rightRaw=${pendingEvent.rightRaw}, actualRaw=$actualRaw, " +
                    "gainQ16=$actualGainQ16.",
            )
        }, IBASSO_EVENT_DEBOUNCE_MS)
    }

    private fun failIbassoPendingResponses(message: String) {
        val error = IOException(message)
        ibassoPendingResponses.values.forEach { it.completeExceptionally(error) }
        ibassoPendingResponses.clear()
    }

    private fun closeIbassoVolumeControl() {
        ibassoReaderRunning.set(false)
        val reader = ibassoReaderThread
        ibassoReaderThread = null
        ibassoReaderConnection = null
        ibassoReaderEndpoint = null
        failIbassoPendingResponses("iBasso HID reader stopped.")
        synchronized(ibassoEventLock) {
            ibassoEventGeneration += 1
            ibassoPendingEvent = null
        }
        if (reader != null && reader != Thread.currentThread()) {
            reader.join(250)
        }
        val controlConnection = ibassoVolumeConnection
        val hidInterface = ibassoVolumeInterface
        if (controlConnection != null && hidInterface != null) {
            runCatching { controlConnection.releaseInterface(hidInterface) }
        }
        runCatching { controlConnection?.close() }
        ibassoVolumeConnection = null
        ibassoVolumeInterface = null
        ibassoVolumeDeviceId = null
        synchronized(ibassoReaderHealthLock) {
            ibassoReaderHealth = IbassoReaderHealth()
        }
        ibassoLastWrittenRaw = null
        ibassoLastWrittenAtMs = 0L
    }

    private fun setPcmVolumeGain(targetGainQ16: Int, smooth: Boolean) {
        val startGainQ16 = pcmVolumeGainQ16
        val generation = ++volumeRampGeneration
        if (!smooth || startGainQ16 == targetGainQ16) {
            pcmVolumeGainQ16 = targetGainQ16
            return
        }
        repeat(6) { index ->
            mainHandler.postDelayed({
                if (generation == volumeRampGeneration) {
                    val step = index + 1
                    pcmVolumeGainQ16 = startGainQ16 +
                        ((targetGainQ16 - startGainQ16) * step / 6)
                }
            }, (index + 1) * 20L)
        }
    }

    private fun transferIbassoPacket(
        connection: UsbDeviceConnection,
        packet: ByteArray,
        expectedCommand: Int,
    ): ByteArray? {
        if (ibassoReaderWriteOnly) {
            val result = connection.controlTransfer(
                0x21,
                0x09,
                0x0200,
                0,
                packet,
                packet.size,
                200,
            )
            return if (result == packet.size) {
                ByteArray(16).also { it[6] = expectedCommand.toByte() }
            } else {
                null
            }
        }
        if (!ibassoReaderRunning.get() || ibassoReaderConnection !== connection) return null
        val future = CompletableFuture<ByteArray>()
        if (ibassoPendingResponses.putIfAbsent(expectedCommand, future) != null) return null
        return try {
            val result = connection.controlTransfer(
                0x21,
                0x09,
                0x0200,
                0,
                packet,
                packet.size,
                200,
            )
            if (result != packet.size) {
                null
            } else {
                runCatching { future.get(300, TimeUnit.MILLISECONDS) }.getOrNull()
                    ?: if (ibassoReaderWriteOnly) {
                        ByteArray(16).also { it[6] = expectedCommand.toByte() }
                    } else {
                        null
                    }
            }
        } finally {
            ibassoPendingResponses.remove(expectedCommand, future)
        }
    }

    private fun readHardwareVolumeCurrent(
        connection: UsbDeviceConnection,
        feature: HardwareVolumeFeature,
    ): Int? {
        val data = ByteArray(2)
        val result = connection.controlTransfer(
            hardwareVolumeRequestType(UsbConstants.USB_DIR_IN, feature.recipient),
            if (feature.protocol == "uac2") 0x01 else 0x81,
            (0x02 shl 8) or feature.channel,
            (feature.unitId shl 8) or feature.controlInterface,
            data,
            data.size,
            300,
        )
        return if (result == data.size) readSignedQ8_8(data, 0) else null
    }

    private fun writeHardwareVolumeValue(
        connection: UsbDeviceConnection,
        feature: HardwareVolumeFeature,
        valueQ8_8: Int,
    ): Boolean {
        val data = byteArrayOf(valueQ8_8.toByte(), (valueQ8_8 shr 8).toByte())
        return connection.controlTransfer(
            hardwareVolumeRequestType(UsbConstants.USB_DIR_OUT, feature.recipient),
            0x01,
            (0x02 shl 8) or feature.channel,
            (feature.unitId shl 8) or feature.controlInterface,
            data,
            data.size,
            300,
        ) == data.size
    }

    fun setTargetBufferMs(value: Int): Map<String, Any?> {
        targetBufferMs = value.coerceIn(50, 1000)
        applyNativeTargetBuffer(activePacketsPerSecond)
        if (activePacketsPerSecond > 0) {
            emitTransportTelemetry(activePacketsPerSecond, force = true)
        }
        return currentState + mapOf("targetBufferMs" to targetBufferMs)
    }

    fun stop(): Map<String, Any?> {
        val keepSession = stopWorkerKeepingSession()
        if (keepSession && connection != null) {
            // PCM 与 DSD 都保持等时传输连续；强制清空在途 URB 会造成断流音爆。
            if (shouldFlushOutputOnStop(sessionDsdKind)) {
                UsbExclusiveNative.flushOutput()?.let { error ->
                    UsbDiagnostics.w(tag, "Failed to flush stopped PCM output: $error")
                    hardCloseSession("PCM output flush failed")
                }
            }
            // 空窗期持续垫 DoP/native 静音直到下一首接管或延迟关闭（自然播完时
            // 写线程退出前已启动，重复调用无副作用；PCM 无编码器时为空操作）
            if (connection != null) {
                startDopIdleFiller()
                scheduleDeferredClose()
            }
        }
        return updateState(inactiveState("USB exclusive playback stopped."))
    }

    fun release(): Map<String, Any?> {
        stopWorkerKeepingSession()
        hardCloseSession("release")
        return updateState(inactiveState("USB exclusive playback stopped."))
    }

    // 停写线程；返回 true 表示线程干净退出、USB 会话仍可热复用
    private fun stopWorkerKeepingSession(): Boolean {
        stopped.set(true)
        paused.set(false)
        pendingSeekMs.set(-1L)
        val thread = worker
        worker = null
        if (thread == null || thread == Thread.currentThread()) {
            return !sessionBroken && connection != null
        }
        thread.join(800)
        if (thread.isAlive) {
            // 收不回来（多半阻塞在 native 写的水位回收上），只能硬关让写立即返回
            UsbDiagnostics.w(tag, "exclusive worker join timeout, forcing session close")
            hardCloseSession("worker join timeout")
            thread.join(500)
            return false
        }
        return !sessionBroken && connection != null
    }

    private fun scheduleDeferredClose() {
        mainHandler.removeCallbacks(deferredCloseRunnable)
        mainHandler.postDelayed(deferredCloseRunnable, 4000L)
    }

    // 空窗期（切歌/停止后）持续垫 DSD 静音（0x69）：与写线程互斥（先 join 再启动），
    // DoP 标记相位/native 帧对齐由 sessionDsd 延续，DAC 始终收到合法 DSD 流不掉锁
    private fun startDopIdleFiller() {
        val encoder = sessionDsd ?: return
        val packetizer = sessionPacketizer ?: return
        val frameRate = sessionSampleRate ?: return
        if (idleFillerThread?.isAlive == true) {
            return
        }
        idleFillerRunning.set(true)
        UsbDiagnostics.i(tag, "DSD idle filler started at $frameRate frames/s")
        val thread = Thread({
            // 单次约 10ms 的量，写满水位由 native 阻塞回收自然限速
            val frames = maxOf(1, frameRate / 100)
            try {
                while (idleFillerRunning.get()) {
                    packetizer.write(encoder.encodeSilence(frames))
                }
            } catch (error: Throwable) {
                // 会话已断（拔线/被关），交给延迟关闭兜底
                UsbDiagnostics.w(tag, "DSD idle filler exit: ${error.message}")
            }
        }, "SylvakruUsbDopIdleFill")
        idleFillerThread = thread
        thread.start()
    }

    private fun stopDopIdleFiller() {
        idleFillerRunning.set(false)
        val thread = idleFillerThread ?: return
        idleFillerThread = null
        if (thread != Thread.currentThread()) {
            thread.join(500)
        }
    }

    private fun hardCloseSession(reason: String) {
        if (connection == null && sessionTarget == null) {
            return
        }
        UsbDiagnostics.i(tag, "close exclusive USB session: $reason")
        updateSessionDiagnostics("closed", mapOf("reason" to reason, "atMs" to System.currentTimeMillis()))
        mainHandler.removeCallbacks(deferredCloseRunnable)
        stopDopIdleFiller()
        sessionDsd = null
        sessionPacketizer = null
        sessionDsdKind = null
        sessionNativeFormat = null
        sessionTarget = null
        sessionDeviceId = null
        sessionDevice = null
        sessionSampleRate = null
        sessionChannels = null
        sessionBitDepth = null
        synchronized(volumeLock) {
            hardwareVolumeActive = false
            hardwareVolumeControl = null
            volumeRampGeneration += 1
            closeIbassoVolumeControl()
            UsbExclusiveNative.close()
            connection?.close()
            connection = null
        }
        activePacketsPerSecond = 0
    }

    private fun emitTransportTelemetry(packetsPerSecond: Int, force: Boolean = false) {
        val nowMs = SystemClock.elapsedRealtime()
        if (!force && nowMs - lastTelemetryEmitMs < 100) {
            return
        }
        lastTelemetryEmitMs = nowMs

        val nativeTelemetry = UsbExclusiveNative.transportTelemetry()
        val pendingIsoPackets = nativeTelemetry.getOrNull(0) ?: 0L
        val totalIsoPackets = nativeTelemetry.getOrNull(1) ?: 0L
        val pendingUrbs = nativeTelemetry.getOrNull(2) ?: 0L
        val nativeIsoErrors = nativeTelemetry.getOrNull(3) ?: 0L
        val bufferLevelMs = if (packetsPerSecond > 0) {
            (pendingIsoPackets * 1000L) / packetsPerSecond
        } else {
            0L
        }
        val active = currentState["active"] == true

        if (active && lastTelemetryBufferMs != null && lastTelemetryBufferMs!! > 0 && bufferLevelMs == 0L) {
            zeroBufferUnderruns += 1
        }
        lastTelemetryBufferMs = bufferLevelMs

        if (active && bufferLevelMs > 0) {
            minimumBufferLevelMs = minimumBufferLevelMs?.let { minOf(it, bufferLevelMs) } ?: bufferLevelMs
        }
        val underrunCount = nativeIsoErrors + zeroBufferUnderruns
        if (underrunCount > lastTelemetryUnderrunCount) {
            lastUnderrunAtMs = nowMs
        }
        lastTelemetryUnderrunCount = underrunCount

        emitTelemetry(
            mapOf(
                "active" to active,
                "bufferLevelMs" to if (active) bufferLevelMs else 0L,
                "minimumBufferLevelMs" to minimumBufferLevelMs,
                "targetBufferMs" to targetBufferMs,
                "isoPacketCount" to totalIsoPackets,
                "pendingUrbs" to pendingUrbs,
                "underrunCount" to underrunCount,
                "lastUnderrunAtMs" to lastUnderrunAtMs,
                "updatedAtMs" to nowMs,
            ),
        )
        if (active && sessionStartedAtMs > 0) {
            val elapsedMs = (nowMs - sessionStartedAtMs).coerceAtLeast(0L)
            val submittedBytes = sessionSubmittedBytes.get()
            updateSessionDiagnostics(
                "transport",
                mapOf(
                    "submittedBytes" to submittedBytes,
                    "averageBytesPerSecond" to if (elapsedMs > 0) {
                        submittedBytes * 1000L / elapsedMs
                    } else {
                        0L
                    },
                    "bufferLevelMs" to bufferLevelMs,
                    "minimumBufferLevelMs" to minimumBufferLevelMs,
                    "pendingUrbs" to pendingUrbs,
                    "isoPacketCount" to totalIsoPackets,
                    "underrunCount" to underrunCount,
                    "lastUnderrunAtMs" to lastUnderrunAtMs,
                ),
            )
        }
    }

    private fun recordFeedbackDiagnostics(
        target: OutputTarget,
        actualQ16: Int,
        nominalQ16: Int,
        ignored: Boolean,
    ) {
        if (ignored) {
            sessionFeedbackIgnoredCount += 1
        }
        val actualFrames = actualQ16.toDouble() / 65536.0
        val nominalFrames = nominalQ16.toDouble() / 65536.0
        updateSessionDiagnostics(
            "feedback",
            mapOf(
                "endpoint" to target.feedbackEndpointLabel,
                "actualFrames" to actualFrames,
                "nominalFrames" to nominalFrames,
                "deviationRatio" to if (nominalFrames > 0) actualFrames / nominalFrames else null,
                "ignoredCount" to sessionFeedbackIgnoredCount,
            ),
        )
    }

    private fun emitInactiveTelemetry() {
        lastTelemetryBufferMs = null
        lastTelemetryUnderrunCount = 0L
        lastUnderrunAtMs = null
        emitTelemetry(
            mapOf(
                "active" to false,
                "bufferLevelMs" to 0,
                "minimumBufferLevelMs" to null,
                "targetBufferMs" to targetBufferMs,
                "isoPacketCount" to 0,
                "pendingUrbs" to 0,
                "underrunCount" to 0,
                "lastUnderrunAtMs" to null,
                "updatedAtMs" to SystemClock.elapsedRealtime(),
            ),
        )
    }

    private fun applyNativeTargetBuffer(packetsPerSecond: Int) {
        if (packetsPerSecond <= 0) {
            return
        }
        val packetCount = ((targetBufferMs.toLong() * packetsPerSecond) + 999L) / 1000L
        val maxPendingUrbs = ((packetCount + 15L) / 16L).coerceIn(8L, 512L).toInt()
        UsbExclusiveNative.setMaxPendingOutputUrbs(maxPendingUrbs)
        UsbDiagnostics.i(
            tag,
            "USB target buffer targetMs=$targetBufferMs packetsPerSecond=$packetsPerSecond " +
                "maxPendingUrbs=$maxPendingUrbs",
        )
    }

    private fun decodeAndWrite(
        file: File,
        target: OutputTarget,
        streaming: Boolean = false,
        totalBytes: Long = 0L,
    ) {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var dataSource: GrowingFileDataSource? = null
        var sawInputEos = false
        var outputDone = false
        val info = MediaCodec.BufferInfo()
        val startMs = SystemClock.elapsedRealtime()
        var lastPositionEmitMs = 0L
        var packetizer: PcmIsoPacketizer? = null
        // 流式独占当前应播位置（ms）与缓冲日志去重，语义同 writeRawPcm
        var streamTargetMs = 0L
        var streamBufferingLogged = false

        try {
            if (streaming) {
                dataSource = GrowingFileDataSource(file, RandomAccessFile(file, "r"), totalBytes)
                extractor.setDataSource(dataSource)
            } else {
                extractor.setDataSource(file.absolutePath)
            }
            val trackIndex = findAudioTrack(extractor)
            if (trackIndex < 0) {
                emitError("No audio track was found in ${file.name}.")
                return
            }

            extractor.selectTrack(trackIndex)
            val format = extractor.getTrackFormat(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime.isNullOrBlank()) {
                emitError("Audio MIME type is missing.")
                return
            }

            val durationMs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION) / 1000
            } else {
                null
            }
            val sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                null
            }
            val channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else {
                null
            }

            UsbDiagnostics.i(
                tag,
                "decoder input format=$format, mime=$mime, sampleRate=$sampleRate, channels=$channels, " +
                    "durationMs=$durationMs, endpointInterval=${target.endpoint.interval}",
            )

            if (mime == "audio/raw") {
                writeRawPcm(extractor, file, format, sampleRate, channels, durationMs, target, startMs, streaming)
                return
            }

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            if (sampleRate != null && channels != null) {
                packetizer = createPacketizer(sampleRate, channels, 16, target)
            }

            updateState(
                currentState + mapOf(
                    "active" to true,
                    "playing" to !paused.get(),
                    "durationMs" to durationMs,
                    "sampleRate" to sampleRate,
                    "bitDepth" to (target.usbBitResolution ?: 16),
                    "message" to "USB exclusive decoding ${file.name} to ${target.endpointLabel}, channels=$channels.",
                ),
            )

            while (!stopped.get() && !outputDone) {
                val wasPaused = paused.get()
                if (wasPaused) {
                    UsbDiagnostics.i(tag, "exclusive worker waiting because playback is paused.")
                }
                while (paused.get() && !stopped.get()) {
                    Thread.sleep(25)
                }
                if (wasPaused && !stopped.get()) {
                    UsbDiagnostics.i(tag, "exclusive worker resumed.")
                }
                if (stopped.get()) break

                consumePendingSeekMs()?.let { seekMs ->
                    val seekUs = seekMs * 1000
                    UsbDiagnostics.i(tag, "exclusive decoder seek to ${seekMs}ms.")
                    // seek 不 flush：丢在途 URB 会瞬断 ISO 流出小音爆（与 DoP 同因）。
                    // 只在解码侧跳位，旧缓冲（约一个水位）放完后无缝续上新位置。
                    extractor.seekTo(seekUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    codec.flush()
                    packetizer?.reset()
                    sawInputEos = false
                    outputDone = false
                    lastPositionEmitMs = -1L
                    streamTargetMs = seekMs
                    streamBufferingLogged = false
                    updateState(
                        currentState + mapOf(
                            "active" to true,
                            "playing" to !paused.get(),
                            "positionMs" to seekMs,
                            "message" to "Seeked.",
                        ),
                    )
                }

                if (!sawInputEos) {
                    val inputIndex = codec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex)
                        val sampleSize = if (inputBuffer != null) {
                            extractor.readSampleData(inputBuffer, 0)
                        } else {
                            -1
                        }
                        if (sampleSize < 0) {
                            if (streaming && file.exists()) {
                                // 流式下载未完成，读到 -1 不是真 EOF：seek 落在未下载区或
                                // 顺序播到当前下载末尾。空帧还回 input buffer，等下载推进后
                                // 回到当前位置重探，绝不置 EOS 去跳下一首（跳歌会爆音）。
                                codec.queueInputBuffer(inputIndex, 0, 0, 0, 0)
                                if (!streamBufferingLogged) {
                                    streamBufferingLogged = true
                                    UsbDiagnostics.i(tag, "streaming decoder buffering at ${streamTargetMs}ms, waiting for download")
                                }
                                Thread.sleep(80)
                                if (pendingSeekMs.get() < 0L) {
                                    extractor.seekTo(streamTargetMs * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                                }
                                continue
                            }
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            sawInputEos = true
                        } else {
                            streamBufferingLogged = false
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                sampleSize,
                                extractor.sampleTime,
                                0,
                            )
                            extractor.advance()
                        }
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(info, 10_000)
                if (outputIndex >= 0) {
                    val outputBuffer = codec.getOutputBuffer(outputIndex)
                    if (outputBuffer != null && info.size > 0) {
                        val writer = packetizer
                            ?: createPacketizer(
                                sampleRate ?: 48000,
                                channels ?: 2,
                                16,
                                target,
                            ).also { packetizer = it }
                        writeOutputBuffer(outputBuffer, info, writer)
                    }
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                    codec.releaseOutputBuffer(outputIndex, false)

                    val positionMs = if (info.presentationTimeUs > 0) {
                        info.presentationTimeUs / 1000
                    } else {
                        SystemClock.elapsedRealtime() - startMs
                    }
                    streamTargetMs = positionMs
                    if (positionMs - lastPositionEmitMs >= 250) {
                        lastPositionEmitMs = positionMs
                        updateState(
                            currentState + mapOf(
                                "active" to true,
                                "playing" to !paused.get(),
                                "positionMs" to positionMs,
                            ),
                        )
                    }
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val outputFormat = codec.outputFormat
                    val outputSampleRate = if (outputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    } else {
                        null
                    }
                    val pcmEncoding = if (
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                        outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)
                    ) {
                        outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
                    } else {
                        null
                    }
                    val outputChannels = if (outputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    } else {
                        channels
                    }
                    val outputBitDepth = bitDepthFromPcmEncoding(pcmEncoding)
                    UsbDiagnostics.i(
                        tag,
                        "decoder output format changed: $outputFormat, pcmEncoding=$pcmEncoding, " +
                            "decoderBitDepth=$outputBitDepth, usbBitDepth=${target.usbBitResolution}",
                    )
                    if (outputSampleRate != null && outputChannels != null) {
                        packetizer?.flush()
                        packetizer = createPacketizer(
                            outputSampleRate,
                            outputChannels,
                            outputBitDepth,
                            target,
                        )
                    }
                    updateState(
                        currentState + mapOf(
                            "sampleRate" to outputSampleRate,
                            "bitDepth" to (target.usbBitResolution ?: outputBitDepth),
                        ),
                    )
                }
            }

            UsbDiagnostics.i(tag, "exclusive decode reached end of stream, flushing remainder.")
            packetizer?.flush()
            if (!stopped.get()) {
                workerEndedAtEof = true
                updateState(inactiveState("USB exclusive playback completed."))
            }
        } catch (error: Throwable) {
            UsbDiagnostics.w("UsbExclusiveAudioEngine", "Exclusive playback failed.", error)
            sessionBroken = true
            emitError(error.message ?: "USB exclusive playback failed.")
        } finally {
            try {
                codec?.stop()
            } catch (_: Throwable) {
            }
            codec?.release()
            extractor.release()
            runCatching { dataSource?.close() }
            if (sessionBroken) {
                hardCloseSession("decode worker failed")
            } else {
                // 会话留给下一首热复用，短时间内没有新的 start 再关
                scheduleDeferredClose()
            }
        }
    }

    /**
     * 流式独占的数据源：文件仍在下载增长中。读到未下载区域时等数据，
     * 解码线程随之停在 readSampleData 上，USB 端表现与用户暂停一致（不爆音）；
     * 恢复要求多攒一段余量，避免走走停停。下载完成时 Dart 侧把 .part 改名为
     * 正式缓存名，已打开的 fd 不受影响，据"原路径消失"判断下载结束。
     */
    private inner class GrowingFileDataSource(
        private val partFile: File,
        private val input: RandomAccessFile,
        private val totalBytes: Long = 0L,
    ) : MediaDataSource() {
        private val rebufferBytes = 256L * 1024L
        private var bufferingLogged = false

        override fun readAt(position: Long, buffer: ByteArray, offset: Int, size: Int): Int {
            if (size <= 0) {
                return 0
            }
            var required = position + size
            while (!stopped.get()) {
                val complete = !partFile.exists()
                val length = input.length()
                if (complete || length >= required) {
                    if (position >= length) {
                        return -1
                    }
                    input.seek(position)
                    return input.read(buffer, offset, minOf(size.toLong(), length - position).toInt())
                }
                if (!bufferingLogged) {
                    bufferingLogged = true
                    UsbDiagnostics.i(
                        tag,
                        "streaming source buffering: need=${position + size}, have=$length",
                    )
                }
                required = position + size + rebufferBytes
                Thread.sleep(50)
            }
            return -1
        }

        override fun getSize(): Long {
            // 下载完成后返回真实大小。下载中返回估算总大小（偏大保证 ≥ 真实），
            // 让 MediaExtractor 认定文件有界、可按 FLAC seektable 定位到任意时间点
            // 去 seek 未下载区（readAt 再按当前 .part 长度兜底等待下载）。估算缺失
            // （0）时退回 -1（旧行为：只能顺序解码，seek 未下载区会误判 EOF）。
            if (!partFile.exists()) {
                return input.length()
            }
            return if (totalBytes > 0L) maxOf(totalBytes, input.length()) else -1L
        }

        override fun close() {
            input.close()
        }
    }

    /**
     * DSD 文件的 DoP 输出主循环：DsdFileReader → DopPacketizer → 现有 PcmIsoPacketizer。
     * DoP 帧被当作普通 24-bit PCM 打包（帧率 = DSD 速率 ÷ 16），24→32 slot 的高位对齐
     * 恰好满足 DoP 低 8 位补零的要求，传输层零改动。
     * 关键约束：DoP 路径上不允许任何 DSP（音量/抖动/重采样都会破坏标记、输出全幅噪声）；
     * 暂停时必须持续发 DoP 封装的 0x69 静音——发 PCM 零或停流会让 DAC 掉出 DSD 模式并可能爆音。
     */
    private fun dsdDecodeAndWrite(
        reader: DsdFileReader,
        target: OutputTarget,
        streamingFile: File? = null,
        nativeFormat: String? = null,
    ) {
        var lastPositionEmitMs = 0L
        // 流式下载中的缓冲恢复水位：饥饿后攒到该长度才继续读，避免走走停停
        var streamingResumeBytes = 0L
        var streamingBufferingLogged = false
        // nativeFormat=null 走 DoP（24-bit 帧，帧率=速率÷16）；否则按字节排列直发
        //（帧率=速率÷8÷每采样字节数），两者都复用 PcmIsoPacketizer 的水位/反馈节奏
        val nativeBps = nativeDsdBytesPerSample(nativeFormat)
        val frameRate = if (nativeBps != null) reader.sampleRate / 8 / nativeBps else reader.dopFrameRate
        val frameBitDepth = if (nativeBps != null) nativeBps * 8 else 24
        val modeLabel = if (nativeBps != null) "native($nativeFormat)" else "DoP"
        // 编码相位/帧对齐跨曲目延续：会话存活期间复用同一编码器与打包器
        val dop = sessionDsd ?: run {
            val created: DsdStreamEncoder = if (nativeBps != null) {
                NativeDsdPacketizer(reader.channels, nativeBps, nativeFormat == "u32be")
            } else {
                DopPacketizer(reader.channels)
            }
            sessionDsd = created
            created
        }
        try {
            val packetizer = sessionPacketizer
                ?.also {
                    activePacketsPerSecond = target.packetsPerSecond
                    applyNativeTargetBuffer(target.packetsPerSecond)
                }
                ?: createPacketizer(
                    frameRate,
                    reader.channels,
                    frameBitDepth,
                    target,
                    applyDigitalVolume = false,
                ).also { sessionPacketizer = it }
            updateState(
                currentState + mapOf(
                    "active" to true,
                    "playing" to !paused.get(),
                    "durationMs" to reader.durationMs,
                    "sampleRate" to reader.sampleRate,
                    "bitDepth" to 1,
                    "message" to "USB exclusive $modeLabel streaming DSD${reader.dsdMultiple ?: ""} " +
                        "(${reader.formatName}) to ${target.endpointLabel}.",
                ),
            )

            // 单次读写约 10 ms 的量；写满水位后由 native 阻塞回收自然限速
            val silenceFramesPerWrite = maxOf(1, frameRate / 100)
            val buffer = ByteArray(reader.channels * (nativeBps ?: 2) * silenceFramesPerWrite)

            while (!stopped.get()) {
                consumePendingSeekMs()?.let { seekMs ->
                    // DoP seek 不 flush 也不复位：丢 URB 会瞬断 ISO 流让 DAC
                    // 掉出 DSD 模式再重锁（就是 seek 咔嗒声）。旧缓冲（约一个
                    // 水位）放完无缝续上新位置，标记相位全程连续；先把不足
                    // 一帧的余量补齐保持帧对齐
                    packetizer.write(dop.drain())
                    val actualMs = reader.seekTo(seekMs)
                    lastPositionEmitMs = -1L
                    updateState(
                        currentState + mapOf(
                            "active" to true,
                            "playing" to !paused.get(),
                            "positionMs" to actualMs,
                            "message" to "Seeked.",
                        ),
                    )
                }

                if (paused.get()) {
                    packetizer.write(dop.encodeSilence(silenceFramesPerWrite))
                    continue
                }

                // 流式下载：数据没跟上时垫 DSD 静音等下载，保持 DAC 停留在 DSD
                // 模式（DoP/native 都绝不能断流，断点样本也不能修改，只能发 0x69）
                if (streamingFile != null && streamingFile.exists()) {
                    val length = streamingFile.length()
                    val ready = reader.canReadAt(length) &&
                        (streamingResumeBytes == 0L || length >= streamingResumeBytes)
                    if (!ready) {
                        if (streamingResumeBytes == 0L) {
                            streamingResumeBytes = length + 256L * 1024L
                        }
                        if (!streamingBufferingLogged) {
                            streamingBufferingLogged = true
                            UsbDiagnostics.i(
                                tag,
                                "DSD streaming buffering at ${reader.positionMs}ms, have=$length",
                            )
                        }
                        packetizer.write(dop.encodeSilence(silenceFramesPerWrite))
                        continue
                    }
                    streamingResumeBytes = 0L
                    streamingBufferingLogged = false
                }

                val count = reader.read(buffer)
                if (count < 0) {
                    // 结尾不足一帧的余量补 0x69，再垫约 200ms 静音把尾部完整送出，
                    // 同时盖住自动切歌的空窗，DAC 不掉出 DSD 模式
                    packetizer.write(dop.drain())
                    packetizer.write(dop.encodeSilence(silenceFramesPerWrite * 20))
                    packetizer.flush()
                    break
                }
                packetizer.write(dop.encode(buffer, count))

                val positionMs = reader.positionMs
                if (positionMs - lastPositionEmitMs >= 250) {
                    lastPositionEmitMs = positionMs
                    updateState(
                        currentState + mapOf(
                            "active" to true,
                            "playing" to !paused.get(),
                            "positionMs" to positionMs,
                        ),
                    )
                }
            }

            UsbDiagnostics.i(tag, "exclusive DSD playback reached end of stream.")
            if (!stopped.get()) {
                workerEndedAtEof = true
                updateState(inactiveState("USB exclusive playback completed."))
            }
        } catch (error: Throwable) {
            UsbDiagnostics.w(tag, "Exclusive DSD playback failed.", error)
            sessionBroken = true
            emitError(error.message ?: "USB exclusive DSD playback failed.")
        } finally {
            runCatching { reader.close() }
            if (sessionBroken) {
                hardCloseSession("DSD worker failed")
            } else {
                // 会话留给下一首热复用；自然播完立即接上空窗静音填充，
                // 短时间内没有新的 start 再由延迟关闭拆链路
                if (workerEndedAtEof) {
                    startDopIdleFiller()
                }
                scheduleDeferredClose()
            }
        }
    }

    private fun writeRawPcm(
        extractor: MediaExtractor,
        file: File,
        format: MediaFormat,
        sampleRate: Int?,
        channels: Int?,
        durationMs: Long?,
        target: OutputTarget,
        startMs: Long,
        streaming: Boolean = false,
    ) {
        if (sampleRate == null || channels == null) {
            emitError("Raw PCM stream is missing sample rate or channel count.")
            return
        }

        val pcmEncoding = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
            format.containsKey(MediaFormat.KEY_PCM_ENCODING)
        ) {
            format.getInteger(MediaFormat.KEY_PCM_ENCODING)
        } else {
            null
        }
        val containerBitDepth = if (format.containsKey("bits-per-sample")) {
            format.getInteger("bits-per-sample")
        } else {
            null
        }
        val sourceBitDepth = pcmEncoding
            ?.let { bitDepthFromPcmEncoding(it) }
            ?: containerBitDepth
            ?: 16
        val maxInputSize = if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
            format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE).coerceAtLeast(4096)
        } else {
            64 * 1024
        }
        val buffer = ByteBuffer.allocate(maxInputSize)
        val packetizer = createPacketizer(sampleRate, channels, sourceBitDepth, target)
        var lastPositionEmitMs = 0L
        var lastSampleTimeUs: Long? = null
        var rawChunkLogCount = 0
        // 流式独占当前应播位置（ms）：读到已下载末尾或 seek 落在未下载区时，
        // 回到这里重试，绝不误判成播放结束去跳下一首
        var streamTargetMs = 0L
        var streamBufferingLogged = false

        UsbDiagnostics.i(
            tag,
            "raw PCM direct path sampleRate=$sampleRate, channels=$channels, " +
                "sourceBitDepth=$sourceBitDepth, pcmEncoding=$pcmEncoding, " +
                "containerBitDepth=$containerBitDepth, maxInputSize=$maxInputSize, " +
                "targetBitDepth=${target.usbBitResolution}",
        )
        updateState(
            currentState + mapOf(
                "active" to true,
                "playing" to !paused.get(),
                "durationMs" to durationMs,
                "sampleRate" to sampleRate,
                "bitDepth" to (target.usbBitResolution ?: sourceBitDepth),
                "message" to "USB exclusive streaming raw PCM ${file.name} to ${target.endpointLabel}.",
            ),
        )

        while (!stopped.get()) {
            val wasPaused = paused.get()
            if (wasPaused) {
                UsbDiagnostics.i(tag, "exclusive worker waiting because playback is paused.")
            }
            while (paused.get() && !stopped.get()) {
                Thread.sleep(25)
            }
            if (wasPaused && !stopped.get()) {
                UsbDiagnostics.i(tag, "exclusive worker resumed.")
            }
            if (stopped.get()) break

            consumePendingSeekMs()?.let { seekMs ->
                val seekUs = seekMs * 1000
                UsbDiagnostics.i(tag, "exclusive raw PCM seek to ${seekMs}ms.")
                // seek 不 flush：丢在途 URB 会瞬断 ISO 流出小音爆（与 DoP 同因）。
                // 只在解码侧跳位，旧缓冲（约一个水位）放完后无缝续上新位置。
                extractor.seekTo(seekUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                packetizer.reset()
                lastPositionEmitMs = -1L
                lastSampleTimeUs = null
                streamTargetMs = seekMs
                streamBufferingLogged = false
                updateState(
                    currentState + mapOf(
                        "active" to true,
                        "playing" to !paused.get(),
                        "positionMs" to seekMs,
                        "message" to "Seeked.",
                    ),
                )
            }

            buffer.clear()
            val sampleTimeUs = extractor.sampleTime
            val sampleSize = extractor.readSampleData(buffer, 0)
            if (sampleSize < 0) {
                // 流式下载没结束时，读到 -1 不是真 EOF：多半是 seek 落在尚未下载的
                // 区段，或顺序播到了当前下载末尾。等下载推进后回到当前位置重探，
                // 绝不当成播完去跳下一首（跳歌会重建会话、DAC 重锁并爆音）。
                // 循环顶部照常响应停止/暂停/新的用户 seek，不会卡死。
                if (streaming && file.exists()) {
                    if (!streamBufferingLogged) {
                        streamBufferingLogged = true
                        UsbDiagnostics.i(tag, "streaming raw PCM buffering at ${streamTargetMs}ms, waiting for download")
                    }
                    Thread.sleep(80)
                    // 没有更新的用户 seek 时重探当前位置；有的话留给顶部消费新目标
                    if (pendingSeekMs.get() < 0L) {
                        extractor.seekTo(streamTargetMs * 1000, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                    }
                    continue
                }
                break
            }
            streamBufferingLogged = false
            val data = ByteArray(sampleSize)
            buffer.position(0)
            buffer.limit(sampleSize)
            buffer.get(data)
            if (rawChunkLogCount < 12) {
                val frameBytes = channels * bytesPerSampleForBitDepth(sourceBitDepth)
                val frames = if (frameBytes > 0) sampleSize / frameBytes else 0
                val deltaUs = lastSampleTimeUs?.let { sampleTimeUs - it }
                UsbDiagnostics.i(
                    tag,
                    "raw PCM chunk size=$sampleSize, sampleTimeUs=$sampleTimeUs, " +
                        "deltaUs=${deltaUs ?: "n/a"}, frames=$frames, frameBytes=$frameBytes, " +
                        "sourceBitDepth=$sourceBitDepth",
                )
                rawChunkLogCount++
            }
            lastSampleTimeUs = sampleTimeUs
            if (sampleTimeUs > 0) {
                streamTargetMs = sampleTimeUs / 1000
            }
            packetizer.write(data)

            val positionMs = if (sampleTimeUs > 0) {
                sampleTimeUs / 1000
            } else {
                SystemClock.elapsedRealtime() - startMs
            }
            if (positionMs - lastPositionEmitMs >= 250) {
                lastPositionEmitMs = positionMs
                updateState(
                    currentState + mapOf(
                        "active" to true,
                        "playing" to !paused.get(),
                        "positionMs" to positionMs,
                    ),
                )
            }
            extractor.advance()
        }

        UsbDiagnostics.i(
            tag,
            "exclusive raw PCM loop exit: stopped=${stopped.get()}, streaming=$streaming, " +
                "partExists=${file.exists()}, lastPos=${streamTargetMs}ms",
        )
        packetizer.flush()
        if (!stopped.get()) {
            workerEndedAtEof = true
            updateState(inactiveState("USB exclusive playback completed."))
        }
    }

    private fun createPacketizer(
        sampleRate: Int,
        channels: Int,
        bitDepth: Int,
        target: OutputTarget,
        applyDigitalVolume: Boolean = true,
    ): PcmIsoPacketizer {
        val inputBytesPerSample = bytesPerSampleForBitDepth(bitDepth)
        val usbBytesPerSample = target.usbBytesPerSample
        val usbBitResolution = target.usbBitResolution ?: (usbBytesPerSample * 8)
        UsbDiagnostics.i(
            tag,
            "USB PCM packetizer sampleRate=$sampleRate, channels=$channels, " +
                "decoderBitDepth=$bitDepth, inputBytesPerSample=$inputBytesPerSample, " +
                "usbBytesPerSample=$usbBytesPerSample, usbBitResolution=$usbBitResolution, " +
                "packetsPerSecond=${target.packetsPerSecond}, endpointInterval=${target.endpoint.interval}, " +
                "format=${target.formatInfo}",
        )
        val packetBytes = requiredIsoPacketBytes(
            sampleRate,
            target.packetsPerSecond,
            channels,
            usbBytesPerSample,
        )
        activePacketsPerSecond = target.packetsPerSecond
        applyNativeTargetBuffer(target.packetsPerSecond)
        UsbExclusiveNative.setIsoPacketSize(packetBytes)
        val outputIntervalMicroframes = isoIntervalMicroframes(target.endpoint.interval)
        val feedbackOutputPacketDivisor = target.feedbackEndpoint?.let {
            val feedbackIntervalMicroframes = isoIntervalMicroframes(it.interval)
            UsbDiagnostics.i(
                tag,
                "USB feedback intervals outputMicroframes=$outputIntervalMicroframes, " +
                    "feedbackMicroframes=$feedbackIntervalMicroframes",
            )
            1
        } ?: 1
        UsbDiagnostics.i(
            tag,
            "USB feedback scaling outputIntervalMicroframes=$outputIntervalMicroframes, " +
                "feedbackDivisor=$feedbackOutputPacketDivisor, feedback=${target.feedbackEndpointLabel}",
        )
        return PcmIsoPacketizer(
            sampleRate,
            target.packetsPerSecond,
            channels,
            inputBytesPerSample,
            bitDepth,
            usbBytesPerSample,
            usbBitResolution,
            feedbackOutputPacketDivisor,
            feedbackFramesPerPacketQ16 = target.feedbackEndpoint?.let {
                { UsbExclusiveNative.feedbackFramesPerPacketQ16() }
            },
            reportFeedback = { actualQ16, nominalQ16, ignored ->
                recordFeedbackDiagnostics(target, actualQ16, nominalQ16, ignored)
            },
            volumeGainQ16 = if (applyDigitalVolume) {
                { pcmVolumeGainQ16 }
            } else {
                null
            },
        ) { data, packetLengths, packetCount ->
            val error = UsbExclusiveNative.writeIsoPackets(data, packetLengths, packetCount)
            if (error != null) {
                throw IllegalStateException(error)
            }
            sessionSubmittedBytes.addAndGet(data.size.toLong())
            emitTransportTelemetry(target.packetsPerSecond)
        }
    }

    /**
     * 配置 DAC 时钟到 [sampleRate]。返回 null 表示可以继续；返回非 null 的原因字符串表示
     * 校验到时钟与请求不一致（GET_CUR 读回一个有效且不同的采样率），调用方应据此回退系统输出。
     * 注意：很多 DAC（如 Macaron）SET_CUR 成功但 GET_CUR 恒返回 0，属于“不报告实际值”，
     * 不能当成不一致——否则会把本可正常独占的设备误判成失败。只有读回“有效非零且不同”才判失败。
     */
    private fun configureUsbAudioClock(
        connection: UsbDeviceConnection,
        device: UsbDevice,
        target: OutputTarget,
        sampleRate: Int,
        quirk: DacQuirk = DacQuirk(),
    ): String? {
        val controlInterface = findAudioControlInterface(device)
        val controlInterfaceNumber = controlInterface?.id ?: target.usbInterface.id
        val clockSourceId = findUac2ClockSourceId(
            connection.rawDescriptors,
            streamingInterfaceNumber = target.usbInterface.id,
            streamingAlternateSetting = target.alternateSetting,
        )

        val claimedControl = controlInterface?.let {
            runCatching { connection.claimInterface(it, true) }.getOrDefault(false)
        } == true
        try {
            if (clockSourceId != null) {
                val beforeReadBack = readUac2ClockSampleRate(
                    connection,
                    clockSourceId,
                    controlInterfaceNumber,
                    "before",
                )
                val data = byteArrayOf(
                    (sampleRate and 0xff).toByte(),
                    ((sampleRate ushr 8) and 0xff).toByte(),
                    ((sampleRate ushr 16) and 0xff).toByte(),
                    ((sampleRate ushr 24) and 0xff).toByte(),
                )
                val result = connection.controlTransfer(
                    UsbConstants.USB_DIR_OUT or UsbConstants.USB_TYPE_CLASS or USB_RECIP_INTERFACE,
                    0x01,
                    0x01 shl 8,
                    (clockSourceId shl 8) or controlInterfaceNumber,
                    data,
                    data.size,
                    1000,
                )
                UsbDiagnostics.i(
                    tag,
                    "UAC2 clock SET_CUR sampleRate=$sampleRate, clockSourceId=$clockSourceId, " +
                    "controlInterface=$controlInterfaceNumber, result=$result",
                )
                // quirk：部分 DAC SET_CUR 后需要几十 ms 才锁定新时钟
                if (quirk.clockSetCurDelayMs > 0) {
                    Thread.sleep(quirk.clockSetCurDelayMs.toLong())
                }
                if (quirk.clockSkipGetCurValidation) {
                    // quirk：个别设备 GET_CUR 返回垃圾但 SET_CUR 实际生效
                    updateSessionDiagnostics(
                        "clock",
                        mapOf(
                            "protocol" to "uac2",
                            "sampleRate" to sampleRate,
                            "clockSourceId" to clockSourceId,
                            "controlInterface" to controlInterfaceNumber,
                            "beforeReadBack" to beforeReadBack,
                            "setCurResult" to result,
                            "setCurDelayMs" to quirk.clockSetCurDelayMs,
                            "skipGetCurValidation" to true,
                        ),
                    )
                    return null
                }
                val readBack = readUac2ClockSampleRate(
                    connection,
                    clockSourceId,
                    controlInterfaceNumber,
                    "after",
                )
                updateSessionDiagnostics(
                    "clock",
                    mapOf(
                        "protocol" to "uac2",
                        "sampleRate" to sampleRate,
                        "clockSourceId" to clockSourceId,
                        "controlInterface" to controlInterfaceNumber,
                        "beforeReadBack" to beforeReadBack,
                        "setCurResult" to result,
                        "setCurDelayMs" to quirk.clockSetCurDelayMs,
                        "skipGetCurValidation" to false,
                        "readBack" to readBack,
                    ),
                )
                if (readBack != null && readBack > 0 && readBack != sampleRate) {
                    UsbDiagnostics.w(
                        tag,
                        "UAC2 clock mismatch: requested=$sampleRate readBack=$readBack; " +
                            "falling back to system output.",
                    )
                    return "DAC 未接受采样率 ${sampleRate}Hz（读回 ${readBack}Hz），已回退系统输出。"
                }
                return null
            }

            val data = byteArrayOf(
                (sampleRate and 0xff).toByte(),
                ((sampleRate ushr 8) and 0xff).toByte(),
                ((sampleRate ushr 16) and 0xff).toByte(),
            )
            val result = connection.controlTransfer(
                UsbConstants.USB_DIR_OUT or UsbConstants.USB_TYPE_CLASS or USB_RECIP_ENDPOINT,
                0x01,
                0x01 shl 8,
                target.endpoint.address,
                data,
                data.size,
                1000,
            )
            UsbDiagnostics.i(
                tag,
                "UAC1 endpoint SET_CUR sampleRate=$sampleRate, endpoint=0x${
                    target.endpoint.address.toString(16)
                }, result=$result",
            )
            if (quirk.clockSetCurDelayMs > 0) {
                Thread.sleep(quirk.clockSetCurDelayMs.toLong())
            }
            updateSessionDiagnostics(
                "clock",
                mapOf(
                    "protocol" to "uac1",
                    "sampleRate" to sampleRate,
                    "controlInterface" to controlInterfaceNumber,
                    "endpoint" to "0x${target.endpoint.address.toString(16)}",
                    "setCurResult" to result,
                    "setCurDelayMs" to quirk.clockSetCurDelayMs,
                ),
            )
            return null
        } catch (error: RuntimeException) {
            UsbDiagnostics.w(tag, "USB audio clock configuration failed.", error)
            updateSessionDiagnostics(
                "clock",
                mapOf(
                    "sampleRate" to sampleRate,
                    "error" to (error.message ?: error.javaClass.simpleName),
                ),
            )
            return null
        } finally {
            controlInterface?.let { usbInterface ->
                if (claimedControl) {
                    runCatching { connection.releaseInterface(usbInterface) }
                }
            }
        }
    }

    private fun readUac2ClockSampleRate(
        connection: UsbDeviceConnection,
        clockSourceId: Int,
        controlInterfaceNumber: Int,
        label: String,
    ): Int? {
        val data = ByteArray(4)
        val result = connection.controlTransfer(
            UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_CLASS or USB_RECIP_INTERFACE,
            0x81,
            0x01 shl 8,
            (clockSourceId shl 8) or controlInterfaceNumber,
            data,
            data.size,
            1000,
        )
        val sampleRate = if (result == 4) {
            (data[0].toInt() and 0xff) or
                ((data[1].toInt() and 0xff) shl 8) or
                ((data[2].toInt() and 0xff) shl 16) or
                ((data[3].toInt() and 0xff) shl 24)
        } else {
            null
        }
        UsbDiagnostics.i(
            tag,
            "UAC2 clock GET_CUR $label result=$result, clockSourceId=$clockSourceId, " +
                "controlInterface=$controlInterfaceNumber, sampleRate=${sampleRate ?: "n/a"}, " +
                "raw=${hexPreview(data)}",
        )
        return sampleRate
    }

    private fun hexPreview(data: ByteArray, limit: Int = 16): String =
        data.take(minOf(data.size, limit)).joinToString(" ") { byte ->
            (byte.toInt() and 0xff).toString(16).padStart(2, '0')
        }

    private fun findAudioControlInterface(device: UsbDevice, interfaceNumber: Int? = null): UsbInterface? {
        for (index in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(index)
            if (
                usbInterface.interfaceClass == UsbConstants.USB_CLASS_AUDIO &&
                usbInterface.interfaceSubclass == 1 &&
                (interfaceNumber == null || usbInterface.id == interfaceNumber)
            ) {
                return usbInterface
            }
        }
        return null
    }

    private fun writeOutputBuffer(
        outputBuffer: ByteBuffer,
        info: MediaCodec.BufferInfo,
        packetizer: PcmIsoPacketizer,
    ) {
        val data = ByteArray(info.size)
        outputBuffer.position(info.offset)
        outputBuffer.limit(info.offset + info.size)
        outputBuffer.get(data)
        packetizer.write(data)
    }

    private fun findAudioTrack(extractor: MediaExtractor): Int {
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                return index
            }
        }
        return -1
    }

    private fun collectOutputCandidates(
        device: UsbDevice,
        streamingFormats: Map<Pair<Int, Int>, StreamingFormatInfo>,
    ): List<OutputTarget> {
        val candidates = mutableListOf<OutputTarget>()
        for (index in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(index)
            if (usbInterface.interfaceClass != UsbConstants.USB_CLASS_AUDIO) {
                continue
            }
            for (endpointIndex in 0 until usbInterface.endpointCount) {
                val endpoint = usbInterface.getEndpoint(endpointIndex)
                if (
                    endpoint.direction == UsbConstants.USB_DIR_OUT &&
                    endpoint.type == UsbConstants.USB_ENDPOINT_XFER_ISOC
                ) {
                    val alt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        usbInterface.alternateSetting
                    } else {
                        0
                    }
                    candidates += OutputTarget(
                        usbInterface = usbInterface,
                        endpoint = endpoint,
                        feedbackEndpoint = findFeedbackEndpoint(usbInterface),
                        formatInfo = streamingFormats[usbInterface.id to alt],
                    )
                }
            }
        }
        return candidates
    }

    /**
     * 汇总诊断报告所需的“App 解析结果”部分（原始描述符、AS 格式、输出候选、UAC2 时钟源）。
     * 只在有权限时临时打开设备读取描述符，读完即关，不影响正在进行的独占播放。
     */
    fun collectDiagnostics(usbManager: UsbManager, device: UsbDevice?): Map<String, Any?> {
        val session = sessionDiagnosticsSnapshot()
        if (device == null) {
            return mapOf(
                "available" to false,
                "message" to "未检测到 USB 音频设备。",
                "session" to session,
            )
        }
        if (!usbManager.hasPermission(device)) {
            return mapOf(
                "available" to false,
                "permissionGranted" to false,
                "message" to "未授权，无法读取描述符。",
                "session" to session,
            )
        }

        val connection = usbManager.openDevice(device)
            ?: return mapOf(
                "available" to false,
                "permissionGranted" to true,
                "message" to "无法打开 USB 设备读取描述符。",
                "session" to session,
            )

        return try {
            val descriptors = connection.rawDescriptors
            val streamingFormats = parseStreamingFormatInfo(descriptors)
            val candidates = collectOutputCandidates(device, streamingFormats)
                .sortedWith(compareBy<OutputTarget> { it.endpoint.maxPacketSize }.thenBy { it.alternateSetting })
            val clockSourceId = candidates.firstOrNull()?.let {
                findUac2ClockSourceId(descriptors, it.usbInterface.id, it.alternateSetting)
            }
            mapOf(
                "available" to true,
                "permissionGranted" to true,
                "rawDescriptorLength" to (descriptors?.size ?: 0),
                "rawDescriptorsHex" to descriptors?.let { hexDump(it) },
                "streamingFormats" to streamingFormats.values
                    .sortedWith(compareBy<StreamingFormatInfo> { it.interfaceNumber }.thenBy { it.alternateSetting })
                    .map { it.toString() },
                "outputCandidates" to candidates.map { candidate ->
                    "alt=${candidate.alternateSetting}/max=${candidate.endpoint.maxPacketSize}/" +
                        "outAttr=0x${candidate.endpoint.attributes.toString(16)}/" +
                        "interval=${candidate.endpoint.interval}/" +
                        "feedback=${candidate.feedbackEndpointLabel}/" +
                        "usbBytes=${candidate.usbBytesPerSample}/bits=${candidate.usbBitResolution}/" +
                        "raw=${candidate.isRawData}/" +
                        "format=${candidate.formatInfo}"
                },
                "clockSourceId" to clockSourceId,
                "session" to session,
                "hardwareVolume" to collectHardwareVolumeDiagnostics(
                    connection,
                    device,
                    descriptors,
                ),
                // quirk 匹配结果：命中哪条 / 未命中用默认值，以及各字段生效值
                "quirkMatch" to (UsbDacQuirks.matchDescription(
                    context,
                    device.vendorId,
                    device.productId,
                ) ?: "none (defaults)"),
                "quirkEffective" to UsbDacQuirks.forDevice(
                    context,
                    device.vendorId,
                    device.productId,
                ).toString(),
                "quirkLoadErrors" to UsbDacQuirks.loadErrors(context)
                    .joinToString("; ")
                    .takeIf { it.isNotEmpty() },
            )
        } catch (error: RuntimeException) {
            mapOf(
                "available" to false,
                "permissionGranted" to true,
                "message" to "读取描述符失败：${error.message}",
                "session" to session,
            )
        } finally {
            connection.close()
        }
    }

    private data class HardwareVolumeControl(
        val features: List<HardwareVolumeFeature>,
        val range: HardwareVolumeRange,
        val source: String,
    )

    private fun collectHardwareVolumeDiagnostics(
        connection: UsbDeviceConnection,
        device: UsbDevice,
        descriptors: ByteArray?,
    ): Map<String, Any?> {
        val features = parseHardwareVolumeFeatures(descriptors).toMutableList()
        val quirk = UsbDacQuirks.forDevice(context, device.vendorId, device.productId)
        val quirkOverride = buildMap<String, Any> {
            quirk.hardwareVolumeFeatureUnitId?.let { put("featureUnitId", it) }
            quirk.hardwareVolumeControlInterface?.let { put("controlInterface", it) }
            if (quirk.hardwareVolumeChannels.isNotEmpty()) {
                put("channels", quirk.hardwareVolumeChannels)
            }
            quirk.hardwareVolumeProtocol?.let { put("protocol", it) }
            put("recipient", quirk.hardwareVolumeRecipient)
            hardwareVolumeRangeOverride(quirk)?.let {
                put(
                    "range",
                    mapOf(
                        "minQ8_8Db" to it.minQ8_8,
                        "maxQ8_8Db" to it.maxQ8_8,
                        "stepQ8_8Db" to it.stepQ8_8,
                        "muteQ8_8Db" to it.muteQ8_8,
                    ),
                )
            }
            quirk.hardwareVolumeEnabled?.let { put("enabled", it) }
            quirk.hardwareVolumeDsdSupported?.let { put("dsdSupported", it) }
        }
        val quirkUnitId = quirk.hardwareVolumeFeatureUnitId
        val quirkInterface = quirk.hardwareVolumeControlInterface
        if (
            quirkUnitId != null &&
            quirkInterface != null &&
            features.none { it.unitId == quirkUnitId && it.controlInterface == quirkInterface }
        ) {
            val protocol = quirk.hardwareVolumeProtocol
                ?.takeIf { it == "uac1" || it == "uac2" } ?: if (
                findAudioControlInterface(device, quirkInterface)?.interfaceProtocol == 0x20
            ) {
                "uac2"
            } else {
                "uac1"
            }
            features += quirk.hardwareVolumeChannels.ifEmpty { listOf(0) }.map { channel ->
                HardwareVolumeFeature(
                    protocol = protocol,
                    controlInterface = quirkInterface,
                    unitId = quirkUnitId,
                    sourceId = -1,
                    channel = channel,
                    writable = true,
                    recipient = quirk.hardwareVolumeRecipient,
                )
            }
        }
        if (features.isEmpty()) {
            return mapOf(
                "available" to false,
                "featureUnits" to emptyList<String>(),
                "quirkOverride" to quirkOverride,
            )
        }

        val overrideRange = hardwareVolumeRangeOverride(quirk)
        val probes = features
            .groupBy { Triple(it.protocol, it.controlInterface, it.unitId) }
            .values
            .flatMap { group ->
                val feature = group.first()
                val controlInterface = findAudioControlInterface(device, feature.controlInterface)
                val requiresClaim = hardwareVolumeRequiresInterfaceClaim(feature.recipient)
                val claimed = !requiresClaim || controlInterface?.let {
                    runCatching { connection.claimInterface(it, true) }.getOrDefault(false)
                } == true
                if (!claimed) {
                    listOf(
                        mapOf(
                            "protocol" to feature.protocol,
                            "controlInterface" to feature.controlInterface,
                            "featureUnitId" to feature.unitId,
                            "error" to "Failed to claim AudioControl interface.",
                        ),
                    )
                } else {
                    try {
                        group.sortedBy { it.channel }.map {
                            readHardwareVolumeProbe(connection, it, overrideRange)
                        }
                    } finally {
                        if (requiresClaim) {
                            runCatching { connection.releaseInterface(controlInterface!!) }
                        }
                    }
                }
            }
        return mapOf(
            "available" to true,
            "featureUnits" to features.map { it.description() },
            "probes" to probes,
            "quirkOverride" to quirkOverride,
        )
    }

    private fun parseHardwareVolumeFeatures(descriptors: ByteArray?): List<HardwareVolumeFeature> {
        if (descriptors == null) {
            return emptyList()
        }
        val features = mutableListOf<HardwareVolumeFeature>()
        var offset = 0
        var interfaceNumber = -1
        var interfaceClass = -1
        var interfaceSubclass = -1
        var interfaceProtocol = -1
        while (offset + 1 < descriptors.size) {
            val length = descriptors[offset].toInt() and 0xff
            val descriptorType = descriptors[offset + 1].toInt() and 0xff
            if (length < 2 || offset + length > descriptors.size) {
                break
            }
            if (descriptorType == 0x04 && length >= 9) {
                interfaceNumber = descriptors[offset + 2].toInt() and 0xff
                interfaceClass = descriptors[offset + 5].toInt() and 0xff
                interfaceSubclass = descriptors[offset + 6].toInt() and 0xff
                interfaceProtocol = descriptors[offset + 7].toInt() and 0xff
            } else if (
                descriptorType == 0x24 &&
                interfaceClass == UsbConstants.USB_CLASS_AUDIO &&
                interfaceSubclass == 1 &&
                length >= 7 &&
                (descriptors[offset + 2].toInt() and 0xff) == 0x06
            ) {
                if (interfaceProtocol == 0x20) {
                    val controlCount = (length - 6) / 4
                    for (channel in 0 until controlCount) {
                        val controlOffset = offset + 5 + channel * 4
                        val controls = (descriptors[controlOffset].toInt() and 0xff) or
                            ((descriptors[controlOffset + 1].toInt() and 0xff) shl 8) or
                            ((descriptors[controlOffset + 2].toInt() and 0xff) shl 16) or
                            ((descriptors[controlOffset + 3].toInt() and 0xff) shl 24)
                        val volumeControl = (controls ushr 2) and 0x03
                        val writable = when (volumeControl) {
                            0x01 -> false
                            0x03 -> true
                            else -> null
                        } ?: continue
                        features += HardwareVolumeFeature(
                            protocol = "uac2",
                            controlInterface = interfaceNumber,
                            unitId = descriptors[offset + 3].toInt() and 0xff,
                            sourceId = descriptors[offset + 4].toInt() and 0xff,
                            channel = channel,
                            writable = writable,
                        )
                    }
                } else {
                    val controlSize = descriptors[offset + 5].toInt() and 0xff
                    if (controlSize in 1..4) {
                        val controlCount = (length - 7) / controlSize
                        for (channel in 0 until controlCount) {
                            var controls = 0
                            for (byteIndex in 0 until controlSize) {
                                controls = controls or (
                                    (descriptors[offset + 6 + channel * controlSize + byteIndex].toInt() and 0xff) shl
                                        (byteIndex * 8)
                                    )
                            }
                            if (controls and 0x02 == 0) {
                                continue
                            }
                            features += HardwareVolumeFeature(
                                protocol = "uac1",
                                controlInterface = interfaceNumber,
                                unitId = descriptors[offset + 3].toInt() and 0xff,
                                sourceId = descriptors[offset + 4].toInt() and 0xff,
                                channel = channel,
                                writable = true,
                            )
                        }
                    }
                }
            }
            offset += length
        }
        return features
    }

    private fun parseOutputTerminalSources(descriptors: ByteArray?): Set<Int> {
        if (descriptors == null) {
            return emptySet()
        }
        val sources = mutableSetOf<Int>()
        var offset = 0
        var interfaceClass = -1
        var interfaceSubclass = -1
        while (offset + 1 < descriptors.size) {
            val length = descriptors[offset].toInt() and 0xff
            val descriptorType = descriptors[offset + 1].toInt() and 0xff
            if (length < 2 || offset + length > descriptors.size) {
                break
            }
            if (descriptorType == 0x04 && length >= 9) {
                interfaceClass = descriptors[offset + 5].toInt() and 0xff
                interfaceSubclass = descriptors[offset + 6].toInt() and 0xff
            } else if (
                descriptorType == 0x24 &&
                interfaceClass == UsbConstants.USB_CLASS_AUDIO &&
                interfaceSubclass == 1 &&
                length >= 8 &&
                (descriptors[offset + 2].toInt() and 0xff) == 0x03
            ) {
                sources += descriptors[offset + 7].toInt() and 0xff
            }
            offset += length
        }
        return sources
    }

    private fun readHardwareVolumeRangeValue(
        connection: UsbDeviceConnection,
        feature: HardwareVolumeFeature,
    ): HardwareVolumeRange? {
        val requestType = hardwareVolumeRequestType(UsbConstants.USB_DIR_IN, feature.recipient)
        val value = (0x02 shl 8) or feature.channel
        val index = (feature.unitId shl 8) or feature.controlInterface
        val range = if (feature.protocol == "uac2") {
            val header = ByteArray(2)
            if (connection.controlTransfer(requestType, 0x02, value, index, header, header.size, 300) != 2) {
                return null
            }
            val count = (header[0].toInt() and 0xff) or ((header[1].toInt() and 0xff) shl 8)
            if (count != 1) {
                return null
            }
            val data = ByteArray(8)
            if (connection.controlTransfer(requestType, 0x02, value, index, data, data.size, 300) != data.size) {
                return null
            }
            HardwareVolumeRange(
                minQ8_8 = readSignedQ8_8(data, 2),
                maxQ8_8 = readSignedQ8_8(data, 4),
                stepQ8_8 = readSignedQ8_8(data, 6),
            )
        } else {
            fun readAttribute(request: Int): Int? {
                val data = ByteArray(2)
                return if (
                    connection.controlTransfer(requestType, request, value, index, data, data.size, 300) == data.size
                ) {
                    readSignedQ8_8(data, 0)
                } else {
                    null
                }
            }
            HardwareVolumeRange(
                minQ8_8 = readAttribute(0x82) ?: return null,
                maxQ8_8 = readAttribute(0x83) ?: return null,
                stepQ8_8 = readAttribute(0x84) ?: return null,
            )
        }
        return range.takeIf {
            it.minQ8_8 != Short.MIN_VALUE.toInt() &&
                it.minQ8_8 <= it.maxQ8_8 &&
                it.stepQ8_8 > 0
        }
    }

    private fun readHardwareVolumeProbe(
        connection: UsbDeviceConnection,
        feature: HardwareVolumeFeature,
        overrideRange: HardwareVolumeRange? = null,
    ): Map<String, Any?> {
        val requestType = hardwareVolumeRequestType(UsbConstants.USB_DIR_IN, feature.recipient)
        val value = (0x02 shl 8) or feature.channel
        val index = (feature.unitId shl 8) or feature.controlInterface
        val current = ByteArray(2)
        val currentResult = connection.controlTransfer(
            requestType,
            if (feature.protocol == "uac2") 0x01 else 0x81,
            value,
            index,
            current,
            current.size,
            300,
        )
        return buildMap {
            put("protocol", feature.protocol)
            put("controlInterface", feature.controlInterface)
            put("featureUnitId", feature.unitId)
            put("channel", feature.channel)
            put("recipient", feature.recipient)
            put("writeState", if (feature.writable) "read-write" else "read-only")
            put("currentResult", currentResult)
            if (currentResult == current.size) {
                put("currentQ8_8Db", readSignedQ8_8(current, 0))
            }
            if (overrideRange != null) {
                put(
                    "range",
                    mapOf(
                        "source" to "quirk",
                        "minQ8_8Db" to overrideRange.minQ8_8,
                        "maxQ8_8Db" to overrideRange.maxQ8_8,
                        "stepQ8_8Db" to overrideRange.stepQ8_8,
                        "muteQ8_8Db" to overrideRange.muteQ8_8,
                    ),
                )
            } else if (feature.protocol == "uac2") {
                put("range", readUac2VolumeRange(connection, requestType, value, index))
            } else {
                put("range", readUac1VolumeRange(connection, requestType, value, index))
            }
        }
    }

    private fun readUac2VolumeRange(
        connection: UsbDeviceConnection,
        requestType: Int,
        value: Int,
        index: Int,
    ): Map<String, Any?> {
        val header = ByteArray(2)
        val headerResult = connection.controlTransfer(requestType, 0x02, value, index, header, header.size, 300)
        if (headerResult != header.size) {
            return mapOf("result" to headerResult)
        }
        val count = (header[0].toInt() and 0xff) or ((header[1].toInt() and 0xff) shl 8)
        if (count !in 1..16) {
            return mapOf("result" to headerResult, "subrangeCount" to count)
        }
        val data = ByteArray(2 + count * 6)
        val result = connection.controlTransfer(requestType, 0x02, value, index, data, data.size, 300)
        if (result != data.size) {
            return mapOf("result" to result, "subrangeCount" to count)
        }
        return mapOf(
            "result" to result,
            "subranges" to (0 until count).map { subrange ->
                val offset = 2 + subrange * 6
                mapOf(
                    "minQ8_8Db" to readSignedQ8_8(data, offset),
                    "maxQ8_8Db" to readSignedQ8_8(data, offset + 2),
                    "stepQ8_8Db" to readSignedQ8_8(data, offset + 4),
                )
            },
        )
    }

    private fun readUac1VolumeRange(
        connection: UsbDeviceConnection,
        requestType: Int,
        value: Int,
        index: Int,
    ): Map<String, Any?> {
        fun readAttribute(request: Int): Int? {
            val data = ByteArray(2)
            return if (connection.controlTransfer(requestType, request, value, index, data, data.size, 300) == data.size) {
                readSignedQ8_8(data, 0)
            } else {
                null
            }
        }
        return mapOf(
            "minQ8_8Db" to readAttribute(0x82),
            "maxQ8_8Db" to readAttribute(0x83),
            "stepQ8_8Db" to readAttribute(0x84),
        )
    }

    private fun readSignedQ8_8(data: ByteArray, offset: Int): Int =
        ((data[offset].toInt() and 0xff) or ((data[offset + 1].toInt() and 0xff) shl 8)).toShort().toInt()

    private fun hexDump(bytes: ByteArray): String {
        val builder = StringBuilder(bytes.size * 3)
        for (index in bytes.indices) {
            if (index % 16 == 0) {
                if (index != 0) {
                    builder.append('\n')
                }
                builder.append(String.format(Locale.US, "%04x: ", index))
            } else {
                builder.append(' ')
            }
            builder.append(String.format(Locale.US, "%02x", bytes[index].toInt() and 0xff))
        }
        return builder.toString()
    }

    private fun findOutputTarget(
        device: UsbDevice,
        streamingFormats: Map<Pair<Int, Int>, StreamingFormatInfo> = emptyMap(),
        sampleRate: Int? = null,
        channels: Int = 2,
        bitDepth: Int? = null,
        requireRawData: Boolean = false,
        reportSelection: Boolean = false,
    ): OutputTarget? {
        // native DSD 要求 RAW_DATA alt（bmFormats D31）；quirk 驱动的设备描述符
        // 可能不声明，此时调用方传 false、靠 bitDepth 匹配 subslot
        val candidates = collectOutputCandidates(device, streamingFormats)
            .filter { !requireRawData || it.isRawData }

        if (candidates.isEmpty()) {
            recordOutputSelection(
                reportSelection,
                candidates,
                null,
                sampleRate,
                channels,
                bitDepth,
                requireRawData,
            )
            return null
        }

        if (sampleRate == null) {
            val selected = candidates.minWith(compareBy<OutputTarget> {
                it.endpoint.maxPacketSize
            }.thenBy { it.alternateSetting })
            recordOutputSelection(
                reportSelection,
                candidates,
                selected,
                null,
                channels,
                bitDepth,
                requireRawData,
            )
            return selected
        }

        val sortedCandidates = candidates.sortedWith(compareBy<OutputTarget> {
            it.endpoint.maxPacketSize
        }.thenBy { it.alternateSetting })
        val fittingCandidates = sortedCandidates.filter {
            it.endpoint.maxPacketSize >= requiredIsoPacketBytes(
                sampleRate,
                it.packetsPerSecond,
                channels,
                it.usbBytesPerSample,
            )
        }
        val exactBitDepthCandidates = bitDepth?.let { requested ->
            fittingCandidates.filter { it.usbBitResolution == requested }
        } ?: emptyList()
        val autoBitDepthCandidates = if (bitDepth == null) {
            listOf(24, 32, 16)
                .firstNotNullOfOrNull { preferred ->
                    fittingCandidates.filter { it.usbBitResolution == preferred }.takeIf { it.isNotEmpty() }
                }
                ?: fittingCandidates
        } else {
            emptyList()
        }
        val selectedPool = when {
            exactBitDepthCandidates.isNotEmpty() -> exactBitDepthCandidates
            autoBitDepthCandidates.isNotEmpty() -> autoBitDepthCandidates
            fittingCandidates.isNotEmpty() -> fittingCandidates
            else -> sortedCandidates
        }
        val selected = selectedPool.minWith(
            compareBy<OutputTarget> { it.usbBytesPerSample }
                .thenBy { it.endpoint.maxPacketSize }
                .thenBy { it.alternateSetting },
        )
        val selectedRequiredPacketBytes = requiredIsoPacketBytes(
            sampleRate,
            selected.packetsPerSecond,
            channels,
            selected.usbBytesPerSample,
        )
        if (selected.endpoint.maxPacketSize < selectedRequiredPacketBytes) {
            UsbDiagnostics.w(
                tag,
                "selected USB alt may be too small: requiredPacketBytes=$selectedRequiredPacketBytes, " +
                    "selectedMaxPacket=${selected.endpoint.maxPacketSize}, sampleRate=$sampleRate, " +
                    "channels=$channels, bitDepth=${bitDepth ?: "auto"}",
            )
        }
        UsbDiagnostics.i(
            tag,
            "selected USB alt=${selected.alternateSetting}, maxPacket=${selected.endpoint.maxPacketSize}, " +
                "requiredPacketBytes=$selectedRequiredPacketBytes, " +
                "requestedBitDepth=${bitDepth ?: "auto"}, selectedBitDepth=${selected.usbBitResolution}, " +
                "packetsPerSecond=${selected.packetsPerSecond}, candidates=${sortedCandidates.joinToString { candidate ->
                    val required = requiredIsoPacketBytes(
                        sampleRate,
                        candidate.packetsPerSecond,
                        channels,
                        candidate.usbBytesPerSample,
                    )
                    "alt=${candidate.alternateSetting}/max=${candidate.endpoint.maxPacketSize}/" +
                        "outAttr=0x${candidate.endpoint.attributes.toString(16)}/" +
                        "feedback=${candidate.feedbackEndpointLabel}/" +
                        "usbBytes=${candidate.usbBytesPerSample}/bits=${candidate.usbBitResolution}/" +
                        "required=$required/format=${candidate.formatInfo}"
                }}",
        )
        recordOutputSelection(
            reportSelection,
            sortedCandidates,
            selected,
            sampleRate,
            channels,
            bitDepth,
            requireRawData,
        )
        return selected
    }

    private fun recordOutputSelection(
        enabled: Boolean,
        candidates: List<OutputTarget>,
        selected: OutputTarget?,
        sampleRate: Int?,
        channels: Int,
        bitDepth: Int?,
        requireRawData: Boolean,
    ) {
        if (!enabled) {
            return
        }
        fun targetMap(target: OutputTarget): Map<String, Any?> {
            val required = sampleRate?.let {
                requiredIsoPacketBytes(it, target.packetsPerSecond, channels, target.usbBytesPerSample)
            }
            return mapOf(
                "interface" to target.usbInterface.id,
                "alt" to target.alternateSetting,
                "maxPacketSize" to target.endpoint.maxPacketSize,
                "packetsPerSecond" to target.packetsPerSecond,
                "usbBytes" to target.usbBytesPerSample,
                "bitDepth" to target.usbBitResolution,
                "raw" to target.isRawData,
                "requiredPacketBytes" to required,
                "fits" to (required == null || target.endpoint.maxPacketSize >= required),
                "feedback" to target.feedbackEndpointLabel,
            )
        }
        addOutputSelectionDiagnostics(
            mapOf(
                "sampleRate" to sampleRate,
                "channels" to channels,
                "bitDepth" to bitDepth,
                "requireRawData" to requireRawData,
                "candidates" to candidates.map(::targetMap),
                "selected" to selected?.let(::targetMap),
            ),
        )
    }

    private fun findFeedbackEndpoint(usbInterface: UsbInterface): UsbEndpoint? {
        for (endpointIndex in 0 until usbInterface.endpointCount) {
            val endpoint = usbInterface.getEndpoint(endpointIndex)
            val isIsochronous = endpoint.type == UsbConstants.USB_ENDPOINT_XFER_ISOC
            val isInput = endpoint.direction == UsbConstants.USB_DIR_IN
            val usageType = endpoint.attributes and 0x30
            if (isIsochronous && isInput && usageType == 0x10) {
                return endpoint
            }
        }
        return null
    }

    private fun parseStreamingFormatInfo(descriptors: ByteArray?): Map<Pair<Int, Int>, StreamingFormatInfo> {
        if (descriptors == null) {
            UsbDiagnostics.w(tag, "USB raw descriptors unavailable; cannot parse AS format descriptors.")
            return emptyMap()
        }

        val formats = mutableMapOf<Pair<Int, Int>, StreamingFormatInfo>()
        var offset = 0
        var currentInterfaceNumber = -1
        var currentAlternateSetting = -1
        var currentInterfaceSubclass = -1
        var currentInterfaceProtocol = -1

        while (offset + 1 < descriptors.size) {
            val length = descriptors[offset].toInt() and 0xff
            val descriptorType = descriptors[offset + 1].toInt() and 0xff
            if (length < 2 || offset + length > descriptors.size) {
                break
            }

            if (descriptorType == 0x04 && length >= 9) {
                currentInterfaceNumber = descriptors[offset + 2].toInt() and 0xff
                currentAlternateSetting = descriptors[offset + 3].toInt() and 0xff
                currentInterfaceSubclass = descriptors[offset + 6].toInt() and 0xff
                currentInterfaceProtocol = descriptors[offset + 8].toInt() and 0xff
            } else if (
                descriptorType == 0x24 &&
                currentInterfaceSubclass == 2 &&
                length >= 3
            ) {
                val key = currentInterfaceNumber to currentAlternateSetting
                val subtype = descriptors[offset + 2].toInt() and 0xff
                val existing = formats[key] ?: StreamingFormatInfo(
                    interfaceNumber = currentInterfaceNumber,
                    alternateSetting = currentAlternateSetting,
                    protocol = currentInterfaceProtocol,
                )
                when (subtype) {
                    0x01 -> {
                        val terminalLink = if (length >= 4) {
                            descriptors[offset + 3].toInt() and 0xff
                        } else {
                            existing.terminalLink
                        }
                        val formatType = if (length >= 6) {
                            descriptors[offset + 5].toInt() and 0xff
                        } else {
                            existing.formatType
                        }
                        // UAC2 AS_GENERAL（16 字节）的 bmFormats：D31=RAW_DATA 即 native DSD alt；
                        // UAC1 该描述符只有 7 字节，天然不会进这个分支
                        val bmFormats = if (length >= 10) {
                            (descriptors[offset + 6].toInt() and 0xff) or
                                ((descriptors[offset + 7].toInt() and 0xff) shl 8) or
                                ((descriptors[offset + 8].toInt() and 0xff) shl 16) or
                                ((descriptors[offset + 9].toInt() and 0xff) shl 24)
                        } else {
                            existing.bmFormats
                        }
                        val channels = if (length >= 11) {
                            descriptors[offset + 10].toInt() and 0xff
                        } else {
                            existing.channels
                        }
                        formats[key] = existing.copy(
                            terminalLink = terminalLink,
                            formatType = formatType,
                            bmFormats = bmFormats,
                            channels = channels,
                        )
                    }
                    0x02 -> {
                        // UAC1 Type-I 格式描述符比 UAC2 多一个 bNrChannels 字段、且带采样率表，
                        // 描述符更长（length>=7）；UAC2 Type-I 固定 length=6。原实现两个分支判据
                        // 顺序写反（先判 length>=6），导致 UAC1 描述符错误命中 UAC2 布局，把
                        // bSubframeSize(2/3/4) 当成位深，16-bit 被当 2/3/4-bit 严重右移打成静音。
                        if (length >= 7) {
                            // UAC1: bFormatType, bNrChannels, bSubframeSize, bBitResolution, …
                            formats[key] = existing.copy(
                                formatType = descriptors[offset + 3].toInt() and 0xff,
                                channels = descriptors[offset + 4].toInt() and 0xff,
                                subslotSize = descriptors[offset + 5].toInt() and 0xff,
                                bitResolution = descriptors[offset + 6].toInt() and 0xff,
                            )
                        } else if (length >= 6) {
                            // UAC2: bFormatType, bSubslotSize, bBitResolution
                            formats[key] = existing.copy(
                                formatType = descriptors[offset + 3].toInt() and 0xff,
                                subslotSize = descriptors[offset + 4].toInt() and 0xff,
                                bitResolution = descriptors[offset + 5].toInt() and 0xff,
                            )
                        }
                    }
                }
            }

            offset += length
        }

        UsbDiagnostics.i(
            tag,
            "USB AS formats parsed: ${formats.values.sortedWith(
                compareBy<StreamingFormatInfo> { it.interfaceNumber }.thenBy { it.alternateSetting },
            ).joinToString()}",
        )
        return formats
    }

    private fun findUac2ClockSourceId(
        descriptors: ByteArray?,
        streamingInterfaceNumber: Int,
        streamingAlternateSetting: Int,
    ): Int? {
        if (descriptors == null) {
            return null
        }

        var offset = 0
        var currentInterfaceNumber = -1
        var currentAlternateSetting = -1
        var currentInterfaceSubclass = -1
        var terminalLink: Int? = null
        var firstClockSourceId: Int? = null
        var hasClockSource = false
        val inputTerminalClockIds = mutableMapOf<Int, Int>()
        val outputTerminalClockIds = mutableMapOf<Int, Int>()

        while (offset + 1 < descriptors.size) {
            val length = descriptors[offset].toInt() and 0xff
            val descriptorType = descriptors[offset + 1].toInt() and 0xff
            if (length < 2 || offset + length > descriptors.size) {
                break
            }

            if (descriptorType == 0x04 && length >= 9) {
                currentInterfaceNumber = descriptors[offset + 2].toInt() and 0xff
                currentAlternateSetting = descriptors[offset + 3].toInt() and 0xff
                currentInterfaceSubclass = descriptors[offset + 6].toInt() and 0xff
            } else if (descriptorType == 0x24 && length >= 3) {
                val subtype = descriptors[offset + 2].toInt() and 0xff
                when (subtype) {
                    0x0a -> {
                        hasClockSource = true
                        if (length >= 4 && firstClockSourceId == null) {
                            firstClockSourceId = descriptors[offset + 3].toInt() and 0xff
                        }
                    }
                    0x02 -> {
                        if (length >= 8) {
                            val terminalId = descriptors[offset + 3].toInt() and 0xff
                            inputTerminalClockIds[terminalId] =
                                descriptors[offset + 7].toInt() and 0xff
                        }
                    }
                    0x03 -> {
                        if (length >= 9) {
                            val terminalId = descriptors[offset + 3].toInt() and 0xff
                            outputTerminalClockIds[terminalId] =
                                descriptors[offset + 8].toInt() and 0xff
                        }
                    }
                    0x01 -> {
                        if (
                            currentInterfaceNumber == streamingInterfaceNumber &&
                            currentAlternateSetting == streamingAlternateSetting &&
                            currentInterfaceSubclass == 2 &&
                            length >= 4
                        ) {
                            terminalLink = descriptors[offset + 3].toInt() and 0xff
                        }
                    }
                }
            }

            offset += length
        }

        // UAC1 设备没有 clock source 实体（描述符里不会出现 CLOCK_SOURCE，子类型 0x0a），
        // 采样率必须通过端点 SET_CUR 设置（见 configureUsbAudioClock 的 UAC1 分支）。
        // 下面的 terminal→clock 映射按 UAC2 布局解析，对 UAC1 会误读
        // （把 INPUT_TERMINAL 的 bNrChannels 当成 clockSourceId），因此无 clock source 时直接返回 null。
        if (!hasClockSource) {
            UsbDiagnostics.i(
                tag,
                "no UAC2 clock source entity (UAC1 device); using endpoint SET_CUR.",
            )
            return null
        }

        val linkedTerminal = terminalLink
        val result = linkedTerminal?.let {
            inputTerminalClockIds[it] ?: outputTerminalClockIds[it]
        } ?: firstClockSourceId
        UsbDiagnostics.i(
            tag,
            "parsed UAC2 clock source: streamingInterface=$streamingInterfaceNumber, " +
                "alt=$streamingAlternateSetting, terminalLink=$terminalLink, clockSourceId=$result",
        )
        return result
    }

    private fun requiredIsoPacketBytes(
        sampleRate: Int,
        packetsPerSecond: Int,
        channels: Int,
        bytesPerSample: Int,
    ): Int {
        val maxFramesPerPacket = (sampleRate + packetsPerSecond - 1) / packetsPerSecond
        return maxFramesPerPacket * channels * bytesPerSample
    }

    private fun isoIntervalMicroframes(interval: Int): Int {
        return 1 shl (interval.coerceIn(1, 4) - 1)
    }

    private fun bytesPerSampleForBitDepth(bitDepth: Int): Int {
        return when {
            bitDepth <= 8 -> 1
            bitDepth <= 16 -> 2
            bitDepth <= 24 -> 3
            else -> 4
        }
    }

    // 系统 MediaExtractor 支持、可边下边播（流式独占）的常见有损容器扩展名。
    // 与 Dart 侧 _exclusivePlayablePath 的流式白名单保持一致；wv/ape 等系统不支持的不在此列。
    private val streamableLossyExts = setOf("mp3", "m4a", "m4b", "mp4", "aac", "ogg", "oga", "opus")

    private fun isSupportedFile(filePath: String, sourceFormat: String?): Boolean {
        // 已知无损容器与 DSD 直接放行（含仍在下载的 .part 流式无损），零探测开销
        if (sourceFormat == "flac" || sourceFormat == "wav" || sourceFormat == "wave") {
            return true
        }
        if (isDsdFile(filePath, sourceFormat)) {
            return true
        }
        val lower = filePath.lowercase(Locale.ROOT)
        // 流式独占：file 仍在下载增长（xxx.ext.part），按真实扩展名判定，不剥 .part 会误判
        val streaming = lower.endsWith(".part")
        val effective = if (streaming) lower.removeSuffix(".part") else lower
        if (effective.endsWith(".flac") || effective.endsWith(".wav") || effective.endsWith(".wave")) {
            return true
        }
        if (streaming) {
            // 下载中文件无法完整探测：按扩展名放行系统可流式解码的有损容器（mp3/m4a/ogg 等），
            // 与 FLAC 流式独占同等对待；wv/ape 等系统不支持的不会以 .part 走到这里。
            val ext = effective.substringAfterLast('.', "")
            return ext in streamableLossyExts
        }
        // 完整文件的其余格式（m4a/AAC、mp3、ogg 等）以系统解码器能力为准：MediaCodec 能解出 PCM
        // 就走独占直驱；系统解不了的容器（WavPack/APE 等）判为不支持，交由 Dart 侧回退共享输出——
        // 绝不能进独占后 worker 线程再异步失败导致无声。
        return isMediaCodecDecodable(filePath)
    }

    /// 用 MediaExtractor + MediaCodecList 探测文件能否被系统解码器解成 PCM。
    /// 只查解码器可用性、不实例化 codec，保守判定：宁可返回 false 回退共享，也不误放导致独占无声。
    private fun isMediaCodecDecodable(filePath: String): Boolean {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(filePath)
            val trackIndex = findAudioTrack(extractor)
            if (trackIndex < 0) {
                return false
            }
            val format = extractor.getTrackFormat(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return false
            // 原始 PCM（如 WAV）由 writeRawPcm 直通，无需解码器
            if (mime == "audio/raw") {
                return true
            }
            val decoder = MediaCodecList(MediaCodecList.REGULAR_CODECS)
                .findDecoderForFormat(format)
            val decodable = decoder != null
            UsbDiagnostics.i(tag, "decodability probe file=$filePath, mime=$mime, decoder=${decoder ?: "none"}")
            decodable
        } catch (error: Exception) {
            UsbDiagnostics.w(tag, "decodability probe failed for $filePath: ${error.message}")
            false
        } finally {
            try {
                extractor.release()
            } catch (_: Throwable) {
            }
        }
    }

    private fun isDsdFile(filePath: String, sourceFormat: String?): Boolean {
        if (sourceFormat == "dsf" || sourceFormat == "dff") {
            return true
        }
        val lower = filePath.lowercase(Locale.ROOT)
        return lower.endsWith(".dsf") || lower.endsWith(".dff")
    }

    private fun capability(
        available: Boolean,
        permissionGranted: Boolean,
        device: UsbDevice?,
        target: OutputTarget?,
        message: String,
    ): Map<String, Any?> {
        return mapOf(
            "available" to available,
            "permissionGranted" to permissionGranted,
            "deviceName" to device?.productName,
            "deviceId" to device?.deviceId,
            "interfaceNumber" to target?.usbInterface?.id,
            "alternateSetting" to target?.alternateSetting,
            "endpointAddress" to target?.endpoint?.address,
            "maxPacketSize" to target?.endpoint?.maxPacketSize,
            "sampleRates" to listOf(44100, 48000, 88200, 96000, 176400, 192000),
            "bitDepths" to listOf(16, 24, 32),
            "channelCounts" to listOf(2),
            "message" to message,
        )
    }

    private fun emitError(message: String) {
        updateState(inactiveState(message))
    }

    private fun consumePendingSeekMs(): Long? {
        val seekMs = pendingSeekMs.getAndSet(-1L)
        return if (seekMs >= 0L) seekMs else null
    }

    private fun updateState(state: Map<String, Any?>): Map<String, Any?> {
        currentState = state
        emitState(state)
        if (state["active"] != true) {
            emitInactiveTelemetry()
        }
        return state
    }

    private fun inactiveState(message: String? = null): Map<String, Any?> {
        return mapOf(
            "playbackId" to playbackId,
            "active" to false,
            "playing" to false,
            "positionMs" to 0,
            "durationMs" to null,
            "sampleRate" to null,
            "bitDepth" to null,
            "format" to null,
            "message" to message,
        )
    }

    private fun bitDepthFromPcmEncoding(pcmEncoding: Int?): Int {
        return when (pcmEncoding) {
            3 -> 8
            4 -> 32
            0x80000000.toInt() -> 24
            else -> 16
        }
    }

    private data class OutputTarget(
        val usbInterface: UsbInterface,
        val endpoint: UsbEndpoint,
        val feedbackEndpoint: UsbEndpoint? = null,
        val formatInfo: StreamingFormatInfo? = null,
    ) {
        val alternateSetting: Int
            get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                usbInterface.alternateSetting
            } else {
                0
            }

        val endpointLabel: String
            get() = "interface=${usbInterface.id}, alt=$alternateSetting, endpoint=0x${
                endpoint.address.toString(16)
            }"

        val feedbackEndpointLabel: String
            get() = feedbackEndpoint?.let {
                "0x${it.address.toString(16)}/max=${it.maxPacketSize}/interval=${it.interval}/attr=0x${
                    it.attributes.toString(16)
                }"
            } ?: "none"

        val packetsPerSecond: Int
            get() {
                if (usbInterface.interfaceProtocol == 32) {
                    val interval = endpoint.interval.coerceIn(1, 4)
                    return 8000 / (1 shl (interval - 1))
                }
                return 1000
            }

        val usbBytesPerSample: Int
            get() = formatInfo?.subslotSize?.takeIf { it > 0 } ?: 2

        val usbBitResolution: Int?
            get() = formatInfo?.bitResolution?.takeIf { it > 0 }

        val isRawData: Boolean
            get() = formatInfo?.isRawData == true
    }

    private data class StreamingFormatInfo(
        val interfaceNumber: Int,
        val alternateSetting: Int,
        val protocol: Int,
        val terminalLink: Int? = null,
        val formatType: Int? = null,
        val channels: Int? = null,
        val subslotSize: Int? = null,
        val bitResolution: Int? = null,
        val bmFormats: Int? = null,
    ) {
        // UAC2 bmFormats 的 D31 = RAW_DATA，即 native DSD alt
        val isRawData: Boolean
            get() = bmFormats != null && (bmFormats and (1 shl 31)) != 0
    }

    private class PcmIsoPacketizer(
        private val sampleRate: Int,
        private val packetsPerSecond: Int,
        channels: Int,
        private val inputBytesPerSample: Int,
        private val inputBitDepth: Int,
        private val usbBytesPerSample: Int,
        private val usbBitResolution: Int,
        private val feedbackOutputPacketDivisor: Int,
        private val feedbackFramesPerPacketQ16: (() -> Int)? = null,
        private val reportFeedback: ((Int, Int, Boolean) -> Unit)? = null,
        private val volumeGainQ16: (() -> Int)? = null,
        private val writePackets: (ByteArray, IntArray, Int) -> Unit,
    ) {
        private val pending = ByteArrayOutputStream()
        private val transfer = ByteArrayOutputStream()
        private val transferPacketLengths = IntArray(16)
        private val bytesPerFrame = channels * usbBytesPerSample
        private val inputBytesPerFrame = channels * inputBytesPerSample
        private var sampleRemainder = 0
        private var feedbackRemainderQ16 = 0L
        private var transferPacketCount = 0
        private var packetLogCount = 0
        private var feedbackRejectLogCount = 0
        private var pcmPreviewLogged = false
        private var pcmPreviewAttempts = 0

        fun write(data: ByteArray) {
            val converted = convertPcmToUsbSlots(data)
            if (!pcmPreviewLogged) {
                pcmPreviewAttempts++
                val forcePreview = pcmPreviewAttempts >= 64
                if (hasAudibleSamples(data) || forcePreview) {
                    pcmPreviewLogged = true
                    logPcmPreview(
                        data,
                        converted,
                        if (forcePreview) "forced-after-silence" else "first-nonzero",
                    )
                }
            }
            pending.write(converted)
            drain(fullPacketsOnly = true)
        }

        fun flush() {
            drain(fullPacketsOnly = false)
        }

        fun reset() {
            pending.reset()
            transfer.reset()
            transferPacketCount = 0
            sampleRemainder = 0
            feedbackRemainderQ16 = 0L
            packetLogCount = 0
            feedbackRejectLogCount = 0
            pcmPreviewLogged = false
            pcmPreviewAttempts = 0
        }

        private fun drain(fullPacketsOnly: Boolean) {
            while (pending.size() > 0) {
                val packetBytes = nextPacketBytes()
                if (fullPacketsOnly && pending.size() < packetBytes) {
                    return
                }
                val source = pending.toByteArray()
                val length = minOf(packetBytes, source.size)
                val packet = ByteArray(packetBytes)
                System.arraycopy(source, 0, packet, 0, length)
                pending.reset()
                if (source.size > length) {
                    pending.write(source, length, source.size - length)
                }
                if (packetLogCount < 5) {
                    ++packetLogCount
                    UsbDiagnostics.d(
                        "UsbExclusiveAudioEngine",
                        "USB PCM packet bytes=${packet.size}, filled=$length",
                    )
                }
                transfer.write(packet)
                transferPacketLengths[transferPacketCount] = packet.size
                transferPacketCount++
                if (transferPacketCount >= transferPacketLengths.size) {
                    flushTransfer()
                }
            }

            if (!fullPacketsOnly) {
                flushTransfer()
            }
        }

        private fun flushTransfer() {
            if (transferPacketCount == 0) {
                return
            }
            writePackets(
                transfer.toByteArray(),
                transferPacketLengths.copyOf(transferPacketCount),
                transferPacketCount,
            )
            transfer.reset()
            transferPacketCount = 0
        }

        private fun nextPacketBytes(): Int {
            val feedbackQ16 = feedbackFramesPerPacketQ16?.invoke() ?: 0
            if (feedbackQ16 > 0) {
                val outputFeedbackQ16 = feedbackQ16 / feedbackOutputPacketDivisor
                val nominalFramesQ16 = ((sampleRate.toLong() shl 16) / packetsPerSecond).toInt()
                val minFeedbackQ16 = nominalFramesQ16 - (nominalFramesQ16 / 8)
                val maxFeedbackQ16 = nominalFramesQ16 + (nominalFramesQ16 / 2)
                if (outputFeedbackQ16 in minFeedbackQ16..maxFeedbackQ16) {
                    reportFeedback?.invoke(outputFeedbackQ16, nominalFramesQ16, false)
                    feedbackRemainderQ16 += outputFeedbackQ16.toLong()
                    val frames = (feedbackRemainderQ16 ushr 16).toInt()
                    feedbackRemainderQ16 = feedbackRemainderQ16 and 0xffff
                    if (frames > 0) {
                        return maxOf(bytesPerFrame, frames * bytesPerFrame)
                    }
                } else {
                    reportFeedback?.invoke(outputFeedbackQ16, nominalFramesQ16, true)
                    if (feedbackRejectLogCount < 8) {
                        ++feedbackRejectLogCount
                        UsbDiagnostics.w(
                            "UsbExclusiveAudioEngine",
                            "USB feedback ignored outputFrames=${q16ToFrames(outputFeedbackQ16)}, " +
                                "nominalFrames=${q16ToFrames(nominalFramesQ16)}, " +
                                "sampleRate=$sampleRate, packetsPerSecond=$packetsPerSecond",
                        )
                    }
                }
            }

            sampleRemainder += sampleRate
            val frames = sampleRemainder / packetsPerSecond
            sampleRemainder %= packetsPerSecond
            return maxOf(bytesPerFrame, frames * bytesPerFrame)
        }

        private fun q16ToFrames(value: Int): String =
            String.format(Locale.US, "%.6f", value.toDouble() / 65536.0)

        private fun convertPcmToUsbSlots(data: ByteArray): ByteArray {
            val gainQ16 = volumeGainQ16?.invoke() ?: UNITY_GAIN_Q16
            val applyGain = gainQ16 < UNITY_GAIN_Q16
            // 满刻度且无需重排位深时零拷贝直通，保持位完美。
            if (!applyGain && inputBytesPerSample == usbBytesPerSample && inputBitDepth == usbBitResolution) {
                return data
            }

            val frames = data.size / inputBytesPerFrame
            val output = ByteArray(frames * bytesPerFrame)
            var inputOffset = 0
            var outputOffset = 0
            repeat(frames) {
                repeat(inputBytesPerFrame / inputBytesPerSample) {
                    var sample = readSignedLittleEndian(data, inputOffset, inputBytesPerSample, inputBitDepth)
                    if (applyGain) {
                        // 在源位深域施加线性增益（Long 防溢出）再做 slot 对齐移位。
                        sample = ((sample.toLong() * gainQ16) shr 16).toInt()
                    }
                    val shifted = if (usbBitResolution >= inputBitDepth) {
                        sample shl (usbBitResolution - inputBitDepth)
                    } else {
                        sample shr (inputBitDepth - usbBitResolution)
                    }
                    writeLittleEndian(output, outputOffset, usbBytesPerSample, shifted)
                    inputOffset += inputBytesPerSample
                    outputOffset += usbBytesPerSample
                }
            }
            return output
        }

        private fun hasAudibleSamples(input: ByteArray): Boolean {
            val frames = input.size / inputBytesPerFrame
            val samplesPerFrame = inputBytesPerFrame / inputBytesPerSample
            val samplesToInspect = minOf(4096, frames * samplesPerFrame)
            var sumAbs = 0L
            for (index in 0 until samplesToInspect) {
                val offset = index * inputBytesPerSample
                val sample = readSignedLittleEndian(input, offset, inputBytesPerSample, inputBitDepth)
                val abs = kotlin.math.abs(sample.toLong())
                sumAbs += abs
                if (abs > 512) {
                    return true
                }
            }
            return samplesToInspect > 0 && (sumAbs / samplesToInspect) > 64
        }

        private fun logPcmPreview(input: ByteArray, converted: ByteArray, reason: String) {
            val frames = input.size / inputBytesPerFrame
            val samplesPerFrame = inputBytesPerFrame / inputBytesPerSample
            val samplesToInspect = minOf(4096, frames * samplesPerFrame)
            var minSample = 0
            var maxSample = 0
            var sumAbs = 0L
            for (index in 0 until samplesToInspect) {
                val offset = index * inputBytesPerSample
                val sample = readSignedLittleEndian(input, offset, inputBytesPerSample, inputBitDepth)
                if (index == 0 || sample < minSample) minSample = sample
                if (index == 0 || sample > maxSample) maxSample = sample
                sumAbs += kotlin.math.abs(sample.toLong())
            }
            val averageAbs = if (samplesToInspect > 0) sumAbs / samplesToInspect else 0
            UsbDiagnostics.i(
                "UsbExclusiveAudioEngine",
                "USB PCM preview reason=$reason, inputBytes=${input.size}, convertedBytes=${converted.size}, frames=$frames, " +
                    "inputBitDepth=$inputBitDepth, usbBytesPerSample=$usbBytesPerSample, " +
                    "usbBitResolution=$usbBitResolution, min=$minSample, max=$maxSample, avgAbs=$averageAbs, " +
                    "inputHead=${input.toHexPreview()}, usbHead=${converted.toHexPreview()}",
            )
        }

        private fun ByteArray.toHexPreview(limit: Int = 64): String {
            return take(minOf(size, limit)).joinToString(" ") { byte ->
                (byte.toInt() and 0xff).toString(16).padStart(2, '0')
            }
        }

        private fun readSignedLittleEndian(
            data: ByteArray,
            offset: Int,
            bytes: Int,
            bitDepth: Int,
        ): Int {
            var value = 0
            for (index in 0 until bytes) {
                value = value or ((data[offset + index].toInt() and 0xff) shl (index * 8))
            }
            val shift = (32 - bitDepth).coerceIn(0, 31)
            return (value shl shift) shr shift
        }

        private fun writeLittleEndian(
            data: ByteArray,
            offset: Int,
            bytes: Int,
            value: Int,
        ) {
            for (index in 0 until bytes) {
                data[offset + index] = ((value ushr (index * 8)) and 0xff).toByte()
            }
        }
    }
}
