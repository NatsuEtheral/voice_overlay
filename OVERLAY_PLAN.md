# Implementation Plan: Floating Voice Overlay & Ambient Dictation

**Target:** Android Floating Bubble Dictation with On-Device Whisper Base STT  
**Repo:** `https://github.com/NatsuEtheral/voice_overlay.git`

---

## 1. Streaming vs. Push-to-Talk (The Truth About Whisper on Mobile)

### Can we do real-time streaming with Whisper?
* **Whisper's Architecture:** Whisper is an **encoder-decoder transformer** designed for full audio chunks (with attention across the entire utterance). It is not natively a streaming CTC or RNN-T model.
* **The "Pseudo-Streaming" Problem:** To stream Whisper, you must re-encode and re-decode audio every 1.5–2 seconds. On a mobile CPU (like Snapdragon 7 Gen 3 on the OnePlus Nord CE4):
  1. Each pass takes ~300ms–500ms of 100% CPU time.
  2. Running this continuously while the user is talking drains battery and creates thermal throttling.
  3. Whisper frequently hallucinates or duplicates words at artificial chunk boundaries (e.g., repeating the last two words of every chunk).
* **The Winning Solution (Short-Burst Batch with 120Hz Visualizer):**
  * When speaking: The user sees a fluid 120Hz dynamic audio waveform and timer (low CPU, ~2% battery).
  * When done (Tap Stop): Whisper Base transcribes a 5-second voice sentence in **under 0.8 seconds**.
  * **Result:** The user gets complete sentence accuracy, proper capitalization, smart punctuation, and zero battery drain.

---

## 2. Floating Window States & UI Design

Using `flutter_overlay_window`, the overlay runs a native Android floating window above all apps (WhatsApp, Slack, Chrome, Instagram):

```
State 1: COLLAPSED (Idle)
┌──────┐
│  🎙️  │  (Draggable 60x60dp bubble snapped to screen edge)
└──────┘

State 2: RECORDING (Tap on bubble)
┌──────────────────────────────────────────────┐
│ 🔴 00:04   |||||||!||||||||!||||   [ ■ STOP ] │  (Expands to 260x64dp pill)
└──────────────────────────────────────────────┘

State 3: RESULT & ACTIONS (Transcribed & Polished)
┌──────────────────────────────────────────────┐
│ "Let's meet up at the cafe around 5:30."     │
│ ───────────────────────────────────────────  │
│ [📋 Copied!]  [💾 Save Note]  [✕ Close]      │  (Expands to 300x150dp card)
└──────────────────────────────────────────────┘
```

---

## 3. Text Injection: Getting Text into the Chatbox

We use a two-tier approach:

### Tier 1: Instant Clipboard + Keyboard Suggestion Strip (Zero Extra Permission)
* When transcription completes, the text is immediately copied to `Clipboard.setData()`.
* **The Magic of Modern Keyboards:** Gboard, Samsung Keyboard, and SwiftKey automatically detect when text was copied and **display the text as a 1-tap chip directly above the keyboard**.
* The user simply taps the chip and the entire message is in WhatsApp's chatbox.

### Tier 2: Direct Auto-Paste via Android Accessibility Service (Optional Convenience)
* If the user enables the optional Accessibility Service for the app in Android Settings:
* The overlay detects the currently focused input box on screen (`AccessibilityNodeInfo`) and performs `ACTION_SET_TEXT` or `ACTION_PASTE`.
* The text appears in WhatsApp **with zero additional taps**.

---

## 4. "Clean Speech" Engine (Filler-Word Stripper)

When users speak lazily, conversational tics degrade readability. The "Clean Speech" pipeline applies intelligent rule-based cleaning before outputting:

* **Strips filler words:** Removes *"um"*, *"uh"*, *"err"*, *"ah"*, *"like"* (when used as filler between pauses), *"you know"*, *"sort of"*.
* **Deduplicates repeated words:** *"I I was thinking"* $\rightarrow$ *"I was thinking"*.
* **Sentence Polish:** Capitalizes first letter, adds trailing period or question mark, fixes spacing around commas.
* **Toggle:** A simple toggle in the overlay (`Clean: ON / OFF`) so users can keep exact speech if desired.

---

## 5. Android Quick Settings Tile (`TileService`)

To make the overlay feel built into the operating system:
* Implement an Android `TileService` (`VoiceDictationTileService`).
* When the user pulls down the Android notification shade:
  * Tap **"Voice Dictation"** tile $\rightarrow$ Instantly summons the floating bubble.
  * Tap again $\rightarrow$ Dismisses the bubble.
* No need to open the main app just to start dictating.

---

## 6. Phased Implementation Roadmap

1. **Phase 1: Overlay Permissions & Core Service**
   * Add `SYSTEM_ALERT_WINDOW` & foreground service permissions in `AndroidManifest.xml`.
   * Add `flutter_overlay_window` dependency.
   * Create `@pragma('vm:entry-point') void overlayMain()`.
2. **Phase 2: Floating Bubble UI (3 States)**
   * Collapsed draggable bubble $\rightarrow$ Recording pill with audio visualizer $\rightarrow$ Result card.
   * Auto-resize window using `FlutterOverlayWindow.resizeOverlay(...)`.
3. **Phase 3: Audio & STT Integration in Overlay**
   * Share Whisper model state / audio recording between main engine and overlay.
   * Integrate "Clean Speech" post-processing filter.
4. **Phase 4: Quick Settings Tile & Clipboard Pipeline**
   * Android `TileService` integration.
   * Auto-copy + haptic feedback + toast notification.
