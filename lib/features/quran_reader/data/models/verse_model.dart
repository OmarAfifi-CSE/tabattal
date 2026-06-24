class WordModel {
  final int id;
  final String textUthmani;
  final String codeV1;
  final int lineNumber;
  final String charTypeName; // 'word' or 'end'
  final String verseKey;

  WordModel({
    required this.id,
    required this.textUthmani,
    required this.codeV1,
    required this.lineNumber,
    required this.charTypeName,
    required this.verseKey,
  });

  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      id: json['id'] as int? ?? 0,
      textUthmani: json['text_uthmani'] as String? ?? '',
      codeV1: json['code_v1'] as String? ?? '',
      lineNumber: json['line_number'] as int? ?? 1,
      charTypeName: json['char_type_name'] as String? ?? 'word',
      verseKey: json['verse_key'] as String? ?? '',
    );
  }
}

class VerseModel {
  final int id;
  final int verseNumber;
  final String verseKey;
  final String textUthmani;
  final List<WordModel> words;
  final int juzNumber;

  VerseModel({
    required this.id,
    required this.verseNumber,
    required this.verseKey,
    required this.textUthmani,
    required this.words,
    required this.juzNumber,
  });

  factory VerseModel.fromJson(Map<String, dynamic> json) {
    final wordsJson = json['words'] as List<dynamic>? ?? [];
    
    return VerseModel(
      id: json['id'] as int? ?? 0,
      verseNumber: json['verse_number'] as int? ?? 0,
      verseKey: json['verse_key'] as String? ?? '',
      textUthmani: json['text_uthmani'] as String? ?? 'Error loading verse text',
      words: wordsJson.map((w) => WordModel.fromJson(w)).toList(),
      juzNumber: json['juz_number'] as int? ?? 1,
    );
  }
}

class LineData {
  final int lineNumber;
  final List<WordModel> words;

  LineData({
    required this.lineNumber,
    required this.words,
  });
}
