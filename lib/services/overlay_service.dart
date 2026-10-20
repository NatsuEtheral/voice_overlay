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
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  Future<bool?> requestPermission() async {
    return await FlutterOverlayWindow.requestPermission();
  }

  Future<bool> isOverlayActive() async {
    return await FlutterOverlayWindow.isActive();
  }

  Future<void> showOverlay() async {
    final granted = await isPermissionGranted();
    if (!granted) {
      final req = await requestPermission();
      if (req != true) return;
    }

    // Default collapsed floating bubble size (65x65)
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
  }

  Future<void> closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> toggleOverlay() async {
    final active = await isOverlayActive();
    if (active) {
      await closeOverlay();
    } else {
      await showOverlay();
    }
  }

  static Future<void> resizeToBubble() async {
    await FlutterOverlayWindow.resizeOverlay(70, 70, true);
  }

  static Future<void> resizeToRecording() async {
    await FlutterOverlayWindow.resizeOverlay(270, 75, false);
  }

  static Future<void> resizeToResult() async {
    await FlutterOverlayWindow.resizeOverlay(320, 180, false);
  }
}
