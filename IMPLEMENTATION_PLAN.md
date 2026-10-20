# Implementation Plan: Offline Voice Notes App (Flutter)

**Project Name:** `VoiceNotes Offline` (working title)  
**Target Platforms:** Android (Primary initial target), iOS, Desktop (macOS/Windows/Linux ready)  
**Core Technologies:** Flutter, On-Device Whisper / ONNX Speech-to-Text, On-Device Neural / Native TTS, Local SQLite & Markdown Storage.

---

## 1. Project Overview & Objectives

The goal is to build a fast, privacy-first, local-only note-taking application in Flutter. The app allows users to create notes by typing or speaking, transcribes speech 100% on-device (zero cloud / zero server fees), offers downloadable models to balance accuracy vs. storage, and can read notes back using offline Text-to-Speech (TTS).

### Key Features for the Foundation (MVP)
1. **Local Notes Management:** Create, read, edit, delete, and search notes. Notes support title, content, timestamp, tags, and optional audio recording attachments.
2. **Model Downloader & Manager:** A dedicated settings screen where users can browse, download, delete, and switch between various on-device speech models (e.g., Whisper Tiny ~75MB, Whisper Base ~140MB, Piper TTS voices).
3. **Voice-to-Note (Offline STT):** Record audio directly inside the note editor, run local inference, and insert transcribed text into the note.
4. **Read Aloud (Offline TTS):** Play back note content using either the device's native offline TTS engine or a downloadable high-quality neural voice.
5. **100% Airplane Mode Verified:** Zero internet permissions required for note-taking and transcription (internet is only used when the user explicitly downloads a model).

---

## 2. Technical Stack & Dependencies

| Layer | Library / Tool | Justification |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.x (Dart)** | Cross-platform codebase (Android, iOS, Desktop), fast UI rendering, rich audio ecosystem. |
| **Unified STT & TTS Engine** | **`sherpa_onnx`** | High-performance C++/Dart bindings for ONNX Runtime. Provides both offline Whisper/Moonshine STT **and** Piper/VITS TTS in one unified library without needing separate heavy engines. |
| **Native Fallback TTS** | **`flutter_tts`** | Leverages built-in Android/iOS offline speech synthesis engines so TTS works immediately with 0MB download. |
| **Audio Recording** | **`record`** | High-quality, cross-platform audio recording. Directly records to 16kHz 16-bit mono WAV (the native format required by Whisper). |
| **Audio Playback** | **`audioplayers`** | Plays recorded voice memos and synthesized speech. |
| **Local Database** | **`sqflite` + `path_provider`** | Reliable, local SQLite database for note metadata and search. Content and audio clips stored locally on disk. |
| **Model Downloader** | **`dio`** | Robust HTTP client supporting chunked downloads, progress percentages, and pause/resume. |
| **State Management** | **`flutter_riverpod`** | Clean, testable, reactive state management for model loading, audio states, and note data. |

---

## 3. Architecture & Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                       Flutter UI Layer                      │
│  [Note List Screen]  [Note Editor Screen]  [Model Manager]   │
└──────────────┬──────────────────┬─────────────────┬─────────┘
               │                  │                 │
┌──────────────▼──────────────────▼─────────────────▼─────────┐
│                     Service / Provider Layer                │
│  ┌──────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │   NotesService   │  │  ModelManager  │  │ AudioService │ │
│  │    (SQLite)      │  │  (Downloader)  │  │(Record/Play) │ │
│  └──────────────────┘  └────────────────┘  └──────────────┘ │
└──────────────┬──────────────────┬─────────────────┬─────────┘
               │                  │                 │
┌──────────────▼──────┐  ┌────────▼───────┐  ┌──────▼─────────┐
│ Local App Storage   │  │ sherpa_onnx    │  │ Native TTS     │
│ - notes.db          │  │ - Whisper Tiny │  │ - Android TTS  │
│ - notes/*.md        │  │ - Piper Voices │  │ - iOS Spoken   │
│ - models/*.onnx     │  │ (CPU Inference)│  │   Content      │
└─────────────────────┘  └────────────────┘  └────────────────┘
```

---

## 4. Phased Implementation Roadmap

### Phase 1: Environment Setup & Project Initialization
- Check/install Flutter SDK (Android Studio and Android SDK are already configured on the machine).
- Initialize Flutter project in `/Users/hussain/Projects/OfflineSTT_TTS`.
- Configure Android permissions:
  * `RECORD_AUDIO` (microphone access)
  * `INTERNET` (used strictly for downloading model files from Hugging Face / GitHub releases)
  * `FOREGROUND_SERVICE` (prevents OS from killing transcription mid-inference)
- Set up project structure (`lib/models`, `lib/services`, `lib/views`, `lib/providers`).

### Phase 2: Local Notes Storage & UI Foundation
- Create Note data model:
  ```dart
  class Note {
    final String id;
    String title;
    String content;
    DateTime createdAt;
    DateTime updatedAt;
    String? audioPath; // Path to recorded audio file if kept
    List<String> tags;
  }
  ```
- Implement `NotesDatabase` using SQLite.
- Build clean Material 3 UI:
  * **HomeScreen:** List of notes with search bar, tag filter, and Floating Action Button (New Note).
  * **NoteEditorScreen:** Title field, multi-line content field, formatting toolbar, and bottom recording/listening bar.

### Phase 3: Model Downloader & Storage Management
- Define available model catalog (hosted on Hugging Face / GitHub releases):
  1. **Whisper Tiny (Quantized int8):** ~40MB–75MB (Super fast, best for older devices, low battery usage).
  2. **Whisper Base (Quantized int8):** ~140MB (Higher accuracy, good for standard conversations).
  3. **SenseVoice Small / Moonshine:** ~80MB–150MB (Ultra-fast real-time edge STT).
  4. **Piper TTS Voice (en_US):** ~25MB (Natural sounding offline neural voice).
- Build `ModelManagerView`:
  * List available models with download sizes, descriptions, and recommended device specs.
  * Download progress bar (MB downloaded, percentage, download speed).
  * Ability to delete downloaded models to free up phone storage.
  * Active model selector (sets default model for STT and TTS).

### Phase 4: Voice-to-Note (Offline STT Engine)
- Audio capture pipeline:
  * User taps the **Mic button** in `NoteEditorScreen`.
  * Audio is recorded as 16,000 Hz, 16-bit Mono PCM `.wav`.
  * Visual recording indicator (waveform / pulsing timer).
- Inference pipeline:
  * User taps **Stop**.
  * Audio file is fed into the active on-device Whisper model via `sherpa_onnx`.
  * Inference completes on CPU (typically 1–3 seconds for a 10-second memo).
  * Transcribed text is automatically inserted at cursor position or appended to the note.
  * Light post-processing: auto-capitalization and trailing punctuation.

### Phase 5: Read-Aloud (Offline TTS Engine)
- Add a **Speaker button** to the note toolbar.
- Quick Mode: Uses `flutter_tts` (built-in Android/iOS offline voice) for instant playback without needing extra model downloads.
- Neural Mode: Uses downloaded `Piper` voice model for human-like natural speech synthesis.
- Playback controls: Play, Pause, Stop, and Playback Speed slider (0.75x, 1.0x, 1.25x, 1.5x).

### Phase 6: Polish, Testing & Verification
- Test in **100% Airplane Mode** (verify notes, STT, and TTS all execute with Wi-Fi & cellular disabled).
- Benchmark CPU usage and memory footprint on Android device.
- Add simple export (Share note as Plain Text / Markdown / Audio file).

---

## 5. Review & Approval Checklist

Before we start coding:
- [ ] Confirm the choice of **Flutter** for the initial build.
- [ ] Confirm the choice of **`sherpa_onnx`** (supports both Whisper STT and Piper TTS locally).
- [ ] Confirm the scope of **Phase 1 & Phase 2** as the first development sprint.
