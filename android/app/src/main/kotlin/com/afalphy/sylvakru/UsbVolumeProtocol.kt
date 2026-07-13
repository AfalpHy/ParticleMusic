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
        val baseGain = gainQ16.coerceIn(0, IBASSO_UNITY_GAIN_Q16)
        val adjustedGain = if (baseGain == 0) {
            0
        } else {
            val factor = 10.0.pow(replayGainMilliDb.toDouble() / 20000.0)
            val adjusted = baseGain * factor
            when {
                adjusted.isNaN() -> 0
                adjusted == Double.POSITIVE_INFINITY -> IBASSO_UNITY_GAIN_Q16
                adjusted <= 0 -> 0
                adjusted >= IBASSO_UNITY_GAIN_Q16 -> IBASSO_UNITY_GAIN_Q16
                else -> adjusted.roundToInt()
            }
        }
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

internal fun ibassoVolumeReadPacket(): ByteArray = ByteArray(16).also {
    it[0] = 65
    it[1] = 0x12
    it[2] = 0xe4.toByte()
    it[3] = 0xa2.toByte()
    it[5] = 0x11
    it[6] = 1
}
