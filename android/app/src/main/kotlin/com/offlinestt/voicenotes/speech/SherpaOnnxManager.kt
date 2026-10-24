package com.offlinestt.voicenotes.speech

import android.content.Context
import android.util.Log
import com.k2fsa.sherpa.onnx.FeatureConfig
import com.k2fsa.sherpa.onnx.OfflineModelConfig
import com.k2fsa.sherpa.onnx.OfflineRecognizer
import com.k2fsa.sherpa.onnx.OfflineRecognizerConfig
import com.k2fsa.sherpa.onnx.OfflineWhisperModelConfig
import com.k2fsa.sherpa.onnx.WaveReader
import com.offlinestt.voicenotes.data.ModelDownloadManager
import com.offlinestt.voicenotes.data.UserPreferences
import com.offlinestt.voicenotes.models.SpeechModelInfo
import com.offlinestt.voicenotes.models.SpeechModelType
import com.offlinestt.voicenotes.models.defaultModelCatalog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

class SherpaOnnxManager private constructor(private val context: Context) {

    private var recognizer: OfflineRecognizer? = null
    private var loadedModelId: String? = null

    companion object {
        private const val TAG = "SherpaOnnxManager"

        @Volatile
        private var instance: SherpaOnnxManager? = null

        fun getInstance(context: Context): SherpaOnnxManager {
            return instance ?: synchronized(this) {
                instance ?: SherpaOnnxManager(context.applicationContext).also { instance = it }
            }
        }
    }

    val isModelLoaded: Boolean
        get() = recognizer != null

    val currentModelId: String?
        get() = loadedModelId

    @Synchronized
    fun initModel(model: SpeechModelInfo): Boolean {
        if (model.id == loadedModelId && recognizer != null) {
            return true
        }

        try {
            val downloadManager = ModelDownloadManager.getInstance(context)
            val modelDir = downloadManager.getModelDirectory(model)

            if (!modelDir.exists()) {
                Log.e(TAG, "Model directory not found: ${modelDir.absolutePath}")
                return false
            }

            val files = modelDir.listFiles() ?: emptyArray()
            val encoderFile = files.firstOrNull { it.name.contains("encoder") && it.name.endsWith(".onnx") }
            val decoderFile = files.firstOrNull { it.name.contains("decoder") && it.name.endsWith(".onnx") }
            val tokensFile = files.firstOrNull { it.name.contains("tokens") && it.name.endsWith(".txt") }

            if (encoderFile == null || decoderFile == null || tokensFile == null) {
                Log.e(TAG, "Missing model files in ${modelDir.absolutePath}. Found: ${files.map { it.name }}")
                return false
            }

            Log.d(TAG, "Loading Whisper model: ${model.name}")
            Log.d(TAG, "Encoder: ${encoderFile.absolutePath}")
            Log.d(TAG, "Decoder: ${decoderFile.absolutePath}")
            Log.d(TAG, "Tokens: ${tokensFile.absolutePath}")

            val whisperConfig = OfflineWhisperModelConfig(
                encoder = encoderFile.absolutePath,
                decoder = decoderFile.absolutePath,
                language = if (model.id.contains("multi")) "" else "en",
                task = "transcribe"
            )

            val modelConfig = OfflineModelConfig(
                whisper = whisperConfig,
                tokens = tokensFile.absolutePath,
                numThreads = 2,
                debug = false,
                provider = "cpu",
                modelType = "whisper"
            )

            val recognizerConfig = OfflineRecognizerConfig(
                featConfig = FeatureConfig(sampleRate = 16000, featureDim = 80),
                modelConfig = modelConfig,
                decodingMethod = "greedy_search"
            )

            recognizer = OfflineRecognizer(assetManager = null, config = recognizerConfig)
            loadedModelId = model.id
            Log.d(TAG, "Loaded model successfully: ${model.name}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed loading model ${model.name}: ${e.message}", e)
            recognizer = null
            loadedModelId = null
            return false
        }
    }

    suspend fun transcribeWavFile(wavFile: File): String = withContext(Dispatchers.Default) {
        if (!wavFile.exists()) {
            return@withContext "Error: Audio file does not exist"
        }

        // Ensure model is initialized
        if (recognizer == null) {
            val userPrefs = UserPreferences.getInstance(context)
            val selectedId = userPrefs.activeSttModelId.value
            val downloadManager = ModelDownloadManager.getInstance(context)

            var targetModel = defaultModelCatalog.firstOrNull { it.id == selectedId }
            if (targetModel == null || !downloadManager.isModelDownloaded(targetModel)) {
                // Fallback to any downloaded STT model
                targetModel = defaultModelCatalog.firstOrNull {
                    it.type == SpeechModelType.STT && downloadManager.isModelDownloaded(it)
                }
            }

            if (targetModel != null) {
                initModel(targetModel)
            } else {
                return@withContext "No speech model downloaded. Please open Model Settings."
            }
        }

        val rec = recognizer ?: return@withContext "Speech recognizer not initialized"

        try {
            val waveData = WaveReader.readWave(wavFile.absolutePath)
            if (waveData.samples.isEmpty()) {
                return@withContext ""
            }

            val stream = rec.createStream()
            try {
                stream.acceptWaveform(waveData.samples, waveData.sampleRate)
                rec.decode(stream)
                val result = rec.getResult(stream)
                return@withContext result.text.trim()
            } finally {
                stream.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Transcription failed: ${e.message}", e)
            return@withContext "Transcription error: ${e.message}"
        }
    }
}
