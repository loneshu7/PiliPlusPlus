package com.example.piliplus

/** Selection/cache state only: changing subtitles must never operate on the A/V player. */
internal class Media3SubtitleSelection<K, V> {
    var requested: K? = null
        private set
    var ownsOutput = true
        private set
    var revision = 0L
        private set
    private var cachedKey: K? = null
    private var cachedValue: V? = null

    fun select(key: K?): Long {
        revision++
        ownsOutput = true
        requested = key
        return revision
    }

    fun cached(): V? = if (requested != null && requested == cachedKey) cachedValue else null

    fun complete(token: Long, key: K, value: V): Boolean {
        if (token != revision || key != requested || !ownsOutput) return false
        cachedKey = key
        cachedValue = value
        return true
    }

    fun selectEmbedded() {
        select(null)
        ownsOutput = false
    }

    fun onMediaOpened(preserveSubtitle: Boolean) {
        if (preserveSubtitle) return
        select(null)
        cachedKey = null
        cachedValue = null
    }
}
