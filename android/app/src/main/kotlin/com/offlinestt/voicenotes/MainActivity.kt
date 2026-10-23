package com.offlinestt.voicenotes

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import com.offlinestt.voicenotes.data.ModelDownloadManager
import com.offlinestt.voicenotes.data.UserPreferences
import com.offlinestt.voicenotes.models.SpeechModelType
import com.offlinestt.voicenotes.models.defaultModelCatalog
import com.offlinestt.voicenotes.overlay.VoiceOverlayService
import com.offlinestt.voicenotes.speech.SherpaOnnxManager
import com.offlinestt.voicenotes.ui.screens.HomeScreen
import com.offlinestt.voicenotes.ui.screens.ModelManagerScreen
import com.offlinestt.voicenotes.ui.screens.NoteEditorScreen
import com.offlinestt.voicenotes.ui.theme.BackgroundDark
import com.offlinestt.voicenotes.ui.theme.VoiceNotesTheme

sealed class Screen {
    object Home : Screen()
    data class NoteEditor(val noteId: String? = null) : Screen()
    object ModelManager : Screen()
}

class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        // Permissions handled
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Enable 120Hz High Refresh Rate on supported devices
        enableHighRefreshRate()

        // Request runtime permissions (Audio & Notifications)
        requestAppPermissions()

        // Auto-download default Whisper Base model on first install if not present
        ensureDefaultModelAvailable()

        handleIntent(intent)

        setContent {
            VoiceNotesTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = BackgroundDark
                ) {
                    var currentScreen by remember { mutableStateOf<Screen>(Screen.Home) }

                    AnimatedContent(
                        targetState = currentScreen,
                        transitionSpec = { fadeIn() togetherWith fadeOut() },
                        label = "ScreenTransition"
                    ) { screen ->
                        when (screen) {
                            is Screen.Home -> {
                                HomeScreen(
                                    onNoteClick = { noteId ->
                                        currentScreen = Screen.NoteEditor(noteId)
                                    },
                                    onCreateNoteClick = {
                                        currentScreen = Screen.NoteEditor(null)
                                    },
                                    onOpenModelManager = {
                                        currentScreen = Screen.ModelManager
                                    }
                                )
                            }
                            is Screen.NoteEditor -> {
                                NoteEditorScreen(
                                    noteId = screen.noteId,
                                    onNavigateBack = {
                                        currentScreen = Screen.Home
                                    }
                                )
                            }
                            is Screen.ModelManager -> {
                                ModelManagerScreen(
                                    onNavigateBack = {
                                        currentScreen = Screen.Home
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("ACTION_TOGGLE_OVERLAY", false) == true) {
            val serviceIntent = Intent(this, VoiceOverlayService::class.java).apply {
                action = VoiceOverlayService.ACTION_TOGGLE_OVERLAY
            }
            startService(serviceIntent)
            intent.removeExtra("ACTION_TOGGLE_OVERLAY")
        }
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val display = display
            val supportedModes = display?.supportedModes ?: return
            val maxMode = supportedModes.maxByOrNull { it.refreshRate }
            if (maxMode != null && maxMode.refreshRate >= 90f) {
                window.attributes = window.attributes.apply {
                    preferredDisplayModeId = maxMode.modeId
                }
            }
        }
    }

    private fun requestAppPermissions() {
        val permissionsToRequest = mutableListOf<String>()

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permissionsToRequest.add(Manifest.permission.RECORD_AUDIO)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        if (permissionsToRequest.isNotEmpty()) {
            permissionLauncher.launch(permissionsToRequest.toTypedArray())
        }
    }

    private fun ensureDefaultModelAvailable() {
        val downloadManager = ModelDownloadManager.getInstance(this)
        val userPrefs = UserPreferences.getInstance(this)
        val defaultModel = defaultModelCatalog.firstOrNull { it.id == "stt_whisper_base_en" } ?: return

        if (!downloadManager.isModelDownloaded(defaultModel)) {
            downloadManager.downloadModel(defaultModel) { success ->
                if (success) {
                    SherpaOnnxManager.getInstance(this).initModel(defaultModel)
                    userPrefs.setActiveSttModelId(defaultModel.id)
                }
            }
        } else {
            SherpaOnnxManager.getInstance(this).initModel(defaultModel)
        }
    }
}
