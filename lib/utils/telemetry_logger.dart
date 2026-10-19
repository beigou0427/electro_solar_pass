// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/utils/telemetry_logger.dart
// COO 注入：Sheryl Sandberg (Meta) - 第 1/3 段：獨立遙測地基
// 說明：企業級行為追蹤探針 (Telemetry Probe)
// ==========================================

import 'package:flutter/foundation.dart'; // 引入 debugPrint

class TelemetryLogger {
  // 單例模式 (Singleton)，確保全域共用同一個日誌串流
  static final TelemetryLogger _instance = TelemetryLogger._internal();
  factory TelemetryLogger() => _instance;
  TelemetryLogger._internal();

  // 本地快取日誌，未來可擴充自動打包上傳伺服器
  final List<Map<String, dynamic>> _logs = [];

  /// 紀錄核心營運事件 (Event Tracking)
  void logEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) {
    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'event': eventName,
      'params': parameters ?? {},
    };
    
    _logs.add(logEntry);

    // 僅在開發模式下印出，避免影響生產環境 (Release Build) 效能
    if (kDebugMode) {
      debugPrint('📊 [Sheryl Sandberg Telemetry] $eventName | Params: $parameters');
    }
  }

  /// 取得所有日誌 (供管理員匯出或分析用)
  List<Map<String, dynamic>> exportLogs() {
    return List.unmodifiable(_logs);
  }
}

// 建立全域快捷實例
final telemetry = TelemetryLogger();
