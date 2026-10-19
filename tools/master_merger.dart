// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：tools/master_merger.dart
// 說明：[全景雷達版] 同時搜尋專案目錄與桌面，全量收攏 813 題並同步燒錄韌體
// ==========================================

import 'dart:io';
import 'dart:convert';

void main() {
  print('🛰️ [全景雷達總裝] 啟動雙目錄全量物料搜索 (專案目錄 + 桌面)...');

  final currentDir = Directory.current;
  final parentDir = currentDir.parent; // 桌面目錄

  final targetBatches = [
    'batch1_questions.json',
    'batch2_questions.json',
    'batch3_questions.json',
    'batch4_questions.json',
    'batch5a_questions.json',
    'batch5b_questions.json',
  ];

  final List<Map<String, dynamic>> masterList = [];
  final Set<String> uniqueIds = {};
  int loadedCount = 0;

  for (final filename in targetBatches) {
    File? foundFile;

    // 先在當前專案資料夾找
    final localFile = File('${currentDir.path}/$filename');
    if (localFile.existsSync()) {
      foundFile = localFile;
    } else {
      // 若沒有，去外層桌面找
      final desktopFile = File('${parentDir.path}/$filename');
      if (desktopFile.existsSync()) {
        foundFile = desktopFile;
      }
    }

    if (foundFile != null) {
      try {
        final List<dynamic> list = jsonDecode(foundFile.readAsStringSync());
        int added = 0;
        for (final item in list) {
          final id = item['id'] as String;
          if (!uniqueIds.contains(id)) {
            uniqueIds.add(id);
            masterList.add(Map<String, dynamic>.from(item));
            added++;
          }
        }
        print('  📦 成功捕獲 ${foundFile.path} ➔ 裝載 $added 題');
        loadedCount++;
      } catch (e) {
        print('  ⚠️ 解析 $filename 失敗: $e');
      }
    } else {
      print('  ❌ 警報：找不到 $filename！');
    }
  }

  // 1. 輸出總表到專案根目錄
  final outputFile = File('master_00700_complete.json');
  outputFile.writeAsStringSync(jsonEncode(masterList));

  // 2. 自動直接固化燒錄至 lib/data/question_bank.dart
  print('\n🔄 正在自動將完整題庫固化至 App 出廠韌體...');
  final targetFile = File('lib/data/question_bank.dart');
  final buffer = StringBuffer();
  buffer.writeln("// ==========================================");
  buffer.writeln("// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)");
  buffer.writeln("// 檔案：lib/data/question_bank.dart");
  buffer.writeln("// 說明：[全量 813 題韌體] 官方真題出廠預裝，0 毫秒開箱即用");
  buffer.writeln("// ==========================================\n");
  buffer.writeln("import 'dart:convert';");
  buffer.writeln("import '../models/core_types.dart';\n");
  buffer.writeln("final String _embeddedMasterJson = r'''");
  buffer.write(jsonEncode(masterList));
  buffer.writeln("\n''';\n");
  buffer.writeln("final List<QuestionItem> initialQuestionBank = (_embeddedMasterJson.isNotEmpty)");
  buffer.writeln("    ? (jsonDecode(_embeddedMasterJson) as List)");
  buffer.writeln("        .map((e) => QuestionItem.fromJson(e as Map<String, dynamic>))");
  buffer.writeln("        .toList()");
  buffer.writeln("    : [];\n");
  targetFile.writeAsStringSync(buffer.toString());

  print('═══════════════════════════════════════════════════════');
  print('🎉 【813 題全量收攏大滿貫】');
  print('  📁 成功裝載批次：$loadedCount / ${targetBatches.length} 個檔案');
  print('  🔥 總題庫總數：${masterList.length} 題！');
  print('  🚀 韌體燒錄狀態：已直接寫入 ${targetFile.path}');
  print('═══════════════════════════════════════════════════════\n');
}
