package com.afalphy.sylvakru

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import kotlin.math.pow

class UsbHardwareVolumeTest {
    private val master = HardwareVolumeFeature(
        protocol = "uac2",
        controlInterface = 0,
        unitId = 7,
        sourceId = 2,
        channel = 0,
        writable = true,
    )

    @Test
    fun selectsUniqueWritableFeatureOnPlaybackPath() {
        val selected = selectHardwareVolumeFeatures(
            features = listOf(
                master,
                master.copy(channel = 1),
                master.copy(unitId = 8, sourceId = 9),
            ),
            terminalLink = 2,
            outputTerminalSources = setOf(7),
            quirk = DacQuirk(),
        )

        assertEquals(listOf(master), selected)
    }

    @Test
    fun rejectsAmbiguousPlaybackFeatures() {
        val selected = selectHardwareVolumeFeatures(
            features = listOf(master, master.copy(unitId = 8)),
            terminalLink = 2,
            outputTerminalSources = setOf(7, 8),
            quirk = DacQuirk(),
        )

        assertNull(selected)
    }

    @Test
    fun quirkSelectsSpecifiedChannels() {
        val left = master.copy(channel = 1)
        val right = master.copy(channel = 2)
        val selected = selectHardwareVolumeFeatures(
            features = listOf(master, left, right),
            terminalLink = null,
            outputTerminalSources = emptySet(),
            quirk = DacQuirk(
                hardwareVolumeFeatureUnitId = 7,
                hardwareVolumeControlInterface = 0,
                hardwareVolumeChannels = listOf(1, 2),
            ),
        )

        assertEquals(listOf(left, right), selected)
    }

    @Test
    fun mapsLinearGainToQ8_8DbAndSnapsToStep() {
        val range = HardwareVolumeRange(
            minQ8_8 = -60 * 256,
            maxQ8_8 = 0,
            stepQ8_8 = 256,
            muteQ8_8 = -112 * 256,
        )

        assertEquals(-6 * 256, hardwareVolumeQ8_8(32768, range))
        assertEquals(-112 * 256, hardwareVolumeQ8_8(0, range))
    }

    @Test
    fun mapsQ8_8DbBackToLinearGain() {
        assertEquals(65536, hardwareVolumeGainQ16(0, Short.MIN_VALUE.toInt()))
        assertEquals(32846, hardwareVolumeGainQ16(-6 * 256, Short.MIN_VALUE.toInt()))
        assertEquals(0, hardwareVolumeGainQ16(Short.MIN_VALUE.toInt(), Short.MIN_VALUE.toInt()))
        assertEquals(0, hardwareVolumeGainQ16(Int.MIN_VALUE, Short.MIN_VALUE.toInt()))
        assertEquals(65536, hardwareVolumeGainQ16(Int.MAX_VALUE, Short.MIN_VALUE.toInt()))
    }

    @Test
    fun buildsClassRequestTypeForConfiguredRecipient() {
        assertEquals(0xa0, hardwareVolumeRequestType(0x80, "device"))
        assertEquals(0x20, hardwareVolumeRequestType(0x00, "device"))
        assertEquals(0xa1, hardwareVolumeRequestType(0x80, "interface"))
        assertEquals(0x21, hardwareVolumeRequestType(0x00, "interface"))
    }

    @Test
    fun claimsInterfaceOnlyForInterfaceRecipient() {
        assertEquals(false, hardwareVolumeRequiresInterfaceClaim("device"))
        assertEquals(true, hardwareVolumeRequiresInterfaceClaim("interface"))
    }

    @Test
    fun usesDedicatedConnectionOnlyForDeviceRecipient() {
        assertEquals(true, hardwareVolumeRequiresDedicatedConnection("device"))
        assertEquals(false, hardwareVolumeRequiresDedicatedConnection("interface"))
    }

    @Test
    fun acceptsDeviceRoundingWithinOneVolumeStep() {
        assertEquals(true, hardwareVolumeReadbackMatches(-1536, -1280, 256))
        assertEquals(false, hardwareVolumeReadbackMatches(-1536, -1024, 256))
        assertEquals(true, hardwareVolumeReadbackMatches(Short.MIN_VALUE.toInt(), Short.MIN_VALUE.toInt(), 256))
    }

    @Test
    fun acceptsSameRangeFromTwoChannels() {
        val range = HardwareVolumeRange(-63 * 256, 0, 256, -112 * 256)

        assertEquals(range, uniformHardwareVolumeRange(listOf(range, range), 2))
        assertNull(uniformHardwareVolumeRange(listOf(range), 2))
    }

    @Test
    fun mapsAcousticGainToIbassoHardwareTable() {
        val ninetyPercentGain = (0.9.pow(1.5) * 65536).toInt()

        assertEquals(0, ibassoVolumeIndex(0))
        assertEquals(90, ibassoVolumeIndex(ninetyPercentGain))
        assertEquals(100, ibassoVolumeIndex(65536))
        assertEquals(97, ibassoDeviceVolume(23))
        assertEquals(10, ibassoDeviceVolume(90))
    }

    @Test
    fun buildsIbassoI2cVolumePacket() {
        val packet = ibassoI2cWritePacket(
            command = 1,
            slave = 0x60,
            offset = 9,
            byteOffset = 1,
            value = 97,
        )

        assertEquals(16, packet.size)
        assertEquals(
            listOf(1, 17, 0x88, 0x60, 0, 0, 5, 9, 0, 1, 0, 97),
            packet.take(12).map { it.toInt() and 0xff },
        )
    }

    @Test
    fun appliesDsdCompensationInHalfDbHardwareSteps() {
        assertEquals(85, ibassoDsdVolume(97, 6))
        assertEquals(109, ibassoDsdVolume(97, -6))
        assertEquals(0, ibassoDsdVolume(4, 6))
        assertEquals(255, ibassoDsdVolume(250, -6))
    }
}
