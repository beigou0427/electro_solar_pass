// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/utils/memory_engine.dart
// CTO 注入：Werner Vogels (Amazon) - 第 1/3 段：艾賓浩斯與 FSRS 間隔重複演算法
// 說明：[前沿神經學習模型] 基於指數記憶衰減之自適應複習排程與留存率精算器
// ==========================================

import 'dart:math';

/// 考生作戰自我認知評級 (Review Rating)
enum StudyRating {
  again(1, "忘光重來", 0.0), // 完全忘記或算錯：立即重置間隔
  hard(2, "勉強答對", 0.8),  // 苦思良久：間隔微幅提升，增加複習頻率
  good(3, "掌握良好", 1.0),  // 正常發揮：標準艾賓浩斯指數增長
  easy(4, "秒殺斬殺", 1.3);  // 徹底刻入肌肉記憶：大幅拉長間隔，釋放複習時間

  final int value;
  final String label;
  final double factorMultiplier;
  const StudyRating(this.value, this.label, this.factorMultiplier);
}

/// 單一考題的記憶神經狀態 (Memory Card State)
class MemoryCardState {
  final String questionId;
  final int repetitions;       // 連續成功作答次數
  final double stability;       // 記憶穩定度 S (天數，代表留存率降至 90% 所需的時間)
  final double difficulty;      // 題目主觀難度 D (範圍 1.0 ~ 10.0)
  final double easinessFactor;   // 簡易度因子 EF (SuperMemo 基準，下限 1.3)
  final DateTime lastReviewed;  // 上次作答時間點
  final DateTime nextReviewDate;// 演算法排定的最佳複習時間點

  MemoryCardState({
    required this.questionId,
    this.repetitions = 0,
    this.stability = 0.5,
    this.difficulty = 5.0,
    this.easinessFactor = 2.5,
    DateTime? lastReviewed,
    DateTime? nextReviewDate,
  })  : lastReviewed = lastReviewed ?? DateTime.now(),
        nextReviewDate = nextReviewDate ?? DateTime.now();

  /// 序列化 Map (支援快照持久化)
  Map<String, dynamic> toMap() => {
    'questionId': questionId,
    'repetitions': repetitions,
    'stability': stability,
    'difficulty': difficulty,
    'easinessFactor': easinessFactor,
    'lastReviewed': lastReviewed.toIso8601String(),
    'nextReviewDate': nextReviewDate.toIso8601String(),
  };

  factory MemoryCardState.fromMap(Map<String, dynamic> map) {
    return MemoryCardState(
      questionId: map['questionId'] as String? ?? '',
      repetitions: map['repetitions'] as int? ?? 0,
      stability: (map['stability'] as num?)?.toDouble() ?? 0.5,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 5.0,
      easinessFactor: (map['easinessFactor'] as num?)?.toDouble() ?? 2.5,
      lastReviewed: DateTime.tryParse(map['lastReviewed'] as String? ?? '') ?? DateTime.now(),
      nextReviewDate: DateTime.tryParse(map['nextReviewDate'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Werner Vogels 艾賓浩斯與 FSRS 核心演算法大腦
class AdvancedMemoryEngine {
  /// 根據當下時間與記憶穩定度，精算考生的即時記憶留存率 R (Retention Rate: 0.0 ~ 1.0)
  /// 公式依據 Ebbinghaus-FSRS 指數衰減模型：R = e^(-Δt / S)
  static double calculateCurrentRetention(MemoryCardState state, {DateTime? targetTime}) {
    final now = targetTime ?? DateTime.now();
    final elapsedHours = now.difference(state.lastReviewed).inMinutes / 60.0;
    final elapsedDays = max(0.0, elapsedHours / 24.0);

    // 當時間經過 0 天，留存率為 100%；隨時間推進，呈負指數曲線下滑
    final retention = exp(-elapsedDays / max(0.1, state.stability));
    return double.parse(retention.clamp(0.0, 1.0).toStringAsFixed(4));
  }

  /// 核心排程演算法：依據考生反饋計算下一階段的記憶狀態
  static MemoryCardState processReview({
    required MemoryCardState currentState,
    required StudyRating rating,
    DateTime? reviewTimestamp,
  }) {
    final now = reviewTimestamp ?? DateTime.now();
    int newRepetitions = currentState.repetitions;
    double newStability = currentState.stability;
    double newDifficulty = currentState.difficulty;
    double newEF = currentState.easinessFactor;

    // 1. 調整難度係數 D (Difficulty Adjustment: 1.0 ~ 10.0)
    // 答錯難度增加，秒殺難度降低
    final difficultyDelta = (3 - rating.value) * 0.4;
    newDifficulty = (newDifficulty + difficultyDelta).clamp(1.0, 10.0);

    // 2. 調整簡易度因子 EF (SuperMemo SM-2 標準演算法)
    // EF' = EF + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02))
    final grade = rating.value + 1; // 轉為 2~5 標度
    newEF = newEF + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02));
    if (newEF < 1.3) newEF = 1.3; // 1.3 是 SM-2 的數學收斂底限

    // 3. 計算新間隔天數與穩定度 S (Stability & Interval)
    double intervalDays;

    if (rating == StudyRating.again) {
      // 【遺忘斷崖】：重置連續計數，間隔縮短至 10 分鐘 (0.007 天)，進入高危急診佇列
      newRepetitions = 0;
      newStability = 0.2; // 穩定度暴跌
      intervalDays = 0.007; // 約 10 分鐘後再次複習
    } else {
      newRepetitions += 1;
      if (newRepetitions == 1) {
        intervalDays = 1.0; // 第一次答對，間隔 1 天
      } else if (newRepetitions == 2) {
        intervalDays = 3.0; // 第二次答對，間隔 3 天
      } else {
        // 第三次以上，依據穩定度與 EF 指數膨脹
        intervalDays = currentState.stability * newEF * rating.factorMultiplier;
      }
      // 穩定度隨成功作答以對數階梯增強
      newStability = intervalDays * (1 + (11 - newDifficulty) / 10.0);
    }

    // 計算精確的下一次複習時間戳記
    final intervalMinutes = (intervalDays * 24 * 60).round();
    final nextReview = now.add(Duration(minutes: max(5, intervalMinutes)));

    return MemoryCardState(
      questionId: currentState.questionId,
      repetitions: newRepetitions,
      stability: double.parse(newStability.toStringAsFixed(2)),
      difficulty: double.parse(newDifficulty.toStringAsFixed(2)),
      easinessFactor: double.parse(newEF.toStringAsFixed(3)),
      lastReviewed: now,
      nextReviewDate: nextReview,
    );
  }

  /// 診斷考題是否「已瀕臨遺忘臨界點」（當預估留存率低於 75% 即列入優先複習佇列）
  static bool isDueForReview(MemoryCardState state, {double threshold = 0.75}) {
    final retention = calculateCurrentRetention(state);
    return retention <= threshold || DateTime.now().isAfter(state.nextReviewDate);
  }
}
