package com.rishi.focusblock

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.Editable
import android.text.Spannable
import android.text.SpannableString
import android.text.TextWatcher
import android.text.style.ForegroundColorSpan
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import java.util.Date

/**
 * Full-screen, hard-to-skip interruption. Launched via a full-screen-intent
 * notification so it appears over other apps and the lock screen.
 *
 * Dismissal: type the challenge word. Correct letters light up white; a wrong
 * letter resets progress and plays an error tone. A default ALARM ringtone
 * loops until dismissed. Auto-dismisses after 30 seconds as a safety fallback.
 */
class OverlayActivity : AppCompatActivity() {

    companion object {
        private const val EXTRA_TITLE = "extra_title"
        private const val EXTRA_BEGIN = "extra_begin"
        private const val EXTRA_END = "extra_end"
        private const val EXTRA_WINDOW = "extra_window"
        private const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        private const val AUTO_DISMISS_MS = 30_000L

        // Challenge words — copied verbatim from the macOS OverlayWindowController.
        private val CHALLENGE_WORDS = listOf(
            "FOCUS", "COMMIT", "BEGIN", "ARRIVE", "PRESENT",
            "DELIVER", "ENGAGE", "PREPARE", "SHOWUP", "READY"
        )

        // 20 quotes — copied verbatim from the macOS OverlayWindowController.
        private val QUOTES = listOf(
            "This meeting happens with or without your attention. Choose with.",
            "Stop negotiating with yourself. Wrap up and show up.",
            "You said yes to this. Honor it.",
            "Avoiding it won't cancel it.",
            "Five minutes of prep beats thirty minutes of apologizing.",
            "Close the tabs. The meeting is the work now.",
            "You don't need motivation. You need to stand up.",
            "Every minute you stall, the meeting gets harder.",
            "The dread dies the moment you start moving.",
            "Showing up late is a decision. So is showing up ready.",
            "Discomfort now or regret later. Pick one.",
            "You're not in flow. You're avoiding.",
            "Stop scrolling. Start moving.",
            "Finish the sentence, save the file, go.",
            "The work will wait. The meeting won't.",
            "Your future self is begging you to get up now.",
            "Nothing on your screen matters more than the next hour.",
            "Be the person who walks in prepared.",
            "Procrastination is fear wearing comfortable clothes.",
            "Win the hour by walking in ready."
        )

        fun createIntent(
            context: Context,
            title: String,
            beginMs: Long,
            endMs: Long,
            window: Int,
            notificationId: Int
        ): Intent = Intent(context, OverlayActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(EXTRA_TITLE, title)
            .putExtra(EXTRA_BEGIN, beginMs)
            .putExtra(EXTRA_END, endMs)
            .putExtra(EXTRA_WINDOW, window)
            .putExtra(EXTRA_NOTIFICATION_ID, notificationId)
    }

    private lateinit var challengeView: TextView
    private lateinit var hiddenInput: EditText

    private val handler = Handler(Looper.getMainLooper())
    private val autoDismissRunnable = Runnable { dismiss() }

    private var challengeWord: String = "FOCUS"
    private var typedCount: Int = 0
    private var dismissed: Boolean = false
    private var clearingInput: Boolean = false

    private var alarmPlayer: MediaPlayer? = null
    private var toneGenerator: ToneGenerator? = null

    private val colorTyped by lazy { ContextCompat.getColor(this, R.color.overlay_letter_typed) }
    private val colorPending by lazy { ContextCompat.getColor(this, R.color.overlay_letter_pending) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_overlay)

        setUpLockScreenFlags()

        challengeView = findViewById(R.id.challenge_word)
        hiddenInput = findViewById(R.id.hidden_input)
        setUpInput()

        // Block the back gesture/button: the only way out is the word (or the
        // 30 s fallback). Home cannot be blocked on Android — see README.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Intentionally ignored.
            }
        })

        applyTriggerIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A second trigger fired while the overlay was already up (singleInstance):
        // restart with the new event's content, alarm, and timer.
        setIntent(intent)
        stopAlarm()
        handler.removeCallbacks(autoDismissRunnable)
        applyTriggerIntent(intent)
    }

    /** Reads the trigger extras, fills the UI, starts the alarm and the 30 s fallback. */
    private fun applyTriggerIntent(intent: Intent) {
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Upcoming Event"
        val beginMs = intent.getLongExtra(EXTRA_BEGIN, System.currentTimeMillis())
        val endMs = intent.getLongExtra(EXTRA_END, beginMs)
        val window = intent.getIntExtra(EXTRA_WINDOW, 0)
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        if (notificationId != 0) {
            getSystemService(NotificationManager::class.java).cancel(notificationId)
        }

        challengeWord = CHALLENGE_WORDS.random()
        typedCount = 0
        dismissed = false

        findViewById<TextView>(R.id.event_title).text = title
        findViewById<TextView>(R.id.time_to_event).text = timeToLabel(window)
        findViewById<TextView>(R.id.event_meta).text =
            "${startTimeLabel(beginMs)}  ·  ${durationLabel(beginMs, endMs)}"
        findViewById<TextView>(R.id.quote).text = "“${QUOTES.random()}”"
        renderChallenge()

        startAlarm()
        handler.postDelayed(autoDismissRunnable, AUTO_DISMISS_MS)
    }

    // ---------------------------------------------------------------- labels

    private fun timeToLabel(window: Int): String = when (window) {
        30, 10, 5 -> getString(R.string.overlay_minutes_format, window)
        else -> getString(R.string.overlay_starting_soon)
    }

    private fun startTimeLabel(beginMs: Long): String =
        android.text.format.DateFormat.getTimeFormat(this).format(Date(beginMs))

    private fun durationLabel(beginMs: Long, endMs: Long): String {
        val totalMinutes = ((endMs - beginMs) / 60_000L).toInt().coerceAtLeast(0)
        if (totalMinutes < 60) return "$totalMinutes minutes"
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return when {
            minutes > 0 -> "${hours}h ${minutes}m"
            hours > 1 -> "$hours hours"
            else -> "1 hour"
        }
    }

    // ------------------------------------------------------- window/keyguard

    private fun setUpLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            // API 26 fallback (deprecated flags, still functional there).
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        getSystemService(KeyguardManager::class.java).requestDismissKeyguard(this, null)
    }

    // ------------------------------------------------------------- challenge

    private fun setUpInput() {
        hiddenInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable) {
                if (clearingInput) return
                val typed = s.toString()
                if (typed.isEmpty()) return
                clearingInput = true
                s.clear()
                clearingInput = false
                for (c in typed) handleChar(c)
            }
        })

        // Tapping anywhere brings the keyboard back if it was dismissed.
        findViewById<android.view.View>(R.id.overlay_root).setOnClickListener { showKeyboard() }

        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
        hiddenInput.requestFocus()
    }

    private fun showKeyboard() {
        hiddenInput.requestFocus()
        getSystemService(InputMethodManager::class.java)
            .showSoftInput(hiddenInput, InputMethodManager.SHOW_IMPLICIT)
    }

    override fun onResume() {
        super.onResume()
        // Post so the window has focus before the IME request.
        handler.post { showKeyboard() }
    }

    private fun handleChar(raw: Char) {
        if (dismissed) return
        val c = raw.uppercaseChar()
        if (!c.isLetter()) return // ignore digits, space, punctuation: neither advance nor reset

        if (typedCount < challengeWord.length && c == challengeWord[typedCount]) {
            typedCount++
            if (typedCount == challengeWord.length) {
                renderChallenge()
                playTone(ToneGenerator.TONE_PROP_ACK)
                dismiss()
                return
            }
        } else {
            typedCount = 0
            playTone(ToneGenerator.TONE_SUP_ERROR)
        }
        renderChallenge()
    }

    private fun renderChallenge() {
        val span = SpannableString(challengeWord)
        for (i in challengeWord.indices) {
            val color = if (i < typedCount) colorTyped else colorPending
            span.setSpan(ForegroundColorSpan(color), i, i + 1, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        challengeView.text = span
    }

    // ------------------------------------------------------------------ audio

    private fun startAlarm() {
        stopAlarm()
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: return
        try {
            alarmPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@OverlayActivity, uri)
                isLooping = true
                prepare()
                start()
            }
        } catch (e: Exception) {
            // No alarm sound available (e.g. emulator without ringtones) — the
            // visual interruption still works.
            alarmPlayer?.release()
            alarmPlayer = null
        }
    }

    private fun stopAlarm() {
        alarmPlayer?.let { player ->
            try {
                if (player.isPlaying) player.stop()
            } catch (_: IllegalStateException) {
            }
            player.release()
        }
        alarmPlayer = null
    }

    private fun playTone(tone: Int) {
        try {
            if (toneGenerator == null) {
                toneGenerator = ToneGenerator(AudioManager.STREAM_ALARM, 80)
            }
            toneGenerator?.startTone(tone, 200)
        } catch (_: RuntimeException) {
            // ToneGenerator can fail on constrained devices; non-fatal.
        }
    }

    // ---------------------------------------------------------------- finish

    private fun dismiss() {
        if (dismissed) return
        dismissed = true
        stopAlarm()
        handler.removeCallbacks(autoDismissRunnable)
        finish()
    }

    override fun onDestroy() {
        stopAlarm()
        handler.removeCallbacks(autoDismissRunnable)
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
