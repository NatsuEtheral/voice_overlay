import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/speech_model_info.dart';
import '../services/model_downloader_service.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';

class ModelsState {
  final List<SpeechModelInfo> models;
  final bool isLoading;
  final String? activeSttModelId;
  final String? activeTtsModelId;
  final String? statusMessage;

  ModelsState({
    this.models = const [],
    this.isLoading = true,
    this.activeSttModelId,
    this.activeTtsModelId,
    this.statusMessage,
  });

  ModelsState copyWith({
    List<SpeechModelInfo>? models,
    bool? isLoading,
    String? activeSttModelId,
    String? activeTtsModelId,
    String? statusMessage,
  }) {
    return ModelsState(
      models: models ?? this.models,
      isLoading: isLoading ?? this.isLoading,
      activeSttModelId: activeSttModelId ?? this.activeSttModelId,
      activeTtsModelId: activeTtsModelId ?? this.activeTtsModelId,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  SpeechModelInfo? get activeSttModel {
    return models.cast<SpeechModelInfo?>().firstWhere(
      (m) => m?.id == activeSttModelId,
      orElse: () => null,
    );
  }

  SpeechModelInfo? get activeTtsModel {
    return models.cast<SpeechModelInfo?>().firstWhere(
      (m) => m?.id == activeTtsModelId,
      orElse: () => null,
    );
  }
}

class ModelsNotifier extends StateNotifier<ModelsState> {
  ModelsNotifier() : super(ModelsState()) {
    initCatalog();
  }

  Future<void> initCatalog() async {
    state = state.copyWith(isLoading: true);
    final updatedModels = <SpeechModelInfo>[];

    String? defaultStt;
    String? defaultTts;

    for (final model in defaultModelCatalog) {
      final downloaded = await ModelDownloaderService.instance.isModelDownloaded(model);

      if (model.id == 'stt_whisper_base_en' && downloaded) {
        defaultStt = model.id;
      } else if (model.type == SpeechModelType.stt && defaultStt == null && downloaded) {
        defaultStt = model.id;
      }
      if (model.type == SpeechModelType.tts && defaultTts == null && downloaded) {
        defaultTts = model.id;
      }

      updatedModels.add(model.copyWith(isDownloaded: downloaded));
    }

    final finalModels = updatedModels.map((m) {
      if (m.type == SpeechModelType.stt) {
        return m.copyWith(isSelected: m.id == defaultStt);
      } else {
        return m.copyWith(isSelected: m.id == defaultTts);
      }
    }).toList();

    state = state.copyWith(
      models: finalModels,
      activeSttModelId: defaultStt,
      activeTtsModelId: defaultTts ?? 'tts_system_native',
      isLoading: false,
    );

    // Initialize active STT model if downloaded
    final activeStt = state.activeSttModel;
    if (activeStt != null && activeStt.isDownloaded) {
      await SttService.instance.initModel(activeStt);
    }
  }

  Future<void> downloadModel(String modelId) async {
    final index = state.models.indexWhere((m) => m.id == modelId);
    if (index == -1) return;

    final targetModel = state.models[index];
    if (targetModel.isDefaultBuiltIn || targetModel.isDownloaded) return;

    try {
      await ModelDownloaderService.instance.downloadAndExtractModel(
        model: targetModel,
        onProgress: (progress) {
          final updated = [...state.models];
          updated[index] = updated[index].copyWith(downloadProgress: progress);
          state = state.copyWith(models: updated);
        },
      );

      // Successfully downloaded
      final updated = [...state.models];
      updated[index] = updated[index].copyWith(
        isDownloaded: true,
        downloadProgress: 1.0,
      );

      // Auto-select if first of its type
      if (targetModel.type == SpeechModelType.stt && state.activeSttModelId == null) {
        state = state.copyWith(models: updated, activeSttModelId: targetModel.id);
        await SttService.instance.initModel(targetModel);
      } else {
        state = state.copyWith(models: updated);
      }
    } catch (e) {
      final updated = [...state.models];
      updated[index] = updated[index].copyWith(downloadProgress: 0.0);
      state = state.copyWith(
        models: updated,
        statusMessage: 'Download failed: $e',
      );
    }
  }

  Future<void> selectModel(String modelId) async {
    final model = state.models.firstWhere((m) => m.id == modelId);
    if (!model.isDownloaded && !model.isDefaultBuiltIn) return;

    if (model.type == SpeechModelType.stt) {
      final updated = state.models.map((m) {
        if (m.type == SpeechModelType.stt) {
          return m.copyWith(isSelected: m.id == modelId);
        }
        return m;
      }).toList();
      state = state.copyWith(models: updated, activeSttModelId: model.id);
      await SttService.instance.initModel(model);
    } else {
      final updated = state.models.map((m) {
        if (m.type == SpeechModelType.tts) {
          return m.copyWith(isSelected: m.id == modelId);
        }
        return m;
      }).toList();
      state = state.copyWith(models: updated, activeTtsModelId: model.id);
      await TtsService.instance.initNeuralModel(model);
    }
  }

  Future<void> deleteModel(String modelId) async {
    final index = state.models.indexWhere((m) => m.id == modelId);
    if (index == -1) return;

    final targetModel = state.models[index];
    if (targetModel.isDefaultBuiltIn) return;

    await ModelDownloaderService.instance.deleteModel(targetModel);

    final updated = [...state.models];
    updated[index] = updated[index].copyWith(
      isDownloaded: false,
      downloadProgress: 0.0,
      isSelected: false,
    );

    String? newActiveStt = state.activeSttModelId;
    if (state.activeSttModelId == modelId) {
      newActiveStt = null;
      SttService.instance.dispose();
    }

    state = state.copyWith(
      models: updated,
      activeSttModelId: newActiveStt,
    );
  }
}

final modelsProvider = StateNotifierProvider<ModelsNotifier, ModelsState>((ref) {
  return ModelsNotifier();
});
