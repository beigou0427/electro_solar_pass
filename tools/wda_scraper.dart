// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：tools/wda_scraper.dart
// COO 注入：Javier Olivan (Meta) - 第 1/3 段：自動化爬蟲與解析引擎
// 說明：勞動部(WDA)官方題庫格式 Regex 自動解析器
// ==========================================

import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  print('🚀 [Javier Olivan] 啟動勞動部題庫自動化爬蟲與解析引擎...');

  // 1. 鎖定目標：勞動部標準試卷格式
  // (實務上你可以把 PDF 複製成純文字存入 raw_questions.txt，或直接透過 http.get 爬取線上測驗網)
  // 這裡我內建了一段從官方題庫複製出來的「髒資料 (Raw Data)」，包含單複選
  final rawData = '''
1. (3) 單相二線式之低壓110 伏特瓦時計，其電源非接地導線應接於： (1)1L 端 (2)2L 端 (3)1S 端 (4)2S 端。
2. (2) 截面積14 平方毫米之銅絞線，係由7 股多少毫米之單芯銅線絞合而成？ (1)1.0 (2)1.6 (3)2.0 (4)2.6。
3. (1,2,3) 依據法規，下列哪些場所必須裝設漏電斷路器？ ①浴室 ②游泳池 ③臨時用電 ④乾燥天花板。
  ''';

  print('⏳ 正在進行 Regex 正規表示式深度匹配...');

  // 2. 針對台灣技能檢定格式打造的終極 Regex (支援 1,2,3 複選與 ①②③④ 特殊符號)
  final RegExp regex = RegExp(
    r'\d+\.\s*\(([\d,]+)\)\s*(.*?)\s*(?:\(1\)|①)(.*?)(?:\(2\)|②)(.*?)(?:\(3\)|③)(.*?)(?:\(4\)|④)(.*?)(?=\n\d+\.|$)',
    dotAll: true,
  );

  final matches = regex.allMatches(rawData);
  final List<Map<String, dynamic>> outputList = [];
  int count = 0;

  for (final match in matches) {
    try {
      // 3. 解析答案 (區分單選與複選)
      final rawAnswer = match.group(1)!.trim();
      final isMultiple = rawAnswer.contains(',');
      final answerList = isMultiple 
          ? rawAnswer.split(',').map((e) => int.parse(e.trim())).toList()
          : [int.parse(rawAnswer)];

      // 4. 解析題幹與選項
      final question = match.group(2)!.trim();
      final opt1 = match.group(3)!.trim().replaceAll('。', '');
      final opt2 = match.group(4)!.trim().replaceAll('。', '');
      final opt3 = match.group(5)!.trim().replaceAll('。', '');
      final opt4 = match.group(6)!.trim().replaceAll('。', '');

      // 5. 組裝成我們 App 的強型別 JSON 格式
      outputList.add({
        "id": "Q-00700-AUTO-${(count + 1).toString().padLeft(4, '0')}",
        "category": "00700_B",
        "categoryLabel": "乙級室內配線 (自動爬取)",
        "workItem": "歷屆試題批次匯入",
        "type": isMultiple ? "multiple" : "single",
        "difficulty": 2,
        "isFree": false,
        "question": question,
        "options": [opt1, opt2, opt3, opt4],
        "answer": answerList,
        "explanation": {
          "quickHack": "⚡ 此題由系統自動匯入",
          "formula": "勞動部官方標準答案",
          "stepByStep": "本題正解為 $rawAnswer",
          "fieldNote": "AI 正在分析本題實務考點..."
        }
      });
      count++;
    } catch (e) {
      print('⚠️ 警告：第 ${count + 1} 題解析失敗，跳過。錯誤：$e');
    }
  }

  // 6. 輸出 JSON 檔案
  final outputFile = File('scraped_wda_bank.json');
  await outputFile.writeAsString(jsonEncode(outputList));
  
  print('✅ 解析完成！成功萃取 $count 道真題。');
  print('📁 檔案已匯出至：${outputFile.absolute.path}');
}
