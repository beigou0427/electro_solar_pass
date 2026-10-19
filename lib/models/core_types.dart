// ==========================================
// 專案名稱：電光證照霸 PRO - 核心資料模型
// 檔案：lib/models/core_types.dart
// ==========================================

enum CategoryType {
  roomWiring('00700_B'),
  solarPV('21000_B');

  final String value;
  const CategoryType(this.value);

  factory CategoryType.fromString(String val) {
    return CategoryType.values.firstWhere((e) => e.value == val, orElse: () => CategoryType.roomWiring);
  }
}

class Explanation {
  final String quickHack;   // ⚡ 一秒記憶口訣
  final String formula;     // 📐 核心公式或法規條號
  final String stepByStep;  // 📝 完整算式推導
  final String fieldNote;   // 🛠️ 案場老手實務與術科防呆提醒

  Explanation({
    required this.quickHack,
    required this.formula,
    required this.stepByStep,
    required this.fieldNote,
  });

  factory Explanation.fromJson(Map<String, dynamic> json) {
    return Explanation(
      quickHack: json['quickHack'] ?? '',
      formula: json['formula'] ?? '',
      stepByStep: json['stepByStep'] ?? '',
      fieldNote: json['fieldNote'] ?? '',
    );
  }
}

class QuestionItem {
  final String id;
  final CategoryType category;
  final String categoryLabel;
  final String workItem;
  final String type; // 'single' | 'multiple'
  final int difficulty; // 1 | 2 | 3
  final bool isFree; // true: 免費, false: 觸發 Paywall
  final String question;
  final List<String> options;
  final List<int> answer; // 1-based index
  final Explanation explanation;

  QuestionItem({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.workItem,
    required this.type,
    required this.difficulty,
    required this.isFree,
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    return QuestionItem(
      id: json['id'] ?? '',
      category: CategoryType.fromString(json['category'] ?? '00700_B'),
      categoryLabel: json['categoryLabel'] ?? '',
      workItem: json['workItem'] ?? '',
      type: json['type'] ?? 'single',
      difficulty: json['difficulty'] ?? 1,
      isFree: json['isFree'] ?? false,
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      answer: List<int>.from(json['answer'] ?? []),
      explanation: Explanation.fromJson(json['explanation'] ?? {}),
    );
  }
}

enum LicenseTier {
  free('FREE'),
  tier1_30days('TIER_1'),
  tier2_180days('TIER_2'),
  proLifetime('PRO');

  final String value;
  const LicenseTier(this.value);
}

class UserProfile {
  LicenseTier licenseTier;
  List<String> masteredIds;
  List<String> wrongQueueIds;
  List<String> bookmarkedIds;

  UserProfile({
    this.licenseTier = LicenseTier.free,
    this.masteredIds = const [],
    this.wrongQueueIds = const [],
    this.bookmarkedIds = const [],
  });
}
