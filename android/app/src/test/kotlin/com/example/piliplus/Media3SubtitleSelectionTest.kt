package com.example.piliplus

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class Media3SubtitleSelectionTest {
    @Test
    fun closingAndReopeningUsesTheParsedTimeline() {
        val selection = Media3SubtitleSelection<String, String>()
        val token = selection.select("Chinese")
        assertTrue(selection.complete(token, "Chinese", "parsed Chinese"))
        repeat(3) {
            selection.select(null)
            assertNull(selection.cached())
            selection.select("Chinese")
            assertEquals("parsed Chinese", selection.cached())
        }
    }

    @Test
    fun repeatedSelectionKeepsTheTimeline() {
        val selection = Media3SubtitleSelection<String, String>()
        selection.complete(selection.select("Chinese"), "Chinese", "parsed")
        selection.select("Chinese")
        assertEquals("parsed", selection.cached())
    }

    @Test
    fun replacingTheSubtitleDoesNotDisplayTheOldTimeline() {
        val selection = Media3SubtitleSelection<String, String>()
        selection.complete(selection.select("Chinese"), "Chinese", "parsed Chinese")
        val token = selection.select("English")
        assertNull(selection.cached())
        assertTrue(selection.complete(token, "English", "parsed English"))
        assertEquals("parsed English", selection.cached())
    }

    @Test
    fun closingWhileLoadingRejectsTheLateResponse() {
        val selection = Media3SubtitleSelection<String, String>()
        val token = selection.select("Chinese")
        selection.select(null)
        assertFalse(selection.complete(token, "Chinese", "late"))
        assertNull(selection.cached())
    }

    @Test
    fun rapidLanguageSwitchingRejectsOutOfOrderResponses() {
        val selection = Media3SubtitleSelection<String, String>()
        val first = selection.select("Chinese")
        val second = selection.select("English")
        val third = selection.select("Chinese")
        assertFalse(selection.complete(first, "Chinese", "old Chinese"))
        assertFalse(selection.complete(second, "English", "old English"))
        assertTrue(selection.complete(third, "Chinese", "current Chinese"))
        assertEquals("current Chinese", selection.cached())
    }

    @Test
    fun aNewVideoClearsThePreviousVideosTimelineAndPendingLoad() {
        val selection = Media3SubtitleSelection<String, String>()
        val token = selection.select("Chinese")
        selection.complete(token, "Chinese", "parsed")
        selection.onMediaOpened(preserveSubtitle = false)
        assertNull(selection.requested)
        selection.select("Chinese")
        assertNull(selection.cached())
        assertFalse(selection.complete(token, "Chinese", "late"))
    }

    @Test
    fun qualityChangesPreserveTheTimelineWithoutReloading() {
        val selection = Media3SubtitleSelection<String, String>()
        selection.complete(selection.select("Chinese"), "Chinese", "parsed")
        selection.onMediaOpened(preserveSubtitle = true)
        assertEquals("Chinese", selection.requested)
        assertEquals("parsed", selection.cached())
    }

    @Test
    fun qualityChangesPreserveAnInFlightSubtitleForTheSameVideo() {
        val selection = Media3SubtitleSelection<String, String>()
        val token = selection.select("Chinese")
        selection.onMediaOpened(preserveSubtitle = true)
        assertTrue(selection.complete(token, "Chinese", "parsed"))
    }

    @Test
    fun qualityChangesWhileClosedKeepSubtitlesClosed() {
        val selection = Media3SubtitleSelection<String, String>()
        selection.complete(selection.select("Chinese"), "Chinese", "parsed")
        selection.select(null)
        selection.onMediaOpened(preserveSubtitle = true)
        assertNull(selection.requested)
        assertNull(selection.cached())
        selection.select("Chinese")
        assertEquals("parsed", selection.cached())
    }

    @Test
    fun embeddedSelectionTakesOutputOwnershipAndRejectsLateExternalCues() {
        val selection = Media3SubtitleSelection<String, String>()
        val token = selection.select("Chinese")
        selection.selectEmbedded()
        assertFalse(selection.ownsOutput)
        assertFalse(selection.complete(token, "Chinese", "late"))
        selection.select(null)
        assertTrue(selection.ownsOutput)
    }
}
