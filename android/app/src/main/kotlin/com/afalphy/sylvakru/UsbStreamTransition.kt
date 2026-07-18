package com.afalphy.sylvakru

internal const val USB_TRANSITION_FADE_MS = 16
internal const val USB_TRANSITION_OLD_SILENCE_MS = 24
internal const val USB_TRANSITION_PREROLL_MS = 100
internal const val USB_TRANSITION_DRAIN_TIMEOUT_MS = 220L
internal const val USB_PAUSE_RESUME_FADE_MS = 16
internal const val USB_VOLUME_RAMP_STEP_MS = 20L
internal const val USB_VOLUME_RAMP_MIN_STEPS = 6
internal const val USB_VOLUME_RAMP_FULL_RISE_STEPS = 30

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

// preRollMs 可由 quirk clock.preRollMs 覆盖：重锁慢的 DAC（继电器/异步锁定）
// 100ms 不够时按设备加长。
internal fun usbTransitionSilencePlan(
    action: UsbStreamTransitionAction,
    preRollMs: Int = USB_TRANSITION_PREROLL_MS,
): UsbTransitionSilencePlan = when (action) {
    UsbStreamTransitionAction.REUSE -> UsbTransitionSilencePlan(0, 0, 0)
    UsbStreamTransitionAction.SILENT_RECONFIGURE -> UsbTransitionSilencePlan(
        oldFadeMs = USB_TRANSITION_FADE_MS,
        oldSilenceMs = USB_TRANSITION_OLD_SILENCE_MS,
        newPreRollMs = preRollMs,
    )
    // 新开流（首播/停止后再播/自然播完切到不同参数）没有旧流要淡出，但 DAC
    // 同样要重锁时钟：预滚静音让重锁咔嗒不盖到曲子开头。
    UsbStreamTransitionAction.OPEN_FRESH -> UsbTransitionSilencePlan(
        oldFadeMs = 0,
        oldSilenceMs = 0,
        newPreRollMs = preRollMs,
    )
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

// 恢复播放的逐帧淡入增益：从 0 线性升到满刻度，消掉任意样本点续播的幅度跳变。
internal fun pcmFadeInGainQ16(frameIndex: Int, totalFrames: Int): Int {
    require(totalFrames > 0)
    if (frameIndex >= totalFrames) return 65536
    return ((frameIndex.coerceAtLeast(0).toLong() shl 16) / totalFrames).toInt()
}

// 数字音量渐变步数：上升按跨度限速（满跨度约 600ms）防止误拖滑条炸耳，
// 下降保持最少步数快速到位。
internal fun pcmVolumeRampSteps(startGainQ16: Int, targetGainQ16: Int): Int {
    val riseQ16 = targetGainQ16.toLong() - startGainQ16.toLong()
    if (riseQ16 <= 0) return USB_VOLUME_RAMP_MIN_STEPS
    val riseSteps = ((riseQ16 * USB_VOLUME_RAMP_FULL_RISE_STEPS + 65535L) / 65536L).toInt()
    return riseSteps.coerceAtLeast(USB_VOLUME_RAMP_MIN_STEPS)
}

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
