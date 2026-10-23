package com.offlinestt.voicenotes

import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.annotation.RequiresApi
import com.offlinestt.voicenotes.overlay.VoiceOverlayService

@RequiresApi(Build.VERSION_CODES.N)
class VoiceTileService : TileService() {

    override fun onClick() {
        super.onClick()

        val serviceIntent = Intent(this, VoiceOverlayService::class.java)
        if (VoiceOverlayService.isRunning) {
            stopService(serviceIntent)
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        }
        updateTileState()
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTileState()
    }

    private fun updateTileState() {
        val tile = qsTile ?: return
        val active = VoiceOverlayService.isRunning

        tile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.label = if (active) "Voice: Active" else "Voice Dictation"
        tile.updateTile()
    }
}
