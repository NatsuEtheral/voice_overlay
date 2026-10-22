import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static final OverlayService instance = OverlayService._internal();
  OverlayService._internal();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.offlinestt.voicenotes/overlay_channel');

  void initTileListener() {
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'toggleOverlay') {
        await toggleOverlay();
      }
    });
  }

  Future<bool> isPermissionGranted() async {
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      debugPrint('OverlayService.isPermissionGranted: $granted');
      return granted;
    } catch (e) {
      debugPrint('OverlayService.isPermissionGranted error: $e');
      return false;
    }
  }

  Future<bool?> requestPermission() async {
    try {
      debugPrint('OverlayService.requestPermission called');
      return await FlutterOverlayWindow.requestPermission();
    } catch (e) {
      debugPrint('OverlayService.requestPermission error: $e');
      return false;
    }
  }

  Future<bool> isOverlayActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (_) {
      return false;
    }
  }

  Future<bool> showOverlay() async {
    final granted = await isPermissionGranted();
    if (!granted) {
      debugPrint('OverlayService.showOverlay: permission not granted');
      return false;
    }

    try {
      debugPrint('OverlayService.showOverlay: launching overlay window');
      // Pass pixel dimensions matching the collapsed floating bubble (~80dp * 3.0 density)
      await FlutterOverlayWindow.showOverlay(
        width: 250,
        height: 250,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Voice Dictation',
        overlayContent: 'Tap to record voice and dictate anywhere',
        flag: OverlayFlag.defaultFlag,
      );
      debugPrint('OverlayService.showOverlay: launched successfully');
      return true;
    } catch (e, stack) {
      debugPrint('OverlayService.showOverlay error: $e\n$stack');
      return false;
    }
  }

  Future<void> closeOverlay() async {
    try {
      debugPrint('OverlayService.closeOverlay called');
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('OverlayService.closeOverlay error: $e');
    }
  }

  Future<bool> toggleOverlay() async {
    final active = await isOverlayActive();
    if (active) {
      await closeOverlay();
      return false;
    } else {
      return await showOverlay();
    }
  }

  static Future<void> resizeToBubble() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(80, 80, true);
    } catch (e) {
      debugPrint('OverlayService.resizeToBubble error: $e');
    }
  }

  static Future<void> resizeToRecording() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(280, 80, false);
    } catch (e) {
      debugPrint('OverlayService.resizeToRecording error: $e');
    }
  }

  static Future<void> resizeToResult() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(320, 190, false);
    } catch (e) {
      debugPrint('OverlayService.resizeToResult error: $e');
    }
  }
}
