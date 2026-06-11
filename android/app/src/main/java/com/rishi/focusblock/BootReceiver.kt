package com.rishi.focusblock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts calendar monitoring after a device reboot or an app update, so
 * FocusBlock keeps running passively without the user reopening the app.
 * Starting a specialUse foreground service from BOOT_COMPLETED is permitted
 * (it is not on the boot-restricted FGS-type list).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                if (CalendarRepository.hasPermission(context)) {
                    MonitorService.start(context)
                }
            }
        }
    }
}
