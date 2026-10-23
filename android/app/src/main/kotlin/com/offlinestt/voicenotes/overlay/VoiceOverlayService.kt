package com.offlinestt.voicenotes.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import android.widget.Toast
import androidx.core.app.NotificationCompat
import com.offlinestt.voicenotes.MainActivity
import com.offlinestt.voicenotes.data.NotesDatabaseHelper
import com.offlinestt.voicenotes.data.UserPreferences
import com.offlinestt.voicenotes.models.Note
import com.offlinestt.voicenotes.speech.AudioRecordManager
import com.offlinestt.voicenotes.speech.CleanSpeechEngine
import com.offlinestt.voicenotes.speech.SherpaOnnxManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class VoiceOverlayService : Service() {

    private val scope = CoroutineScope(Dispatchers.Main)
    private var amplitudeJob: Job? = null
    private val handler = Handler(Looper.getMainLooper())
    private var durationRunnable: Runnable? = null

    private lateinit var windowManager: WindowManager
    private var floatingView: FloatingOverlayView? = null

    private var rawTranscribedText = ""
    private var currentRecordedFile: java.io.File? = null

    companion object {
        private const val TAG = "VoiceOverlayService"
        private const val CHANNEL_ID = "voice_overlay_service_channel"
        private const val NOTIFICATION_ID = 4579

        const val ACTION_START_OVERLAY = "ACTION_START_OVERLAY"
        const val ACTION_STOP_OVERLAY = "ACTION_STOP_OVERLAY"
        const val ACTION_TOGGLE_OVERLAY = "ACTION_TOGGLE_OVERLAY"

        @Volatile
        var isRunning = false
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        initFloatingView()
        isRunning = true
        UserPreferences.getInstance(this).setOverlayActive(true)
        Log.d(TAG, "VoiceOverlayService created and running")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_OVERLAY -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_TOGGLE_OVERLAY -> {
                // If service is already active, close it
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_STICKY
    }

    private fun initFloatingView() {
        if (floatingView != null) return

        floatingView = FloatingOverlayView(this).apply {
            onBubbleClicked = { startVoiceRecording() }
            onStopClicked = { stopVoiceRecordingAndTranscribe() }
            onCancelClicked = { cancelVoiceRecording() }
            onSaveNoteClicked = { text -> saveToNotesDatabase(text) }
            onRecopyClicked = { text -> copyToClipboard(text) }
            onToggleCleanSpeech = { isClean -> handleToggleCleanSpeech(isClean) }
        }

        try {
            windowManager.addView(floatingView, floatingView?.layoutParams)
            floatingView?.showBubbleState()
        } catch (e: Exception) {
            Log.e(TAG, "Failed adding floating view to WindowManager: ${e.message}", e)
        }
    }

    private fun startVoiceRecording() {
        val recorder = AudioRecordManager.getInstance(this)
        val started = recorder.startRecording()

        if (!started) {
            Toast.makeText(this, "Microphone permission required", Toast.LENGTH_SHORT).show()
            floatingView?.showBubbleState()
            return
        }

        floatingView?.showRecordingState()

        // Start 120Hz waveform collector
        amplitudeJob?.cancel()
        amplitudeJob = scope.launch {
            recorder.amplitudeFlow.collect { amp ->
                floatingView?.updateWaveformAmplitude(amp)
            }
        }

        // Start duration ticker
        durationRunnable?.let { handler.removeCallbacks(it) }
        durationRunnable = object : Runnable {
            override fun run() {
                val dur = recorder.currentDurationMs
                floatingView?.updateDuration(dur)
                handler.postDelayed(this, 250)
            }
        }
        handler.post(durationRunnable!!)
    }

    private fun stopVoiceRecordingAndTranscribe() {
        stopDurationTicker()
        amplitudeJob?.cancel()
        amplitudeJob = null

        val recorder = AudioRecordManager.getInstance(this)
        val wavFile = recorder.stopRecording()
        currentRecordedFile = wavFile

        if (wavFile == null || !wavFile.exists()) {
            floatingView?.showBubbleState()
            return
        }

        floatingView?.showTranscribingState()

        scope.launch {
            val sherpa = SherpaOnnxManager.getInstance(this@VoiceOverlayService)
            val text = sherpa.transcribeWavFile(wavFile)
            rawTranscribedText = text

            val userPrefs = UserPreferences.getInstance(this@VoiceOverlayService)
            val isClean = userPrefs.cleanSpeechEnabled.value
            val polished = CleanSpeechEngine.clean(text, enabled = isClean)

            // Auto-copy to clipboard if enabled
            if (userPrefs.autoCopyToClipboard.value && polished.isNotBlank()) {
                copyToClipboard(polished)
            }

            withContext(Dispatchers.Main) {
                floatingView?.showResultState(polished, isClean)
            }
        }
    }

    private fun cancelVoiceRecording() {
        stopDurationTicker()
        amplitudeJob?.cancel()
        amplitudeJob = null
        AudioRecordManager.getInstance(this).stopRecording()
        floatingView?.showBubbleState()
    }

    private fun handleToggleCleanSpeech(isClean: Boolean) {
        val userPrefs = UserPreferences.getInstance(this)
        userPrefs.setCleanSpeechEnabled(isClean)
        val polished = CleanSpeechEngine.clean(rawTranscribedText, enabled = isClean)
        copyToClipboard(polished)
        floatingView?.showResultState(polished, isClean)
    }

    private fun copyToClipboard(text: String) {
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("Voice Dictation", text)
        clipboard.setPrimaryClip(clip)
        Toast.makeText(this, "Copied to clipboard", Toast.LENGTH_SHORT).show()
    }

    private fun saveToNotesDatabase(text: String) {
        val title = if (text.length > 30) text.take(30) + "..." else text
        val note = Note(
            title = title,
            content = text,
            audioPath = currentRecordedFile?.absolutePath,
            durationMs = 0L
        )
        NotesDatabaseHelper.getInstance(this).insertNote(note)
        Toast.makeText(this, "Saved to Notes", Toast.LENGTH_SHORT).show()
    }

    private fun stopDurationTicker() {
        durationRunnable?.let {
            handler.removeCallbacks(it)
            durationRunnable = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopDurationTicker()
        amplitudeJob?.cancel()
        AudioRecordManager.getInstance(this).stopRecording()

        floatingView?.let {
            if (it.isAttachedToWindow) {
                windowManager.removeView(it)
            }
        }
        floatingView = null
        isRunning = false
        UserPreferences.getInstance(this).setOverlayActive(false)
        Log.d(TAG, "VoiceOverlayService destroyed")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Voice Dictation Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the floating voice dictation bubble active over other apps"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Voice Dictation Active")
            .setContentText("Tap the floating bubble to speak and dictate anywhere")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }
}
