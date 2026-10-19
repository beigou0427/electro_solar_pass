// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/utils/cheat_sheet_generator.dart
// 說明：[PRO專屬] 考前弱點衝刺小抄 HTML 合成引擎
// ==========================================

import '../models/core_types.dart';

class CheatSheetGenerator {
  /// 生成可直接 Print-to-PDF 的高對比考前小抄 HTML
  static String buildHtmlDocument({
    required List<QuestionItem> wrongQuestions,
    required String licenseType,
  }) {
    final now = DateTime.now();
    final dateStr = "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}";

    if (wrongQuestions.isEmpty) {
      return """
<!DOCTYPE html>
<html>
<head><meta charset='utf-8'><title>考前弱點小抄</title></head>
<body style="font-family: sans-serif; text-align: center; padding: 50px; color: #334155;">
  <h2>🎉 太強了！目前沒有任何待消滅的錯題。</h2>
  <p>您的實戰答對率已達標，請直接前往考場領取證照！</p>
</body>
</html>
""";
    }

    final buffer = StringBuffer();
    buffer.writeln("<!DOCTYPE html><html><head><meta charset='utf-8'>");
    buffer.writeln("<title>電光證照霸 PRO - 考前 10 分鐘弱點衝刺小抄</title>");
    buffer.writeln("<style>");
    buffer.writeln("""
      @page { size: A4; margin: 15mm; }
      body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "PingFang TC", sans-serif; color: #0f172a; line-height: 1.5; font-size: 13px; margin: 0; padding: 10px; }
      .header { border-bottom: 2px solid #0f172a; padding-bottom: 8px; margin-bottom: 16px; display: flex; justify-content: space-between; align-items: flex-end; }
      .title { font-size: 20px; font-weight: 800; color: #0f172a; margin: 0; }
      .meta { font-size: 11px; color: #64748b; }
      .warning-box { background: #fff1f2; border-left: 4px solid #f43f5e; padding: 8px 12px; margin-bottom: 16px; font-size: 12px; color: #9f1239; }
      .question-card { border: 1px solid #cbd5e1; border-radius: 6px; padding: 10px 12px; margin-bottom: 12px; page-break-inside: avoid; background: #ffffff; }
      .q-header { display: flex; justify-content: space-between; margin-bottom: 4px; font-weight: 700; font-size: 12px; color: #475569; }
      .q-text { font-size: 13px; font-weight: 600; color: #0f172a; margin-bottom: 6px; }
      .q-ans { color: #059669; font-weight: 800; font-size: 12px; margin-bottom: 4px; }
      .box-hack { background: #fefce8; border: 1px solid #fef08a; padding: 6px 10px; border-radius: 4px; margin-top: 4px; font-size: 11.5px; }
      .box-formula { background: #f0fdf4; border: 1px solid #bbf7d0; padding: 6px 10px; border-radius: 4px; margin-top: 4px; font-size: 11.5px; color: #166534; }
      .print-btn { background: #0284c7; color: white; border: none; padding: 8px 16px; border-radius: 4px; font-weight: 700; cursor: pointer; margin-bottom: 16px; }
      @media print {
        .print-btn { display: none; }
        body { padding: 0; }
        .question-card { border: 1px solid #94a3b8; }
      }
    """);
    buffer.writeln("</style></head><body>");

    buffer.writeln("<button class='print-btn' onclick='window.print()'>🖨️ 點此列印 / 另存為 PDF 小抄 (Ctrl+P)</button>");
    buffer.writeln("<div class='header'>");
    buffer.writeln("  <div><h1 class='title'>⚡ 電光證照霸 PRO - 考前救命弱點小抄</h1><div class='meta'>職類標的：$licenseType ｜ 個人待消滅錯題總整理</div></div>");
    buffer.writeln("  <div class='meta'>產出日期：$dateStr ｜ 共 ${wrongQuestions.length} 題弱點</div>");
    buffer.writeln("</div>");

    buffer.writeln("<div class='warning-box'>⚠️ <strong>考前 10 分鐘作戰守則</strong>：進考場手機關機前，專注複習本單之「一秒口訣」與「法規數值」，把失去的 20 分全部討回來！</div>");

    for (int i = 0; i < wrongQuestions.length; i++) {
      final q = wrongQuestions[i];
      final ansStr = q.answer.map((a) => "(${a})").join("、");

      buffer.writeln("<div class='question-card'>");
      buffer.writeln("  <div class='q-header'><span>#${i + 1} [${q.id}] ${q.workItem}</span><span>${q.type == 'single' ? '單選題' : '⚠️ 複選題'}</span></div>");
      buffer.writeln("  <div class='q-text'>${q.question}</div>");
      buffer.writeln("  <div class='q-ans'>🎯 官方標準正解：$ansStr</div>");

      if (q.explanation.quickHack.isNotEmpty) {
        buffer.writeln("  <div class='box-hack'><strong>⚡ 一秒口訣：</strong>${q.explanation.quickHack}</div>");
      }
      if (q.explanation.formula.isNotEmpty) {
        buffer.writeln("  <div class='box-formula'><strong>📐 核心算式/條號：</strong>${q.explanation.formula}</div>");
      }
      buffer.writeln("</div>");
    }

    buffer.writeln("</body></html>");
    return buffer.toString();
  }
}
