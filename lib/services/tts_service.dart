import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../models/speech_model_info.dart';
import 'model_downloader_service.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  sherpa.OfflineTts? _sherpaTts;
  String? _loadedTtsModelId;

  TtsState _state = TtsState.stopped;
  TtsState get state => _state;

  final ValueNotifier<TtsState> stateNotifier = ValueNotifier<TtsState>(TtsState.stopped);

  double _speechRate = 1.0;
  double get speechRate => _speechRate;

  Future<void> init() async {
    await _flutterTts.setSpeechRate(0.5); // standard speed on flutter_tts is ~0.5
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _state = TtsState.playing;
      stateNotifier.value = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
      stateNotifier.value = TtsState.stopped;
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('FlutterTts error: $msg');
      _state = TtsState.stopped;
      stateNotifier.value = TtsState.stopped;
    });

    _audioPlayer.onPlayerStateChanged.listen((pState) {
      if (pState == PlayerState.playing) {
        _state = TtsState.playing;
      } else if (pState == PlayerState.paused) {
        _state = TtsState.paused;
      } else if (pState == PlayerState.completed || pState == PlayerState.stopped) {
        _state = TtsState.stopped;
      }
      stateNotifier.value = _state;
    });
  }

  Future<bool> initNeuralModel(SpeechModelInfo model) async {
    try {
      await sherpa.initBindingsAsync();

      if (_loadedTtsModelId == model.id && _sherpaTts != null) {
        return true;
      }

      _sherpaTts?.free();
      _sherpaTts = null;
      _loadedTtsModelId = null;

      if (model.isDefaultBuiltIn) return true;

      final dirPath = await ModelDownloaderService.instance.getModelDir(model);
      final dir = Directory(dirPath);
      if (!await dir.exists()) return false;

      final files = await dir.list(recursive: true).toList();
      String? modelPath;
      String? tokensPath;
      String? dataDir;

      for (final f in files) {
        final path = f.path;
        final name = p.basename(path).toLowerCase();

        if (name.endsWith('.onnx')) {
          modelPath = path;
        } else if (name == 'tokens.txt') {
          tokensPath = path;
        } else if (name == 'espeak-ng-data' && f is Directory) {
          dataDir = path;
        }
      }

      if (modelPath == null || tokensPath == null) {
        debugPrint('Missing neural TTS files in $dirPath');
        return false;
      }

      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: modelPath,
            tokens: tokensPath,
            dataDir: dataDir ?? '',
          ),
          numThreads: 2,
          debug: false,
        ),
      );

      _sherpaTts = sherpa.OfflineTts(config);
      _loadedTtsModelId = model.id;
      return true;
    } catch (e) {
      debugPrint('Failed to initialize neural TTS: $e');
      return false;
    }
  }

  Future<void> speak(String text, {SpeechModelInfo? activeModel}) async {
    if (text.trim().isEmpty) return;
    await stop();

    // If active model is neural Piper and is loaded, synthesize audio
    if (activeModel != null && !activeModel.isDefaultBuiltIn && _sherpaTts != null) {
      try {
        final audio = _sherpaTts!.generate(text: text, sid: 0, speed: _speechRate.toDouble());
        final tempDir = await getTemporaryDirectory();
        final outWav = p.join(tempDir.path, 'tts_output.wav');
        sherpa.writeWave(filename: outWav, samples: audio.samples, sampleRate: audio.sampleRate);
        await _audioPlayer.play(DeviceFileSource(outWav));
        return;
      } catch (e) {
        debugPrint('Neural TTS failed, falling back to Native TTS: $e');
      }
    }

    // Default: Native device TTS
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    await _audioPlayer.stop();
    _state = TtsState.stopped;
    stateNotifier.value = TtsState.stopped;
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    await _audioPlayer.pause();
    _state = TtsState.paused;
    stateNotifier.value = TtsState.paused;
  }

  void setRate(double rate) {
    _speechRate = rate;
    _flutterTts.setSpeechRate(rate * 0.5);
  }

  void dispose() {
    stop();
    _sherpaTts?.free();
    _audioPlayer.dispose();
  }
}
