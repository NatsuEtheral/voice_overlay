import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import '../models/speech_model_info.dart';

class ModelDownloaderService {
  static final ModelDownloaderService instance = ModelDownloaderService._internal();
  ModelDownloaderService._internal();

  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};

  Future<String> getModelsBaseDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(appDir.path, 'speech_models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  Future<String> getModelDir(SpeechModelInfo model) async {
    final base = await getModelsBaseDir();
    return p.join(base, model.relativeDirPath);
  }

  Future<bool> isModelDownloaded(SpeechModelInfo model) async {
    if (model.isDefaultBuiltIn) return true;
    final dirPath = await getModelDir(model);
    final dir = Directory(dirPath);
    if (!await dir.exists()) return false;

    // Check if directory has files inside
    final files = await dir.list().toList();
    return files.isNotEmpty;
  }

  Future<void> downloadAndExtractModel({
    required SpeechModelInfo model,
    required void Function(double progress) onProgress,
  }) async {
    if (model.isDefaultBuiltIn) return;

    final baseDir = await getModelsBaseDir();
    final targetDir = Directory(await getModelDir(model));
    final cancelToken = CancelToken();
    _cancelTokens[model.id] = cancelToken;

    final tempArchive = File(p.join(baseDir, '${model.id}.archive'));

    try {
      // 1. Download file
      await _dio.download(
        model.downloadUrl,
        tempArchive.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );

      // 2. Extract Archive
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final bytes = await tempArchive.readAsBytes();
      Archive? archive;

      if (model.downloadUrl.endsWith('.tar.bz2')) {
        final bz2 = BZip2Decoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(bz2);
      } else if (model.downloadUrl.endsWith('.tar.gz') || model.downloadUrl.endsWith('.tgz')) {
        final gz = GZipDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(gz);
      } else if (model.downloadUrl.endsWith('.zip')) {
        archive = ZipDecoder().decodeBytes(bytes);
      }

      if (archive != null) {
        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            // Flatten single top-level folder if archive contains one
            final parts = p.split(filename);
            final cleanFilename = parts.length > 1 ? parts.sublist(1).join('/') : filename;
            final outFile = File(p.join(targetDir.path, cleanFilename));
            await outFile.parent.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
      }

      // Cleanup temp archive
      if (await tempArchive.exists()) {
        await tempArchive.delete();
      }

      onProgress(1.0);
    } catch (e) {
      if (await tempArchive.exists()) {
        await tempArchive.delete();
      }
      rethrow;
    } finally {
      _cancelTokens.remove(model.id);
    }
  }

  void cancelDownload(String modelId) {
    _cancelTokens[modelId]?.cancel();
    _cancelTokens.remove(modelId);
  }

  Future<void> deleteModel(SpeechModelInfo model) async {
    if (model.isDefaultBuiltIn) return;
    final dir = Directory(await getModelDir(model));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
