package com.offlinestt.voicenotes.overlay

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.AttributeSet
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.offlinestt.voicenotes.offline_voice_notes.R
import kotlin.math.abs
import kotlin.math.hypot

@SuppressLint("ClickableViewAccessibility")
class FloatingOverlayView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private val windowManager: WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    val layoutParams = WindowManager.LayoutParams().apply {
        type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        format = PixelFormat.TRANSLUCENT
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        gravity = Gravity.TOP or Gravity.START
        width = WindowManager.LayoutParams.WRAP_CONTENT
        height = WindowManager.LayoutParams.WRAP_CONTENT
        x = 0
        y = 400
    }

    // UI State Containers
    private val layoutBubble: FrameLayout
    private val layoutRecording: LinearLayout
    private val layoutTranscribing: LinearLayout
    private val layoutResult: LinearLayout

    // Controls
    private val tvDuration: TextView
    private val waveformView: WaveformCanvasView
    private val btnStop: FrameLayout
    private val btnCancel: ImageView
    private val tvTranscribedText: TextView
    private val btnToggleClean: TextView
    private val btnCloseResult: ImageView
    private val btnSaveNote: LinearLayout
    private val tvSaveLabel: TextView
    private val btnRecopy: ImageView

    // Touch & Drag state
    private val touchSlop = ViewConfiguration.get(context).scaledTouchSlop
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var isDragging = false

    // Callbacks to Service
    var onBubbleClicked: (() -> Unit)? = null
    var onStopClicked: (() -> Unit)? = null
    var onCancelClicked: (() -> Unit)? = null
    var onSaveNoteClicked: ((String) -> Unit)? = null
    var onRecopyClicked: ((String) -> Unit)? = null
    var onToggleCleanSpeech: ((Boolean) -> Unit)? = null

    private var rawText = ""
    private var isCleanSpeechOn = true
    private var autoCollapseRunnable: Runnable? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.layout_floating_overlay, this, true)

        layoutBubble = findViewById(R.id.layout_bubble)
        layoutRecording = findViewById(R.id.layout_recording)
        layoutTranscribing = findViewById(R.id.layout_transcribing)
        layoutResult = findViewById(R.id.layout_result)

        tvDuration = findViewById(R.id.tv_duration)
        waveformView = findViewById(R.id.waveform_view)
        btnStop = findViewById(R.id.btn_stop)
        btnCancel = findViewById(R.id.btn_cancel)
        tvTranscribedText = findViewById(R.id.tv_transcribed_text)
        btnToggleClean = findViewById(R.id.btn_toggle_clean)
        btnCloseResult = findViewById(R.id.btn_close_result)
        btnSaveNote = findViewById(R.id.btn_save_note)
        tvSaveLabel = findViewById(R.id.tv_save_label)
        btnRecopy = findViewById(R.id.btn_recopy)

        setupListeners()
        setupTouchHandler()
    }

    private fun setupListeners() {
        btnStop.setOnClickListener {
            performHaptic()
            onStopClicked?.invoke()
        }

        btnCancel.setOnClickListener {
            performHaptic()
            onCancelClicked?.invoke()
        }

        btnCloseResult.setOnClickListener {
            showBubbleState()
        }

        btnRecopy.setOnClickListener {
            performHaptic()
            onRecopyClicked?.invoke(tvTranscribedText.text.toString())
        }

        btnSaveNote.setOnClickListener {
            performHaptic()
            onSaveNoteClicked?.invoke(tvTranscribedText.text.toString())
            tvSaveLabel.text = "Saved ✓"
            btnSaveNote.isEnabled = false
        }

        btnToggleClean.setOnClickListener {
            performHaptic()
            isCleanSpeechOn = !isCleanSpeechOn
            btnToggleClean.text = if (isCleanSpeechOn) "Clean: ON" else "Clean: OFF"
            onToggleCleanSpeech?.invoke(isCleanSpeechOn)
        }
    }

    private fun setupTouchHandler() {
        layoutBubble.setOnTouchListener { _, event ->
            handleBubbleTouch(event)
        }
    }

    private fun handleBubbleTouch(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialX = layoutParams.x
                initialY = layoutParams.y
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                isDragging = false
                return true
            }

            MotionEvent.ACTION_MOVE -> {
                val dx = (event.rawX - initialTouchX).toInt()
                val dy = (event.rawY - initialTouchY).toInt()

                if (!isDragging && hypot(dx.toDouble(), dy.toDouble()) > touchSlop) {
                    isDragging = true
                }

                if (isDragging) {
                    layoutParams.x = initialX + dx
                    layoutParams.y = initialY + dy
                    updateLayout()
                }
                return true
            }

            MotionEvent.ACTION_UP -> {
                if (!isDragging) {
                    // Tap detected!
                    performHaptic()
                    onBubbleClicked?.invoke()
                } else {
                    // Drag ended: snap to left or right screen edge
                    snapToEdge()
                }
                isDragging = false
                return true
            }
        }
        return false
    }

    private fun snapToEdge() {
        val displayMetrics = context.resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val viewWidth = layoutBubble.width.coerceAtLeast(1)

        val targetX = if (layoutParams.x + (viewWidth / 2) < screenWidth / 2) {
            16 // Snap to left edge with 16px margin
        } else {
            screenWidth - viewWidth - 16 // Snap to right edge
        }

        val startX = layoutParams.x
        ValueAnimator.ofInt(startX, targetX).apply {
            duration = 250
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                layoutParams.x = anim.animatedValue as Int
                updateLayout()
            }
            start()
        }
    }

    fun showBubbleState() {
        cancelAutoCollapse()
        layoutBubble.visibility = View.VISIBLE
        layoutRecording.visibility = View.GONE
        layoutTranscribing.visibility = View.GONE
        layoutResult.visibility = View.GONE
        updateLayout()
    }

    fun showRecordingState() {
        cancelAutoCollapse()
        layoutBubble.visibility = View.GONE
        layoutRecording.visibility = View.VISIBLE
        layoutTranscribing.visibility = View.GONE
        layoutResult.visibility = View.GONE
        tvDuration.text = "00:00"
        updateLayout()
    }

    fun showTranscribingState() {
        cancelAutoCollapse()
        layoutBubble.visibility = View.GONE
        layoutRecording.visibility = View.GONE
        layoutTranscribing.visibility = View.VISIBLE
        layoutResult.visibility = View.GONE
        updateLayout()
    }

    fun showResultState(text: String, isClean: Boolean = true) {
        cancelAutoCollapse()
        rawText = text
        isCleanSpeechOn = isClean

        layoutBubble.visibility = View.GONE
        layoutRecording.visibility = View.GONE
        layoutTranscribing.visibility = View.GONE
        layoutResult.visibility = View.VISIBLE

        tvTranscribedText.text = text
        btnToggleClean.text = if (isClean) "Clean: ON" else "Clean: OFF"
        tvSaveLabel.text = "Save Note"
        btnSaveNote.isEnabled = true

        updateLayout()

        // Auto-collapse after 15 seconds of inactivity
        autoCollapseRunnable = Runnable { showBubbleState() }
        postDelayed(autoCollapseRunnable, 15000)
    }

    fun updateDuration(durationMs: Long) {
        val totalSecs = durationMs / 1000
        val mins = totalSecs / 60
        val secs = totalSecs % 60
        tvDuration.text = String.format("%02d:%02d", mins, secs)
    }

    fun updateWaveformAmplitude(amplitude: Float) {
        waveformView.updateAmplitude(amplitude)
    }

    private fun updateLayout() {
        if (isAttachedToWindow) {
            windowManager.updateViewLayout(this, layoutParams)
        }
    }

    private fun cancelAutoCollapse() {
        autoCollapseRunnable?.let {
            removeCallbacks(it)
            autoCollapseRunnable = null
        }
    }

    private fun performHaptic() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator.vibrate(
                    VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
                )
            } else {
                @Suppress("DEPRECATION")
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                vibrator.vibrate(40)
            }
        } catch (_: Exception) {}
    }
}
