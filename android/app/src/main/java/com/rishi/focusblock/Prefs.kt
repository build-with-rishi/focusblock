package com.rishi.focusblock

import android.content.Context
import android.content.SharedPreferences

/**
 * SharedPreferences wrapper: alert-window toggles and per-trigger dedup.
 *
 * Dedup keys are "eventId|instanceBeginMs|windowMinutes" so each (event
 * instance, window) pair fires exactly once, surviving service restarts.
 */
object Prefs {

    val ALL_WINDOWS = listOf(30, 10, 5)

    private const val NAME = "focusblock"
    private const val KEY_FIRED = "fired_triggers"
    private const val PRUNE_AGE_MS = 2 * 60 * 60 * 1000L // drop entries 2h after event start

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    fun isWindowEnabled(context: Context, minutes: Int): Boolean =
        prefs(context).getBoolean("window_$minutes", true)

    fun setWindowEnabled(context: Context, minutes: Int, enabled: Boolean) {
        prefs(context).edit().putBoolean("window_$minutes", enabled).apply()
    }

    fun enabledWindows(context: Context): List<Int> =
        ALL_WINDOWS.filter { isWindowEnabled(context, it) }

    fun triggerKey(eventId: Long, beginMs: Long, window: Int): String =
        "$eventId|$beginMs|$window"

    fun hasFired(context: Context, key: String): Boolean =
        prefs(context).getStringSet(KEY_FIRED, emptySet()).orEmpty().contains(key)

    fun markFired(context: Context, key: String, nowMs: Long) {
        val current = prefs(context).getStringSet(KEY_FIRED, emptySet()).orEmpty()
        // Copy before mutating: the set returned by getStringSet must not be modified.
        val kept = current.filterTo(mutableSetOf()) { entry ->
            val begin = entry.split("|").getOrNull(1)?.toLongOrNull() ?: return@filterTo false
            begin > nowMs - PRUNE_AGE_MS
        }
        kept.add(key)
        prefs(context).edit().putStringSet(KEY_FIRED, kept).apply()
    }
}
