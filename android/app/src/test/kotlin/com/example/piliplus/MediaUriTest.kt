package com.example.piliplus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaUriTest {
    @Test
    fun plainFilePathNeedsFileUri() {
        assertTrue(needsFileUri("/sdcard/Movies/video.mp4"))
    }

    @Test
    fun httpUrlStaysHttp() {
        assertFalse(needsFileUri("https://example.com/media/video.m3u8"))
    }

    @Test
    fun contentUriStaysContent() {
        assertFalse(needsFileUri("content://media/external/video/42"))
    }

    @Test
    fun duplicateUpgcxcodeSlashIsNormalizedWithoutChangingQuery() {
        assertEquals(
            "https://upos-sz-mirrorali.bilivideo.com/upgcxcode/32/25/video.m4s?deadline=123&token=a%2Fb",
            normalizeMediaUrl(
                "https://upos-sz-mirrorali.bilivideo.com//upgcxcode/32/25/video.m4s?deadline=123&token=a%2Fb",
            ),
        )
    }

    @Test
    fun unrelatedDuplicatePathIsLeftUntouched() {
        assertEquals(
            "https://example.com//media/video.m4s?token=value",
            normalizeMediaUrl("https://example.com//media/video.m4s?token=value"),
        )
    }
}