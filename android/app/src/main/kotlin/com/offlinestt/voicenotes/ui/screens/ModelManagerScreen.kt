package com.offlinestt.voicenotes.ui.screens

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.offlinestt.voicenotes.data.ModelDownloadManager
import com.offlinestt.voicenotes.data.UserPreferences
import com.offlinestt.voicenotes.models.SpeechModelInfo
import com.offlinestt.voicenotes.models.SpeechModelType
import com.offlinestt.voicenotes.speech.SherpaOnnxManager
import com.offlinestt.voicenotes.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModelManagerScreen(
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val downloadManager = remember { ModelDownloadManager.getInstance(context) }
    val userPrefs = remember { UserPreferences.getInstance(context) }
    val sherpa = remember { SherpaOnnxManager.getInstance(context) }

    val models by downloadManager.catalogFlow.collectAsState()
    val activeModelId by userPrefs.activeSttModelId.collectAsState()
    val cleanSpeechEnabled by userPrefs.cleanSpeechEnabled.collectAsState()
    val autoCopyEnabled by userPrefs.autoCopyToClipboard.collectAsState()

    // Calculate total disk usage
    val totalStorageUsageMb = remember(models) {
        val dir = downloadManager.modelsDir
        if (dir.exists()) {
            val bytes = dir.walkTopDown().filter { it.isFile }.map { it.length() }.sum()
            bytes.toDouble() / (1024.0 * 1024.0)
        } else 0.0
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Speech Models & Settings", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = BackgroundDark)
            )
        },
        containerColor = BackgroundDark
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(16.dp)
        ) {
            // Storage Summary Card
            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = CardSurface)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Storage, contentDescription = null, tint = PrimaryIndigoLight, modifier = Modifier.size(28.dp))
                        Spacer(modifier = Modifier.width(14.dp))
                        Column {
                            Text("Offline Models Storage", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 15.sp)
                            Text(
                                String.format("%.1f MB used on device", totalStorageUsageMb),
                                color = TextSecondary,
                                fontSize = 13.sp
                            )
                        }
                    }
                }
            }

            // Dictation Settings Section
            item {
                Text(
                    "DICTATION PREFERENCES",
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                    color = PrimaryIndigoLight,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }

            item {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = CardSurface)
                ) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        // Clean Speech Toggle
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Clean Speech Filter", fontWeight = FontWeight.SemiBold, color = Color.White, fontSize = 14.sp)
                                Text("Removes 'um', 'uh', stutters, and fixes punctuation", color = TextSecondary, fontSize = 12.sp)
                            }
                            Switch(
                                checked = cleanSpeechEnabled,
                                onCheckedChange = { userPrefs.setCleanSpeechEnabled(it) },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = Color.White,
                                    checkedTrackColor = PrimaryIndigo
                                )
                            )
                        }

                        Divider(modifier = Modifier.padding(vertical = 10.dp), color = OutlineColor)

                        // Auto-copy to Clipboard Toggle
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text("Auto-Copy to Clipboard", fontWeight = FontWeight.SemiBold, color = Color.White, fontSize = 14.sp)
                                Text("Copies text immediately for 1-tap pasting in chats", color = TextSecondary, fontSize = 12.sp)
                            }
                            Switch(
                                checked = autoCopyEnabled,
                                onCheckedChange = { userPrefs.setAutoCopyToClipboard(it) },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = Color.White,
                                    checkedTrackColor = PrimaryIndigo
                                )
                            )
                        }
                    }
                }
            }

            // STT Models Section
            item {
                Text(
                    "WHISPER SPEECH-TO-TEXT MODELS",
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                    color = PrimaryIndigoLight,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }

            val sttModels = models.filter { it.type == SpeechModelType.STT }
            items(sttModels, key = { it.id }) { model ->
                ModelItemCard(
                    model = model,
                    isSelected = model.id == activeModelId,
                    onSelect = {
                        userPrefs.setActiveSttModelId(model.id)
                        sherpa.initModel(model)
                        downloadManager.refreshDownloadStatus()
                        Toast.makeText(context, "Active model set to ${model.name}", Toast.LENGTH_SHORT).show()
                    },
                    onDownload = {
                        downloadManager.downloadModel(model) { success ->
                            if (success) {
                                userPrefs.setActiveSttModelId(model.id)
                                sherpa.initModel(model)
                            }
                        }
                    },
                    onDelete = {
                        downloadManager.deleteModel(model)
                    }
                )
            }

            // TTS Models Section
            item {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    "TEXT-TO-SPEECH (TTS) ENGINES",
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                    color = PrimaryIndigoLight,
                    modifier = Modifier.padding(vertical = 8.dp)
                )
            }

            val ttsModels = models.filter { it.type == SpeechModelType.TTS }
            items(ttsModels, key = { it.id }) { model ->
                ModelItemCard(
                    model = model,
                    isSelected = model.isSelected,
                    onSelect = {},
                    onDownload = {},
                    onDelete = {}
                )
            }
        }
    }
}

@Composable
fun ModelItemCard(
    model: SpeechModelInfo,
    isSelected: Boolean,
    onSelect: () -> Unit,
    onDownload: () -> Unit,
    onDelete: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 5.dp),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = CardSurface),
        border = CardDefaults.outlinedCardBorder().copy(
            brush = androidx.compose.ui.graphics.SolidColor(
                if (isSelected) PrimaryIndigo else OutlineColor
            ),
            width = if (isSelected) 1.5.dp else 1.dp
        )
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Radio button for selection
                if (model.isDownloaded) {
                    RadioButton(
                        selected = isSelected,
                        onClick = onSelect,
                        colors = RadioButtonDefaults.colors(
                            selectedColor = PrimaryIndigo,
                            unselectedColor = TextSecondary
                        )
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(24.dp)
                            .clip(CircleShape)
                            .background(SurfaceDark),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Default.CloudDownload, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(14.dp))
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                }

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        model.name,
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp,
                        color = Color.White
                    )
                    Text(
                        model.description,
                        fontSize = 12.sp,
                        color = TextSecondary,
                        lineHeight = 16.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(10.dp))

            // Specs Row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    model.formattedSize,
                    fontSize = 11.sp,
                    color = PrimaryIndigoLight,
                    fontWeight = FontWeight.Medium
                )

                Spacer(modifier = Modifier.width(12.dp))

                Text(
                    model.speedRating,
                    fontSize = 11.sp,
                    color = TextSecondary
                )

                Spacer(modifier = Modifier.weight(1f))

                // Actions: Download, Delete, or Active
                if (model.isDownloading) {
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            String.format("%.0f%%", model.downloadProgress * 100),
                            fontSize = 11.sp,
                            color = PrimaryIndigoLight,
                            fontWeight = FontWeight.Bold
                        )
                        LinearProgressIndicator(
                            progress = { model.downloadProgress },
                            color = PrimaryIndigo,
                            trackColor = SurfaceDark,
                            modifier = Modifier
                                .width(90.dp)
                                .height(4.dp)
                        )
                    }
                } else if (model.isDownloaded) {
                    if (isSelected) {
                        Text(
                            "ACTIVE",
                            fontWeight = FontWeight.Bold,
                            color = AccentGreen,
                            fontSize = 11.sp,
                            modifier = Modifier
                                .clip(RoundedCornerShape(6.dp))
                                .background(AccentGreen.copy(alpha = 0.15f))
                                .padding(horizontal = 8.dp, vertical = 3.dp)
                        )
                    } else if (!model.isDefaultBuiltIn) {
                        IconButton(onClick = onDelete, modifier = Modifier.size(28.dp)) {
                            Icon(Icons.Default.DeleteOutline, contentDescription = "Delete", tint = TextSecondary, modifier = Modifier.size(18.dp))
                        }
                    }
                } else {
                    FilledTonalButton(
                        onClick = onDownload,
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = PrimaryIndigo.copy(alpha = 0.2f),
                            contentColor = PrimaryIndigoLight
                        ),
                        shape = RoundedCornerShape(12.dp),
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                    ) {
                        Icon(Icons.Default.Download, contentDescription = null, modifier = Modifier.size(14.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Download", fontSize = 12.sp)
                    }
                }
            }
        }
    }
}
