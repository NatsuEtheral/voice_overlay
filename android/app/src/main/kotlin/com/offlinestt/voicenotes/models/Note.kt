package com.offlinestt.voicenotes.models

import java.util.UUID

data class Note(
    val id: String = UUID.randomUUID().toString(),
    val title: String = "",
    val content: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val tags: List<String> = emptyList(),
    val isPinned: Boolean = false,
    val audioPath: String? = null,
    val durationMs: Long = 0L,
)
