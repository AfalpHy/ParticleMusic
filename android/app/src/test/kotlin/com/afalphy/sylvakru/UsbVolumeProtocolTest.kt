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
    fun routesOnlyPendingCommandResponses() {
        val matchingPacket = ibassoResponsePacket(65)
        val matching = routeIbassoVolumePacket(matchingPacket, setOf(65), null)
        val wrongCommand = routeIbassoVolumePacket(ibassoResponsePacket(64), setOf(65), null)

        assertTrue(matching is IbassoVolumePacketRoute.CommandResponse)
        matching as IbassoVolumePacketRoute.CommandResponse
        assertEquals(65, matching.command)
        assertSame(matchingPacket, matching.packet)
        assertEquals(IbassoVolumePacketRoute.Unknown, wrongCommand)
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
    fun selectsReadableDeviceGainOnlyForSmoothHandoff() {
        assertEquals(
            HardwareVolumeHandoffTarget(32768, HardwareVolumeHandoffSource.DEVICE),
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
        assertEquals(IbassoDc03ProVolumeProtocol.rawToLinearGainQ16(97), pcm.gainQ16)
        assertEquals(85, dsd.raw)
        assertEquals(IbassoDc03ProVolumeProtocol.rawToLinearGainQ16(85), dsd.gainQ16)
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
        ByteArray(16).also {
            it[0] = 0xfe.toByte()
            it[1] = 0x01
            it[8] = leftRaw.toByte()
            it[9] = rightRaw.toByte()
        }

    private fun ibassoResponsePacket(command: Int): ByteArray =
        ByteArray(16).also { it[6] = command.toByte() }

    private fun gainQ16ForIndex(index: Int): Int =
        ((index / 100.0).pow(1.5) * 65536).roundToInt()
}
