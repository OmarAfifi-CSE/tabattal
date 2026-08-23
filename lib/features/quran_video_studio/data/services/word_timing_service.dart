import 'dart:math';
import 'package:dio/dio.dart';
import '../../../quran_reader/data/models/verse_model.dart';
import '../../domain/entities/word_timing_segment.dart';

/// Provides millisecond-accurate word timing segments for Quran recitations.
/// Combines network fetching with offline memory caching and robust proportional fallback.
class WordTimingService {
  final Dio _dio;
  static final Map<String, Map<String, List<WordTimingSegment>>> _chapterCache = {};
  static final Map<String, List<WordTimingSegment>> _verseCache = {};

  WordTimingService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Clears the in-memory timing caches
  static void clearCache() {
    _chapterCache.clear();
    _verseCache.clear();
  }

  /// Verified Quran.com API recitation IDs mapped directly to studio reciter paths
  static const Map<String, int> _verifiedReciterIdMap = {
    'Minshawy_Murattal_128kbps': 9,
    'Minshawy_Mujawwad_192kbps': 8,
    'Husary_128kbps': 6,
    'Abdul_Basit_Murattal_192kbps': 2,
    'Abdul_Basit_Mujawwad_128kbps': 1,
    'Abu_Bakr_Ash-Shaatree_128kbps': 4,
    'Saood_ash-Shuraym_128kbps': 10,
  };

  /// Known Quran.com API recitation IDs mapped from reciter identifiers with verified word timings
  static int? getQuranDotComRecitationId(String reciterPath) {
    if (_verifiedReciterIdMap.containsKey(reciterPath)) {
      return _verifiedReciterIdMap[reciterPath];
    }
    final lower = reciterPath.toLowerCase();
    if (lower.contains('minshaw')) {
      return lower.contains('mujawwad') ? 8 : 9;
    }
    if (lower.contains('abdul_basit') || lower.contains('abdulbasit')) {
      return lower.contains('mujawwad') ? 1 : 2;
    }
    if (lower.contains('husar') && !lower.contains('mujawwad') && !lower.contains('muallim')) {
      return 6;
    }
    if (lower.contains('shaatree') || lower.contains('shatri')) {
      return 4;
    }
    if (lower.contains('shuraym') || lower.contains('shuraim')) {
      return 10;
    }
    return null;
  }

  /// Retrieves word timing segments for a verse and reciter, guaranteeing non-empty return.
  Future<List<WordTimingSegment>> getWordTimings({
    required int surahNumber,
    required VerseModel verse,
    required String reciterPath,
    required Duration totalAyahDuration,
  }) async {
    final verseKey = verse.verseKey;
    final directCacheKey = '$reciterPath:$verseKey';
    if (_verseCache.containsKey(directCacheKey) && _verseCache[directCacheKey]!.isNotEmpty) {
      return _verseCache[directCacheKey]!;
    }

    final recitationId = getQuranDotComRecitationId(reciterPath);
    if (recitationId != null) {
      final chapterKey = '$recitationId:$surahNumber';

      // Check if entire chapter is already cached
      if (!_chapterCache.containsKey(chapterKey)) {
        try {
          final url = 'https://api.quran.com/api/v4/chapter_recitations/$recitationId/$surahNumber?segments=true';
          final response = await _dio.get(url);
          if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
            final audioFile = response.data['audio_file'] as Map<String, dynamic>?;
            final timestamps = audioFile?['timestamps'] as List<dynamic>?;
            if (timestamps != null && timestamps.isNotEmpty) {
              final chapterMap = <String, List<WordTimingSegment>>{};
              for (final t in timestamps) {
                final vMap = t as Map<String, dynamic>;
                final vKey = vMap['verse_key'] as String? ?? '';
                final rawSegments = vMap['segments'] as List<dynamic>?;
                if (rawSegments != null && rawSegments.isNotEmpty) {
                  double? firstSegStart;
                  for (final s in rawSegments) {
                    if (s is List && s.length >= 3) {
                      firstSegStart = (s[1] as num).toDouble();
                      break;
                    }
                  }
                  final baseStart = firstSegStart ?? (vMap['timestamp_from'] as num?)?.toDouble() ?? 0.0;

                  final segments = <WordTimingSegment>[];
                  for (int i = 0; i < rawSegments.length; i++) {
                    if (rawSegments[i] is! List) continue;
                    final list = rawSegments[i] as List<dynamic>;
                    if (list.length < 3) continue;

                    final wordPos = (list[0] as num).toInt();
                    final double segStart = (list[1] as num).toDouble();
                    final double segEnd = (list[2] as num).toDouble();
                    final int rawStart = (segStart - baseStart).round();
                    final int rawEnd = (segEnd - baseStart).round();

                    segments.add(
                      WordTimingSegment(
                        wordPosition: wordPos,
                        startMs: max(0, rawStart),
                        endMs: max(max(0, rawStart), rawEnd),
                      ),
                    );
                  }

                  if (segments.isNotEmpty) {
                    chapterMap[vKey] = segments;
                  }
                }
              }
              _chapterCache[chapterKey] = chapterMap;
            }
          }
        } catch (_) {
          // Graceful fallback to proportional calculation on network error
        }
      }

      if (_chapterCache.containsKey(chapterKey) && _chapterCache[chapterKey]!.containsKey(verseKey)) {
        final segments = _chapterCache[chapterKey]![verseKey]!;
        _verseCache[directCacheKey] = segments;
        return segments;
      }
    }


    // Phonetically calibrated proportional word timing fallback algorithm
    final fallbackSegments = computeProportionalTimings(
      verse: verse,
      totalDurationMs: totalAyahDuration.inMilliseconds,
    );

    _verseCache[directCacheKey] = fallbackSegments;
    return fallbackSegments;
  }


  /// Calculates proportional time slices calibrated to Arabic recitation phonetic phonology, madd, and intro/outro pauses.
  static List<WordTimingSegment> computeProportionalTimings({
    required VerseModel verse,
    required int totalDurationMs,
  }) {
    final words = verse.words;
    if (words.isEmpty) {
      return [
        WordTimingSegment(
          wordPosition: 1,
          startMs: 0,
          endMs: max(totalDurationMs, 1000),
        ),
      ];
    }

    // Weight each word by character length, Madd marks, and Shaddah
    final weights = words.map((w) {
      final text = w.textUthmani;
      int weight = text.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '').length * 2;
      // Extra weight for Madd marks
      if (text.contains('~') || text.contains('\u06E1') || text.contains('\u0653')) {
        weight += 6;
      }
      for (final char in text.runes) {
        final c = String.fromCharCode(char);
        if (c == 'ا' || c == 'و' || c == 'ي' || c == 'ى' || c == 'آ') {
          weight += 2;
        }
        if (c == '\u0651') {
          weight += 2;
        }
      }
      return max(weight, 4);
    }).toList();

    final totalWeight = weights.fold<int>(0, (sum, w) => sum + w);
    final totalMs = max(totalDurationMs, words.length * 400);

    // Account for reciter breath/silence at intro (~150ms) and outro (~200ms)
    final introSilenceMs = min(200, (totalMs * 0.030).round());
    final outroSilenceMs = min(250, (totalMs * 0.035).round());
    final speechDuration = max(totalMs - introSilenceMs - outroSilenceMs, words.length * 300);

    final segments = <WordTimingSegment>[];
    int currentStartMs = introSilenceMs;

    for (int i = 0; i < words.length; i++) {
      final wordFraction = weights[i] / totalWeight;
      final wordDuration = (speechDuration * wordFraction).round();
      final endMs = i == words.length - 1 ? (totalMs - outroSilenceMs) : (currentStartMs + wordDuration);

      segments.add(
        WordTimingSegment(
          wordPosition: i + 1,
          startMs: currentStartMs,
          endMs: endMs,
        ),
      );

      currentStartMs = endMs;
    }

    return segments;
  }


  /// Groups verse words and their timing segments into cohesive line-level slices.
  static List<LineTimingSegment> groupIntoLineSegments({
    required VerseModel verse,
    required List<WordTimingSegment> wordTimings,
    int? totalAyahDurationMs,
  }) {
    final words = verse.words;
    if (words.isEmpty) {
      final endMs = totalAyahDurationMs ?? (wordTimings.isNotEmpty ? wordTimings.last.endMs : 3000);
      return [
        LineTimingSegment(
          lineNumber: 1,
          startWordIndex: 0,
          endWordIndex: 0,
          startMs: 0,
          endMs: endMs,
        ),
      ];
    }

    final totalWords = words.length;
    List<List<int>> wordIndexChunks = [];
    if (totalWords <= 6) {
      wordIndexChunks = [List.generate(totalWords, (i) => i)];
    } else {
      // Balanced distribution: calculate optimal number of lines so every line has balanced word counts (3-5 words)
      final int numLines = (totalWords / 4.8).ceil();
      final int baseWordsPerLine = totalWords ~/ numLines;
      final int remainder = totalWords % numLines;

      wordIndexChunks = [];
      int currentIdx = 0;
      for (int l = 0; l < numLines; l++) {
        final chunkSize = baseWordsPerLine + (l < remainder ? 1 : 0);
        wordIndexChunks.add(List.generate(chunkSize, (k) => currentIdx + k));
        currentIdx += chunkSize;
      }
    }

    final lineSegments = <LineTimingSegment>[];
    for (int lineIdx = 0; lineIdx < wordIndexChunks.length; lineIdx++) {
      final indices = wordIndexChunks[lineIdx];
      final firstWordIdx = indices.first;
      final lastWordIdx = indices.last;

      // First line starts at 0ms to cover intro audio; subsequent lines start at their first word onset
      final int startMs;
      if (lineIdx == 0) {
        startMs = 0;
      } else {
        startMs = firstWordIdx < wordTimings.length ? wordTimings[firstWordIdx].startMs : 0;
      }

      // End of line: perfectly chained to the exact millisecond the first word of the NEXT line begins
      final int endMs;
      if (lineIdx + 1 < wordIndexChunks.length) {
        final nextFirstWordIdx = wordIndexChunks[lineIdx + 1].first;
        endMs = nextFirstWordIdx < wordTimings.length
            ? wordTimings[nextFirstWordIdx].startMs
            : (lastWordIdx < wordTimings.length ? wordTimings[lastWordIdx].endMs : startMs + 2000);
      } else {
        // Final line in verse stays active until the very end of the ayah audio file
        final lastSegEnd = wordTimings.isNotEmpty ? wordTimings.last.endMs : (startMs + 2000);
        endMs = totalAyahDurationMs != null ? max(totalAyahDurationMs, lastSegEnd) : lastSegEnd;
      }

      lineSegments.add(
        LineTimingSegment(
          lineNumber: lineIdx + 1,
          startWordIndex: firstWordIdx,
          endWordIndex: lastWordIdx,
          startMs: startMs,
          endMs: max(startMs + 300, endMs),
        ),
      );
    }

    return lineSegments;
  }
}
