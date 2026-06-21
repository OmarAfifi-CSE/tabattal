class TafsirModel {
  final int id;
  final int tafsirId;
  final String? verseKey;
  final String text;

  TafsirModel({
    required this.id,
    required this.tafsirId,
    this.verseKey,
    required this.text,
  });

  factory TafsirModel.fromJson(Map<String, dynamic> json) {
    return TafsirModel(
      id: json['id'] as int? ?? 0,
      tafsirId: json['tafsir_id'] ?? json['resource_id'] as int? ?? 0,
      verseKey: json['verse_key'] as String?,
      text: json['text'] as String? ?? 'Tafsir not found.',
    );
  }
}
