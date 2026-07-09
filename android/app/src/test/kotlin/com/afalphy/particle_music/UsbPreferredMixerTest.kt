package com.afalphy.sylvakru

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UsbPreferredMixerTest {
    @Test
    fun requestedRateDoesNotFallBackToAnotherBitPerfectRate() {
        val chosen = chooseBitPerfectMixerSampleRate(
            requestedSampleRate = 96000,
            supportedSampleRates = listOf(48000),
        )

        assertNull(chosen)
    }

    @Test
    fun requestedRateUsesExactBitPerfectRateWhenAvailable() {
        val chosen = chooseBitPerfectMixerSampleRate(
            requestedSampleRate = 96000,
            supportedSampleRates = listOf(48000, 96000),
        )

        assertEquals(96000, chosen)
    }

    @Test
    fun missingRequestedRateUsesHighestBitPerfectRate() {
        val chosen = chooseBitPerfectMixerSampleRate(
            requestedSampleRate = null,
            supportedSampleRates = listOf(44100, 96000, 48000),
        )

        assertEquals(96000, chosen)
    }
}
