class SearchVerseModel {
  final int id;
  final String verseKey;
  final int surah;
  final int ayah;
  final int page;
  final String textClean;
  final String textUthmani;

  SearchVerseModel({
    required this.id,
    required this.verseKey,
    required this.surah,
    required this.ayah,
    required this.page,
    required this.textClean,
    required this.textUthmani,
  });

  factory SearchVerseModel.fromMap(Map<String, dynamic> map) {
    return SearchVerseModel(
      id: map['id'] as int,
      verseKey: map['verse_key'] as String,
      surah: map['surah'] as int,
      ayah: map['ayah'] as int,
      page: map['page'] as int,
      textClean: map['text_clean'] as String,
      textUthmani: map['text_uthmani'] as String,
    );
  }
}
