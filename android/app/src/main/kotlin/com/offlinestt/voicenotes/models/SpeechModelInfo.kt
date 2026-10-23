package com.offlinestt.voicenotes.models

enum class SpeechModelType { STT, TTS }

data class SpeechModelInfo(
    val id: String,
    val name: String,
    val description: String,
    val type: SpeechModelType,
    val sizeBytes: Long,
    val fileUrls: List<String> = emptyList(),
    val downloadUrl: String = "",
    val relativeDirPath: String,
    val speedRating: String,
    val accuracyRating: String,
    val isDefaultBuiltIn: Boolean = false,
    val isDownloaded: Boolean = false,
    val isSelected: Boolean = false,
    val downloadProgress: Float = 0f, // 0.0f to 1.0f
    val isDownloading: Boolean = false
) {
    val formattedSize: String
        get() {
            if (sizeBytes <= 0) return "Built-in (0 MB)"
            val mb = sizeBytes.toDouble() / (1024.0 * 1024.0)
            return String.format("%.1f MB", mb)
        }
}

val defaultModelCatalog = listOf(
    SpeechModelInfo(
        id = "stt_whisper_tiny_en",
        name = "Whisper Tiny (English)",
        description = "Ultra-fast, lowest battery and RAM usage. Best for quick notes and older phones.",
        type = SpeechModelType.STT,
        sizeBytes = 40L * 1024 * 1024,
        fileUrls = listOf(
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-encoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-decoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-tokens.txt"
        ),
        relativeDirPath = "stt_whisper_tiny_en",
        speedRating = "⚡ Ultra Fast (0.2x)",
        accuracyRating = "Good"
    ),
    SpeechModelInfo(
        id = "stt_whisper_base_en",
        name = "Whisper Base (English)",
        description = "Higher accuracy with enhanced punctuation. Recommended for clear, detailed notes.",
        type = SpeechModelType.STT,
        sizeBytes = 74L * 1024 * 1024,
        fileUrls = listOf(
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base.en/resolve/main/base.en-encoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base.en/resolve/main/base.en-decoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base.en/resolve/main/base.en-tokens.txt"
        ),
        relativeDirPath = "stt_whisper_base_en",
        speedRating = "🚀 Fast (0.4x)",
        accuracyRating = "High",
        isSelected = true
    ),
    SpeechModelInfo(
        id = "stt_whisper_tiny_multi",
        name = "Whisper Tiny (Multilingual)",
        description = "Supports 99+ languages including Spanish, French, German, Hindi, Chinese, and more.",
        type = SpeechModelType.STT,
        sizeBytes = 75L * 1024 * 1024,
        fileUrls = listOf(
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-encoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-decoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-tokens.txt"
        ),
        relativeDirPath = "stt_whisper_tiny_multi",
        speedRating = "⚡ Ultra Fast",
        accuracyRating = "Good"
    ),
    SpeechModelInfo(
        id = "stt_whisper_small_en",
        name = "Whisper Small (English)",
        description = "High accuracy with advanced nuance and punctuation. Recommended for clear, detailed notes.",
        type = SpeechModelType.STT,
        sizeBytes = 374L * 1024 * 1024,
        fileUrls = listOf(
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small.en/resolve/main/small.en-encoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small.en/resolve/main/small.en-decoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small.en/resolve/main/small.en-tokens.txt"
        ),
        relativeDirPath = "stt_whisper_small_en",
        speedRating = "🚀 Balanced (0.6x)",
        accuracyRating = "Very High"
    ),
    SpeechModelInfo(
        id = "stt_whisper_small_multi",
        name = "Whisper Small (Multilingual)",
        description = "Very high accuracy across 99+ languages with strong multilingual understanding.",
        type = SpeechModelType.STT,
        sizeBytes = 375L * 1024 * 1024,
        fileUrls = listOf(
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-encoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-decoder.int8.onnx",
            "https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-tokens.txt"
        ),
        relativeDirPath = "stt_whisper_small_multi",
        speedRating = "🚀 Balanced",
        accuracyRating = "Very High"
    ),
    SpeechModelInfo(
        id = "tts_system_native",
        name = "Device Native TTS",
        description = "Uses your phone’s built-in offline speech engine (Google Speech / Device TTS). No download required.",
        type = SpeechModelType.TTS,
        sizeBytes = 0L,
        relativeDirPath = "",
        speedRating = "⚡ Instant",
        accuracyRating = "Standard",
        isDefaultBuiltIn = true,
        isDownloaded = true,
        isSelected = true
    ),
    SpeechModelInfo(
        id = "tts_piper_en_lessac",
        name = "Piper Neural Voice (Lessac)",
        description = "Natural, human-like US English voice with smooth intonation and high clarity.",
        type = SpeechModelType.TTS,
        sizeBytes = 35L * 1024 * 1024,
        downloadUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2",
        relativeDirPath = "tts_piper_en_lessac",
        speedRating = "🚀 Real-time Neural",
        accuracyRating = "Studio Quality"
    )
)
