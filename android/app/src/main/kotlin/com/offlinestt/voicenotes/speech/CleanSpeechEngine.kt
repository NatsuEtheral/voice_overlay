package com.offlinestt.voicenotes.speech

object CleanSpeechEngine {

    private val fillerWordsRegex = Regex(
        "\\b(um+|uh+|er+|ah+|like|you know|i mean|sort of|kind of)\\b",
        RegexOption.IGNORE_CASE
    )

    private val stutterRegex = Regex(
        "\\b(\\w+)\\s+\\1\\b",
        RegexOption.IGNORE_CASE
    )

    fun clean(text: String, enabled: Boolean = true): String {
        if (!enabled || text.isBlank()) return text.trim()

        var result = text

        // 1. Remove filler words
        result = fillerWordsRegex.replace(result, "")

        // 2. Remove repeated stutter words (e.g., "the the" -> "the")
        result = stutterRegex.replace(result, "$1")

        // 3. Clean up multiple whitespaces
        result = result.replace(Regex("\\s+"), " ").trim()

        // 4. Clean stray commas before punctuation
        result = result.replace(Regex(",\\s*([.?!])"), "$1")
        result = result.replace(Regex(",\\s*,"), ",")

        // 5. Capitalize first letter of sentences
        result = result.replace(Regex("(^|[.?!]\\s+)([a-z])")) { match ->
            match.groupValues[1] + match.groupValues[2].uppercase()
        }

        // 6. Ensure ending punctuation if reasonable length
        if (result.isNotEmpty() && !result.endsWith(".") && !result.endsWith("?") && !result.endsWith("!")) {
            result += "."
        }

        return result
    }
}
