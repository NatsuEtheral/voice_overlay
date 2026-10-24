# Current Status: Migration to Native Android (Kotlin)

**Timestamp:** 2026-10-24 07:33 IST  
**Active Branch:** `migrate_to_kotlin`  
**Repository:** `https://github.com/NatsuEtheral/voice_overlay.git`  
**Target Device:** OnePlus Nord CE4 (`CPH2691`), Snapdragon 7 Gen 3, Android 14/15  
**Generated APK:** `~/Downloads/voice-overlay.apk` (139 MB) — Installed & Running (PID: 18769)  

---

## 1. Why We Migrated from Flutter to Native Kotlin
- **Root Cause of Overlay Touch Bug:** Under Flutter, running `flutter_overlay_window` spawned a secondary Flutter engine inside `WindowManager`. On ColorOS/OxygenOS (OnePlus), touch events were triggering `ACTION_CANCEL` and gralloc buffer allocation errors due to gesture manager interference.
- **Performance & Latency:** Native Android `WindowManager` with a lightweight XML/View layout and direct `AudioRecord` provides instantaneous touch reaction, zero secondary engine RAM overhead (~100MB saved), and fluid 120Hz waveform rendering via a custom hardware-accelerated Canvas.

---

## 2. Implemented Architecture & Tech Stack

| Component | Technology / Implementation | Status |
| :--- | :--- | :--- |
| **Main App UI** | Pure Jetpack Compose + Material 3, Dark Theme | ✅ Implemented |
| **Floating Overlay** | Native `WindowManager` (`TYPE_APPLICATION_OVERLAY`) + custom `FloatingOverlayView` | ✅ Implemented |
| **Waveform Visualizer** | Custom `WaveformCanvasView` (hardware accelerated, 120Hz) | ✅ Implemented |
| **Background Service** | `VoiceOverlayService` (Foreground Service with microphone type) | ✅ Implemented |
| **Audio Capture** | Direct `android.media.AudioRecord` (16 kHz, 16-bit mono PCM, RMS live streaming) | ✅ Implemented |
| **Speech Inference (STT)**| Official `com.k2fsa.sherpa.onnx` native JNI bindings with int8 Whisper models | ✅ Implemented |
| **Native Libraries (.so)**| `libsherpa-onnx-jni.so`, `libonnxruntime.so`, `libsherpa-onnx-c-api.so` extracted for `arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86` | ✅ Placed in `jniLibs/` |
| **Clean Speech Engine** | Regex filler word removal ("um", "uh", "you know"), stutter cleaner, auto-capitalization | ✅ Implemented |
| **Text-to-Speech (TTS)** | Native Android `TextToSpeech` engine wrapper | ✅ Implemented |
| **Model Downloads** | OkHttp streaming downloader with live progress & exact same Cloudflare CDN URLs | ✅ Implemented |
| **Default Model** | Whisper Base English (`base.en-encoder.int8.onnx`, 74 MB) set as default | ✅ Configured |
| **Persistence** | SQLiteOpenHelper with reactive `StateFlow<List<Note>>` | ✅ Implemented |
| **User Preferences** | SharedPreferences / DataStore wrapper (`UserPreferences.kt`) | ✅ Implemented |
| **Quick Settings Tile** | `VoiceTileService` to toggle overlay directly without opening `MainActivity` | ✅ Implemented |

---

## 3. Directory Structure of Native Implementation

```text
android/app/src/main/
├── AndroidManifest.xml                    # Cleaned of Flutter; services and permissions registered
├── jniLibs/                               # Prebuilt Sherpa ONNX and ONNX Runtime libraries
│   ├── arm64-v8a/
│   ├── armeabi-v7a/
│   ├── x86/
│   └── x86_64/
├── kotlin/
│   ├── com/k2fsa/sherpa/onnx/            # Official Sherpa ONNX Kotlin bindings
│   │   ├── FeatureConfig.kt
│   │   ├── HomophoneReplacerConfig.kt
│   │   ├── OfflineRecognizer.kt
│   │   ├── OfflineStream.kt
│   │   ├── QnnConfig.kt
│   │   └── WaveReader.kt
│   └── com/offlinestt/voicenotes/
│       ├── MainActivity.kt                # Jetpack Compose entry point + 120Hz refresh setup
│       ├── VoiceTileService.kt            # Quick Settings tile integration
│       ├── data/
│       │   ├── ModelDownloadManager.kt    # OkHttp model downloader & catalog state
│       │   ├── NotesDatabaseHelper.kt     # Reactive SQLite database
│       │   └── UserPreferences.kt         # Model selection & settings persistence
│       ├── models/
│       │   ├── Note.kt                    # Note data entity
│       │   └── SpeechModelInfo.kt         # Complete model catalog (Cloudflare CDN links)
│       ├── overlay/
│       │   ├── FloatingOverlayView.kt     # WindowManager view: drag, snap, state transitions
│       │   ├── VoiceOverlayService.kt     # Foreground service handling record & STT pipeline
│       │   └── WaveformCanvasView.kt      # Real-time audio waveform view
│       ├── speech/
│       │   ├── AudioRecordManager.kt      # 16kHz PCM capture + WAV header formatting
│       │   ├── CleanSpeechEngine.kt       # Filler word & stutter removal
│       │   ├── SherpaOnnxManager.kt       # Whisper int8 ONNX inference wrapper
│       │   └── TtsEngine.kt               # Native TTS wrapper
│       └── ui/
│           ├── screens/
│           │   ├── HomeScreen.kt          # Notes list, search, floating bubble control
│           │   ├── ModelManagerScreen.kt  # Download & select speech models
│           │   └── NoteEditorScreen.kt    # Dictation, editor, tags, TTS playback
│           └── theme/
│               └── Theme.kt               # Material 3 dark color scheme & typography
└── res/
    ├── drawable/                          # Vector assets (mic, stop, close, copy, save, etc.)
    ├── layout/
    │   └── layout_floating_overlay.xml    # Multi-state overlay UI (bubble, pill, card)
    └── values/
        └── styles.xml                     # Clean native Material 3 theme
```

---

## 4. Work Completed
1. **Sherpa ONNX JNI Integration:** Downloaded and extracted official release `v1.13.8` JNI binaries for all Android ABIs (`arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`).
2. **Missing Reference Fixes:**
   - Added `QnnConfig.kt` to resolve unresolved references in `OfflineRecognizer.kt`.
   - Updated `SherpaOnnxManager.kt` constructor call for `OfflineRecognizer(assetManager = null, config = recognizerConfig)`.
   - Fixed `R` resource resolution in `FloatingOverlayView.kt`.
   - Added `CircleShape` import in `ModelManagerScreen.kt`.
3. **Legacy Flutter Cleanup:** Removed `GeneratedPluginRegistrant.java` from `src/main/java`.
4. **Native Build & Assembly:** Successful build via `./gradlew assembleDebug` with 0 compilation errors.
5. **APK Generated & Placed:** Copied debug APK to `~/Downloads/voice-overlay.apk` (139 MB).
6. **Git Synchronized:** Committed and pushed to remote branch `migrate_to_kotlin` (`16b700f`).

---

## 5. Testing on Phone
You can install `~/Downloads/voice-overlay.apk` directly on your OnePlus Nord CE4:
- Transfer `voice-overlay.apk` to your phone or install via ADB:
  ```bash
  adb install -r ~/Downloads/voice-overlay.apk
  ```
- **What to verify:**
  1. **Home Screen:** High refresh rate (120Hz) smoothness, notes list, model status.
  2. **Model Download:** Go to Models $\rightarrow$ Whisper Base English (74MB) default download from Cloudflare CDN.
  3. **Floating Overlay Activation:** Tap the Floating Voice Bubble card $\rightarrow$ grant `Display over other apps` permission $\rightarrow$ purple floating bubble appears.
  4. **Instant Touch Response:** Tap the floating orb $\rightarrow$ expands immediately into recording pill with live waveform (no ignored touches or `ACTION_CANCEL` bugs!).
  5. **Dictation & Auto-Copy:** Speak $\rightarrow$ tap Stop $\rightarrow$ clean transcribed text appears and automatically copies to clipboard for instant pasting anywhere.
  6. **Quick Settings Tile:** Add and test the Voice Overlay tile in the notification drawer.

---

## 6. Startup Crash Fix (October 24, 2026)
- **Problem 1:** In `AndroidManifest.xml`, relative class paths like `.MainActivity` were resolving to `com.offlinestt.voicenotes.offline_voice_notes.MainActivity` (due to the `namespace` configuration in `build.gradle.kts`), leading to `ClassNotFoundException: Didn't find class ... MainActivity`.
  - **Resolution:** Updated all components (`MainActivity`, `VoiceTileService`, `VoiceOverlayService`) to use fully qualified class names.
- **Problem 2:** A partially downloaded / corrupted `base.en-decoder.int8.onnx` file (~33 MB instead of ~130 MB) caused an unhandled C++ `Ort::Exception: Protobuf parsing failed` during synchronous `onCreate` initialization.
  - **Resolution:**
    1. Implemented atomic file downloads in `ModelDownloadManager` (`.tmp` files with byte length validation before renaming).
    2. Added `.complete` marker file tracking.
    3. Moved Sherpa ONNX model loading to background `Dispatchers.IO` thread in `MainActivity`.
- **Problem 3 (Stop Recording Crash):** When tapping Stop / Done, JNI called `OfflineRecognizer.getResult()`. The native C++ library (`libsherpa-onnx-jni.so`) looked up `OfflineRecognizerResult` with a 7-parameter constructor: `(String, String[], float[], String, String, String, float[])`. Because `OfflineRecognizerResult` had an 8th parameter (`words: IntArray = IntArray(0)`) without `@JvmOverloads`, JNI threw `NoSuchMethodError` and aborted.
  - **Resolution:** Added `@JvmOverloads` to `OfflineRecognizerResult`, generating the exact 7-parameter JVM constructor required by Sherpa ONNX JNI. Also added proper `.release()` cleanup for native `OfflineStream` instances.
- **Status:** App builds, installs, runs, and transcribes voice recordings without crashing.
