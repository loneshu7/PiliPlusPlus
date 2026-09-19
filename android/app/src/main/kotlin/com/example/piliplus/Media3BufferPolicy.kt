package com.example.piliplus

internal data class Media3BufferPolicy(
    val targetBufferBytes: Int,
    val minBufferMs: Int,
    val maxBufferMs: Int,
    val bufferForPlaybackMs: Int,
    val bufferForPlaybackAfterRebufferMs: Int,
    val backBufferDurationMs: Int,
)

/**
 * Maps the shared VOD preferences onto a self-consistent Media3 load policy.
 *
 * Media3 evaluates the byte budget against the allocator total, which also
 * covers retained back-buffer samples, so a back buffer sharing the forward
 * budget can starve loading while playback is still consuming media. The
 * forward duration therefore owns the buffering target and the back buffer is
 * disabled, mirroring mpv's separate forward and backward byte budgets.
 *
 * Playback start thresholds stay at Media3's documented defaults so a rebuffer
 * resumes as soon as a small amount of media is available instead of stalling
 * at a threshold the byte budget may never let the loader reach.
 *
 * Live sessions retain Media3's defaults because their latency policy cannot be
 * inferred from the VOD buffer-duration preference.
 */
internal fun resolveMedia3BufferPolicy(
    targetBufferBytes: Int,
    bufferDurationMs: Int,
    isLive: Boolean,
): Media3BufferPolicy? {
    if (isLive) return null
    val maximumMs = bufferDurationMs.coerceAtLeast(MIN_MEDIA3_BUFFER_DURATION_MS)
    return Media3BufferPolicy(
        targetBufferBytes = targetBufferBytes.coerceAtLeast(MIN_MEDIA3_TARGET_BUFFER_BYTES),
        minBufferMs = maximumMs,
        maxBufferMs = maximumMs,
        bufferForPlaybackMs = minOf(DEFAULT_MEDIA3_PLAYBACK_MS, maximumMs),
        bufferForPlaybackAfterRebufferMs = minOf(DEFAULT_MEDIA3_REBUFFER_MS, maximumMs),
        backBufferDurationMs = 0,
    )
}

private const val MIN_MEDIA3_TARGET_BUFFER_BYTES = 64 * 1024
private const val MIN_MEDIA3_BUFFER_DURATION_MS = 500
private const val DEFAULT_MEDIA3_PLAYBACK_MS = 1000
private const val DEFAULT_MEDIA3_REBUFFER_MS = 2000
