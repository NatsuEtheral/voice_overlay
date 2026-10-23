package com.offlinestt.voicenotes.data

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class UserPreferences private constructor(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("voice_notes_prefs", Context.MODE_PRIVATE)

    private val _activeSttModelId = MutableStateFlow(
        prefs.getString(KEY_ACTIVE_STT_MODEL, "stt_whisper_base_en") ?: "stt_whisper_base_en"
    )
    val activeSttModelId: StateFlow<String> = _activeSttModelId.asStateFlow()

    private val _cleanSpeechEnabled = MutableStateFlow(
        prefs.getBoolean(KEY_CLEAN_SPEECH, true)
    )
    val cleanSpeechEnabled: StateFlow<Boolean> = _cleanSpeechEnabled.asStateFlow()

    private val _autoCopyToClipboard = MutableStateFlow(
        prefs.getBoolean(KEY_AUTO_COPY, true)
    )
    val autoCopyToClipboard: StateFlow<Boolean> = _autoCopyToClipboard.asStateFlow()

    private val _isOverlayActive = MutableStateFlow(
        prefs.getBoolean(KEY_OVERLAY_ACTIVE, false)
    )
    val isOverlayActive: StateFlow<Boolean> = _isOverlayActive.asStateFlow()

    companion object {
        private const val KEY_ACTIVE_STT_MODEL = "active_stt_model"
        private const val KEY_CLEAN_SPEECH = "clean_speech"
        private const val KEY_AUTO_COPY = "auto_copy"
        private const val KEY_OVERLAY_ACTIVE = "overlay_active"

        @Volatile
        private var instance: UserPreferences? = null

        fun getInstance(context: Context): UserPreferences {
            return instance ?: synchronized(this) {
                instance ?: UserPreferences(context.applicationContext).also { instance = it }
            }
        }
    }

    fun setActiveSttModelId(modelId: String) {
        prefs.edit().putString(KEY_ACTIVE_STT_MODEL, modelId).apply()
        _activeSttModelId.value = modelId
    }

    fun setCleanSpeechEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_CLEAN_SPEECH, enabled).apply()
        _cleanSpeechEnabled.value = enabled
    }

    fun setAutoCopyToClipboard(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_AUTO_COPY, enabled).apply()
        _autoCopyToClipboard.value = enabled
    }

    fun setOverlayActive(active: Boolean) {
        prefs.edit().putBoolean(KEY_OVERLAY_ACTIVE, active).apply()
        _isOverlayActive.value = active
    }
}
