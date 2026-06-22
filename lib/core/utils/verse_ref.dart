import '../../features/quran_reader/presentation/widgets/quran_metadata.dart';

class VerseRef {
  final int surah;
  final int ayah;

  const VerseRef(this.surah, this.ayah);

  factory VerseRef.fromKey(String key) {
    final parts = key.split(':');
    if (parts.length != 2) throw const FormatException('Invalid verse key');
    return VerseRef(int.parse(parts[0]), int.parse(parts[1]));
  }

  factory VerseRef.fromId(int id) {
    return VerseRef(id ~/ 1000, id % 1000);
  }

  int get verseId => surah * 1000 + ayah;
  String get verseKey => '$surah:$ayah';

  VerseRef? get next {
    final length = QuranMetadata.surahLengthOf(surah);
    if (ayah < length) return VerseRef(surah, ayah + 1);
    if (surah < 114) return VerseRef(surah + 1, 1);
    return null; // end of Quran
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VerseRef && other.surah == surah && other.ayah == ayah;
  }

  @override
  int get hashCode => surah.hashCode ^ ayah.hashCode;

  @override
  String toString() => verseKey;
}
