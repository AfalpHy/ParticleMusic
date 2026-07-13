package com.afalphy.sylvakru

import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.roundToInt

internal data class UsbVolumeCapabilities(
    val readable: Boolean,
    val unsolicitedEvents: Boolean,
    val dsdGain: Boolean,
)

internal data class UsbVolumeEvent(
    val leftRaw: Int,
    val rightRaw: Int,
)

internal data class UsbVolumeTarget(
    val baseRaw: Int,
    val dsdRaw: Int,
)

internal enum class HardwareVolumeHandoffSource { DEVICE, APP }

internal data class HardwareVolumeHandoffTarget(
    val gainQ16: Int,
    val source: HardwareVolumeHandoffSource,
)

internal data class UsbActualVolume(
    val raw: Int,
    val gainQ16: Int,
)

internal data class HardwareVolumeWriteResult(
    val error: String? = null,
    val actual: UsbActualVolume? = null,
)

internal fun actualHardwareVolume(
    valuesQ8_8: List<Int>,
    muteQ8_8: Int,
): UsbActualVolume? = valuesQ8_8
    .map { raw -> UsbActualVolume(raw, hardwareVolumeGainQ16(raw, muteQ8_8)) }
    .minWithOrNull(compareBy<UsbActualVolume> { it.gainQ16 }.thenBy { it.raw })

internal sealed interface UsbVolumeProtocolSelection

internal data object StandardUsbVolumeProtocol : UsbVolumeProtocolSelection

internal data class VendorUsbVolumeProtocol(
    val protocol: UsbVolumeProtocol,
) : UsbVolumeProtocolSelection

internal data class UnsupportedUsbVolumeProtocol(
    val id: String,
) : UsbVolumeProtocolSelection

internal data class HardwareVolumeRecovery(
    val hardwareActive: Boolean,
    val fallbackReason: String,
)

internal sealed interface IbassoVolumePacketRoute {
    data class CommandResponse(
        val command: Int,
        val packet: ByteArray,
    ) : IbassoVolumePacketRoute

    data class Event(
        val event: UsbVolumeEvent,
        val isWriteConfirmation: Boolean,
    ) : IbassoVolumePacketRoute

    data object Unknown : IbassoVolumePacketRoute
}

internal data class IbassoReaderHealth(
    val failureCount: Int = 0,
    val pendingReadFailureCount: Int = 0,
    val restartRequested: Boolean = false,
    val writeOnly: Boolean = false,
    val readbackVerified: Boolean = false,
) {
    val readable: Boolean
        get() = !writeOnly

    fun afterFailure(): IbassoReaderHealth = if (failureCount == 0) {
        copy(
            failureCount = 1,
            pendingReadFailureCount = 0,
            restartRequested = true,
            writeOnly = false,
            readbackVerified = false,
        )
    } else {
        copy(
            failureCount = failureCount + 1,
            pendingReadFailureCount = 0,
            restartRequested = false,
            writeOnly = true,
            readbackVerified = false,
        )
    }

    fun afterReadResult(readLength: Int, hasPendingResponse: Boolean): IbassoReaderHealth =
        if (readLength > 0 || !hasPendingResponse) {
            copy(pendingReadFailureCount = 0)
        } else {
            copy(pendingReadFailureCount = pendingReadFailureCount + 1)
        }

    fun hasPersistentPendingFailure(limit: Int): Boolean =
        pendingReadFailureCount >= limit.coerceAtLeast(1)

    fun afterRestart(): IbassoReaderHealth = copy(
        pendingReadFailureCount = 0,
        restartRequested = false,
    )

    fun afterVerifiedReadback(): IbassoReaderHealth = copy(
        pendingReadFailureCount = 0,
        readbackVerified = true,
    )
}

internal fun shouldResumeIbassoReaderHealth(
    health: IbassoReaderHealth,
    healthDeviceId: Int?,
    deviceId: Int,
): Boolean = health.failureCount > 0 && healthDeviceId == deviceId

internal fun isCurrentIbassoReaderGeneration(
    readerGeneration: Long,
    currentGeneration: Long,
    running: Boolean,
    threadMatches: Boolean,
    connectionMatches: Boolean,
    endpointMatches: Boolean,
): Boolean = readerGeneration == currentGeneration &&
    running &&
    threadMatches &&
    connectionMatches &&
    endpointMatches

internal fun shouldRestartIbassoReaderGeneration(
    readerGeneration: Long,
    currentGeneration: Long,
    running: Boolean,
    readerThreadExited: Boolean,
    connectionMatches: Boolean,
    endpointMatches: Boolean,
    volumeConnectionMatches: Boolean,
    restartRequested: Boolean,
): Boolean = isFailedIbassoReaderGenerationCurrent(
    readerGeneration,
    currentGeneration,
    running,
    failedThreadNotReplaced = readerThreadExited,
    connectionMatches,
    endpointMatches,
    volumeConnectionMatches,
) && restartRequested

internal fun isFailedIbassoReaderGenerationCurrent(
    readerGeneration: Long,
    currentGeneration: Long,
    running: Boolean,
    failedThreadNotReplaced: Boolean,
    connectionMatches: Boolean,
    endpointMatches: Boolean,
    volumeConnectionMatches: Boolean,
): Boolean = readerGeneration == currentGeneration &&
    !running &&
    failedThreadNotReplaced &&
    connectionMatches &&
    endpointMatches &&
    volumeConnectionMatches

internal fun hardwareVolumeWriteOnlyForState(
    protocol: String?,
    ibassoHealth: IbassoReaderHealth,
): Boolean = protocol == "ibassoDc03Pro" && ibassoHealth.writeOnly

internal fun hardwareVolumeReadbackVerifiedForState(
    protocol: String?,
    standardReadbackVerified: Boolean,
    ibassoHealth: IbassoReaderHealth,
): Boolean = when (protocol) {
    null -> false
    "ibassoDc03Pro" -> ibassoHealth.readbackVerified && !ibassoHealth.writeOnly
    else -> standardReadbackVerified
}

internal fun shouldUseDirectIbassoSetReport(
    writeOnly: Boolean,
    readerAvailable: Boolean,
    allowWhenReaderUnavailable: Boolean,
): Boolean = writeOnly || (!readerAvailable && allowWhenReaderUnavailable)

internal class IbassoVolumeEventDebouncer {
    private val lock = Any()
    private var token = 0L
    private var event: UsbVolumeEvent? = null

    fun submit(value: UsbVolumeEvent): Long = synchronized(lock) {
        event = value
        ++token
    }

    fun consume(expectedToken: Long): UsbVolumeEvent? = synchronized(lock) {
        if (expectedToken != token) {
            null
        } else {
            event.also { event = null }
        }
    }

    fun clear() = synchronized(lock) {
        event = null
        token += 1
    }
}

internal interface UsbVolumeProtocol {
    val id: String
    val capabilities: UsbVolumeCapabilities

    fun appGainToRaw(
        gainQ16: Int,
        replayGainMilliDb: Int,
        dsdCompensationDb: Int,
    ): UsbVolumeTarget

    fun rawToLinearGainQ16(raw: Int): Int

    fun decodeEvent(packet: ByteArray): UsbVolumeEvent?

    fun isWriteConfirmation(event: UsbVolumeEvent, lastWrittenRaw: Int?): Boolean =
        lastWrittenRaw != null &&
            event.leftRaw == lastWrittenRaw &&
            event.rightRaw == lastWrittenRaw
}

internal object IbassoDc03ProVolumeProtocol : UsbVolumeProtocol {
    override val id = "ibassoDc03Pro"
    override val capabilities = UsbVolumeCapabilities(
        readable = true,
        unsolicitedEvents = true,
        dsdGain = true,
    )

    override fun appGainToRaw(
        gainQ16: Int,
        replayGainMilliDb: Int,
        dsdCompensationDb: Int,
    ): UsbVolumeTarget {
        val adjustedGain = effectiveVolumeGainQ16(gainQ16, replayGainMilliDb)
        if (adjustedGain <= 0) {
            return UsbVolumeTarget(baseRaw = 255, dsdRaw = 255)
        }
        val baseRaw = ibassoDeviceVolume(ibassoVolumeIndex(adjustedGain))
        return UsbVolumeTarget(
            baseRaw = baseRaw,
            dsdRaw = ibassoDsdVolume(baseRaw, dsdCompensationDb),
        )
    }

    override fun rawToLinearGainQ16(raw: Int): Int {
        val index = ibassoVolumeTable.indices.minByOrNull {
            abs(ibassoVolumeTable[it] - raw.coerceIn(0, 255))
        } ?: return 0
        return ((index.toDouble() / ibassoVolumeTable.lastIndex).pow(1.5) *
            IBASSO_UNITY_GAIN_Q16)
            .roundToInt()
            .coerceIn(0, IBASSO_UNITY_GAIN_Q16)
    }

    override fun decodeEvent(packet: ByteArray): UsbVolumeEvent? {
        if (packet.size != IBASSO_EVENT_PACKET_SIZE ||
            packet[0].toInt() and 0xff != 0xfe ||
            packet[1].toInt() and 0xff != 0x01
        ) {
            return null
        }
        return UsbVolumeEvent(
            leftRaw = packet[8].toInt() and 0xff,
            rightRaw = packet[9].toInt() and 0xff,
        )
    }
}

internal fun usbVolumeProtocolFor(id: String?): UsbVolumeProtocol? =
    when (id?.trim()) {
        "ibassoDc03Pro" -> IbassoDc03ProVolumeProtocol
        else -> null
    }

internal fun usbVolumeProtocolSelection(id: String?): UsbVolumeProtocolSelection {
    val normalized = id?.trim()?.takeIf { it.isNotEmpty() }
    return when (normalized) {
        null, "uac1", "uac2" -> StandardUsbVolumeProtocol
        "ibassoDc03Pro" -> VendorUsbVolumeProtocol(IbassoDc03ProVolumeProtocol)
        else -> UnsupportedUsbVolumeProtocol(normalized)
    }
}

internal fun hardwareVolumeSupportedForStream(
    protocolSelection: UsbVolumeProtocolSelection,
    isDsd: Boolean,
    quirkDsdSupported: Boolean?,
): Boolean {
    if (!isDsd) return true
    return when (protocolSelection) {
        StandardUsbVolumeProtocol -> quirkDsdSupported == true
        is VendorUsbVolumeProtocol ->
            protocolSelection.protocol.capabilities.dsdGain && quirkDsdSupported != false
        is UnsupportedUsbVolumeProtocol -> false
    }
}

internal fun effectiveVolumeGainQ16(userGainQ16: Int, replayGainMilliDb: Int): Int {
    val userGain = userGainQ16.coerceIn(0, IBASSO_UNITY_GAIN_Q16)
    if (userGain == 0) return 0
    val factor = 10.0.pow(replayGainMilliDb.toDouble() / 20000.0)
    val adjusted = userGain * factor
    return when {
        adjusted.isNaN() || adjusted <= 0 -> 0
        !adjusted.isFinite() || adjusted >= IBASSO_UNITY_GAIN_Q16 -> IBASSO_UNITY_GAIN_Q16
        else -> adjusted.roundToInt()
    }
}

internal fun effectiveHardwareVolumeGainQ16(
    userGainQ16: Int,
    replayGainMilliDb: Int,
    dsdCompensationDb: Int,
    isDsd: Boolean,
): Int {
    val combinedGainMilliDb = (
        replayGainMilliDb.toLong() +
            if (isDsd) dsdCompensationDb.toLong() * 1000L else 0L
        ).coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
    return effectiveVolumeGainQ16(userGainQ16, combinedGainMilliDb)
}

internal fun hardwareVolumeRecovery(
    writeFailure: String,
    restoreFailure: String?,
): HardwareVolumeRecovery = if (restoreFailure == null) {
    HardwareVolumeRecovery(
        hardwareActive = false,
        fallbackReason = writeFailure,
    )
} else {
    HardwareVolumeRecovery(
        hardwareActive = true,
        fallbackReason =
            "$writeFailure Failed to restore hardware volume: $restoreFailure",
    )
}

internal fun routeIbassoVolumePacket(
    packet: ByteArray,
    pendingCommands: Set<Int>,
    lastWrittenRaw: Int?,
): IbassoVolumePacketRoute {
    val event = IbassoDc03ProVolumeProtocol.decodeEvent(packet)
    if (event != null) {
        return IbassoVolumePacketRoute.Event(
            event = event,
            isWriteConfirmation =
                IbassoDc03ProVolumeProtocol.isWriteConfirmation(event, lastWrittenRaw),
        )
    }
    val command = packet.getOrNull(6)?.toInt()?.and(0xff)
    return if (command != null && command in pendingCommands) {
        IbassoVolumePacketRoute.CommandResponse(command, packet)
    } else {
        IbassoVolumePacketRoute.Unknown
    }
}

internal fun recentIbassoWrittenRaw(
    lastWrittenRaw: Int?,
    lastWrittenAtMs: Long,
    nowMs: Long,
    windowMs: Long,
): Int? = lastWrittenRaw?.takeIf {
    nowMs - lastWrittenAtMs in 0..windowMs
}

internal fun hardwareVolumeHandoffTarget(
    smooth: Boolean,
    readGainQ16: Int?,
    appTargetQ16: Int,
): HardwareVolumeHandoffTarget = if (
    smooth && readGainQ16 != null && readGainQ16 in 0..IBASSO_UNITY_GAIN_Q16
) {
    HardwareVolumeHandoffTarget(readGainQ16, HardwareVolumeHandoffSource.DEVICE)
} else {
    HardwareVolumeHandoffTarget(
        appTargetQ16.coerceIn(0, IBASSO_UNITY_GAIN_Q16),
        HardwareVolumeHandoffSource.APP,
    )
}

internal fun shouldReadInitialHardwareVolume(
    isNewConnection: Boolean,
    readable: Boolean,
): Boolean = isNewConnection && readable

internal fun ibassoActualEventGainQ16(
    baseRaw: Int,
    isDsd: Boolean,
    dsdCompensationDb: Int,
): UsbActualVolume {
    val actualRaw = if (isDsd) {
        ibassoDsdVolume(baseRaw, dsdCompensationDb)
    } else {
        baseRaw.coerceIn(0, 255)
    }
    return UsbActualVolume(
        raw = actualRaw,
        gainQ16 = IbassoDc03ProVolumeProtocol.rawToLinearGainQ16(actualRaw),
    )
}

private const val IBASSO_UNITY_GAIN_Q16 = 65536
private const val IBASSO_EVENT_PACKET_SIZE = 16

private val ibassoVolumeTable = intArrayOf(
    255, 155, 150, 145, 140, 135, 130, 125, 120, 115, 110, 109, 108, 107, 106, 105,
    104, 103, 102, 101, 100, 99, 98, 97, 96, 95, 94, 93, 92, 91, 90, 88, 86, 84,
    82, 80, 78, 76, 74, 72, 70, 68, 66, 64, 62, 60, 58, 56, 54, 52, 50, 49, 48,
    47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29,
    28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10,
    9, 8, 7, 6, 5, 4, 3, 2, 1, 0,
)

internal fun ibassoVolumeIndex(gainQ16: Int): Int {
    if (gainQ16 <= 0) return 0
    val digitalGain = gainQ16.coerceAtMost(IBASSO_UNITY_GAIN_Q16).toDouble() /
        IBASSO_UNITY_GAIN_Q16
    return (digitalGain.pow(2.0 / 3.0) * (ibassoVolumeTable.size - 1))
        .roundToInt()
        .coerceIn(0, ibassoVolumeTable.lastIndex)
}

internal fun ibassoDeviceVolume(index: Int): Int =
    ibassoVolumeTable[index.coerceIn(0, ibassoVolumeTable.lastIndex)]

internal fun ibassoDsdVolume(baseVolume: Int, compensationDb: Int): Int =
    (baseVolume - compensationDb.coerceIn(-12, 6) * 2).coerceIn(0, 255)

internal fun ibassoI2cWritePacket(
    command: Int,
    slave: Int,
    offset: Int,
    byteOffset: Int,
    value: Int,
): ByteArray = ByteArray(16).also {
    it[0] = command.toByte()
    it[1] = 0x11
    it[2] = 0x88.toByte()
    it[3] = slave.toByte()
    it[6] = 5
    it[7] = offset.toByte()
    it[9] = byteOffset.toByte()
    it[11] = value.toByte()
}

internal fun ibassoRoomWritePacket(command: Int, register: Int, value: Int): ByteArray =
    ByteArray(16).also {
        it[0] = command.toByte()
        it[1] = 0x11
        it[2] = 0xa0.toByte()
        it[3] = 0xa2.toByte()
        it[5] = register.toByte()
        it[6] = 1
        it[7] = value.toByte()
    }

internal fun ibassoVolumePackets(target: UsbVolumeTarget): List<ByteArray> = listOf(
    ibassoI2cWritePacket(1, 0x60, 9, 1, target.baseRaw),
    ibassoI2cWritePacket(2, 0x60, 9, 2, target.baseRaw),
    ibassoI2cWritePacket(3, 0x62, 9, 1, target.baseRaw),
    ibassoI2cWritePacket(4, 0x62, 9, 2, target.baseRaw),
    ibassoI2cWritePacket(9, 0x60, 7, 0, target.dsdRaw),
    ibassoI2cWritePacket(10, 0x60, 7, 1, target.dsdRaw),
    ibassoRoomWritePacket(19, 16, target.baseRaw),
    ibassoI2cWritePacket(11, 0x62, 7, 0, target.dsdRaw),
    ibassoI2cWritePacket(12, 0x62, 7, 1, target.dsdRaw),
    ibassoRoomWritePacket(20, 17, target.baseRaw),
)

internal fun ibassoRollbackTarget(
    lastAppliedTarget: UsbVolumeTarget?,
    initialBaseRaw: Int?,
    dsdCompensationDb: Int,
): UsbVolumeTarget? = lastAppliedTarget ?: initialBaseRaw?.coerceIn(0, 255)?.let { baseRaw ->
    UsbVolumeTarget(baseRaw, ibassoDsdVolume(baseRaw, dsdCompensationDb))
}

internal fun ibassoVolumeReadPacket(): ByteArray = ByteArray(16).also {
    it[0] = 65
    it[1] = 0x12
    it[2] = 0xe4.toByte()
    it[3] = 0xa2.toByte()
    it[5] = 0x11
    it[6] = 1
}
