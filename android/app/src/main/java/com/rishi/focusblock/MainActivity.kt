package com.rishi.focusblock

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.CheckBox
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import java.util.Date

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView
    private lateinit var nextEventText: TextView
    private lateinit var grantButton: Button

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            refreshStatus()
            startServiceIfReady()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusText = findViewById(R.id.status_text)
        nextEventText = findViewById(R.id.next_event_text)
        grantButton = findViewById(R.id.grant_button)

        grantButton.setOnClickListener { requestPermissions() }

        bindWindowCheckbox(R.id.check_30, 30)
        bindWindowCheckbox(R.id.check_10, 10)
        bindWindowCheckbox(R.id.check_5, 5)

        findViewById<Button>(R.id.test_overlay_button).setOnClickListener {
            val now = System.currentTimeMillis()
            startActivity(
                OverlayActivity.createIntent(
                    this,
                    title = "Test Event",
                    beginMs = now + 10 * 60 * 1000L,
                    endMs = now + 55 * 60 * 1000L,
                    window = 10,
                    notificationId = 0
                )
            )
        }

        findViewById<Button>(R.id.battery_button).setOnClickListener {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (_: Exception) {
                // Some OEM builds hide this screen; nothing else to do.
            }
        }

        setUpFullScreenIntentControls()
        startServiceIfReady()
    }

    override fun onResume() {
        super.onResume()
        refreshStatus()
        startServiceIfReady()
    }

    private fun bindWindowCheckbox(viewId: Int, minutes: Int) {
        val box = findViewById<CheckBox>(viewId)
        box.isChecked = Prefs.isWindowEnabled(this, minutes)
        box.setOnCheckedChangeListener { _, checked ->
            Prefs.setWindowEnabled(this, minutes, checked)
        }
    }

    private fun requestPermissions() {
        val wanted = mutableListOf(Manifest.permission.READ_CALENDAR)
        if (Build.VERSION.SDK_INT >= 33) {
            wanted.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        permissionLauncher.launch(wanted.toTypedArray())
    }

    private fun allPermissionsGranted(): Boolean {
        if (!CalendarRepository.hasPermission(this)) return false
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return true
    }

    private fun startServiceIfReady() {
        if (CalendarRepository.hasPermission(this)) {
            MonitorService.start(this)
        }
    }

    private fun refreshStatus() {
        val granted = allPermissionsGranted()
        statusText.setText(if (granted) R.string.permissions_granted else R.string.permissions_missing)
        grantButton.isEnabled = !granted

        val next = if (CalendarRepository.hasPermission(this)) CalendarRepository.nextEvent(this) else null
        if (next == null) {
            nextEventText.setText(R.string.next_event_none)
        } else {
            val time = android.text.format.DateFormat.getTimeFormat(this).format(Date(next.beginMs))
            nextEventText.text = getString(R.string.next_event_format, next.title, time)
        }
    }

    /**
     * Android 14+ only grants USE_FULL_SCREEN_INTENT automatically to apps
     * installed outside the Play Store (e.g. via Android Studio). If the
     * permission is off, surface the system settings screen to enable it.
     */
    private fun setUpFullScreenIntentControls() {
        if (Build.VERSION.SDK_INT < 34) return
        val notificationManager = getSystemService(NotificationManager::class.java)
        if (notificationManager.canUseFullScreenIntent()) return

        findViewById<TextView>(R.id.fullscreen_hint).visibility = android.view.View.VISIBLE
        val button = findViewById<Button>(R.id.fullscreen_button)
        button.visibility = android.view.View.VISIBLE
        button.setOnClickListener {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                        .setData(Uri.parse("package:$packageName"))
                )
            } catch (_: Exception) {
                startActivity(
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                )
            }
        }
    }
}
