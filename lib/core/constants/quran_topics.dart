import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Represents a single verse reference range (e.g., Surah 2, Ayah 153 to 157).
class VerseRange {
  final int surah;
  final int startAyah;
  final int endAyah;

  const VerseRange(this.surah, this.startAyah, [int? endAyah])
      : endAyah = endAyah ?? startAyah;

  /// Parse a string like "2:153-157" or "2:201"
  factory VerseRange.parse(String spec) {
    final parts = spec.trim().split(':');
    final surahNum = int.parse(parts[0]);
    if (parts[1].contains('-')) {
      final rangeParts = parts[1].split('-');
      return VerseRange(
        surahNum,
        int.parse(rangeParts[0]),
        int.parse(rangeParts[1]),
      );
    }
    final ayahNum = int.parse(parts[1]);
    return VerseRange(surahNum, ayahNum, ayahNum);
  }

  bool contains(int surahNum, int ayahNum) {
    if (surah != surahNum) return false;
    return ayahNum >= startAyah && ayahNum <= endAyah;
  }
}

/// A sub-topic under a main Quranic topic.
class QuranSubTopic {
  final String id;
  final String nameAr;
  final String nameEn;
  final List<VerseRange> verseRanges;

  const QuranSubTopic({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.verseRanges,
  });

  String getName(bool isArabic) => isArabic ? nameAr : nameEn;
}

/// Main Quranic topic with authenticated verse ranges and optional sub-topics.
class QuranTopic {
  final String id;
  final IconData icon;
  final String Function(AppLocalizations l10n) getTitle;
  final List<VerseRange> verseRanges;
  final List<QuranSubTopic>? subTopics;

  const QuranTopic({
    required this.id,
    required this.icon,
    required this.getTitle,
    this.verseRanges = const [],
    this.subTopics,
  });

  bool matchesVerse(int surahNum, int ayahNum) {
    for (final range in verseRanges) {
      if (range.contains(surahNum, ayahNum)) return true;
    }
    if (subTopics != null) {
      for (final sub in subTopics!) {
        for (final range in sub.verseRanges) {
          if (range.contains(surahNum, ayahNum)) return true;
        }
      }
    }
    return false;
  }
}

class QuranTopics {
  static final List<QuranTopic> topics = [
    // 1. الأدعية القرآنيات الأربعين المعتمدة
    QuranTopic(
      id: 'supplications',
      icon: Icons.volunteer_activism_rounded,
      getTitle: (l10n) => l10n.topicSupplications,
      verseRanges: const [
        VerseRange(2, 127, 128),
        VerseRange(2, 201),
        VerseRange(2, 250),
        VerseRange(2, 286),
        VerseRange(3, 8, 9),
        VerseRange(3, 16),
        VerseRange(3, 53),
        VerseRange(3, 147),
        VerseRange(3, 191, 194),
        VerseRange(7, 23),
        VerseRange(7, 47),
        VerseRange(7, 89),
        VerseRange(7, 126),
        VerseRange(10, 85, 86),
        VerseRange(14, 38, 41),
        VerseRange(17, 24),
        VerseRange(17, 80),
        VerseRange(18, 10),
        VerseRange(20, 25, 28),
        VerseRange(20, 114),
        VerseRange(21, 83),
        VerseRange(21, 87),
        VerseRange(21, 89),
        VerseRange(23, 97, 98),
        VerseRange(23, 109),
        VerseRange(23, 118),
        VerseRange(25, 65, 66),
        VerseRange(25, 74),
        VerseRange(26, 83, 89),
        VerseRange(27, 19),
        VerseRange(28, 24),
        VerseRange(40, 7, 9),
        VerseRange(46, 15),
        VerseRange(59, 10),
        VerseRange(60, 4, 5),
        VerseRange(66, 11),
      ],
    ),

    // 2. قصص الأنبياء - مفصلة ومستقلة لكل نبي مع الألقاب والتصلية والسلام
    QuranTopic(
      id: 'prophets',
      icon: Icons.auto_stories_rounded,
      getTitle: (l10n) => l10n.topicProphets,
      subTopics: const [
        QuranSubTopic(
          id: 'muhammad',
          nameAr: 'سيدنا محمد صلى الله عليه وسلم',
          nameEn: 'Prophet Muhammad (PBUH)',
          verseRanges: [
            VerseRange(3, 144),
            VerseRange(9, 128, 129),
            VerseRange(33, 40),
            VerseRange(33, 56),
            VerseRange(48, 28, 29),
            VerseRange(68, 4),
            VerseRange(94, 1, 8),
          ],
        ),
        QuranSubTopic(
          id: 'adam',
          nameAr: 'سيدنا آدم عليه السلام',
          nameEn: 'Prophet Adam (PBUH)',
          verseRanges: [
            VerseRange(2, 30, 39),
            VerseRange(7, 11, 27),
            VerseRange(15, 26, 44),
            VerseRange(17, 61, 65),
            VerseRange(20, 115, 126),
          ],
        ),
        QuranSubTopic(
          id: 'nuh',
          nameAr: 'سيدنا نوح عليه السلام',
          nameEn: 'Prophet Noah (PBUH)',
          verseRanges: [
            VerseRange(7, 59, 64),
            VerseRange(10, 71, 73),
            VerseRange(11, 25, 49),
            VerseRange(21, 76, 77),
            VerseRange(23, 23, 30),
            VerseRange(26, 105, 122),
            VerseRange(37, 75, 82),
            VerseRange(54, 9, 16),
            VerseRange(71, 1, 28),
          ],
        ),
        QuranSubTopic(
          id: 'hud',
          nameAr: 'سيدنا هود عليه السلام',
          nameEn: 'Prophet Hud (PBUH)',
          verseRanges: [
            VerseRange(7, 65, 72),
            VerseRange(11, 50, 60),
            VerseRange(26, 123, 140),
            VerseRange(46, 21, 26),
          ],
        ),
        QuranSubTopic(
          id: 'salih',
          nameAr: 'سيدنا صالح عليه السلام',
          nameEn: 'Prophet Salih (PBUH)',
          verseRanges: [
            VerseRange(7, 73, 79),
            VerseRange(11, 61, 68),
            VerseRange(26, 141, 159),
            VerseRange(27, 45, 53),
            VerseRange(54, 23, 32),
          ],
        ),
        QuranSubTopic(
          id: 'ibrahim',
          nameAr: 'سيدنا إبراهيم عليه السلام',
          nameEn: 'Prophet Abraham (PBUH)',
          verseRanges: [
            VerseRange(2, 124, 132),
            VerseRange(2, 260),
            VerseRange(6, 74, 84),
            VerseRange(14, 35, 41),
            VerseRange(19, 41, 50),
            VerseRange(21, 51, 73),
            VerseRange(26, 69, 89),
            VerseRange(37, 83, 113),
            VerseRange(60, 4, 5),
          ],
        ),
        QuranSubTopic(
          id: 'ismael_ishaq_yaqub',
          nameAr: 'سيدنا إسماعيل وإسحاق ويعقوب عليهم السلام',
          nameEn: 'Prophets Ishmael, Isaac & Jacob',
          verseRanges: [
            VerseRange(2, 133, 140),
            VerseRange(19, 49, 55),
            VerseRange(21, 72, 73),
            VerseRange(37, 100, 113),
          ],
        ),
        QuranSubTopic(
          id: 'lut',
          nameAr: 'سيدنا لوط عليه السلام',
          nameEn: 'Prophet Lot (PBUH)',
          verseRanges: [
            VerseRange(7, 80, 84),
            VerseRange(11, 77, 83),
            VerseRange(15, 57, 77),
            VerseRange(26, 160, 175),
            VerseRange(29, 28, 35),
          ],
        ),
        QuranSubTopic(
          id: 'shuaib',
          nameAr: 'سيدنا شعيب عليه السلام',
          nameEn: 'Prophet Shuayb (PBUH)',
          verseRanges: [
            VerseRange(7, 85, 93),
            VerseRange(11, 84, 95),
            VerseRange(26, 176, 191),
          ],
        ),
        QuranSubTopic(
          id: 'yusuf',
          nameAr: 'سيدنا يوسف عليه السلام',
          nameEn: 'Prophet Joseph (PBUH)',
          verseRanges: [
            VerseRange(12, 4, 101),
          ],
        ),
        QuranSubTopic(
          id: 'musa',
          nameAr: 'سيدنا موسى عليه السلام',
          nameEn: 'Prophet Moses (PBUH)',
          verseRanges: [
            VerseRange(2, 49, 61),
            VerseRange(7, 103, 160),
            VerseRange(10, 75, 92),
            VerseRange(20, 9, 98),
            VerseRange(26, 10, 68),
            VerseRange(28, 3, 44),
          ],
        ),
        QuranSubTopic(
          id: 'harun',
          nameAr: 'سيدنا هارون عليه السلام',
          nameEn: 'Prophet Aaron (PBUH)',
          verseRanges: [
            VerseRange(20, 87, 94),
            VerseRange(28, 34, 35),
            VerseRange(37, 114, 122),
          ],
        ),
        QuranSubTopic(
          id: 'dawud',
          nameAr: 'سيدنا داوود عليه السلام',
          nameEn: 'Prophet David (PBUH)',
          verseRanges: [
            VerseRange(2, 251),
            VerseRange(21, 78, 80),
            VerseRange(34, 10, 11),
            VerseRange(38, 17, 26),
          ],
        ),
        QuranSubTopic(
          id: 'sulaiman',
          nameAr: 'سيدنا سليمان عليه السلام',
          nameEn: 'Prophet Solomon (PBUH)',
          verseRanges: [
            VerseRange(21, 81, 82),
            VerseRange(27, 15, 44),
            VerseRange(34, 12, 14),
            VerseRange(38, 30, 40),
          ],
        ),
        QuranSubTopic(
          id: 'ayub',
          nameAr: 'سيدنا أيوب عليه السلام',
          nameEn: 'Prophet Job (PBUH)',
          verseRanges: [
            VerseRange(21, 83, 84),
            VerseRange(38, 41, 44),
          ],
        ),
        QuranSubTopic(
          id: 'yunus',
          nameAr: 'سيدنا يونس عليه السلام',
          nameEn: 'Prophet Jonah (PBUH)',
          verseRanges: [
            VerseRange(10, 98),
            VerseRange(21, 87, 88),
            VerseRange(37, 139, 148),
            VerseRange(68, 48, 50),
          ],
        ),
        QuranSubTopic(
          id: 'zakariya_yahya',
          nameAr: 'سيدنا زكريا وسيدنا يحيى عليهما السلام',
          nameEn: 'Prophets Zechariah & John',
          verseRanges: [
            VerseRange(3, 37, 41),
            VerseRange(19, 1, 15),
            VerseRange(21, 89, 90),
          ],
        ),
        QuranSubTopic(
          id: 'isa',
          nameAr: 'سيدنا عيسى عليه السلام',
          nameEn: 'Prophet Jesus (PBUH)',
          verseRanges: [
            VerseRange(3, 45, 59),
            VerseRange(4, 156, 159),
            VerseRange(5, 110, 120),
            VerseRange(19, 30, 34),
            VerseRange(61, 6),
          ],
        ),
        QuranSubTopic(
          id: 'maryam',
          nameAr: 'السيدة مريم عليها السلام',
          nameEn: 'Mary (Peace be upon her)',
          verseRanges: [
            VerseRange(3, 35, 44),
            VerseRange(19, 16, 29),
            VerseRange(66, 12),
          ],
        ),
      ],
    ),

    // 3. التقوى والإحسان والبر
    QuranTopic(
      id: 'taqwa',
      icon: Icons.eco_rounded,
      getTitle: (l10n) => l10n.topicTaqwa,
      verseRanges: const [
        VerseRange(2, 2, 5),
        VerseRange(2, 177),
        VerseRange(2, 189),
        VerseRange(2, 197),
        VerseRange(3, 15, 17),
        VerseRange(3, 102),
        VerseRange(3, 133, 136),
        VerseRange(3, 172),
        VerseRange(5, 2),
        VerseRange(5, 8),
        VerseRange(9, 119),
        VerseRange(16, 128),
        VerseRange(22, 37),
        VerseRange(39, 33, 35),
        VerseRange(49, 13),
        VerseRange(51, 15, 19),
        VerseRange(65, 2, 3),
        VerseRange(92, 5, 7),
      ],
    ),

    // 4. الصبر والفرج والبشرى
    QuranTopic(
      id: 'patience',
      icon: Icons.favorite_rounded,
      getTitle: (l10n) => l10n.topicPatience,
      verseRanges: const [
        VerseRange(2, 45, 46),
        VerseRange(2, 153, 157),
        VerseRange(3, 146),
        VerseRange(3, 200),
        VerseRange(8, 46),
        VerseRange(11, 115),
        VerseRange(12, 90),
        VerseRange(13, 22, 24),
        VerseRange(16, 96),
        VerseRange(16, 126, 127),
        VerseRange(21, 83, 84),
        VerseRange(39, 10),
        VerseRange(46, 35),
        VerseRange(70, 5),
        VerseRange(94, 1, 8),
        VerseRange(103, 1, 3),
      ],
    ),

    // 5. المغفرة والتبشير والرحمة
    QuranTopic(
      id: 'mercy',
      icon: Icons.wb_sunny_rounded,
      getTitle: (l10n) => l10n.topicMercy,
      verseRanges: const [
        VerseRange(2, 218),
        VerseRange(3, 159),
        VerseRange(4, 110),
        VerseRange(6, 54),
        VerseRange(7, 156),
        VerseRange(12, 87),
        VerseRange(15, 49, 50),
        VerseRange(15, 56),
        VerseRange(24, 22),
        VerseRange(25, 68, 70),
        VerseRange(39, 53),
        VerseRange(42, 25),
        VerseRange(57, 28),
      ],
    ),

    // 6. الترهيب والوعيد وعواقب الظلم
    QuranTopic(
      id: 'warning',
      icon: Icons.shield_rounded,
      getTitle: (l10n) => l10n.topicWarning,
      verseRanges: const [
        VerseRange(4, 168, 169),
        VerseRange(6, 51),
        VerseRange(10, 106, 107),
        VerseRange(14, 42, 52),
        VerseRange(17, 15),
        VerseRange(18, 49),
        VerseRange(22, 47, 48),
        VerseRange(39, 71, 72),
        VerseRange(40, 18),
        VerseRange(50, 45),
        VerseRange(67, 6, 11),
      ],
    ),

    // 7. الأخلاق والمعاملات وبـر الوالدين
    QuranTopic(
      id: 'morals',
      icon: Icons.balance_rounded,
      getTitle: (l10n) => l10n.topicMorals,
      verseRanges: const [
        VerseRange(2, 83),
        VerseRange(4, 36),
        VerseRange(6, 151, 153),
        VerseRange(16, 90),
        VerseRange(17, 23, 38),
        VerseRange(25, 63, 76),
        VerseRange(31, 13, 19),
        VerseRange(41, 34, 35),
        VerseRange(49, 10, 12),
        VerseRange(60, 8),
      ],
    ),

    // 8. التفكر وآيات الخلق والكون
    QuranTopic(
      id: 'creation',
      icon: Icons.public_rounded,
      getTitle: (l10n) => l10n.topicCreation,
      verseRanges: const [
        VerseRange(2, 164),
        VerseRange(3, 190, 191),
        VerseRange(6, 95, 99),
        VerseRange(10, 5, 6),
        VerseRange(13, 2, 4),
        VerseRange(16, 10, 18),
        VerseRange(21, 30, 33),
        VerseRange(30, 20, 25),
        VerseRange(41, 53),
        VerseRange(51, 20, 21),
        VerseRange(67, 1, 4),
        VerseRange(88, 17, 20),
      ],
    ),
  ];
}
