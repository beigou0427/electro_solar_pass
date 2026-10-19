// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/models/event_sourcing_store.dart
// CTO 注入：Brendan Eich (JS 之父 / Mozilla) - 第 1/3 段：事件溯源與學習時光機
// 說明：[Event Sourcing] 不可篡改領域事件流、微秒級行為溯源與任意歷史狀態重播
// ==========================================

import 'dart:convert';
import 'core_types.dart';

/// 領域事件型別列舉
enum StudyEventType {
  questionAttempted("題目作答"),
  ratingApplied("神經評級"),
  streakMaintained("戰鬥打卡"),
  licenseUnlocked("金流解鎖"),
  cheatSheetExported("小抄生成");

  final String label;
  const StudyEventType(this.label);
}

/// Brendan Eich 不可變事件紀錄 (Immutable Event Record)
class StudyEventRecord {
  final String eventId;
  final DateTime timestamp;
  final StudyEventType type;
  final Map<String, dynamic> payload;

  const StudyEventRecord({
    required this.eventId,
    required this.timestamp,
    required this.type,
    required this.payload,
  });

  Map<String, dynamic> toMap() => {
    'id': eventId,
    'ts': timestamp.toIso8601String(),
    'type': type.name,
    'data': payload,
  };

  factory StudyEventRecord.fromMap(Map<String, dynamic> map) {
    return StudyEventRecord(
      eventId: map['id'] as String? ?? '',
      timestamp: DateTime.tryParse(map['ts'] as String? ?? '') ?? DateTime.now(),
      type: StudyEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => StudyEventType.questionAttempted,
      ),
      payload: Map<String, dynamic>.from(map['data'] ?? {}),
    );
  }
}

/// Brendan Eich 事件溯源儲存庫與時光機大腦
class EventSourcingStore {
  final List<StudyEventRecord> _eventStream = [];

  List<StudyEventRecord> get eventStream => List.unmodifiable(_eventStream);
  int get totalEventCount => _eventStream.length;

  /// 追加不可變事件 (Append-Only Event)
  void appendEvent({
    required StudyEventType type,
    required Map<String, dynamic> payload,
    DateTime? eventTime,
  }) {
    final now = eventTime ?? DateTime.now();
    final event = StudyEventRecord(
      eventId: "EVT-${now.microsecondsSinceEpoch}",
      timestamp: now,
      type: type,
      payload: payload,
    );
    _eventStream.add(event);
  }

  /// 【時光倒流核心 (Time Machine Replay)】
  /// 傳入過去任意時間點 [targetTime]，重播事件流，精確重建該時刻的作戰狀態！
  UserProfile replayStateAt(DateTime targetTime) {
    final historicalProfile = UserProfile(licenseTier: LicenseTier.free);

    // 依時間排序並過濾截止至 targetTime 的所有歷史事件
    final pastEvents = _eventStream.where((e) => e.timestamp.isBefore(targetTime) || e.timestamp.isAtSameMomentAs(targetTime)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final event in pastEvents) {
      switch (event.type) {
        case StudyEventType.questionAttempted:
          final qId = event.payload['questionId'] as String?;
          final isCorrect = event.payload['isCorrect'] as bool? ?? false;
          if (qId != null) {
            if (!isCorrect) {
              if (!historicalProfile.wrongQueueIds.contains(qId)) {
                historicalProfile.wrongQueueIds.add(qId);
              }
              historicalProfile.masteredIds.remove(qId);
            }
          }
          break;

        case StudyEventType.ratingApplied:
          final qId = event.payload['questionId'] as String?;
          final rating = event.payload['rating'] as String?;
          if (qId != null) {
            if (rating == 'again') {
              if (!historicalProfile.wrongQueueIds.contains(qId)) {
                historicalProfile.wrongQueueIds.add(qId);
              }
              historicalProfile.masteredIds.remove(qId);
            } else if (rating == 'good' || rating == 'easy') {
              if (!historicalProfile.masteredIds.contains(qId)) {
                historicalProfile.masteredIds.add(qId);
              }
              historicalProfile.wrongQueueIds.remove(qId);
            }
          }
          break;

        case StudyEventType.licenseUnlocked:
          historicalProfile.licenseTier = LicenseTier.proLifetime;
          break;

        case StudyEventType.streakMaintained:
        case StudyEventType.cheatSheetExported:
          // 不影響核心題目狀態
          break;
      }
    }

    return historicalProfile;
  }

  /// 日誌快照壓縮 (Log Compaction)：將全部事件序列化為輕量字串
  String exportEventLogJson() {
    return jsonEncode(_eventStream.map((e) => e.toMap()).toList());
  }

  /// 載入歷史事件流
  void importEventLogJson(String jsonStr) {
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      _eventStream.clear();
      for (final item in list) {
        _eventStream.add(StudyEventRecord.fromMap(Map<String, dynamic>.from(item)));
      }
    } catch (_) {}
  }
}
