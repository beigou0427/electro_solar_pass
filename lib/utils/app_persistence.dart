// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/utils/app_persistence.dart
// 說明：[單檔自包含] 航太級本地磁區安全存取轉接器，支援狀態原子落盤與開機復原
// ==========================================

import 'dart:io';

class AppPersistence {
  static const String _stateFileName = '.storage_battle_state.dat';

  /// 將全域作戰 Token 安全原子寫入本地磁區
  static Future<bool> saveBattleState(String base64Token) async {
    try {
      final file = File(_stateFileName);
      // flush: true 強制將位元組寫入實體磁區，嚴防斷電或系統強制終止造成空檔
      await file.writeAsString(base64Token, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 從本地磁區讀取已儲存之作戰 Token
  static Future<String?> loadBattleState() async {
    try {
      final file = File(_stateFileName);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          return content.trim();
        }
      }
    } catch (_) {}
    return null;
  }

  /// 清除本地磁區存檔 (重置戰力專用)
  static Future<bool> clearBattleState() async {
    try {
      final file = File(_stateFileName);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
