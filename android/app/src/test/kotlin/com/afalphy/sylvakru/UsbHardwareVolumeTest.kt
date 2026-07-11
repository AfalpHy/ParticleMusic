package com.afalphy.sylvakru

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

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
    fun buildsClassRequestTypeForConfiguredRecipient() {
        assertEquals(0xa0, hardwareVolumeRequestType(0x80, "device"))
        assertEquals(0x20, hardwareVolumeRequestType(0x00, "device"))
        assertEquals(0xa1, hardwareVolumeRequestType(0x80, "interface"))
        assertEquals(0x21, hardwareVolumeRequestType(0x00, "interface"))
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
}
