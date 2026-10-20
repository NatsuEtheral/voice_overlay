class CleanSpeechService {
  static final CleanSpeechService instance = CleanSpeechService._internal();
  CleanSpeechService._internal();

  /// Filler words that add no semantic value
  static final List<RegExp> _fillerWordPatterns = [
    RegExp(r'\b(um|uh|err|erm|ah|umm|uhh)\b[,.]?', caseSensitive: false),
    RegExp(r'\b(you know|i mean|sort of|kind of)\b,?', caseSensitive: false),
    // "like" when used as filler (e.g., ", like, " or at sentence start)
    RegExp(r'(^|\s),\s*like\s*,', caseSensitive: false),
    RegExp(r'^\s*like\s+', caseSensitive: false),
  ];

  /// Regex to detect stuttered/duplicated consecutive words (e.g., "I I", "we we")
  static final RegExp _duplicateWordsPattern = RegExp(
    r'\b([a-zA-Z]+)\s+\1\b',
    caseSensitive: false,
  );

  /// Cleans raw transcribed speech by removing verbal tics, stuttering, and fixing punctuation
  String clean(String rawText, {bool enabled = true}) {
    if (!enabled || rawText.trim().isEmpty) {
      return rawText.trim();
    }

    String cleaned = rawText.trim();

    // 1. Remove filler words
    for (final pattern in _fillerWordPatterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    // 2. Remove duplicated consecutive words (run twice for triple repetitions like "I I I")
    cleaned = cleaned.replaceAllMapped(_duplicateWordsPattern, (match) => match.group(1)!);
    cleaned = cleaned.replaceAllMapped(_duplicateWordsPattern, (match) => match.group(1)!);

    // 3. Fix punctuation spacing and double punctuation
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' '); // multiple spaces to single
    cleaned = cleaned.replaceAll(RegExp(r'\s*,\s*,'), ','); // double comma
    cleaned = cleaned.replaceAll(RegExp(r'\s*,\s*\.'), '.'); // comma before period
    cleaned = cleaned.replaceAll(RegExp(r'\s+([,.:;!?])'), r'$1'); // space before punctuation

    cleaned = cleaned.trim();
    if (cleaned.isEmpty) return '';

    // 4. Ensure first letter is capitalized
    cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);

    // 5. Ensure terminal punctuation exists
    if (!RegExp(r'[.!?]$').hasMatch(cleaned)) {
      cleaned += '.';
    }

    return cleaned;
  }
}
