package com.offlinestt.voicenotes.speech

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.sqrt

class AudioRecordManager private constructor(private val context: Context) {

    private val scope = CoroutineScope(Dispatchers.IO)
    private var recordingJob: Job? = null

    private var audioRecord: AudioRecord? = null
    private var isRecording = false

    private val _amplitudeFlow = MutableStateFlow(0f)
    val amplitudeFlow: StateFlow<Float> = _amplitudeFlow.asStateFlow()

    private var currentRecordingFile: File? = null
    private var recordingStartTime = 0L

    companion object {
        private const val TAG = "AudioRecordManager"
        const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        @Volatile
        private var instance: AudioRecordManager? = null

        fun getInstance(context: Context): AudioRecordManager {
            return instance ?: synchronized(this) {
                instance ?: AudioRecordManager(context.applicationContext).also { instance = it }
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun startRecording(): Boolean {
        if (isRecording) return true

        val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid buffer size: $minBufferSize")
            return false
        }

        val bufferSize = minBufferSize * 2

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize")
                audioRecord?.release()
                audioRecord = null
                return false
            }

            val tempFile = File(context.cacheDir, "recording_${System.currentTimeMillis()}.wav")
            currentRecordingFile = tempFile

            audioRecord?.startRecording()
            isRecording = true
            recordingStartTime = System.currentTimeMillis()

            recordingJob = scope.launch {
                writeAudioDataToWav(tempFile, bufferSize)
            }
            Log.d(TAG, "AudioRecord started recording to ${tempFile.absolutePath}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting AudioRecord: ${e.message}", e)
            return false
        }
    }

    fun stopRecording(): File? {
        if (!isRecording) return currentRecordingFile

        try {
            isRecording = false
            recordingJob?.cancel()
            recordingJob = null

            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            _amplitudeFlow.value = 0f

            val file = currentRecordingFile
            if (file != null && file.exists()) {
                updateWavHeader(file)
                Log.d(TAG, "Stopped recording. Saved WAV file size: ${file.length()} bytes")
            }
            return file
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping AudioRecord: ${e.message}", e)
            return null
        }
    }

    val currentDurationMs: Long
        get() = if (isRecording) System.currentTimeMillis() - recordingStartTime else 0L

    private fun writeAudioDataToWav(file: File, bufferSize: Int) {
        val outputStream = FileOutputStream(file)
        val shortBuffer = ShortArray(bufferSize / 2)
        val byteBuffer = ByteArray(bufferSize)

        outputStream.use { out ->
            // Write placeholder 44-byte WAV header (will update on stop)
            out.write(ByteArray(44))

            while (isRecording && scope.isActive) {
                val readShorts = audioRecord?.read(shortBuffer, 0, shortBuffer.size) ?: -1
                if (readShorts > 0) {
                    // Convert shorts to little-endian bytes
                    ByteBuffer.wrap(byteBuffer).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().put(shortBuffer, 0, readShorts)
                    out.write(byteBuffer, 0, readShorts * 2)

                    // Calculate RMS Amplitude
                    var sum = 0.0
                    for (i in 0 until readShorts) {
                        sum += (shortBuffer[i] * shortBuffer[i]).toDouble()
                    }
                    val rms = sqrt(sum / readShorts)
                    val normalized = (rms / 32768.0).toFloat().coerceIn(0f, 1f)
                    _amplitudeFlow.value = normalized
                }
            }
        }
    }

    private fun updateWavHeader(file: File) {
        val rawDataSize = file.length() - 44
        if (rawDataSize < 0) return

        val totalDataLen = rawDataSize + 36
        val channels = 1
        val byteRate = SAMPLE_RATE * channels * 16 / 8

        val header = ByteArray(44)
        header[0] = 'R'.code.toByte() // RIFF
        header[1] = 'I'.code.toByte()
        header[2] = 'F'.code.toByte()
        header[3] = 'F'.code.toByte()
        header[4] = (totalDataLen and 0xff).toByte()
        header[5] = ((totalDataLen shr 8) and 0xff).toByte()
        header[6] = ((totalDataLen shr 16) and 0xff).toByte()
        header[7] = ((totalDataLen shr 24) and 0xff).toByte()
        header[8] = 'W'.code.toByte() // WAVE
        header[9] = 'A'.code.toByte()
        header[10] = 'V'.code.toByte()
        header[11] = 'E'.code.toByte()
        header[12] = 'f'.code.toByte() // 'fmt ' chunk
        header[13] = 'm'.code.toByte()
        header[14] = 't'.code.toByte()
        header[15] = ' '.code.toByte()
        header[16] = 16 // 4 bytes: size of 'fmt ' chunk
        header[17] = 0
        header[18] = 0
        header[19] = 0
        header[20] = 1 // format = 1 (PCM)
        header[21] = 0
        header[22] = channels.toByte()
        header[23] = 0
        header[24] = (SAMPLE_RATE and 0xff).toByte()
        header[25] = ((SAMPLE_RATE shr 8) and 0xff).toByte()
        header[26] = ((SAMPLE_RATE shr 16) and 0xff).toByte()
        header[27] = ((SAMPLE_RATE shr 24) and 0xff).toByte()
        header[28] = (byteRate and 0xff).toByte()
        header[29] = ((byteRate shr 8) and 0xff).toByte()
        header[30] = ((byteRate shr 16) and 0xff).toByte()
        header[31] = ((byteRate shr 24) and 0xff).toByte()
        header[32] = (channels * 16 / 8).toByte() // block align
        header[33] = 0
        header[34] = 16 // bits per sample
        header[35] = 0
        header[36] = 'd'.code.toByte() // 'data' chunk
        header[37] = 'a'.code.toByte()
        header[38] = 't'.code.toByte()
        header[39] = 'a'.code.toByte()
        header[40] = (rawDataSize and 0xff).toByte()
        header[41] = ((rawDataSize shr 8) and 0xff).toByte()
        header[42] = ((rawDataSize shr 16) and 0xff).toByte()
        header[43] = ((rawDataSize shr 24) and 0xff).toByte()

        RandomAccessFile(file, "rw").use { raf ->
            raf.seek(0)
            raf.write(header)
        }
    }
}
