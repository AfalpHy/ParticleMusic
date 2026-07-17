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
    private val protocol = IbassoHidVolumeProtocol

    @Test
    fun selectsUsbSlotFromPcmSourceBitDepthInAutoMode() {
        assertEquals(16, preferredAutoPcmBitDepth(16, listOf(16, 24, 32)))
        assertEquals(24, preferredAutoPcmBitDepth(20, listOf(16, 24, 32)))
        assertEquals(24, preferredAutoPcmBitDepth(null, listOf(16, 24, 32)))
        assertNull(preferredAutoPcmBitDepth(32, listOf(16, 24)))
    }

    @Test
    fun allowsPcmDigitalFallbackWithoutVerifiedHardwareVolume() {
        assertNull(
            unsafeDsdVolumeReason(
                isDsd = false,
                hardwareVolumeActive = false,
                readbackVerified = false,
                writeOnly = true,
            ),
        )
    }

    @Test
    fun usesDigitalFallbackWhenPcmHardwareVolumeLosesVerification() {
        assertTrue(
            shouldUsePcmDigitalVolumeFallback(
                isDsd = false,
                volumeMode = "auto",
                hardwareVolumeActive = true,
                readbackVerified = false,
                writeOnly = true,
            ),
        )
        assertFalse(
            shouldUsePcmDigitalVolumeFallback(
                isDsd = true,
                volumeMode = "auto",
                hardwareVolumeActive = true,
                readbackVerified = false,
                writeOnly = true,
            ),
        )
        assertFalse(
            shouldUsePcmDigitalVolumeFallback(
                isDsd = false,
                volumeMode = "raw",
                hardwareVolumeActive = false,
                readbackVerified = false,
                writeOnly = true,
            ),
        )
    }

    @Test
    fun attenuatesImmediatelyWhenPcmFallsBackFromHardwareVolume() {
        assertFalse(
            shouldSmoothPcmVolumeHandoff(
                smoothHandoff = true,
                isDsd = false,
                wasHardwareActive = true,
                hardwareVolumeActive = false,
            ),
        )
        assertTrue(
            shouldSmoothPcmVolumeHandoff(
                smoothHandoff = true,
                isDsd = false,
                wasHardwareActive = false,
                hardwareVolumeActive = true,
            ),
        )
        assertFalse(
            shouldSmoothPcmVolumeHandoff(
                smoothHandoff = false,
                isDsd = false,
                wasHardwareActive = false,
                hardwareVolumeActive = true,
            ),
        )
    }

    @Test
    fun allowsDsdOnlyWithVerifiedReadableHardwareVolume() {
        assertNull(
            unsafeDsdVolumeReason(
                isDsd = true,
                hardwareVolumeActive = true,
                readbackVerified = true,
                writeOnly = false,
            ),
        )
    }

    @Test
    fun rejectsDsdWithoutActiveHardwareVolume() {
        assertEquals(
            "DSD playback requires active hardware volume.",
            unsafeDsdVolumeReason(
                isDsd = true,
                hardwareVolumeActive = false,
                readbackVerified = true,
                writeOnly = false,
            ),
        )
    }

    @Test
    fun rejectsDsdWriteOnlyOrUnverifiedHardwareVolume() {
        assertEquals(
            "DSD playback requires readable hardware volume confirmation.",
            unsafeDsdVolumeReason(
                isDsd = true,
                hardwareVolumeActive = true,
                readbackVerified = false,
                writeOnly = false,
            ),
        )
        assertEquals(
            "DSD playback requires readable hardware volume confirmation.",
            unsafeDsdVolumeReason(
                isDsd = true,
                hardwareVolumeActive = true,
                readbackVerified = true,
                writeOnly = true,
            ),
        )
    }

    @Test
    fun exposesIbassoProtocolCapabilities() {
        assertEquals("ibassoHid", protocol.id)
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
    fun derivesReadbackStateFromTheActiveProtocol() {
        val contradictoryIbassoHealth = IbassoReaderHealth(
            writeOnly = true,
            readbackVerified = true,
        )

        assertTrue(hardwareVolumeWriteOnlyForState("ibassoHid", contradictoryIbassoHealth))
        assertFalse(
            hardwareVolumeReadbackVerifiedForState(
                "ibassoHid",
                standardReadbackVerified = true,
                ibassoHealth = contradictoryIbassoHealth,
            ),
        )
        assertFalse(hardwareVolumeWriteOnlyForState("uac2", contradictoryIbassoHealth))
        assertTrue(
            hardwareVolumeReadbackVerifiedForState(
                "uac2",
                standardReadbackVerified = true,
                ibassoHealth = contradictoryIbassoHealth,
            ),
        )
        assertFalse(
            hardwareVolumeReadbackVerifiedForState(
                null,
                standardReadbackVerified = true,
                ibassoHealth = contradictoryIbassoHealth,
            ),
        )
    }

    @Test
    fun selectsOnlyTheGenericIbassoHidProtocolId() {
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

    @Test
    fun gatesDsdHardwareGainByProtocolCapabilityAndQuirkEvidence() {
        val vendorWithDsdGain = VendorUsbVolumeProtocol(protocol)
        val vendorWithoutDsdGain = VendorUsbVolumeProtocol(
            object : UsbVolumeProtocol by protocol {
                override val capabilities = protocol.capabilities.copy(dsdGain = false)
            },
        )

        assertTrue(hardwareVolumeSupportedForStream(vendorWithDsdGain, isDsd = true, true))
        assertTrue(hardwareVolumeSupportedForStream(vendorWithDsdGain, isDsd = true, null))
        assertFalse(hardwareVolumeSupportedForStream(vendorWithDsdGain, isDsd = true, false))
        assertFalse(hardwareVolumeSupportedForStream(vendorWithoutDsdGain, isDsd = true, true))
        assertFalse(hardwareVolumeSupportedForStream(vendorWithoutDsdGain, isDsd = true, null))
        assertFalse(hardwareVolumeSupportedForStream(vendorWithoutDsdGain, isDsd = true, false))

        assertTrue(hardwareVolumeSupportedForStream(StandardUsbVolumeProtocol, isDsd = true, true))
        assertFalse(hardwareVolumeSupportedForStream(StandardUsbVolumeProtocol, isDsd = true, false))
        assertFalse(hardwareVolumeSupportedForStream(StandardUsbVolumeProtocol, isDsd = true, null))

        val unsupported = UnsupportedUsbVolumeProtocol("unknownProtocol")
        assertFalse(hardwareVolumeSupportedForStream(unsupported, isDsd = true, true))
        assertFalse(hardwareVolumeSupportedForStream(unsupported, isDsd = true, false))
        assertFalse(hardwareVolumeSupportedForStream(unsupported, isDsd = true, null))

        assertTrue(hardwareVolumeSupportedForStream(vendorWithoutDsdGain, isDsd = false, false))
        assertTrue(hardwareVolumeSupportedForStream(StandardUsbVolumeProtocol, isDsd = false, null))
        assertTrue(hardwareVolumeSupportedForStream(unsupported, isDsd = false, null))
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
    fun reportsPcmBitPerfectOnlyWhenEffectiveDepthAndUsbSlotMatch() {
        assertTrue(pcmBitPerfect(24, 24, 24, digitalVolumeActive = false))
        assertTrue(pcmBitPerfect(16, 16, 16, digitalVolumeActive = false))
        assertFalse(pcmBitPerfect(24, 16, 24, digitalVolumeActive = false))
        assertFalse(pcmBitPerfect(16, 16, 24, digitalVolumeActive = false))
        assertFalse(pcmBitPerfect(null, 16, 16, digitalVolumeActive = false))
        assertFalse(pcmBitPerfect(24, 24, 24, digitalVolumeActive = true))
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
    fun keepsOnlyTheLatestPendingAbsoluteTarget() {
        val running = UsbVolumeRequest(3000, 0, "dac", 0, true, 7)
        val pending = UsbVolumeRequest(2000, 0, "dac", 0, true, 7)
        val incoming = UsbVolumeRequest(2500, 0, "dac", 0, true, 7)

        assertEquals(
            incoming,
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
            incoming,
            coalescedUsbVolumeRequest(running, pending, incoming, isDsd = true),
        )
    }

    @Test
    fun waitsForIbassoSettleAndLatestPendingQuietWindow() {
        val protocol = IbassoHidVolumeProtocol.id

        assertEquals(100L, usbVolumePendingDelayMs(protocol, 1000L, null, 1050L))
        assertEquals(200L, usbVolumePendingDelayMs(protocol, 1000L, 1100L, 1200L))
        assertEquals(50L, usbVolumePendingDelayMs(protocol, 1000L, 1100L, 1350L))
        assertEquals(0L, usbVolumePendingDelayMs(protocol, 1000L, 1100L, 1400L))
    }

    @Test
    fun skipsPendingDebounceOutsideAnActiveIbassoSequence() {
        assertEquals(0L, usbVolumePendingDelayMs(null, null, 1000L, 1100L))
        assertEquals(
            0L,
            usbVolumePendingDelayMs("standardUsbAudioClass", 1000L, 1050L, 1100L),
        )
    }

    @Test
    fun keepsConfiguredProtocolOnlyForHardwareVolumeRequests() {
        val protocol = IbassoHidVolumeProtocol.id

        assertEquals(protocol, usbVolumeProtocolForRequest("auto", protocol, true, true))
        assertEquals(protocol, usbVolumeProtocolForRequest("dac", protocol, true, true))
        assertNull(usbVolumeProtocolForRequest("digital", protocol, true, true))
        assertNull(usbVolumeProtocolForRequest("raw", protocol, true, true))
        assertNull(usbVolumeProtocolForRequest("auto", null, true, true))
        assertNull(usbVolumeProtocolForRequest("auto", protocol, false, true))
        assertNull(usbVolumeProtocolForRequest("auto", protocol, true, false))
    }

    @Test
    fun verifiesIbassoWriteBeforeChangingHardwareAuthority() {
        assertEquals(
            IbassoVolumeVerificationAction.ACCEPT_TARGET,
            ibassoVolumeVerificationAction(100, 102, 100, 1, isDsd = false),
        )
        assertEquals(
            IbassoVolumeVerificationAction.KEEP_PREVIOUS,
            ibassoVolumeVerificationAction(100, 102, 102, 1, isDsd = false),
        )
        assertEquals(
            IbassoVolumeVerificationAction.RETRY_READBACK,
            ibassoVolumeVerificationAction(100, 102, null, 1, isDsd = false),
        )
        assertEquals(
            IbassoVolumeVerificationAction.FREEZE_PCM,
            ibassoVolumeVerificationAction(100, 102, null, 3, isDsd = false),
        )
        assertEquals(
            IbassoVolumeVerificationAction.PAUSE_DSD,
            ibassoVolumeVerificationAction(100, 102, null, 3, isDsd = true),
        )
    }

    @Test
    fun yieldsVerificationToAPendingRequestInsteadOfFreezing() {
        assertEquals(
            IbassoVolumeVerificationAction.YIELD_TO_PENDING,
            ibassoVolumeVerificationAction(
                100, 102, null, 3,
                isDsd = false,
                hasPendingRequest = true,
            ),
        )
        assertEquals(
            IbassoVolumeVerificationAction.YIELD_TO_PENDING,
            ibassoVolumeVerificationAction(
                100, 102, null, 3,
                isDsd = true,
                hasPendingRequest = true,
            ),
        )
        // 读回成功匹配时照常接受，不受挂起请求影响
        assertEquals(
            IbassoVolumeVerificationAction.ACCEPT_TARGET,
            ibassoVolumeVerificationAction(
                100, 102, 100, 3,
                isDsd = false,
                hasPendingRequest = true,
            ),
        )
    }

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

    @Test
    fun skipsOnlyVerifiedDuplicateIbassoVolumeTargets() {
        val target = UsbVolumeTarget(baseRaw = 130, dsdRaw = 130)

        assertTrue(
            shouldSkipIbassoVolumeWrite(
                target = target,
                previousTarget = target,
                readbackVerified = true,
            ),
        )
        assertFalse(
            shouldSkipIbassoVolumeWrite(
                target = target,
                previousTarget = target,
                readbackVerified = false,
            ),
        )
        assertFalse(
            shouldSkipIbassoVolumeWrite(
                target = target,
                previousTarget = UsbVolumeTarget(baseRaw = 120, dsdRaw = 120),
                readbackVerified = true,
            ),
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
    fun decodesEndpointPrefixedAndLegacyUnsolicitedVolumeEvents() {
        val packet = ByteArray(32)
        packet[4] = 0xfe.toByte()
        packet[5] = 0x01
        packet[8] = 97
        packet[9] = 98
        val legacy = ByteArray(16)
        legacy[0] = 0xfe.toByte()
        legacy[1] = 0x01
        legacy[8] = 97
        legacy[9] = 98

        assertEquals(UsbVolumeEvent(97, 98), protocol.decodeEvent(packet))
        assertEquals(UsbVolumeEvent(97, 98), protocol.decodeEvent(legacy))
        assertNull(protocol.decodeEvent(packet.copyOf(9)))

        val response = ByteArray(32)
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

    @Test
    fun routesUnsolicitedEventsBeforeCommandResponses() {
        val packet = ibassoEventPacket(leftRaw = 97, rightRaw = 97).also {
            it[6] = 65
        }

        val route = routeIbassoVolumePacket(packet, setOf(65), lastWrittenRaw = 97)

        assertTrue(route is IbassoVolumePacketRoute.Event)
        route as IbassoVolumePacketRoute.Event
        assertEquals(UsbVolumeEvent(97, 97), route.event)
        assertTrue(route.isWriteConfirmation)
    }

    @Test
    fun routesCommandResponsesAndKeepsTheirCommandId() {
        val matchingPacket = ibassoResponsePacket(65)
        val matching = routeIbassoVolumePacket(matchingPacket, setOf(65), null)
        val wrongCommand = routeIbassoVolumePacket(ibassoResponsePacket(64), setOf(65), null)

        assertTrue(matching is IbassoVolumePacketRoute.CommandResponse)
        matching as IbassoVolumePacketRoute.CommandResponse
        assertEquals(65, matching.command)
        assertSame(matchingPacket, matching.packet)
        assertTrue(wrongCommand is IbassoVolumePacketRoute.CommandResponse)
        wrongCommand as IbassoVolumePacketRoute.CommandResponse
        assertEquals(64, wrongCommand.command)
    }

    @Test
    fun routesLateValidCommandResponsesWithoutReportingUnknownPackets() {
        val packet = ibassoResponsePacket(command = 0, value = 120)

        val route = routeIbassoVolumePacket(packet, emptySet(), null)

        assertTrue(route is IbassoVolumePacketRoute.CommandResponse)
        route as IbassoVolumePacketRoute.CommandResponse
        assertEquals(0, route.command)
        assertSame(packet, route.packet)
    }

    @Test
    fun doesNotMistakeOrdinaryResponsesForEvents() {
        val route = routeIbassoVolumePacket(ibassoResponsePacket(19), setOf(19), null)

        assertTrue(route is IbassoVolumePacketRoute.CommandResponse)
        assertFalse(route is IbassoVolumePacketRoute.Event)
    }

    @Test
    fun classifiesStereoEventsAndUnknownPackets() {
        val confirmation = routeIbassoVolumePacket(
            ibassoEventPacket(leftRaw = 97, rightRaw = 97),
            emptySet(),
            lastWrittenRaw = 97,
        )
        val changed = routeIbassoVolumePacket(
            ibassoEventPacket(leftRaw = 97, rightRaw = 98),
            emptySet(),
            lastWrittenRaw = 97,
        )

        assertTrue((confirmation as IbassoVolumePacketRoute.Event).isWriteConfirmation)
        assertFalse((changed as IbassoVolumePacketRoute.Event).isWriteConfirmation)
        assertEquals(
            IbassoVolumePacketRoute.Unknown,
            routeIbassoVolumePacket(byteArrayOf(0x01), emptySet(), null),
        )
    }

    @Test
    fun transitionsReaderFromRestartToWriteOnlyAfterTwoFailures() {
        val initial = IbassoReaderHealth()
        assertTrue(initial.readable)
        assertFalse(initial.restartRequested)
        assertFalse(initial.writeOnly)

        val firstFailure = initial.afterFailure()
        assertTrue(firstFailure.readable)
        assertTrue(firstFailure.restartRequested)
        assertFalse(firstFailure.writeOnly)
        assertFalse(firstFailure.readbackVerified)

        val restarted = firstFailure.afterRestart()
        assertFalse(restarted.restartRequested)
        val secondFailure = restarted.afterFailure()
        assertFalse(secondFailure.readable)
        assertFalse(secondFailure.restartRequested)
        assertTrue(secondFailure.writeOnly)
        assertFalse(secondFailure.readbackVerified)
    }

    @Test
    fun verifiedReadbackClearsPreviousReaderFailureBeforeNextFailure() {
        val recovered = IbassoReaderHealth()
            .afterFailure()
            .afterRestart()
            .afterVerifiedReadback()

        assertEquals(0, recovered.failureCount)
        assertFalse(recovered.restartRequested)
        assertFalse(recovered.writeOnly)
        assertTrue(recovered.readbackVerified)

        val nextFailure = recovered.afterFailure()
        assertEquals(1, nextFailure.failureCount)
        assertTrue(nextFailure.restartRequested)
        assertFalse(nextFailure.writeOnly)
    }

    @Test
    fun rejectsCallbacksFromSupersededReaderGenerations() {
        assertTrue(
            isCurrentIbassoReaderGeneration(
                readerGeneration = 2,
                currentGeneration = 2,
                running = true,
                threadMatches = true,
                connectionMatches = true,
                endpointMatches = true,
            ),
        )
        assertFalse(
            isCurrentIbassoReaderGeneration(
                readerGeneration = 1,
                currentGeneration = 2,
                running = true,
                threadMatches = true,
                connectionMatches = true,
                endpointMatches = true,
            ),
        )
        assertFalse(
            isCurrentIbassoReaderGeneration(
                readerGeneration = 2,
                currentGeneration = 2,
                running = true,
                threadMatches = false,
                connectionMatches = true,
                endpointMatches = true,
            ),
        )
    }

    @Test
    fun restartsOnlyAfterTheFailedCurrentReaderThreadExits() {
        assertTrue(
            shouldRestartIbassoReaderGeneration(
                readerGeneration = 2,
                currentGeneration = 2,
                running = false,
                readerThreadExited = true,
                connectionMatches = true,
                endpointMatches = true,
                volumeConnectionMatches = true,
                restartRequested = true,
            ),
        )
        assertFalse(
            shouldRestartIbassoReaderGeneration(
                readerGeneration = 1,
                currentGeneration = 2,
                running = false,
                readerThreadExited = true,
                connectionMatches = true,
                endpointMatches = true,
                volumeConnectionMatches = true,
                restartRequested = true,
            ),
        )
        assertFalse(
            shouldRestartIbassoReaderGeneration(
                readerGeneration = 2,
                currentGeneration = 2,
                running = false,
                readerThreadExited = false,
                connectionMatches = true,
                endpointMatches = true,
                volumeConnectionMatches = true,
                restartRequested = true,
            ),
        )
    }

    @Test
    fun ignoresIdleReaderTimeoutsWithoutPendingResponse() {
        var health = IbassoReaderHealth()

        repeat(10) {
            health = health.afterReadResult(readLength = -1, hasPendingResponse = false)
        }

        assertEquals(0, health.pendingReadFailureCount)
        assertEquals(0, health.failureCount)
        assertFalse(health.restartRequested)
        assertFalse(health.writeOnly)
    }

    @Test
    fun pendingReaderFailuresRestartThenBecomeWriteOnly() {
        var health = IbassoReaderHealth()
        repeat(3) {
            health = health.afterReadResult(readLength = -1, hasPendingResponse = true)
        }
        assertTrue(health.hasPersistentPendingFailure(3))

        health = health.afterFailure()
        assertTrue(health.restartRequested)
        assertFalse(health.writeOnly)

        health = health.afterRestart()
        repeat(3) {
            health = health.afterReadResult(readLength = 0, hasPendingResponse = true)
        }
        assertTrue(health.hasPersistentPendingFailure(3))

        health = health.afterFailure()
        assertFalse(health.restartRequested)
        assertTrue(health.writeOnly)
    }

    @Test
    fun successfulReaderReadResetsPendingFailures() {
        var health = IbassoReaderHealth()
            .afterReadResult(readLength = -1, hasPendingResponse = true)
            .afterReadResult(readLength = 0, hasPendingResponse = true)
        assertEquals(2, health.pendingReadFailureCount)

        health = health.afterReadResult(readLength = 16, hasPendingResponse = true)

        assertEquals(0, health.pendingReadFailureCount)
        assertFalse(health.hasPersistentPendingFailure(3))
        assertEquals(0, health.failureCount)
    }

    @Test
    fun idleTimeoutResetsAnIncompletePendingFailureSequence() {
        var health = IbassoReaderHealth()
            .afterReadResult(readLength = -1, hasPendingResponse = true)
            .afterReadResult(readLength = -1, hasPendingResponse = true)

        health = health.afterReadResult(readLength = -1, hasPendingResponse = false)

        assertEquals(0, health.pendingReadFailureCount)
        assertFalse(health.restartRequested)
        assertFalse(health.writeOnly)
    }

    @Test
    fun resumesReaderFailureHealthOnlyForTheSameDevice() {
        val failed = IbassoReaderHealth().afterFailure()

        assertTrue(shouldResumeIbassoReaderHealth(failed, healthDeviceId = 7, deviceId = 7))
        assertFalse(shouldResumeIbassoReaderHealth(failed, healthDeviceId = 7, deviceId = 8))
        assertFalse(
            shouldResumeIbassoReaderHealth(
                IbassoReaderHealth(),
                healthDeviceId = 7,
                deviceId = 7,
            ),
        )
    }

    @Test
    fun keepsTrustedIbassoTargetOnlyForSameDevice() {
        val target = UsbVolumeTarget(baseRaw = 97, dsdRaw = 85)

        assertEquals(target, trustedIbassoTargetForDevice(target, 7, 7))
        assertNull(trustedIbassoTargetForDevice(target, 7, 8))
        assertNull(trustedIbassoTargetForDevice(null, 7, 7))
    }

    @Test
    fun unsolicitedIbassoEventBecomesTrustedTarget() {
        assertEquals(
            UsbVolumeTarget(baseRaw = 97, dsdRaw = 85),
            ibassoTargetFromEvent(baseRaw = 97, dsdCompensationDb = 6),
        )
    }

    @Test
    fun selectsDirectSetReportForRollbackWhenReaderIsUnavailable() {
        assertTrue(
            shouldUseDirectIbassoSetReport(
                writeOnly = false,
                readerAvailable = false,
                allowWhenReaderUnavailable = true,
            ),
        )
        assertFalse(
            shouldUseDirectIbassoSetReport(
                writeOnly = false,
                readerAvailable = true,
                allowWhenReaderUnavailable = true,
            ),
        )
        assertFalse(
            shouldUseDirectIbassoSetReport(
                writeOnly = false,
                readerAvailable = false,
                allowWhenReaderUnavailable = false,
            ),
        )
        assertTrue(
            shouldUseDirectIbassoSetReport(
                writeOnly = true,
                readerAvailable = true,
                allowWhenReaderUnavailable = false,
            ),
        )
    }

    @Test
    fun keepsWrittenRawOnlyInsideConfirmationWindow() {
        assertEquals(97, recentIbassoWrittenRaw(97, 1000, 1001, 500))
        assertEquals(97, recentIbassoWrittenRaw(97, 1000, 1500, 500))
        assertNull(recentIbassoWrittenRaw(97, 1000, 1501, 500))
        assertNull(recentIbassoWrittenRaw(null, 1000, 1001, 500))
    }

    @Test
    fun selectsReadableDeviceGainOnlyWhenItCannotRaiseVolume() {
        assertEquals(
            HardwareVolumeHandoffTarget(16384, HardwareVolumeHandoffSource.DEVICE),
            hardwareVolumeHandoffTarget(true, 16384, 32768),
        )
        assertEquals(
            HardwareVolumeHandoffTarget(16384, HardwareVolumeHandoffSource.APP),
            hardwareVolumeHandoffTarget(true, 32768, 16384),
        )
        assertEquals(
            HardwareVolumeHandoffTarget(16384, HardwareVolumeHandoffSource.APP),
            hardwareVolumeHandoffTarget(false, 32768, 16384),
        )
        assertEquals(
            HardwareVolumeHandoffTarget(16384, HardwareVolumeHandoffSource.APP),
            hardwareVolumeHandoffTarget(true, null, 16384),
        )
        assertEquals(
            HardwareVolumeHandoffTarget(16384, HardwareVolumeHandoffSource.APP),
            hardwareVolumeHandoffTarget(true, 65537, 16384),
        )
    }

    @Test
    fun readsInitialHardwareVolumeOnlyForNewReadableControl() {
        assertTrue(shouldReadInitialHardwareVolume(isNewConnection = true, readable = true))
        assertFalse(shouldReadInitialHardwareVolume(isNewConnection = false, readable = true))
        assertFalse(shouldReadInitialHardwareVolume(isNewConnection = true, readable = false))
    }

    @Test
    fun selectsOnlyTrustedIbassoRollbackTargets() {
        val lastApplied = UsbVolumeTarget(baseRaw = 97, dsdRaw = 85)

        assertEquals(lastApplied, ibassoRollbackTarget(lastApplied, 109, 6))
        assertEquals(UsbVolumeTarget(109, 97), ibassoRollbackTarget(null, 109, 6))
        assertNull(ibassoRollbackTarget(null, null, 6))
    }

    @Test
    fun buildsCompleteIbassoTargetAndRollbackPacketGroups() {
        val targetPackets = ibassoVolumePackets(UsbVolumeTarget(97, 85))
        val rollbackTarget = ibassoRollbackTarget(null, 109, 6)!!
        val rollbackPackets = ibassoVolumePackets(rollbackTarget)
        val commands = listOf(1, 2, 3, 4, 9, 10, 19, 11, 12, 20)

        assertEquals(10, targetPackets.size)
        assertEquals(commands, targetPackets.map { it[0].toInt() and 0xff })
        assertEquals(
            listOf(97, 97, 97, 97, 85, 85, 97, 85, 85, 97),
            targetPackets.map { packet ->
                val command = packet[0].toInt() and 0xff
                packet[if (command == 19 || command == 20) 7 else 11].toInt() and 0xff
            },
        )
        assertEquals(10, rollbackPackets.size)
        assertEquals(commands, rollbackPackets.map { it[0].toInt() and 0xff })
        assertEquals(
            listOf(109, 109, 109, 109, 97, 97, 109, 97, 97, 109),
            rollbackPackets.map { packet ->
                val command = packet[0].toInt() and 0xff
                packet[if (command == 19 || command == 20) 7 else 11].toInt() and 0xff
            },
        )
    }

    @Test
    fun mapsIbassoBaseRawToCurrentPcmOrDsdGain() {
        val pcm = ibassoActualEventGainQ16(97, isDsd = false, dsdCompensationDb = 6)
        val dsd = ibassoActualEventGainQ16(97, isDsd = true, dsdCompensationDb = 6)

        assertEquals(97, pcm.raw)
        assertEquals(IbassoHidVolumeProtocol.rawToLinearGainQ16(97), pcm.gainQ16)
        assertEquals(85, dsd.raw)
        assertEquals(IbassoHidVolumeProtocol.rawToLinearGainQ16(85), dsd.gainQ16)
    }

    @Test
    fun consumesOnlyTheLatestDebouncedVolumeEventOnce() {
        val debouncer = IbassoVolumeEventDebouncer()
        val eventA = UsbVolumeEvent(97, 97)
        val eventB = UsbVolumeEvent(98, 99)

        val token1 = debouncer.submit(eventA)
        val token2 = debouncer.submit(eventB)
        assertFalse(token1 == token2)
        assertNull(debouncer.consume(token1))
        assertEquals(eventB, debouncer.consume(token2))
        assertNull(debouncer.consume(token2))

        val staleToken = debouncer.submit(eventA)
        debouncer.clear()
        assertNull(debouncer.consume(staleToken))
    }

    private fun ibassoEventPacket(leftRaw: Int, rightRaw: Int): ByteArray =
        ByteArray(32).also {
            it[4] = 0xfe.toByte()
            it[5] = 0x01
            it[8] = leftRaw.toByte()
            it[9] = rightRaw.toByte()
        }

    private fun ibassoResponsePacket(command: Int, value: Int = 0): ByteArray =
        ByteArray(32).also {
            it[6] = command.toByte()
            it[7] = 1
            it[8] = value.toByte()
        }

    private fun gainQ16ForIndex(index: Int): Int =
        ((index / 100.0).pow(1.5) * 65536).roundToInt()
}
