class TranslationModel {
  final int resourceId;
  final String text;

  TranslationModel({
    required this.resourceId,
    required this.text,
  });

  factory TranslationModel.fromJson(Map<String, dynamic> json) {
    return TranslationModel(
      resourceId: json['resource_id'] as int? ?? 0,
      text: json['text'] as String? ?? 'Translation not found.',
    );
  }
}
