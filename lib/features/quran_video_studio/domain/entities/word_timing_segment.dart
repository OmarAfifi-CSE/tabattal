import 'package:equatable/equatable.dart';

/// Immutable model representing a millisecond-accurate timing segment for a Quran word.
class WordTimingSegment extends Equatable {
  /// 1-indexed word position within the Ayah (matches `WordModel.id` or sequence).
  final int wordPosition;

  /// Start timestamp in milliseconds relative to Ayah audio start.
  final int startMs;

  /// End timestamp in milliseconds relative to Ayah audio start.
  final int endMs;

  const WordTimingSegment({
    required this.wordPosition,
    required this.startMs,
    required this.endMs,
  });

  /// Duration of this specific word's recitation.
  Duration get duration => Duration(milliseconds: (endMs - startMs).clamp(0, 3600000));

  /// Checks whether a given millisecond timestamp falls within this word.
  bool contains(int positionMs) => positionMs >= startMs && positionMs <= endMs;

  factory WordTimingSegment.fromJson(List<dynamic> json) {
    return WordTimingSegment(
      wordPosition: json[0] as int? ?? 1,
      startMs: json[1] as int? ?? 0,
      endMs: json[2] as int? ?? 0,
    );
  }

  List<dynamic> toJson() => [wordPosition, startMs, endMs];

  @override
  List<Object?> get props => [wordPosition, startMs, endMs];
}

/// Represents a grouped line of words with its aggregate start and end timing.
class LineTimingSegment extends Equatable {
  final int lineNumber;
  final int startWordIndex;
  final int endWordIndex;
  final int startMs;
  final int endMs;

  const LineTimingSegment({
    required this.lineNumber,
    required this.startWordIndex,
    required this.endWordIndex,
    required this.startMs,
    required this.endMs,
  });

  Duration get duration => Duration(milliseconds: (endMs - startMs).clamp(0, 3600000));

  bool contains(int positionMs) => positionMs >= startMs && positionMs <= endMs;

  @override
  List<Object?> get props => [lineNumber, startWordIndex, endWordIndex, startMs, endMs];
}
