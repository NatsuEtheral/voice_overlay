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
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  Future<bool?> requestPermission() async {
    try {
      return await FlutterOverlayWindow.requestPermission();
    } catch (_) {
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
      return false;
    }

    try {
      // Default collapsed floating bubble size (70x70)
      await FlutterOverlayWindow.showOverlay(
        width: 70,
        height: 70,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'Voice Dictation',
        overlayContent: 'Tap to record voice and dictate anywhere',
        flag: OverlayFlag.defaultFlag,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
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
      await FlutterOverlayWindow.resizeOverlay(70, 70, true);
    } catch (_) {}
  }

  static Future<void> resizeToRecording() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(270, 75, false);
    } catch (_) {}
  }

  static Future<void> resizeToResult() async {
    try {
      await FlutterOverlayWindow.resizeOverlay(320, 180, false);
    } catch (_) {}
  }
}
