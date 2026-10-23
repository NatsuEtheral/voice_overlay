package com.offlinestt.voicenotes.data

import android.content.Context
import android.util.Log
import com.offlinestt.voicenotes.models.SpeechModelInfo
import com.offlinestt.voicenotes.models.defaultModelCatalog
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

class ModelDownloadManager private constructor(private val context: Context) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val scope = CoroutineScope(Dispatchers.IO)

    // Live catalog state with download status and progress
    private val _catalogFlow = MutableStateFlow<List<SpeechModelInfo>>(defaultModelCatalog)
    val catalogFlow: StateFlow<List<SpeechModelInfo>> = _catalogFlow.asStateFlow()

    companion object {
        private const val TAG = "ModelDownloadManager"

        @Volatile
        private var instance: ModelDownloadManager? = null

        fun getInstance(context: Context): ModelDownloadManager {
            return instance ?: synchronized(this) {
                instance ?: ModelDownloadManager(context.applicationContext).also {
                    instance = it
                    it.refreshDownloadStatus()
                }
            }
        }
    }

    val modelsDir: File
        get() = File(context.filesDir, "speech_models").apply { if (!exists()) mkdirs() }

    fun getModelDirectory(model: SpeechModelInfo): File {
        return File(modelsDir, model.relativeDirPath)
    }

    fun isModelDownloaded(model: SpeechModelInfo): Boolean {
        if (model.isDefaultBuiltIn) return true
        val dir = getModelDirectory(model)
        if (!dir.exists() || !dir.isDirectory) return false

        // Check if all files in fileUrls exist and are non-empty
        return if (model.fileUrls.isNotEmpty()) {
            model.fileUrls.all { url ->
                val fileName = url.substringAfterLast('/')
                val file = File(dir, fileName)
                file.exists() && file.length() > 1024
            }
        } else {
            dir.listFiles()?.isNotEmpty() == true
        }
    }

    fun refreshDownloadStatus() {
        val userPrefs = UserPreferences.getInstance(context)
        val selectedId = userPrefs.activeSttModelId.value

        _catalogFlow.value = _catalogFlow.value.map { model ->
            val downloaded = isModelDownloaded(model)
            model.copy(
                isDownloaded = downloaded,
                isSelected = model.id == selectedId
            )
        }
    }

    fun downloadModel(model: SpeechModelInfo, onComplete: ((Boolean) -> Unit)? = null) {
        scope.launch {
            try {
                updateModelState(model.id, isDownloading = true, progress = 0.01f)

                val targetDir = getModelDirectory(model).apply { if (!exists()) mkdirs() }
                val totalFiles = model.fileUrls.size
                var completedFiles = 0

                for (url in model.fileUrls) {
                    val fileName = url.substringAfterLast('/')
                    val targetFile = File(targetDir, fileName)

                    Log.d(TAG, "Downloading $fileName from $url...")
                    downloadFile(url, targetFile) { fileProgress ->
                        val overallProgress = (completedFiles + fileProgress) / totalFiles.toFloat()
                        updateModelState(model.id, isDownloading = true, progress = overallProgress)
                    }
                    completedFiles++
                }

                updateModelState(model.id, isDownloading = false, isDownloaded = true, progress = 1.0f)
                refreshDownloadStatus()
                withContext(Dispatchers.Main) { onComplete?.invoke(true) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed downloading model ${model.id}: ${e.message}", e)
                updateModelState(model.id, isDownloading = false, isDownloaded = false, progress = 0f)
                withContext(Dispatchers.Main) { onComplete?.invoke(false) }
            }
        }
    }

    private fun downloadFile(url: String, destination: File, onProgress: (Float) -> Unit) {
        val request = Request.Builder().url(url).build()
        val response = client.newCall(request).execute()

        if (!response.isSuccessful) {
            throw Exception("Failed to download file from $url: HTTP ${response.code}")
        }

        val body = response.body ?: throw Exception("Empty response body from $url")
        val contentLength = body.contentLength()
        val inputStream = body.byteStream()
        val outputStream = FileOutputStream(destination)

        var totalBytesRead = 0L
        val buffer = ByteArray(8 * 1024)
        var bytesRead: Int

        outputStream.use { out ->
            inputStream.use { input ->
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    out.write(buffer, 0, bytesRead)
                    totalBytesRead += bytesRead
                    if (contentLength > 0) {
                        onProgress(totalBytesRead.toFloat() / contentLength.toFloat())
                    }
                }
            }
        }
    }

    fun deleteModel(model: SpeechModelInfo) {
        if (model.isDefaultBuiltIn) return
        val dir = getModelDirectory(model)
        if (dir.exists()) {
            dir.deleteRecursively()
        }
        refreshDownloadStatus()
    }

    private fun updateModelState(
        modelId: String,
        isDownloading: Boolean? = null,
        isDownloaded: Boolean? = null,
        progress: Float? = null
    ) {
        _catalogFlow.value = _catalogFlow.value.map { m ->
            if (m.id == modelId) {
                m.copy(
                    isDownloading = isDownloading ?: m.isDownloading,
                    isDownloaded = isDownloaded ?: m.isDownloaded,
                    downloadProgress = progress ?: m.downloadProgress
                )
            } else m
        }
    }
}
