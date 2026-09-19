package com.example.piliplus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Media3BufferPolicyTest {
    @Test
    fun defaultVodPreferencesKeepAPlayableTimeFloor() {
        assertEquals(
            Media3BufferPolicy(
                targetBufferBytes = 8 * 1024 * 1024,
                minBufferMs = 16000,
                maxBufferMs = 16000,
                bufferForPlaybackMs = 1000,
                bufferForPlaybackAfterRebufferMs = 2000,
                backBufferDurationMs = 0,
            ),
            resolveMedia3BufferPolicy(
                targetBufferBytes = 8 * 1024 * 1024,
                bufferDurationMs = 16000,
                isLive = false,
            ),
        )
    }

    @Test
    fun shortVodPreferenceKeepsAllThresholdsValid() {
        assertEquals(
            Media3BufferPolicy(
                targetBufferBytes = 64 * 1024,
                minBufferMs = 1000,
                maxBufferMs = 1000,
                bufferForPlaybackMs = 1000,
                bufferForPlaybackAfterRebufferMs = 1000,
                backBufferDurationMs = 0,
            ),
            resolveMedia3BufferPolicy(
                targetBufferBytes = 1,
                bufferDurationMs = 1000,
                isLive = false,
            ),
        )
    }

    @Test
    fun liveRetainsMedia3Defaults() {
        assertNull(
            resolveMedia3BufferPolicy(
                targetBufferBytes = 8 * 1024 * 1024,
                bufferDurationMs = 16000,
                isLive = true,
            ),
        )
    }

    @Test
    fun backBufferNeverSharesTheForwardByteBudget() {
        val policy = resolveMedia3BufferPolicy(
            targetBufferBytes = 8 * 1024 * 1024,
            bufferDurationMs = 16000,
            isLive = false,
        )!!
        assertEquals(0, policy.backBufferDurationMs)
    }

    @Test
    fun startThresholdsNeverExceedTheBufferingTarget() {
        listOf(0, 1, 400, 900, 1500, 16000, 60000).forEach { requested ->
            val policy = resolveMedia3BufferPolicy(
                targetBufferBytes = 8 * 1024 * 1024,
                bufferDurationMs = requested,
                isLive = false,
            )!!
            assertTrue(
                "bufferForPlaybackMs must stay within minBufferMs for $requested",
                policy.bufferForPlaybackMs <= policy.minBufferMs,
            )
            assertTrue(
                "bufferForPlaybackAfterRebufferMs must stay within minBufferMs for $requested",
                policy.bufferForPlaybackAfterRebufferMs <= policy.minBufferMs,
            )
            assertTrue(
                "minBufferMs must stay within maxBufferMs for $requested",
                policy.minBufferMs <= policy.maxBufferMs,
            )
        }
    }
}
