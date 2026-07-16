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
    fun reusesAnExactIdleSessionAndOpensFreshForOtherRegularStarts() {
        assertEquals(
            UsbStreamTransitionAction.REUSE,
            usbStreamTransitionAction(pcm441, pcm441, replaceActive = false),
        )
        assertEquals(
            UsbStreamTransitionAction.OPEN_FRESH,
            usbStreamTransitionAction(
                pcm441,
                pcm441.copy(sampleRate = 96000),
                replaceActive = false,
            ),
        )
        assertEquals(
            UsbStreamTransitionAction.OPEN_FRESH,
            usbStreamTransitionAction(null, pcm441, replaceActive = true),
        )
    }

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

    @Test
    fun alignsTheGainAdjustedLastPcmSampleInTheUsbDomain() {
        assertEquals(4096, pcmSampleForUsbTransition(32, 16, 24, 32768))
        assertEquals(-4096, pcmSampleForUsbTransition(-32, 16, 24, 32768))
        assertEquals(32, pcmSampleForUsbTransition(32, 16, 16, 65536))
        assertEquals(0x1234, pcmSampleForUsbTransition(0x123456, 24, 16, 65536))
        assertEquals(Int.MAX_VALUE, pcmSampleForUsbTransition(Int.MAX_VALUE, 32, 32, 65536))
    }

    @Test
    fun doesNotPublishInactiveStateForAnUncommittedReplacementFailure() {
        assertFalse(shouldPublishUsbStartFailure(true, false, true))
        assertTrue(shouldPublishUsbStartFailure(true, true, true))
        assertTrue(shouldPublishUsbStartFailure(false, false, true))
        assertTrue(shouldPublishUsbStartFailure(true, false, false))
    }

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
                (0 until tail.lastIndex).all { index ->
                    kotlin.math.abs(tail[index + 1].toLong()) <=
                        kotlin.math.abs(tail[index].toLong())
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
}
