package com.rishi.focusblock

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat

data class EventInstance(
    val eventId: Long,
    val title: String,
    val beginMs: Long,
    val endMs: Long
)

/**
 * Reads event instances from the device's native calendar provider
 * (CalendarContract.Instances), which includes natively synced Google
 * Calendar accounts. Instances (not Events) is the right table because it
 * expands recurring events into concrete occurrences.
 */
object CalendarRepository {

    private const val IDX_EVENT_ID = 0
    private const val IDX_TITLE = 1
    private const val IDX_BEGIN = 2
    private const val IDX_END = 3
    private const val IDX_ALL_DAY = 4

    private val PROJECTION = arrayOf(
        CalendarContract.Instances.EVENT_ID,
        CalendarContract.Instances.TITLE,
        CalendarContract.Instances.BEGIN,
        CalendarContract.Instances.END,
        CalendarContract.Instances.ALL_DAY
    )

    fun hasPermission(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    /** Timed (non-all-day) instances overlapping [fromMs, toMs], sorted by start. */
    fun instancesBetween(context: Context, fromMs: Long, toMs: Long): List<EventInstance> {
        if (!hasPermission(context)) return emptyList()
        val result = mutableListOf<EventInstance>()
        try {
            CalendarContract.Instances.query(context.contentResolver, PROJECTION, fromMs, toMs)
                ?.use { cursor ->
                    while (cursor.moveToNext()) {
                        if (cursor.getInt(IDX_ALL_DAY) == 1) continue
                        result.add(
                            EventInstance(
                                eventId = cursor.getLong(IDX_EVENT_ID),
                                title = cursor.getString(IDX_TITLE) ?: "Upcoming Event",
                                beginMs = cursor.getLong(IDX_BEGIN),
                                endMs = cursor.getLong(IDX_END)
                            )
                        )
                    }
                }
        } catch (_: SecurityException) {
            // Permission revoked mid-flight; treat as no events.
        }
        return result.sortedBy { it.beginMs }
    }

    /** The next event starting within 24 hours, or null. */
    fun nextEvent(context: Context): EventInstance? {
        val now = System.currentTimeMillis()
        return instancesBetween(context, now, now + 24 * 60 * 60 * 1000L)
            .firstOrNull { it.beginMs > now }
    }
}
