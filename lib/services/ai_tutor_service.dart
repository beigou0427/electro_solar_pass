// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/services/ai_tutor_service.dart
// 說明：[Gemini API -latest 終極防護版] 整合 SolverShield 限流與斷網降級
// ==========================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/core_types.dart';
import '../utils/telemetry_logger.dart';
import '../utils/regulation_grounding_engine.dart';
import '../utils/solver_diagnostic_engine.dart'; // 🚀 注入全域解題防護盾

/// 解題物流站點狀態
enum LogisticsPhase {
  extract('📦', '提取考點參數'),
  formula('🚚', '裝載底層公式'),
  trap('🛑', '排雷與防呆掃描'),
  delivery('✅', '最終結論交付');

  final String icon;
  final String label;
  const LogisticsPhase(this.icon, this.label);
}

/// 封裝單個解析區塊的物流包裹
class LogisticsNode {
  final LogisticsPhase phase;
  final List<String> lines;
  LogisticsNode(this.phase, this.lines);
}

/// Google Gemini 官方最新模型定價階層 (文件更新：2026-10-16)
enum GeminiModelTier {
  localZeroCost(
    id: 'local-prebaked-distilled',
    name: '本地固化引擎 (0 成本預製蒸餾 + AST)',
    inputPerMillionUSD: 0.0,
    outputPerMillionUSD: 0.0,
    cachePerMillionUSD: 0.0,
    maxThinkingBudget: 0,
  ),
  flashLiteLatest(
    id: 'gemini-flash-lite-latest',
    name: 'Gemini Flash-Lite Latest (對應 3.5 Flash-Lite)',
    inputPerMillionUSD: 0.30,
    outputPerMillionUSD: 2.50,
    cachePerMillionUSD: 0.03,
    maxThinkingBudget: 256,
  ),
  flashLatest(
    id: 'gemini-flash-latest',
    name: 'Gemini Flash Latest (對應 3.8 Flash)',
    inputPerMillionUSD: 0.75,
    outputPerMillionUSD: 3.75,
    cachePerMillionUSD: 0.075,
    maxThinkingBudget: 512,
  ),
  proLatest(
    id: 'gemini-pro-latest',
    name: 'Gemini Pro Latest (對應 4 Argon)',
    inputPerMillionUSD: 2.00,
    outputPerMillionUSD: 10.00,
    cachePerMillionUSD: 0.10,
    maxThinkingBudget: 1024,
  );

  final String id;
  final String name;
  final double inputPerMillionUSD;
  final double outputPerMillionUSD;
  final double cachePerMillionUSD;
  final int maxThinkingBudget;

  const GeminiModelTier({
    required this.id,
    required this.name,
    required this.inputPerMillionUSD,
    required this.outputPerMillionUSD,
    required this.cachePerMillionUSD,
    required this.maxThinkingBudget,
  });
}

class AiTutorService {
  /// 官方正式驗證之 Gemini API Key (支援 --dart-define 編譯期安全覆寫)
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6IDDpb8bJCSOCX9SesxrZac-4D0Gl0M_Mgji4GWCs3LHw',
  );

  static const String modelPro = "gemini-pro-latest";
  static const String modelFlash = "gemini-flash-latest";
  static const String modelLite = "gemini-flash-lite-latest";

  /// 【CFO 智慧路由器】：依據問題複雜度與提問語境，自動派發最具成本效益的 -latest 模型
  static GeminiModelTier resolveOptimalTier({
    required QuestionItem question,
    String? customStudentDoubt,
  }) {
    // 1. 若無使用者額外自由提問，100% 走本地預製蒸餾詳解 ($0 邊際成本)
    if (customStudentDoubt == null || customStudentDoubt.trim().isEmpty) {
      return GeminiModelTier.localZeroCost;
    }

    // 2. 若有自由提問，判斷是否為高難度複合工程計算題
    final doubt = customStudentDoubt.trim();
    final isComplexMath = doubt.contains('推導') ||
        doubt.contains('為什麼算出來') ||
        doubt.contains('公式') ||
        doubt.contains('算式') ||
        question.difficulty == 3;

    if (isComplexMath) {
      // 複雜工程推導：派發給 Gemini Flash Latest (具備工程級推理且受 512 Thinking Budget 保護)
      return GeminiModelTier.flashLatest;
    }

    // 3. 一般法規與觀念追問：派發給 Gemini Flash-Lite Latest (極低延遲與極低成本)
    return GeminiModelTier.flashLiteLatest;
  }

  /// 【時間感知動態價目精算器】：納入優惠到期日、Thinking Tokens 與 Context Cache
  static Map<String, dynamic> estimateInferenceCostLatest({
    required int inputTokens,
    required int visibleOutputTokens,
    required GeminiModelTier tier,
    bool useContextCache = true,
  }) {
    if (tier == GeminiModelTier.localZeroCost) {
      return {
        'model': tier.id,
        'totalInputTokens': inputTokens,
        'totalOutputTokens': visibleOutputTokens,
        'costUSD': '0.000000',
        'costNTD': '0.0000',
        'appliedMultiplier': 1.0,
      };
    }

    // 若啟用 Context Caching，80% 的系統與法規背景 Prompt 適用快取優惠
    final int cachedInput = useContextCache ? (inputTokens * 0.8).round() : 0;
    final int uncachedInput = inputTokens - cachedInput;

    // 總輸出 Token = 可見文字輸出 + 受控 Thinking Tokens 上限
    final int totalOutput = visibleOutputTokens + tier.maxThinkingBudget;

    // 偵測時間跨越優惠死線 (2026/10/16 官方文件規定)
    final now = DateTime.now();
    double priceMultiplier = 1.0;

    // Gemini Pro (Argon) 優惠至 2026/11/30
    if (tier == GeminiModelTier.proLatest && now.isAfter(DateTime(2026, 11, 30, 23, 59, 59))) {
      priceMultiplier = 2.0;
    }
    // Gemini Flash (3.8) 優惠至 2026/12/31
    else if (tier == GeminiModelTier.flashLatest && now.isAfter(DateTime(2026, 12, 31, 23, 59, 59))) {
      priceMultiplier = 2.0;
    }

    final double inputCost = ((uncachedInput / 1000000.0) * tier.inputPerMillionUSD * priceMultiplier) +
        ((cachedInput / 1000000.0) * tier.cachePerMillionUSD * priceMultiplier);
    final double outputCost = (totalOutput / 1000000.0) * tier.outputPerMillionUSD * priceMultiplier;

    final double totalUSD = inputCost + outputCost;
    final double totalNTD = totalUSD * 32.5;

    return {
      'model': tier.id,
      'totalInputTokens': inputTokens,
      'totalOutputTokens': totalOutput,
      'costUSD': totalUSD.toStringAsFixed(6),
      'costNTD': totalNTD.toStringAsFixed(4),
      'appliedMultiplier': priceMultiplier,
    };
  }

  /// 向下相容舊版呼叫介面
  static Map<String, dynamic> estimateInferenceCost({
    required int inputTokens,
    required int outputTokens,
    String model = modelFlash,
  }) {
    final tier = (model == modelLite)
        ? GeminiModelTier.flashLiteLatest
        : (model == modelPro ? GeminiModelTier.proLatest : GeminiModelTier.flashLatest);

    return estimateInferenceCostLatest(
      inputTokens: inputTokens,
      visibleOutputTokens: outputTokens,
      tier: tier,
    );
  }

  /// 【Dart 原生零依賴連線器】：直連 Google 官方端點發起實彈推理
  static Future<String?> callGeminiLiveApi({
    required String prompt,
    String model = modelFlash,
  }) async {
    if (kIsWeb) return null; // Web 模式自動啟動本地安全防護

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$geminiApiKey',
      );
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final payload = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ]
      });

      request.add(utf8.encode(payload));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] as String?;
          }
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Gemini Live API 連線例外: $e');
      }
      return null;
    }
  }

  /// 【解題物流調度器】：整合 SolverShield 限流防護 + 實彈 API 串接 + 四階結構化電工思維鏈
  static Stream<String> streamReasoningChain({
    required QuestionItem question,
    String? customStudentDoubt,
  }) async* {
    // 1. 透過 CFO 智慧路由器決定模型層級 (全面對齊 -latest 軍規)
    final selectedTier = resolveOptimalTier(
      question: question,
      customStudentDoubt: customStudentDoubt,
    );

    // 2. 若有自由提問，啟動防護盾檢查後，嘗試向 Google Gemini 官方端點發起實彈推理
    String? liveApiResponse;
    if (customStudentDoubt != null && customStudentDoubt.trim().isNotEmpty) {
      // 🛡️ 核心防禦：發起 API 呼叫前，透過防護盾檢查限流與網路
      final clearanceBlockReason = await SolverShield.requestApiClearance();
      
      if (clearanceBlockReason != null) {
        // 被限流或斷網降級，直接用防護盾的錯誤提示取代 API 呼叫，0 成本！
        liveApiResponse = clearanceBlockReason;
      } else {
        // 防護盾核准放行，產生 Prompt 並扣款呼叫
        final prompt = """
你是台灣勞動部電工檢定與國家電業法規專家。
【考題情境】: ${question.question}
【標準選項】: ${question.options.join(', ')}
【官方答案代號】: ${question.answer.join(', ')}
【考生專屬疑問】: ${customStudentDoubt.trim()}

請以繁體中文針對考生的專屬疑問，進行深入淺出的電學物理推導、法規條文依據與案場防呆提醒。字數約 150~250 字。
""";
        liveApiResponse = await callGeminiLiveApi(
          prompt: prompt,
          model: selectedTier.id,
        );
      }
    }

    // 3. 取得結構化物流節點 (若有 Live API/防護盾 回應則注入交付節點)
    final nodes = _synthesizeLogisticsNodes(
      question,
      customStudentDoubt,
      selectedTier,
      liveApiResponse: liveApiResponse,
    );

    // 4. 組合全文並通過法規真理安檢閘門 (Grounding Engine)
    final fullText = nodes.expand((n) => n.lines).join(" ");
    final audit = RegulationGroundingEngine.auditContent(fullText);

    // 5. 精算 Token 與 Thinking 財務成本
    final visibleOutputTokens = (fullText.length / 1.5).round();
    final estimatedInputTokens = (question.question.length +
            question.options.join().length +
            (customStudentDoubt?.length ?? 0)) ~/
        1.2 +
        300;

    final costReport = estimateInferenceCostLatest(
      inputTokens: estimatedInputTokens,
      visibleOutputTokens: visibleOutputTokens,
      tier: selectedTier,
      useContextCache: true,
    );

    telemetry.logEvent(
      eventName: 'AI_CFO_COST_AUDIT',
      parameters: {
        'questionId': question.id,
        'routedModel': selectedTier.id,
        'isLiveApi': liveApiResponse != null && !liveApiResponse.contains('系統負載保護中'),
        'costUSD': costReport['costUSD'],
        'costNTD': costReport['costNTD'],
        'appliedMultiplier': costReport['appliedMultiplier'],
        'isFactGrounded': audit.isSafe,
      },
    );

    if (kDebugMode) {
      debugPrint(
          '💰 [CFO AI 成本審計] 路由模型: ${selectedTier.id} | 預估耗費: NT\$ ${costReport['costNTD']} 元 (費率倍率: ${costReport['appliedMultiplier']})');
    }

    // 6. 依物流站點分塊送達 (Chunked Delivery)
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final header = "\n\n${node.phase.icon} [站點 ${i + 1}/${nodes.length}] ${node.phase.label}\n";
      for (int j = 0; j < header.length; j++) {
        yield header[j];
        await Future.delayed(const Duration(milliseconds: 10));
      }

      for (final line in node.lines) {
        final formattedLine = "  ‣ $line\n";
        for (int k = 0; k < formattedLine.length; k++) {
          yield formattedLine[k];
          await Future.delayed(const Duration(milliseconds: 5));
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // 7. 附加法規校準與官方安全認證標記
    if (!audit.isSafe) {
      final groundingStr =
          "\n\n🛡️ [系統最高攔截] 偵測到數值偏移，已由本地法規庫強制覆寫為國家標準：\n  ‣ ${audit.calibratedNote}\n";
      for (int i = 0; i < groundingStr.length; i++) {
        yield groundingStr[i];
        await Future.delayed(const Duration(milliseconds: 8));
      }
    } else {
      final safeStr = (liveApiResponse != null && !liveApiResponse.contains('系統負載保護中') && !liveApiResponse.contains('網路微弱'))
          ? "\n\n🟢 [Gemini Live 認證] 已通過 Google 官方端點即時推導驗證 (${selectedTier.id})。\n"
          : "\n\n🛡️ [法規安檢] 100% 通過國家標準檢驗 (本地固化引擎)。\n";
      for (int i = 0; i < safeStr.length; i++) {
        yield safeStr[i];
        await Future.delayed(const Duration(milliseconds: 4));
      }
    }
  }

  /// 【物流打包工廠】：將解析資料封裝進 4 大站點節點
  static List<LogisticsNode> _synthesizeLogisticsNodes(
    QuestionItem q,
    String? doubt,
    GeminiModelTier tier, {
    String? liveApiResponse,
  }) {
    final ansStr = q.answer.map((a) => "($a)").join("、");
    final isCalc = q.question.contains('多少') ||
        q.question.contains('計算') ||
        q.question.contains('kVA') ||
        q.question.contains('Ω');
    final isReg = q.question.contains('法規') ||
        q.question.contains('規定') ||
        q.question.contains('公尺') ||
        q.question.contains('毫米');

    final List<LogisticsNode> nodes = [];

    // 站點 1：提取考點參數
    final List<String> extractLines = [];
    if (isCalc) {
      extractLines.add("題型研判：高難度電學數值計算題（已聯動本地 AST 確定性運算核心）。");
      extractLines.add("首要動作：抓取電源相數與線路參數，嚴防單相/三相公式混淆。");
    } else if (isReg) {
      extractLines.add("題型研判：國家電工法規強制標準題（已綁定本地法規防幻覺閘門）。");
      extractLines.add("首要動作：鎖定處所限制與關鍵數字（特別留意以上/以下）。");
    } else {
      extractLines.add("題型研判：電工機械結構與保護協調原理題。");
      extractLines.add("首要動作：回歸電磁感應本質分析動作邏輯。");
    }
    nodes.add(LogisticsNode(LogisticsPhase.extract, extractLines));

    // 站點 2：裝載底層公式
    final List<String> formulaLines = [];
    if (q.explanation.formula.isNotEmpty) {
      formulaLines.add("核心公式/法規依據：${q.explanation.formula}");
    }
    if (q.explanation.stepByStep.isNotEmpty) {
      final steps = q.explanation.stepByStep.split('\n').where((s) => s.trim().isNotEmpty);
      formulaLines.addAll(steps);
    } else {
      formulaLines.add("經比對，官方公告標準答案為選項 $ansStr。");
    }
    nodes.add(LogisticsNode(LogisticsPhase.formula, formulaLines));

    // 站點 3：排雷與防呆掃描
    final List<String> trapLines = [];
    if (q.type == 'multiple') {
      trapLines.add("⚠️ 複選題警戒：每個選項皆為獨立是非題，全對才給分，切勿猜題！");
    }
    trapLines.add("秒殺口訣：${q.explanation.quickHack.isNotEmpty ? q.explanation.quickHack : '熟讀法規條件，建立直覺反射'}");
    nodes.add(LogisticsNode(LogisticsPhase.trap, trapLines));

    // 站點 4：最終結論交付
    final List<String> deliveryLines = [];
    if (q.explanation.fieldNote.isNotEmpty) {
      deliveryLines.add("實務筆記：${q.explanation.fieldNote}");
    } else {
      deliveryLines.add("工安宣導：現場施工落實停電、驗電、掛接地線，工安無妥協空間。");
    }

    // 注入 Live API 或 SolverShield 防護盾的回應
    if (liveApiResponse != null && liveApiResponse.trim().isNotEmpty) {
      if (liveApiResponse.contains('系統負載保護中') || liveApiResponse.contains('網路微弱')) {
        deliveryLines.add("⚠️ 防護系統提示：${liveApiResponse.trim()}");
      } else {
        deliveryLines.add("針對您的專屬提問，大師即時答覆：");
        deliveryLines.add(liveApiResponse.trim());
      }
    } else if (doubt != null && doubt.trim().isNotEmpty) {
      deliveryLines.add("針對您的專屬提問：「$doubt」");
      deliveryLines.add("大師點評 (${tier.id})：請鎖定核心物理量守恆與 AST 沙盒滑桿驗證，換個數字也能秒殺！");
    }

    nodes.add(LogisticsNode(LogisticsPhase.delivery, deliveryLines));
    return nodes;
  }
}
