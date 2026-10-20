enum SpeechModelType { stt, tts }

class SpeechModelInfo {
  final String id;
  final String name;
  final String description;
  final SpeechModelType type;
  final int sizeBytes;
  final String downloadUrl; // For single archive downloads
  final List<String> fileUrls; // For direct multi-file downloads (no decompression needed)
  final String relativeDirPath;
  final String speedRating; // e.g. "Ultra Fast", "Fast", "Balanced"
  final String accuracyRating; // e.g. "Good", "High", "Very High"
  final bool isDefaultBuiltIn;
  final bool isDownloaded;
  final bool isSelected;
  final double downloadProgress; // 0.0 to 1.0

  SpeechModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.sizeBytes,
    this.downloadUrl = '',
    this.fileUrls = const [],
    required this.relativeDirPath,
    required this.speedRating,
    required this.accuracyRating,
    this.isDefaultBuiltIn = false,
    this.isDownloaded = false,
    this.isSelected = false,
    this.downloadProgress = 0.0,
  });

  String get formattedSize {
    if (sizeBytes <= 0) return 'Built-in (0 MB)';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  SpeechModelInfo copyWith({
    String? id,
    String? name,
    String? description,
    SpeechModelType? type,
    int? sizeBytes,
    String? downloadUrl,
    List<String>? fileUrls,
    String? relativeDirPath,
    String? speedRating,
    String? accuracyRating,
    bool? isDefaultBuiltIn,
    bool? isDownloaded,
    bool? isSelected,
    double? downloadProgress,
  }) {
    return SpeechModelInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileUrls: fileUrls ?? this.fileUrls,
      relativeDirPath: relativeDirPath ?? this.relativeDirPath,
      speedRating: speedRating ?? this.speedRating,
      accuracyRating: accuracyRating ?? this.accuracyRating,
      isDefaultBuiltIn: isDefaultBuiltIn ?? this.isDefaultBuiltIn,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isSelected: isSelected ?? this.isSelected,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

/// Catalog of tested, production-ready on-device speech models
final List<SpeechModelInfo> defaultModelCatalog = [
  // STT Models (Direct fast CDN from Hugging Face - zero decompression delay)
  SpeechModelInfo(
    id: 'stt_whisper_tiny_en',
    name: 'Whisper Tiny (English)',
    description: 'Ultra-fast, lowest battery and RAM usage. Best for quick notes and older phones.',
    type: SpeechModelType.stt,
    sizeBytes: 40 * 1024 * 1024,
    fileUrls: [
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-encoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-decoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny.en/resolve/main/tiny.en-tokens.txt',
    ],
    relativeDirPath: 'stt_whisper_tiny_en',
    speedRating: '⚡ Ultra Fast (0.2x)',
    accuracyRating: 'Good',
    isSelected: true,
  ),
  SpeechModelInfo(
    id: 'stt_whisper_base_en',
    name: 'Whisper Base (English)',
    description: 'Higher accuracy with enhanced punctuation. Recommended for clear, detailed notes.',
    type: SpeechModelType.stt,
    sizeBytes: 74 * 1024 * 1024,
    fileUrls: [
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base.en/resolve/main/base.en-encoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base.en/resolve/main/base.en-decoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-base.en/resolve/main/base.en-tokens.txt',
    ],
    relativeDirPath: 'stt_whisper_base_en',
    speedRating: '🚀 Fast (0.4x)',
    accuracyRating: 'High',
  ),
  SpeechModelInfo(
    id: 'stt_whisper_tiny_multi',
    name: 'Whisper Tiny (Multilingual)',
    description: 'Supports 99+ languages including Spanish, French, German, Hindi, Chinese, and more.',
    type: SpeechModelType.stt,
    sizeBytes: 75 * 1024 * 1024,
    fileUrls: [
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-encoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-decoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-tiny/resolve/main/tiny-tokens.txt',
    ],
    relativeDirPath: 'stt_whisper_tiny_multi',
    speedRating: '⚡ Ultra Fast',
    accuracyRating: 'Good',
  ),
  SpeechModelInfo(
    id: 'stt_whisper_small_en',
    name: 'Whisper Small (English)',
    description: 'High accuracy with advanced nuance and punctuation. Recommended for clear, detailed notes.',
    type: SpeechModelType.stt,
    sizeBytes: 374 * 1024 * 1024,
    fileUrls: [
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small.en/resolve/main/small.en-encoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small.en/resolve/main/small.en-decoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small.en/resolve/main/small.en-tokens.txt',
    ],
    relativeDirPath: 'stt_whisper_small_en',
    speedRating: '🚀 Balanced (0.6x)',
    accuracyRating: 'Very High',
  ),
  SpeechModelInfo(
    id: 'stt_whisper_small_multi',
    name: 'Whisper Small (Multilingual)',
    description: 'Very high accuracy across 99+ languages with strong multilingual understanding.',
    type: SpeechModelType.stt,
    sizeBytes: 375 * 1024 * 1024,
    fileUrls: [
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-encoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-decoder.int8.onnx',
      'https://huggingface.co/csukuangfj/sherpa-onnx-whisper-small/resolve/main/small-tokens.txt',
    ],
    relativeDirPath: 'stt_whisper_small_multi',
    speedRating: '🚀 Balanced',
    accuracyRating: 'Very High',
  ),

  // TTS Models
  SpeechModelInfo(
    id: 'tts_system_native',
    name: 'Device Native TTS',
    description: 'Uses your phone’s built-in offline speech engine (Google Speech / Apple Voice). No download required.',
    type: SpeechModelType.tts,
    sizeBytes: 0,
    relativeDirPath: '',
    speedRating: '⚡ Instant',
    accuracyRating: 'Standard',
    isDefaultBuiltIn: true,
    isDownloaded: true,
    isSelected: true,
  ),
  SpeechModelInfo(
    id: 'tts_piper_en_lessac',
    name: 'Piper Neural Voice (Lessac)',
    description: 'Natural, human-like US English voice with smooth intonation and high clarity.',
    type: SpeechModelType.tts,
    sizeBytes: 35 * 1024 * 1024,
    downloadUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-en_US-lessac-medium.tar.bz2',
    relativeDirPath: 'tts_piper_en_lessac',
    speedRating: '🚀 Real-time Neural',
    accuracyRating: 'Studio Quality',
  ),
];
