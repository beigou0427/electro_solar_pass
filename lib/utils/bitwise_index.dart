// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/utils/bitwise_index.dart
// CTO 注入：John Carmack (id Software / Oculus) - 第 1/3 段：二進位位元遮罩極速索引
// 說明：[極限效能] 消除字串比對與 GC 停頓，以 CPU 單週期位元運算進行 813 題奈秒級檢索
// ==========================================

import '../models/core_types.dart';

/// John Carmack 32 位元二進位屬性旗標 (Bit Flags)
class CarmackBitFlags {
  // 職類屬性 (Bits 0~1)
  static const int category00700 = 1 << 0; // 00000001 (1)
  static const int category21000 = 1 << 1; // 00000010 (2)

  // 題型屬性 (Bits 2~3)
  static const int typeSingle    = 1 << 2; // 00000100 (4)
  static const int typeMultiple  = 1 << 3; // 00001000 (8)

  // 難度屬性 (Bits 4~6)
  static const int difficulty1   = 1 << 4; // 00010000 (16)
  static const int difficulty2   = 1 << 5; // 00100000 (32)
  static const int difficulty3   = 1 << 6; // 01000000 (64)

  // 付費與權限屬性 (Bit 7)
  static const int isFree        = 1 << 7; // 10000000 (128)

  // 動態認知狀態 (Bits 8~11)
  static const int statusMastered = 1 << 8; // 256
  static const int statusWrong    = 1 << 9; // 512
  static const int statusBookmarked = 1 << 10; // 1024
  static const int statusDue      = 1 << 11; // 2048

  // 全通遮罩 (All Match)
  static const int matchAll = 0;
}

/// John Carmack 高效位元快取條目
class IndexedQuestionRef {
  final int index;      // 題目在原陣列的索引 (0 ~ 812)
  final String id;      // 題目 ID
  final int staticMask; // 固化靜態遮罩 (類別、題型、難度)

  const IndexedQuestionRef({
    required this.index,
    required this.id,
    required this.staticMask,
  });
}

/// Carmack 零記憶體配置二進位索引矩陣
class BitwiseQuestionIndex {
  final List<IndexedQuestionRef> _refs;

  BitwiseQuestionIndex._(this._refs);

  /// 靜態工廠：為全量題庫建立連續記憶體位元索引
  factory BitwiseQuestionIndex.build(List<QuestionItem> bank) {
    final List<IndexedQuestionRef> list = List.generate(bank.length, (i) {
      final q = bank[i];
      int mask = 0;

      // 1. 職類編碼
      if (q.category == CategoryType.roomWiring) {
        mask |= CarmackBitFlags.category00700;
      } else {
        mask |= CarmackBitFlags.category21000;
      }

      // 2. 題型編碼
      if (q.type == 'single') {
        mask |= CarmackBitFlags.typeSingle;
      } else {
        mask |= CarmackBitFlags.typeMultiple;
      }

      // 3. 難度編碼
      if (q.difficulty == 1) {
        mask |= CarmackBitFlags.difficulty1;
      } else if (q.difficulty == 2) {
        mask |= CarmackBitFlags.difficulty2;
      } else {
        mask |= CarmackBitFlags.difficulty3;
      }

      // 4. 付費屬性
      if (q.isFree) {
        mask |= CarmackBitFlags.isFree;
      }

      return IndexedQuestionRef(
        index: i,
        id: q.id,
        staticMask: mask,
      );
    });

    return BitwiseQuestionIndex._(list);
  }

  /// 【Carmack 終極檢索】：CPU 位元運算過濾，耗時趨近於 0
  /// [queryMask]: 必須同時滿足的位元組合 (AND 邏輯)
  /// [dynamicStateProvider]: 提供即時動態位元 (已斬殺、錯題、瀕危等)
  List<int> queryIndices({
    required int queryMask,
    int Function(String questionId)? dynamicStateProvider,
  }) {
    if (queryMask == CarmackBitFlags.matchAll && dynamicStateProvider == null) {
      // 快速路徑：無條件全選，直接返回所有索引
      return List.generate(_refs.length, (i) => i);
    }

    final List<int> resultIndices = [];

    for (int i = 0; i < _refs.length; i++) {
      final ref = _refs[i];
      int fullMask = ref.staticMask;

      // 若有動態狀態，熔接動態位元
      if (dynamicStateProvider != null) {
        fullMask |= dynamicStateProvider(ref.id);
      }

      // Carmack 核心：單一條 CPU 位元指令完成全量校驗
      if ((fullMask & queryMask) == queryMask) {
        resultIndices.add(ref.index);
      }
    }

    return resultIndices;
  }
}
