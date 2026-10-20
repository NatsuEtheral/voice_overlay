enum SpeechModelType { stt, tts }

class SpeechModelInfo {
  final String id;
  final String name;
  final String description;
  final SpeechModelType type;
  final int sizeBytes;
  final String downloadUrl;
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
    required this.downloadUrl,
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
  // STT Models (Whisper ONNX via sherpa-onnx)
  SpeechModelInfo(
    id: 'stt_whisper_tiny_en',
    name: 'Whisper Tiny (English)',
    description: 'Ultra-fast, lowest battery and RAM usage. Best for quick notes and older phones.',
    type: SpeechModelType.stt,
    sizeBytes: 39 * 1024 * 1024,
    downloadUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.en.tar.bz2',
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
    downloadUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-base.en.tar.bz2',
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
    downloadUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2',
    relativeDirPath: 'stt_whisper_tiny_multi',
    speedRating: '⚡ Ultra Fast',
    accuracyRating: 'Good',
  ),

  SpeechModelInfo(
    id: 'stt_whisper_small_en',
    name: 'Whisper Small (English)',
    description: 'High accuracy with advanced nuance and punctuation. Recommended for clear, detailed notes.',
    type: SpeechModelType.stt,
    sizeBytes: 150 * 1024 * 1024,
    downloadUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-small.en.tar.bz2',
    relativeDirPath: 'stt_whisper_small_en',
    speedRating: '🚀 Balanced (0.6x)',
    accuracyRating: 'Very High',
  ),
  SpeechModelInfo(
    id: 'stt_whisper_small_multi',
    name: 'Whisper Small (Multilingual)',
    description: 'Very high accuracy across 99+ languages with strong multilingual understanding.',
    type: SpeechModelType.stt,
    sizeBytes: 244 * 1024 * 1024,
    downloadUrl: 'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-small.tar.bz2',
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
    downloadUrl: '',
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
