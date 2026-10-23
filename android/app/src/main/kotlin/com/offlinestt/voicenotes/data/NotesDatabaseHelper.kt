package com.offlinestt.voicenotes.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.offlinestt.voicenotes.models.Note
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.json.JSONArray

class NotesDatabaseHelper private constructor(context: Context) :
    SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    private val scope = CoroutineScope(Dispatchers.IO)
    private val _notesFlow = MutableStateFlow<List<Note>>(emptyList())
    val notesFlow: StateFlow<List<Note>> = _notesFlow.asStateFlow()

    companion object {
        private const val DATABASE_NAME = "offline_voice_notes.db"
        private const val DATABASE_VERSION = 1
        private const val TABLE_NOTES = "notes"

        private const val COL_ID = "id"
        private const val COL_TITLE = "title"
        private const val COL_CONTENT = "content"
        private const val COL_CREATED_AT = "created_at"
        private const val COL_UPDATED_AT = "updated_at"
        private const val COL_TAGS = "tags"
        private const val COL_IS_PINNED = "is_pinned"
        private const val COL_AUDIO_PATH = "audio_path"
        private const val COL_DURATION_MS = "duration_ms"

        @Volatile
        private var instance: NotesDatabaseHelper? = null

        fun getInstance(context: Context): NotesDatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: NotesDatabaseHelper(context.applicationContext).also {
                    instance = it
                    it.refreshNotes()
                }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTable = """
            CREATE TABLE $TABLE_NOTES (
                $COL_ID TEXT PRIMARY KEY,
                $COL_TITLE TEXT NOT NULL,
                $COL_CONTENT TEXT NOT NULL,
                $COL_CREATED_AT INTEGER NOT NULL,
                $COL_UPDATED_AT INTEGER NOT NULL,
                $COL_TAGS TEXT NOT NULL,
                $COL_IS_PINNED INTEGER NOT NULL DEFAULT 0,
                $COL_AUDIO_PATH TEXT,
                $COL_DURATION_MS INTEGER NOT NULL DEFAULT 0
            )
        """.trimIndent()
        db.execSQL(createTable)
        db.execSQL("CREATE INDEX idx_notes_created ON $TABLE_NOTES ($COL_CREATED_AT DESC)")
        db.execSQL("CREATE INDEX idx_notes_pinned ON $TABLE_NOTES ($COL_IS_PINNED DESC)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_NOTES")
        onCreate(db)
    }

    fun refreshNotes() {
        scope.launch {
            _notesFlow.value = getAllNotes()
        }
    }

    fun getAllNotes(): List<Note> {
        val notes = mutableListOf<Note>()
        val db = readableDatabase
        val query = "SELECT * FROM $TABLE_NOTES ORDER BY $COL_IS_PINNED DESC, $COL_UPDATED_AT DESC"
        val cursor = db.rawQuery(query, null)
        cursor.use {
            while (it.moveToNext()) {
                notes.add(cursorToNote(it))
            }
        }
        return notes
    }

    fun getNoteById(id: String): Note? {
        val db = readableDatabase
        val cursor = db.query(
            TABLE_NOTES,
            null,
            "$COL_ID = ?",
            arrayOf(id),
            null,
            null,
            null
        )
        return cursor.use {
            if (it.moveToFirst()) cursorToNote(it) else null
        }
    }

    fun insertNote(note: Note) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COL_ID, note.id)
            put(COL_TITLE, note.title)
            put(COL_CONTENT, note.content)
            put(COL_CREATED_AT, note.createdAt)
            put(COL_UPDATED_AT, note.updatedAt)
            put(COL_TAGS, JSONArray(note.tags).toString())
            put(COL_IS_PINNED, if (note.isPinned) 1 else 0)
            put(COL_AUDIO_PATH, note.audioPath)
            put(COL_DURATION_MS, note.durationMs)
        }
        db.insertWithOnConflict(TABLE_NOTES, null, values, SQLiteDatabase.CONFLICT_REPLACE)
        refreshNotes()
    }

    fun updateNote(note: Note) {
        val db = writableDatabase
        val values = ContentValues().apply {
            put(COL_TITLE, note.title)
            put(COL_CONTENT, note.content)
            put(COL_UPDATED_AT, System.currentTimeMillis())
            put(COL_TAGS, JSONArray(note.tags).toString())
            put(COL_IS_PINNED, if (note.isPinned) 1 else 0)
            put(COL_AUDIO_PATH, note.audioPath)
            put(COL_DURATION_MS, note.durationMs)
        }
        db.update(TABLE_NOTES, values, "$COL_ID = ?", arrayOf(note.id))
        refreshNotes()
    }

    fun deleteNote(id: String) {
        val db = writableDatabase
        db.delete(TABLE_NOTES, "$COL_ID = ?", arrayOf(id))
        refreshNotes()
    }

    fun togglePin(id: String) {
        val note = getNoteById(id) ?: return
        updateNote(note.copy(isPinned = !note.isPinned))
    }

    private fun cursorToNote(cursor: android.database.Cursor): Note {
        val tagsJson = cursor.getString(cursor.getColumnIndexOrThrow(COL_TAGS))
        val tags = mutableListOf<String>()
        try {
            val jsonArray = JSONArray(tagsJson)
            for (i in 0 until jsonArray.length()) {
                tags.add(jsonArray.getString(i))
            }
        } catch (_: Exception) {}

        return Note(
            id = cursor.getString(cursor.getColumnIndexOrThrow(COL_ID)),
            title = cursor.getString(cursor.getColumnIndexOrThrow(COL_TITLE)),
            content = cursor.getString(cursor.getColumnIndexOrThrow(COL_CONTENT)),
            createdAt = cursor.getLong(cursor.getColumnIndexOrThrow(COL_CREATED_AT)),
            updatedAt = cursor.getLong(cursor.getColumnIndexOrThrow(COL_UPDATED_AT)),
            tags = tags,
            isPinned = cursor.getInt(cursor.getColumnIndexOrThrow(COL_IS_PINNED)) == 1,
            audioPath = cursor.getString(cursor.getColumnIndexOrThrow(COL_AUDIO_PATH)),
            durationMs = cursor.getLong(cursor.getColumnIndexOrThrow(COL_DURATION_MS))
        )
    }
}
