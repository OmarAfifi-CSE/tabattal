class TafsirModel {
  final int id;
  final int tafsirId;
  final String text;

  TafsirModel({
    required this.id,
    required this.tafsirId,
    required this.text,
  });

  factory TafsirModel.fromJson(Map<String, dynamic> json) {
    return TafsirModel(
      id: json['id'] as int? ?? 0,
      tafsirId: json['tafsir_id'] as int? ?? 0,
      text: json['text'] as String? ?? 'Tafsir not found.',
    );
  }
}
