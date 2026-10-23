package com.offlinestt.voicenotes.overlay

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import kotlin.random.Random

class WaveformCanvasView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#6366F1")
        style = Paint.Style.FILL
    }

    private val rectF = RectF()
    private val barCount = 18
    private val barHeights = FloatArray(barCount) { 0.1f }
    private var currentAmplitude = 0f

    fun updateAmplitude(amplitude: Float) {
        currentAmplitude = amplitude.coerceIn(0f, 1f)

        // Shift heights left and insert new amplitude
        for (i in 0 until barCount - 1) {
            barHeights[i] = barHeights[i + 1]
        }
        val jitter = Random.nextFloat() * 0.15f
        barHeights[barCount - 1] = (currentAmplitude * 0.85f + jitter).coerceIn(0.08f, 1.0f)
        postInvalidateOnAnimation()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0 || h <= 0) return

        val barWidth = (w / (barCount * 1.6f)).coerceAtLeast(3f)
        val gap = (w - (barWidth * barCount)) / (barCount + 1)
        val centerY = h / 2f
        val cornerRadius = barWidth / 2f

        var startX = gap
        for (i in 0 until barCount) {
            val barH = (barHeights[i] * h * 0.85f).coerceAtLeast(4f)
            val top = centerY - (barH / 2f)
            val bottom = centerY + (barH / 2f)

            rectF.set(startX, top, startX + barWidth, bottom)
            canvas.drawRoundRect(rectF, cornerRadius, cornerRadius, paint)
            startX += barWidth + gap
        }
    }
}
