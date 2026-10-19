// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/utils/cognitive_load_engine.dart
// CTO 注入：Ray Kurzweil (Google) - 第 1/3 段：神經認知負載與動態難度調節 (DDA)
// 說明：[心流引擎] 實時量測腦力負載，自適應穿插信心修復與魔王挑戰，維持 100% 沉浸刷題
// ==========================================

import 'dart:math';
import '../models/core_types.dart';

/// 考生當下心理心流區間 (Csikszentmihalyi Flow Model)
enum CognitiveFlowZone {
  boredom("低度刺激", "大腦餘裕充沛，建議注入魔王難度突破瓶頸"),
  flow("黃金心流", "難度與認知完美對齊，處於最高吸收效率狀態"),
  overload("認知過載", "腦力負載超標，啟動信心修復降溫模式");

  final String label;
  final String description;
  const CognitiveFlowZone(this.label, this.description);
}

/// 神經認知狀態快照實體
class CognitiveState {
  final double loadFactor;               // 當前認知負載 (0.0 完全放鬆 ~ 1.0 極限過載)
  final int consecutiveMistakes;        // 連續失誤次數
  final int consecutiveSuccesses;       // 連續秒殺次數
  final CognitiveFlowZone currentZone;  // 心流區間
  final int recommendedDifficulty;      // 系統自適應推薦難度 (1, 2, 3)
  final bool isConfidenceRestorerActive;// 是否啟動信心修復機制
  final DateTime lastUpdated;

  const CognitiveState({
    required this.loadFactor,
    required this.consecutiveMistakes,
    required this.consecutiveSuccesses,
    required this.currentZone,
    required this.recommendedDifficulty,
    required this.isConfidenceRestorerActive,
    required this.lastUpdated,
  });

  factory CognitiveState.initial() => CognitiveState(
    loadFactor: 0.4, // 開機預設為舒適起點
    consecutiveMistakes: 0,
    consecutiveSuccesses: 0,
    currentZone: CognitiveFlowZone.flow,
    recommendedDifficulty: 2,
    isConfidenceRestorerActive: false,
    lastUpdated: DateTime.now(),
  );
}

/// Ray Kurzweil 自適應動態難度調節引擎 (DDA Engine)
class CognitiveLoadEngine {
  /// 核心步進運算：根據考生最新一次作答反應，更新神經認知狀態
  static CognitiveState processInteraction({
    required CognitiveState prevState,
    required bool isCorrect,
    required int questionDifficulty,
    required int timeSpentSeconds,
    DateTime? actionTimestamp,
  }) {
    final now = actionTimestamp ?? DateTime.now();

    // 1. 自然時間衰減 (Temporal Dissipation)：若休息超過 3 分鐘，認知負載自動向 0.35 基準冷卻
    final idleMinutes = now.difference(prevState.lastUpdated).inMinutes;
    double decayedLoad = prevState.loadFactor;
    if (idleMinutes >= 3) {
      final dissipation = min(0.3, (idleMinutes - 2) * 0.05);
      decayedLoad = max(0.3, decayedLoad - dissipation);
    }

    // 2. 依據作答結果計算認知衝擊量 (Cognitive Delta)
    int newMistakes = prevState.consecutiveMistakes;
    int newSuccesses = prevState.consecutiveSuccesses;
    double deltaLoad = 0.0;

    if (!isCorrect) {
      newMistakes++;
      newSuccesses = 0;
      // 答錯加重負載，連續答錯以非線性遞增
      deltaLoad = 0.18 + (newMistakes * 0.06);
    } else {
      newSuccesses++;
      newMistakes = 0;
      // 答對釋放心理壓力，若秒殺（< 8秒）釋放更多
      final isInstantKill = timeSpentSeconds <= 8;
      deltaLoad = isInstantKill ? -0.15 : -0.08;
    }

    // 難度加權係數
    if (questionDifficulty == 3) deltaLoad += 0.08;
    if (questionDifficulty == 1) deltaLoad -= 0.05;

    final updatedLoad = (decayedLoad + deltaLoad).clamp(0.0, 1.0);

    // 3. 判定心流區間 (Flow Zone Classification)
    CognitiveFlowZone zone;
    int targetDiff;
    bool needRestorer = false;

    if (updatedLoad > 0.75 || newMistakes >= 2) {
      zone = CognitiveFlowZone.overload;
      targetDiff = 1; // 降級至難度 1 送分題
      needRestorer = true; // 啟動信心修復
    } else if (updatedLoad < 0.35 && newSuccesses >= 3) {
      zone = CognitiveFlowZone.boredom;
      targetDiff = 3; // 升級至難度 3 魔王題打破無聊
    } else {
      zone = CognitiveFlowZone.flow;
      targetDiff = 2; // 維持中階心流
    }

    return CognitiveState(
      loadFactor: double.parse(updatedLoad.toStringAsFixed(2)),
      consecutiveMistakes: newMistakes,
      consecutiveSuccesses: newSuccesses,
      currentZone: zone,
      recommendedDifficulty: targetDiff,
      isConfidenceRestorerActive: needRestorer,
      lastUpdated: now,
    );
  }

  /// 【Kurzweil 靶向選題演算法】：從候選題庫中挑選最契合當前心流狀態的一道題
  static QuestionItem selectFlowAlignedQuestion({
    required List<QuestionItem> pool,
    required CognitiveState cognitive,
  }) {
    if (pool.isEmpty) throw ArgumentError("題庫池不可為空");

    // 優先匹配推薦難度之考題
    final matchingDifficulty = pool.where((q) => q.difficulty == cognitive.recommendedDifficulty).toList();
    if (matchingDifficulty.isNotEmpty) {
      return matchingDifficulty.first;
    }

    // 次選中階題
    final fallback = pool.where((q) => q.difficulty == 2).toList();
    if (fallback.isNotEmpty) return fallback.first;

    return pool.first;
  }
}
