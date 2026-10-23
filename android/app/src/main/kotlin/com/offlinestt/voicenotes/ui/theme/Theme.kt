package com.offlinestt.voicenotes.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val PrimaryIndigo = Color(0xFF6366F1)
val PrimaryIndigoLight = Color(0xFF818CF8)
val BackgroundDark = Color(0xFF0F1117)
val SurfaceDark = Color(0xFF161922)
val CardSurface = Color(0xFF1E222D)
val OutlineColor = Color(0xFF2E3446)
val TextPrimary = Color(0xFFF1F5F9)
val TextSecondary = Color(0xFF94A3B8)
val AccentRed = Color(0xFFEF4444)
val AccentGreen = Color(0xFF10B981)

private val DarkColorScheme = darkColorScheme(
    primary = PrimaryIndigo,
    onPrimary = Color.White,
    primaryContainer = Color(0xFF312E81),
    onPrimaryContainer = Color(0xFFE0E7FF),
    secondary = PrimaryIndigoLight,
    onSecondary = Color.Black,
    background = BackgroundDark,
    onBackground = TextPrimary,
    surface = SurfaceDark,
    onSurface = TextPrimary,
    surfaceVariant = CardSurface,
    onSurfaceVariant = TextSecondary,
    outline = OutlineColor
)

@Composable
fun VoiceNotesTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
