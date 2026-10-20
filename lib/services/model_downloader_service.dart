import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import '../models/speech_model_info.dart';

class ModelDownloaderService {
  static final ModelDownloaderService instance = ModelDownloaderService._internal();
  ModelDownloaderService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      followRedirects: true,
      maxRedirects: 5,
    ),
  );
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

    final files = await dir.list(recursive: true).toList();
    if (files.isEmpty) return false;

    // Verify required files exist
    if (model.type == SpeechModelType.stt) {
      bool hasEncoder = false;
      bool hasDecoder = false;
      bool hasTokens = false;

      for (final f in files) {
        final name = p.basename(f.path).toLowerCase();
        if (name.contains('encoder') && name.endsWith('.onnx')) hasEncoder = true;
        if (name.contains('decoder') && name.endsWith('.onnx')) hasDecoder = true;
        if (name.contains('tokens.txt')) hasTokens = true;
      }
      return hasEncoder && hasDecoder && hasTokens;
    }

    // TTS model
    bool hasOnnx = false;
    for (final f in files) {
      if (p.basename(f.path).toLowerCase().endsWith('.onnx')) {
        hasOnnx = true;
        break;
      }
    }
    return hasOnnx;
  }

  Future<void> downloadAndExtractModel({
    required SpeechModelInfo model,
    required void Function(double progress) onProgress,
  }) async {
    if (model.isDefaultBuiltIn) return;

    final targetDir = Directory(await getModelDir(model));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final cancelToken = CancelToken();
    _cancelTokens[model.id] = cancelToken;

    try {
      // 1. Direct Multi-File Fast Download (Hugging Face CDN - zero decompression delay)
      if (model.fileUrls.isNotEmpty) {
        final totalFiles = model.fileUrls.length;
        final List<int> receivedBytes = List.filled(totalFiles, 0);
        final List<int> totalBytes = List.filled(totalFiles, 0);

        for (int i = 0; i < totalFiles; i++) {
          final fileUrl = model.fileUrls[i];
          final fileName = p.basename(Uri.parse(fileUrl).path);
          final destinationPath = p.join(targetDir.path, fileName);
          final tempFilePath = '$destinationPath.download';

          await _dio.download(
            fileUrl,
            tempFilePath,
            cancelToken: cancelToken,
            onReceiveProgress: (rec, tot) {
              receivedBytes[i] = rec;
              if (tot > 0) totalBytes[i] = tot;

              final totalRec = receivedBytes.reduce((a, b) => a + b);
              final totalSum = totalBytes.reduce((a, b) => a + b);

              if (totalSum > 0) {
                onProgress((totalRec / totalSum).clamp(0.0, 0.99));
              } else {
                onProgress(((i + (tot > 0 ? rec / tot : 0.5)) / totalFiles).clamp(0.0, 0.99));
              }
            },
          );

          // Rename temp to final file
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            final destFile = File(destinationPath);
            if (await destFile.exists()) await destFile.delete();
            await tempFile.rename(destinationPath);
          }
        }

        onProgress(1.0);
        return;
      }

      // 2. Archive Download & Background Extraction (for Piper TTS)
      final baseDir = await getModelsBaseDir();
      final tempArchive = File(p.join(baseDir, '${model.id}.archive'));

      await _dio.download(
        model.downloadUrl,
        tempArchive.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total) * 0.9; // 90% for download
            onProgress(progress);
          }
        },
      );

      // Extract in background isolate to prevent UI freezing
      await compute(_extractArchiveWorker, _ExtractParams(
        archivePath: tempArchive.path,
        targetDirPath: targetDir.path,
        isBz2: model.downloadUrl.endsWith('.tar.bz2'),
        isGz: model.downloadUrl.endsWith('.tar.gz') || model.downloadUrl.endsWith('.tgz'),
        isZip: model.downloadUrl.endsWith('.zip'),
      ));

      if (await tempArchive.exists()) {
        await tempArchive.delete();
      }

      onProgress(1.0);
    } catch (e) {
      debugPrint('Download error for ${model.name}: $e');
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

class _ExtractParams {
  final String archivePath;
  final String targetDirPath;
  final bool isBz2;
  final bool isGz;
  final bool isZip;

  _ExtractParams({
    required this.archivePath,
    required this.targetDirPath,
    required this.isBz2,
    required this.isGz,
    required this.isZip,
  });
}

Future<void> _extractArchiveWorker(_ExtractParams params) async {
  final archiveFile = File(params.archivePath);
  if (!await archiveFile.exists()) return;

  final bytes = await archiveFile.readAsBytes();
  Archive? archive;

  if (params.isBz2) {
    final bz2 = BZip2Decoder().decodeBytes(bytes);
    archive = TarDecoder().decodeBytes(bz2);
  } else if (params.isGz) {
    final gz = GZipDecoder().decodeBytes(bytes);
    archive = TarDecoder().decodeBytes(gz);
  } else if (params.isZip) {
    archive = ZipDecoder().decodeBytes(bytes);
  }

  if (archive != null) {
    final targetDir = Directory(params.targetDirPath);
    for (final file in archive) {
      if (file.isFile) {
        final parts = p.split(file.name);
        final cleanFilename = parts.length > 1 ? parts.sublist(1).join('/') : file.name;
        final outFile = File(p.join(targetDir.path, cleanFilename));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }
  }
}
