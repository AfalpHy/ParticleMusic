package com.afalphy.sylvakru

internal fun chooseBitPerfectMixerSampleRate(
    requestedSampleRate: Int?,
    supportedSampleRates: List<Int>,
): Int? {
    val validRates = supportedSampleRates.filter { it > 0 }
    return if (requestedSampleRate != null) {
        validRates.firstOrNull { it == requestedSampleRate }
    } else {
        validRates.maxOrNull()
    }
}
