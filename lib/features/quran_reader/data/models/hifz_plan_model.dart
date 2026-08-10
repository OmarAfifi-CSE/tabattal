import 'package:equatable/equatable.dart';

enum HifzItemStatus {
  notStarted,
  inProgress,
  memorized,
  reviewed,
}

extension HifzItemStatusX on HifzItemStatus {
  String get nameString {
    switch (this) {
      case HifzItemStatus.notStarted:
        return 'notStarted';
      case HifzItemStatus.inProgress:
        return 'inProgress';
      case HifzItemStatus.memorized:
        return 'memorized';
      case HifzItemStatus.reviewed:
        return 'reviewed';
    }
  }

  static HifzItemStatus fromString(String statusStr) {
    switch (statusStr) {
      case 'inProgress':
        return HifzItemStatus.inProgress;
      case 'memorized':
        return HifzItemStatus.memorized;
      case 'reviewed':
        return HifzItemStatus.reviewed;
      default:
        return HifzItemStatus.notStarted;
    }
  }
}

class HifzPlanModel extends Equatable {
  final int id;
  final String title;
  final int surahNumber;
  final int startPage;
  final int endPage;
  final int targetVersesCount;
  final int memorizedVersesCount;
  final String createdAt;
  final String? lastStudiedAt;

  const HifzPlanModel({
    required this.id,
    required this.title,
    required this.surahNumber,
    required this.startPage,
    required this.endPage,
    required this.targetVersesCount,
    this.memorizedVersesCount = 0,
    required this.createdAt,
    this.lastStudiedAt,
  });

  double get progressPercentage =>
      targetVersesCount > 0 ? (memorizedVersesCount / targetVersesCount) : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'surahNumber': surahNumber,
      'startPage': startPage,
      'endPage': endPage,
      'targetVersesCount': targetVersesCount,
      'memorizedVersesCount': memorizedVersesCount,
      'createdAt': createdAt,
      'lastStudiedAt': lastStudiedAt,
    };
  }

  factory HifzPlanModel.fromMap(Map<String, dynamic> map) {
    return HifzPlanModel(
      id: map['id'] as int,
      title: map['title'] as String,
      surahNumber: map['surahNumber'] as int,
      startPage: map['startPage'] as int,
      endPage: map['endPage'] as int,
      targetVersesCount: map['targetVersesCount'] as int,
      memorizedVersesCount: map['memorizedVersesCount'] as int? ?? 0,
      createdAt: map['createdAt'] as String,
      lastStudiedAt: map['lastStudiedAt'] as String?,
    );
  }

  HifzPlanModel copyWith({
    int? id,
    String? title,
    int? surahNumber,
    int? startPage,
    int? endPage,
    int? targetVersesCount,
    int? memorizedVersesCount,
    String? createdAt,
    String? lastStudiedAt,
  }) {
    return HifzPlanModel(
      id: id ?? this.id,
      title: title ?? this.title,
      surahNumber: surahNumber ?? this.surahNumber,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
      targetVersesCount: targetVersesCount ?? this.targetVersesCount,
      memorizedVersesCount: memorizedVersesCount ?? this.memorizedVersesCount,
      createdAt: createdAt ?? this.createdAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        surahNumber,
        startPage,
        endPage,
        targetVersesCount,
        memorizedVersesCount,
        createdAt,
        lastStudiedAt,
      ];
}

class HifzItemModel extends Equatable {
  final String verseKey;
  final int surahNumber;
  final int ayahNumber;
  final int pageNumber;
  final HifzItemStatus status;
  final String? lastReviewedAt;
  final String? nextReviewAt;
  final int reviewCount;

  const HifzItemModel({
    required this.verseKey,
    required this.surahNumber,
    required this.ayahNumber,
    required this.pageNumber,
    this.status = HifzItemStatus.notStarted,
    this.lastReviewedAt,
    this.nextReviewAt,
    this.reviewCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'verseKey': verseKey,
      'surahNumber': surahNumber,
      'ayahNumber': ayahNumber,
      'pageNumber': pageNumber,
      'status': status.nameString,
      'lastReviewedAt': lastReviewedAt,
      'nextReviewAt': nextReviewAt,
      'reviewCount': reviewCount,
    };
  }

  factory HifzItemModel.fromMap(Map<String, dynamic> map) {
    return HifzItemModel(
      verseKey: map['verseKey'] as String,
      surahNumber: map['surahNumber'] as int,
      ayahNumber: map['ayahNumber'] as int,
      pageNumber: map['pageNumber'] as int,
      status: HifzItemStatusX.fromString(map['status'] as String),
      lastReviewedAt: map['lastReviewedAt'] as String?,
      nextReviewAt: map['nextReviewAt'] as String?,
      reviewCount: map['reviewCount'] as int? ?? 0,
    );
  }

  HifzItemModel copyWith({
    String? verseKey,
    int? surahNumber,
    int? ayahNumber,
    int? pageNumber,
    HifzItemStatus? status,
    String? lastReviewedAt,
    String? nextReviewAt,
    int? reviewCount,
  }) {
    return HifzItemModel(
      verseKey: verseKey ?? this.verseKey,
      surahNumber: surahNumber ?? this.surahNumber,
      ayahNumber: ayahNumber ?? this.ayahNumber,
      pageNumber: pageNumber ?? this.pageNumber,
      status: status ?? this.status,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  @override
  List<Object?> get props => [
        verseKey,
        surahNumber,
        ayahNumber,
        pageNumber,
        status,
        lastReviewedAt,
        nextReviewAt,
        reviewCount,
      ];
}
