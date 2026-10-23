package com.offlinestt.voicenotes.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
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
import com.offlinestt.voicenotes.data.NotesDatabaseHelper
import com.offlinestt.voicenotes.data.UserPreferences
import com.offlinestt.voicenotes.models.Note
import com.offlinestt.voicenotes.speech.AudioRecordManager
import com.offlinestt.voicenotes.speech.CleanSpeechEngine
import com.offlinestt.voicenotes.speech.SherpaOnnxManager
import com.offlinestt.voicenotes.speech.TtsEngine
import com.offlinestt.voicenotes.ui.theme.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteEditorScreen(
    noteId: String?,
    onNavigateBack: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val db = remember { NotesDatabaseHelper.getInstance(context) }
    val userPrefs = remember { UserPreferences.getInstance(context) }
    val audioRecorder = remember { AudioRecordManager.getInstance(context) }
    val sherpa = remember { SherpaOnnxManager.getInstance(context) }
    val tts = remember { TtsEngine.getInstance(context) }

    var existingNote by remember { mutableStateOf<Note?>(null) }
    var title by remember { mutableStateOf("") }
    var content by remember { mutableStateOf("") }
    var tags by remember { mutableStateOf<List<String>>(emptyList()) }
    var isPinned by remember { mutableStateOf(false) }

    var isRecording by remember { mutableStateOf(false) }
    var isTranscribing by remember { mutableStateOf(false) }
    var isSpeaking by remember { mutableStateOf(false) }
    var showAddTagDialog by remember { mutableStateOf(false) }
    var newTagText by remember { mutableStateOf("") }

    val amplitude by audioRecorder.amplitudeFlow.collectAsState()

    // Load existing note if editing
    LaunchedEffect(noteId) {
        if (!noteId.isNullOrBlank()) {
            val note = db.getNoteById(noteId)
            if (note != null) {
                existingNote = note
                title = note.title
                content = note.content
                tags = note.tags
                isPinned = note.isPinned
            }
        }
    }

    fun saveNote() {
        val noteToSave = Note(
            id = existingNote?.id ?: java.util.UUID.randomUUID().toString(),
            title = title.ifBlank { if (content.isNotBlank()) content.take(30) + "..." else "Untitled Note" },
            content = content,
            createdAt = existingNote?.createdAt ?: System.currentTimeMillis(),
            updatedAt = System.currentTimeMillis(),
            tags = tags,
            isPinned = isPinned,
            audioPath = existingNote?.audioPath,
            durationMs = existingNote?.durationMs ?: 0L
        )
        if (existingNote == null) {
            db.insertNote(noteToSave)
        } else {
            db.updateNote(noteToSave)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (existingNote == null) "New Note" else "Edit Note", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = {
                        saveNote()
                        onNavigateBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }
                },
                actions = {
                    // Pin toggle
                    IconButton(onClick = { isPinned = !isPinned }) {
                        Icon(
                            Icons.Default.PushPin,
                            contentDescription = "Pin",
                            tint = if (isPinned) PrimaryIndigoLight else TextSecondary
                        )
                    }

                    // Listen (TTS)
                    IconButton(onClick = {
                        if (isSpeaking) {
                            tts.stop()
                            isSpeaking = false
                        } else {
                            if (content.isNotBlank()) {
                                tts.speak(content)
                                isSpeaking = true
                            }
                        }
                    }) {
                        Icon(
                            if (isSpeaking) Icons.Default.VolumeOff else Icons.Default.VolumeUp,
                            contentDescription = "Read Aloud",
                            tint = if (isSpeaking) AccentRed else Color.White
                        )
                    }

                    // Copy content
                    IconButton(onClick = {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("Note Content", content))
                        Toast.makeText(context, "Copied note to clipboard", Toast.LENGTH_SHORT).show()
                    }) {
                        Icon(Icons.Default.ContentCopy, contentDescription = "Copy", tint = Color.White)
                    }

                    // Delete (if existing)
                    if (existingNote != null) {
                        IconButton(onClick = {
                            db.deleteNote(existingNote!!.id)
                            onNavigateBack()
                        }) {
                            Icon(Icons.Default.DeleteOutline, contentDescription = "Delete", tint = AccentRed)
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = BackgroundDark)
            )
        },
        bottomBar = {
            // In-Editor Dictation Bottom Bar
            Surface(
                color = CardSurface,
                tonalElevation = 8.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (isRecording) {
                        // Pulsing red indicator & recording status
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .clip(CircleShape)
                                .background(AccentRed)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Listening...", color = AccentRed, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                        Spacer(modifier = Modifier.weight(1f))

                        Button(
                            onClick = {
                                isRecording = false
                                isTranscribing = true
                                val wav = audioRecorder.stopRecording()

                                scope.launch {
                                    if (wav != null && wav.exists()) {
                                        val rawText = sherpa.transcribeWavFile(wav)
                                        val isClean = userPrefs.cleanSpeechEnabled.value
                                        val polished = CleanSpeechEngine.clean(rawText, enabled = isClean)
                                        if (polished.isNotBlank()) {
                                            content = if (content.isBlank()) polished else "$content $polished"
                                        }
                                    }
                                    isTranscribing = false
                                }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = PrimaryIndigo),
                            shape = RoundedCornerShape(20.dp)
                        ) {
                            Icon(Icons.Default.Stop, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Done")
                        }
                    } else if (isTranscribing) {
                        CircularProgressIndicator(
                            color = PrimaryIndigo,
                            strokeWidth = 2.dp,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(10.dp))
                        Text("Whisper transcribing speech...", color = Color.White, fontSize = 13.sp)
                    } else {
                        // Dictate button
                        FilledTonalButton(
                            onClick = {
                                val started = audioRecorder.startRecording()
                                if (started) {
                                    isRecording = true
                                } else {
                                    Toast.makeText(context, "Microphone permission required", Toast.LENGTH_SHORT).show()
                                }
                            },
                            colors = ButtonDefaults.filledTonalButtonColors(
                                containerColor = PrimaryIndigo.copy(alpha = 0.2f),
                                contentColor = PrimaryIndigoLight
                            ),
                            shape = RoundedCornerShape(20.dp)
                        ) {
                            Icon(Icons.Default.Mic, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text("Tap to Dictate")
                        }

                        Spacer(modifier = Modifier.weight(1f))

                        // Add Tag Button
                        TextButton(onClick = { showAddTagDialog = true }) {
                            Icon(Icons.Default.Label, contentDescription = null, modifier = Modifier.size(16.dp), tint = TextSecondary)
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Tag", color = TextSecondary)
                        }
                    }
                }
            }
        },
        containerColor = BackgroundDark
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 20.dp, vertical = 8.dp)
        ) {
            // Title Field
            TextField(
                value = title,
                onValueChange = { title = it },
                placeholder = { Text("Title", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = OutlineColor) },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White
                ),
                textStyle = LocalTextStyle.current.copy(fontSize = 24.sp, fontWeight = FontWeight.Bold),
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )

            // Tags Carousel
            if (tags.isNotEmpty()) {
                LazyRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    items(tags) { tag ->
                        InputChip(
                            selected = true,
                            onClick = { tags = tags.filter { it != tag } },
                            label = { Text("#$tag", fontSize = 12.sp) },
                            trailingIcon = {
                                Icon(Icons.Default.Close, contentDescription = "Remove Tag", modifier = Modifier.size(14.dp))
                            },
                            colors = InputChipDefaults.inputChipColors(
                                selectedContainerColor = SurfaceDark,
                                selectedLabelColor = PrimaryIndigoLight
                            )
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Content Body Field
            TextField(
                value = content,
                onValueChange = { content = it },
                placeholder = { Text("Type your note or use the microphone button below to dictate offline...", color = OutlineColor) },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary
                ),
                textStyle = LocalTextStyle.current.copy(fontSize = 16.sp, lineHeight = 24.sp),
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
            )
        }
    }

    // Add Tag Dialog
    if (showAddTagDialog) {
        AlertDialog(
            onDismissRequest = { showAddTagDialog = false },
            title = { Text("Add Tag") },
            text = {
                OutlinedTextField(
                    value = newTagText,
                    onValueChange = { newTagText = it },
                    placeholder = { Text("e.g. ideas, work, meeting") },
                    singleLine = true
                )
            },
            confirmButton = {
                Button(onClick = {
                    val trimmed = newTagText.trim().removePrefix("#")
                    if (trimmed.isNotBlank() && !tags.contains(trimmed)) {
                        tags = tags + trimmed
                    }
                    newTagText = ""
                    showAddTagDialog = false
                }) {
                    Text("Add")
                }
            },
            dismissButton = {
                TextButton(onClick = { showAddTagDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
