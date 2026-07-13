package com.afalphy.sylvakru

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.roundToInt

class UsbVolumeProtocolTest {
    private val protocol = IbassoDc03ProVolumeProtocol

    @Test
    fun exposesIbassoProtocolCapabilities() {
        assertEquals("ibassoDc03Pro", protocol.id)
        assertEquals(
            UsbVolumeCapabilities(
                readable = true,
                unsolicitedEvents = true,
                dsdGain = true,
            ),
            protocol.capabilities,
        )
    }

    @Test
    fun selectsVendorStandardAndUnsupportedProtocolsExplicitly() {
        assertSame(IbassoDc03ProVolumeProtocol, usbVolumeProtocolFor("ibassoDc03Pro"))
        assertEquals(StandardUsbVolumeProtocol, usbVolumeProtocolSelection(null))
        assertEquals(StandardUsbVolumeProtocol, usbVolumeProtocolSelection("uac1"))
        assertEquals(StandardUsbVolumeProtocol, usbVolumeProtocolSelection("uac2"))
        assertEquals(
            UnsupportedUsbVolumeProtocol("unknownProtocol"),
            usbVolumeProtocolSelection("unknownProtocol"),
        )
    }

    @Test
    fun combinesReplayGainIntoEffectiveLinearGainSafely() {
        assertEquals(0, effectiveVolumeGainQ16(0, 6000))
        assertEquals(65536, effectiveVolumeGainQ16(65536, 6000))
        assertTrue(abs(effectiveVolumeGainQ16(65536, -6021) - 32768) <= 2)
        assertEquals(0, effectiveVolumeGainQ16(65536, Int.MIN_VALUE))
        assertEquals(65536, effectiveVolumeGainQ16(1, Int.MAX_VALUE))
    }

    @Test
    fun addsDsdCompensationOnlyToDsdHardwareVolume() {
        assertTrue(
            abs(effectiveHardwareVolumeGainQ16(32768, 0, 6, isDsd = true) - 65381) <= 2,
        )
        assertEquals(
            32768,
            effectiveHardwareVolumeGainQ16(32768, 0, 6, isDsd = false),
        )
        assertEquals(
            0,
            effectiveHardwareVolumeGainQ16(0, Int.MAX_VALUE, 6, isDsd = true),
        )
    }

    @Test
    fun keepsHardwareActiveOnlyWhenUnityRestoreFails() {
        assertEquals(
            HardwareVolumeRecovery(
                hardwareActive = false,
                fallbackReason = "Target write failed.",
            ),
            hardwareVolumeRecovery("Target write failed.", restoreFailure = null),
        )
        assertEquals(
            HardwareVolumeRecovery(
                hardwareActive = true,
                fallbackReason =
                    "Target write failed. Failed to restore hardware volume: Restore failed.",
            ),
            hardwareVolumeRecovery("Target write failed.", "Restore failed."),
        )
    }

    @Test
    fun mapsAppGainToIbassoRawTable() {
        assertEquals(255, protocol.appGainToRaw(0, 0, 0).baseRaw)
        assertEquals(97, protocol.appGainToRaw(gainQ16ForIndex(23), 0, 0).baseRaw)
        assertEquals(10, protocol.appGainToRaw(gainQ16ForIndex(90), 0, 0).baseRaw)
        assertEquals(0, protocol.appGainToRaw(65536, 0, 0).baseRaw)
    }

    @Test
    fun keepsMuteAcrossDsdCompensation() {
        assertEquals(UsbVolumeTarget(255, 255), protocol.appGainToRaw(0, 0, 6))
        assertEquals(UsbVolumeTarget(255, 255), protocol.appGainToRaw(0, 0, -6))
    }

    @Test
    fun appliesReplayGainBeforeClampAndDsdHalfDbSteps() {
        assertEquals(
            UsbVolumeTarget(0, 0),
            protocol.appGainToRaw(gainQ16ForIndex(90), 6000, 0),
        )
        assertEquals(
            UsbVolumeTarget(97, 85),
            protocol.appGainToRaw(gainQ16ForIndex(23), 0, 6),
        )
        assertEquals(
            UsbVolumeTarget(97, 109),
            protocol.appGainToRaw(gainQ16ForIndex(23), 0, -6),
        )
        assertEquals(
            UsbVolumeTarget(255, 255),
            protocol.appGainToRaw(65536, Int.MIN_VALUE, 0),
        )
        assertEquals(
            UsbVolumeTarget(0, 0),
            protocol.appGainToRaw(65536, Int.MAX_VALUE, 0),
        )
    }

    @Test
    fun mapsRawTableValuesBackToLinearGain() {
        assertEquals(0, protocol.rawToLinearGainQ16(255))
        assertTrue(
            abs(protocol.rawToLinearGainQ16(97) - gainQ16ForIndex(23)) <= 1,
        )
        assertTrue(
            abs(protocol.rawToLinearGainQ16(10) - gainQ16ForIndex(90)) <= 1,
        )
        assertEquals(65536, protocol.rawToLinearGainQ16(0))
    }

    @Test
    fun decodesOnlyFixedLengthUnsolicitedVolumeEvents() {
        val packet = ByteArray(16)
        packet[0] = 0xfe.toByte()
        packet[1] = 0x01
        packet[8] = 97
        packet[9] = 98

        assertEquals(UsbVolumeEvent(97, 98), protocol.decodeEvent(packet))
        assertNull(protocol.decodeEvent(packet.copyOf(9)))

        val response = ByteArray(16)
        response[6] = 65
        response[8] = 97
        assertNull(protocol.decodeEvent(response))
    }

    @Test
    fun recognizesOnlyMatchingStereoWriteConfirmation() {
        assertTrue(protocol.isWriteConfirmation(UsbVolumeEvent(97, 97), 97))
        assertFalse(protocol.isWriteConfirmation(UsbVolumeEvent(97, 98), 97))
        assertFalse(protocol.isWriteConfirmation(UsbVolumeEvent(97, 97), null))
    }

    private fun gainQ16ForIndex(index: Int): Int =
        ((index / 100.0).pow(1.5) * 65536).roundToInt()
}
