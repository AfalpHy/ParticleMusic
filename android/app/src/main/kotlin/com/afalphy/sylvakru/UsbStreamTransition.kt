package com.afalphy.sylvakru

internal const val USB_TRANSITION_FADE_MS = 16
internal const val USB_TRANSITION_OLD_SILENCE_MS = 24
internal const val USB_TRANSITION_PREROLL_MS = 100
internal const val USB_TRANSITION_DRAIN_TIMEOUT_MS = 220L

internal data class UsbStreamSignature(
    val deviceId: Int,
    val sampleRate: Int?,
    val channels: Int,
    val bitDepth: Int?,
    val dsdKind: String?,
    val nativeFormat: String?,
)

internal enum class UsbStreamTransitionAction {
    REUSE,
    SILENT_RECONFIGURE,
    OPEN_FRESH,
}

internal data class UsbTransitionSilencePlan(
    val oldFadeMs: Int,
    val oldSilenceMs: Int,
    val newPreRollMs: Int,
)

internal fun usbTransitionSilencePlan(
    action: UsbStreamTransitionAction,
): UsbTransitionSilencePlan = if (action == UsbStreamTransitionAction.SILENT_RECONFIGURE) {
    UsbTransitionSilencePlan(
        oldFadeMs = USB_TRANSITION_FADE_MS,
        oldSilenceMs = USB_TRANSITION_OLD_SILENCE_MS,
        newPreRollMs = USB_TRANSITION_PREROLL_MS,
    )
} else {
    UsbTransitionSilencePlan(0, 0, 0)
}

internal fun usbStreamTransitionAction(
    current: UsbStreamSignature?,
    next: UsbStreamSignature,
    replaceActive: Boolean,
): UsbStreamTransitionAction = when {
    current == null -> UsbStreamTransitionAction.OPEN_FRESH
    current == next -> UsbStreamTransitionAction.REUSE
    replaceActive -> UsbStreamTransitionAction.SILENT_RECONFIGURE
    else -> UsbStreamTransitionAction.OPEN_FRESH
}

internal fun shouldPublishUsbStartFailure(
    replaceActive: Boolean,
    transitionCommitted: Boolean,
    currentActive: Boolean,
): Boolean = !replaceActive || transitionCommitted || !currentActive

internal fun pcmFadeToSilence(
    lastSamples: IntArray,
    fadeFrames: Int,
    silenceFrames: Int,
): IntArray {
    require(lastSamples.isNotEmpty())
    require(fadeFrames > 0)
    require(silenceFrames >= 0)
    val result = IntArray((fadeFrames + silenceFrames) * lastSamples.size)
    val denominator = (fadeFrames - 1).coerceAtLeast(1)
    for (frame in 0 until fadeFrames) {
        val numerator = (fadeFrames - 1 - frame).coerceAtLeast(0)
        for (channel in lastSamples.indices) {
            result[frame * lastSamples.size + channel] =
                ((lastSamples[channel].toLong() * numerator) / denominator).toInt()
        }
    }
    return result
}

internal fun pcmSampleForUsbTransition(
    sample: Int,
    inputBitDepth: Int,
    usbBitResolution: Int,
    gainQ16: Int,
): Int {
    val adjusted = ((sample.toLong() * gainQ16.coerceIn(0, 65536)) shr 16).toInt()
    return if (usbBitResolution >= inputBitDepth) {
        adjusted shl (usbBitResolution - inputBitDepth)
    } else {
        adjusted shr (inputBitDepth - usbBitResolution)
    }
}

internal fun usbSilenceFrames(sampleRate: Int, durationMs: Int): Int =
    ((sampleRate.toLong() * durationMs + 999L) / 1000L).coerceAtLeast(1L).toInt()

internal enum class OutputDrainAction { WAIT, DRAINED, TIMED_OUT }

internal fun outputDrainAction(
    pendingPackets: Long,
    elapsedMs: Long,
    timeoutMs: Long,
): OutputDrainAction = when {
    pendingPackets <= 0L -> OutputDrainAction.DRAINED
    elapsedMs >= timeoutMs -> OutputDrainAction.TIMED_OUT
    else -> OutputDrainAction.WAIT
}

internal fun shouldPreserveTrustedHardwareVolume(
    currentDeviceId: Int?,
    nextDeviceId: Int,
    currentProtocol: String?,
    nextProtocol: String?,
    readbackVerified: Boolean,
    writeOnly: Boolean,
): Boolean = currentDeviceId == nextDeviceId &&
    currentProtocol != null &&
    currentProtocol == nextProtocol &&
    readbackVerified &&
    !writeOnly

internal fun frozenPcmCompensationGainQ16(
    trustedHardwareGainQ16: Int,
    requestedTotalGainQ16: Int,
): Int {
    if (trustedHardwareGainQ16 <= 0) return 0
    if (requestedTotalGainQ16 >= trustedHardwareGainQ16) return 65536
    return ((requestedTotalGainQ16.toLong() shl 16) / trustedHardwareGainQ16)
        .coerceIn(0L, 65536L)
        .toInt()
}

internal enum class PreservedVolumeVerificationAction {
    ACCEPT,
    KEEP_FROZEN,
    IGNORE,
}

internal fun preservedVolumeVerificationAction(
    generationMatches: Boolean,
    isDsd: Boolean,
    readbackRaw: Int?,
    trustedRaw: Int,
): PreservedVolumeVerificationAction = when {
    !generationMatches -> PreservedVolumeVerificationAction.IGNORE
    isDsd -> PreservedVolumeVerificationAction.KEEP_FROZEN
    readbackRaw == trustedRaw -> PreservedVolumeVerificationAction.ACCEPT
    else -> PreservedVolumeVerificationAction.KEEP_FROZEN
}
