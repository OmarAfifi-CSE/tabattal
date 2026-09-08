class VerseTimestamp {
  final int surah;
  final int ayah;
  final Duration start;
  final Duration end;

  const VerseTimestamp({
    required this.surah,
    required this.ayah,
    required this.start,
    required this.end,
  });

  int get verseId => surah * 1000 + ayah;
  String get verseKey => '$surah:$ayah';
  Duration get duration => end - start;

  Map<String, dynamic> toJson() => {
        'surah': surah,
        'ayah': ayah,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
      };

  factory VerseTimestamp.fromJson(Map<String, dynamic> json) => VerseTimestamp(
        surah: json['surah'] as int,
        ayah: json['ayah'] as int,
        start: Duration(milliseconds: json['startMs'] as int),
        end: Duration(milliseconds: json['endMs'] as int),
      );
}

class SurahTimings {
  final int surah;
  final String audioUrl;
  final List<VerseTimestamp> verseTimings;

  const SurahTimings({
    required this.surah,
    required this.audioUrl,
    required this.verseTimings,
  });

  /// Binary search to find which verse corresponds to the current playback position.
  /// Runs in O(log N) time with zero allocations, easily satisfying 120 FPS frame budgets.
  VerseTimestamp? findVerseAt(Duration position) {
    if (verseTimings.isEmpty) return null;
    if (position <= verseTimings.first.start) return verseTimings.first;
    if (position >= verseTimings.last.end) return verseTimings.last;

    int low = 0;
    int high = verseTimings.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final item = verseTimings[mid];

      if (position >= item.start && position < item.end) {
        return item;
      } else if (position < item.start) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    if (high >= 0 && high < verseTimings.length) return verseTimings[high];
    if (low < verseTimings.length) return verseTimings[low];
    return verseTimings.last;
  }

  VerseTimestamp? getVerse(int ayah) {
    for (final v in verseTimings) {
      if (v.ayah == ayah) return v;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'surah': surah,
        'audioUrl': audioUrl,
        'verseTimings': verseTimings.map((v) => v.toJson()).toList(),
      };

  factory SurahTimings.fromJson(Map<String, dynamic> json) => SurahTimings(
        surah: json['surah'] as int,
        audioUrl: json['audioUrl'] as String,
        verseTimings: (json['verseTimings'] as List<dynamic>)
            .map((v) => VerseTimestamp.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}
