@file:androidx.annotation.OptIn(
    markerClass = [androidx.media3.common.util.UnstableApi::class],
)

package com.example.piliplus

import android.content.Context
import android.net.Uri
import android.os.Handler
import androidx.media3.common.Format
import androidx.media3.common.text.Cue
import androidx.media3.datasource.DataSourceInputStream
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.extractor.text.DefaultSubtitleParserFactory
import androidx.media3.extractor.text.Subtitle
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

internal data class ApplicationSubtitleRequest(
    val uri: Uri,
    val language: String?,
    val label: String?,
    val mimeType: String,
)

/** Parses sidecar subtitles away from ExoPlayer's merged A/V media periods. */
internal class Media3ApplicationSubtitles(
    private val context: Context,
    private val handler: Handler,
    private val positionMs: () -> Long,
    private val isPlaying: () -> Boolean,
    private val speed: () -> Float,
    private val onCues: (List<Cue>) -> Unit,
    private val onError: (Throwable) -> Unit,
) {
    private val selection = Media3SubtitleSelection<ApplicationSubtitleRequest, Subtitle>()
    private val loader = ThreadPoolExecutor(
        1, 1, 0L, TimeUnit.MILLISECONDS,
        ArrayBlockingQueue(1), ThreadPoolExecutor.DiscardOldestPolicy(),
    )
    private var disposed = false
    private var lastEventIndex: Int? = null
    private val tick = Runnable { synchronize() }

    val ownsOutput: Boolean get() = selection.ownsOutput
    val requested: ApplicationSubtitleRequest? get() = selection.requested

    fun select(request: ApplicationSubtitleRequest?, headers: Map<String, String>) {
        val token = selection.select(request)
        handler.removeCallbacks(tick)
        loader.queue.clear()
        lastEventIndex = null
        if (request == null || selection.cached() == null) onCues(emptyList())
        if (request == null) return
        if (selection.cached() != null) {
            synchronize()
            return
        }
        // Only immutable input crosses into the loading thread. Selection is main-thread owned.
        val requestHeaders = headers.toMap()
        loader.execute {
            val result = runCatching {
                val http = DefaultHttpDataSource.Factory()
                    .setConnectTimeoutMs(8000)
                    .setReadTimeoutMs(8000)
                    .setAllowCrossProtocolRedirects(true)
                    .setDefaultRequestProperties(requestHeaders)
                requestHeaders["User-Agent"]?.let(http::setUserAgent)
                val source = DefaultDataSource.Factory(context, http).createDataSource()
                val bytes = DataSourceInputStream(source, DataSpec(request.uri)).use { it.readBytes() }
                val format = Format.Builder().setSampleMimeType(request.mimeType).build()
                val factory = DefaultSubtitleParserFactory()
                require(factory.supportsFormat(format)) { "Unsupported subtitle MIME type: ${request.mimeType}" }
                // Media3's timeline preserves its parser's styling, positioning and overlapping cues.
                @Suppress("DEPRECATION")
                factory.create(format).parseToLegacySubtitle(bytes, 0, bytes.size)
            }
            handler.post {
                if (disposed || token != selection.revision) return@post
                result.fold(
                    onSuccess = { subtitle ->
                        if (selection.complete(token, request, subtitle)) synchronize()
                    },
                    onFailure = { error ->
                        selection.select(null)
                        onCues(emptyList())
                        onError(error)
                    },
                )
            }
        }
    }

    fun invalidateClock() {
        lastEventIndex = null
    }

    fun onMediaOpened(preserveSubtitle: Boolean) {
        selection.onMediaOpened(preserveSubtitle)
        if (!preserveSubtitle) {
            loader.queue.clear()
            handler.removeCallbacks(tick)
            lastEventIndex = null
            onCues(emptyList())
        }
    }

    fun selectEmbedded() {
        selection.selectEmbedded()
        loader.queue.clear()
        handler.removeCallbacks(tick)
        lastEventIndex = null
        onCues(emptyList())
    }

    /** Reads the real A/V clock, so pause, buffering, speed changes and seeks stay synchronized. */
    fun synchronize() {
        handler.removeCallbacks(tick)
        if (disposed || !selection.ownsOutput) return
        val subtitle = selection.cached() ?: return
        val timeUs = positionMs().coerceAtLeast(0L) * 1000L
        val eventIndex = subtitle.getNextEventTimeIndex(timeUs)
        if (lastEventIndex != eventIndex) {
            lastEventIndex = eventIndex
            onCues(subtitle.getCues(timeUs))
        }
        if (isPlaying()) {
            val delayMs = if (eventIndex >= 0) {
                ((subtitle.getEventTime(eventIndex) - timeUs) / 1000.0 / speed().coerceAtLeast(0.1f))
                    .toLong().coerceIn(10L, 100L)
            } else {
                100L
            }
            handler.postDelayed(tick, delayMs)
        }
    }

    fun dispose() {
        disposed = true
        selection.onMediaOpened(preserveSubtitle = false)
        handler.removeCallbacks(tick)
        loader.shutdownNow()
    }
}
