import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import '../models/speech_model_info.dart';
import 'model_downloader_service.dart';

class SttService {
  static final SttService instance = SttService._internal();
  SttService._internal();

  sherpa.OfflineRecognizer? _recognizer;
  String? _loadedModelId;

  bool get isModelLoaded => _recognizer != null;
  String? get loadedModelId => _loadedModelId;

  Future<bool> initModel(SpeechModelInfo model) async {
    try {
      // Ensure sherpa-onnx native bindings are initialized
      await sherpa.initBindingsAsync();

      if (_loadedModelId == model.id && _recognizer != null) {
        return true;
      }

      // Dispose existing recognizer
      _recognizer?.free();
      _recognizer = null;
      _loadedModelId = null;

      final dirPath = await ModelDownloaderService.instance.getModelDir(model);
      final dir = Directory(dirPath);

      if (!await dir.exists()) {
        debugPrint('STT Model directory does not exist: $dirPath');
        return false;
      }

      final files = await dir.list(recursive: true).toList();

      String? encoderPath;
      String? decoderPath;
      String? tokensPath;

      for (final f in files) {
        final path = f.path;
        final name = p.basename(path).toLowerCase();

        if (name.contains('encoder') && name.endsWith('.onnx')) {
          if (encoderPath == null || (name.contains('int8') && !encoderPath.contains('int8'))) {
            encoderPath = path;
          }
        } else if (name.contains('decoder') && name.endsWith('.onnx')) {
          if (decoderPath == null || (name.contains('int8') && !decoderPath.contains('int8'))) {
            decoderPath = path;
          }
        } else if (name.contains('tokens.txt')) {
          tokensPath = path;
        }
      }

      if (encoderPath == null || decoderPath == null || tokensPath == null) {
        debugPrint('Missing model files in $dirPath. Found: encoder=$encoderPath, decoder=$decoderPath, tokens=$tokensPath');
        return false;
      }

      debugPrint('Initializing Whisper with encoder: $encoderPath, decoder: $decoderPath, tokens: $tokensPath');

      final config = sherpa.OfflineRecognizerConfig(
        model: sherpa.OfflineModelConfig(
          whisper: sherpa.OfflineWhisperModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
          ),
          tokens: tokensPath,
          numThreads: 2,
          debug: false,
          modelType: 'whisper',
        ),
      );

      _recognizer = sherpa.OfflineRecognizer(config);
      _loadedModelId = model.id;
      debugPrint('Loaded Whisper model successfully: ${model.name}');
      return true;
    } catch (e, stack) {
      debugPrint('Failed to initialize STT model: $e\n$stack');
      _recognizer?.free();
      _recognizer = null;
      _loadedModelId = null;
      return false;
    }
  }

  Future<String> transcribeWavFile(String wavPath) async {
    await sherpa.initBindingsAsync();

    if (_recognizer == null) {
      throw Exception('Whisper model is not initialized. Please select or download a model first.');
    }

    final file = File(wavPath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $wavPath');
    }

    try {
      final waveData = sherpa.readWave(wavPath);
      final stream = _recognizer!.createStream();

      stream.acceptWaveform(
        samples: waveData.samples,
        sampleRate: waveData.sampleRate,
      );

      _recognizer!.decode(stream);
      final result = _recognizer!.getResult(stream);
      stream.free();

      final text = result.text.trim();
      return _cleanAndFormatTranscription(text);
    } catch (e) {
      debugPrint('Error transcribing audio: $e');
      rethrow;
    }
  }

  String _cleanAndFormatTranscription(String raw) {
    if (raw.isEmpty) return '';
    // Capitalize first letter
    String formatted = raw[0].toUpperCase() + raw.substring(1);
    // Ensure terminal punctuation
    if (!RegExp(r'[.!?]$').hasMatch(formatted)) {
      formatted += '.';
    }
    return formatted;
  }

  void dispose() {
    _recognizer?.free();
    _recognizer = null;
    _loadedModelId = null;
  }
}
