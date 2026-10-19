// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：test/widget_test.dart
// 說明：[上架前品管測試流水線] 題庫健康度、AST 運算與 UI 煙霧驗收測試 (依賴修復版)
// ==========================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:electro_solar_pass/main.dart';
import 'package:electro_solar_pass/data/question_bank.dart';
import 'package:electro_solar_pass/providers/app_state.dart';
import 'package:electro_solar_pass/utils/preflight_inspector.dart';
import 'package:electro_solar_pass/utils/ast_math_evaluator.dart';
import 'package:electro_solar_pass/utils/calculators.dart';
import 'package:electro_solar_pass/utils/memory_engine.dart';
import 'package:electro_solar_pass/models/core_types.dart';

void main() {
  group('【品管第一防線：題庫健康度與資料完整性驗證】', () {
    test('題庫 JSON 解碼正確，無空值且物件化正常', () {
      expect(initialQuestionBank, isNotEmpty, reason: '初始題庫不應為空');
      for (final q in initialQuestionBank) {
        expect(q.id, isNotEmpty, reason: '每道考題必須具備唯一 ID');
        expect(q.question.trim(), isNotEmpty, reason: '題幹內容不可為空白');
        expect(q.options.length, greaterThanOrEqualTo(2), reason: '選項數必須大於等於 2');
        expect(q.answer, isNotEmpty, reason: '正解清單不可為空');
      }
    });

    test('航太級巡檢器 (Preflight Inspector) 掃描驗證良率 100%', () {
      final report = AerospacePreflightInspector.inspectAndSanitize(
        rawBank: initialQuestionBank,
        onBankSanitized: (sanitized) {
          expect(sanitized.length, equals(initialQuestionBank.length));
        },
      );

      expect(report.isFlightReady, isTrue, reason: '題庫應處於發射就緒狀態 (Zero Quarantine)');
      expect(report.quarantinedCount, equals(0), reason: '隔離異常題數必須為 0');
      expect(report.healthyCount, equals(initialQuestionBank.length));
    });

    test('答案索引合法性檢驗 (1-based index 落在選項長度內)', () {
      for (final q in initialQuestionBank) {
        for (final ansIndex in q.answer) {
          expect(ansIndex, greaterThanOrEqualTo(1), reason: '答案必須為 1-based index');
          expect(ansIndex, lessThanOrEqualTo(q.options.length),
              reason: '答案指標 ($ansIndex) 不能超出選項總數 (${q.options.length})，題目 ID: ${q.id}');
        }
      }
    });

    test('題庫 ID 唯一性校驗 (Zero Collision)', () {
      final Set<String> idSet = {};
      for (final q in initialQuestionBank) {
        expect(idSet.contains(q.id), isFalse, reason: '發現重複的題目 ID: ${q.id}');
        idSet.add(q.id);
      }
      expect(idSet.length, equals(initialQuestionBank.length));
    });
  });

  group('【品管第二防線：底層數學與確定性 AST 運算驗證】', () {
    test('AST 運算子優先順序與括號遞歸下降解析', () {
      expect(ElectricalAstEvaluator.evaluate('10 + 20 * 2'), equals(50.0));
      expect(ElectricalAstEvaluator.evaluate('(10 + 20) * 2'), equals(60.0));
      expect(ElectricalAstEvaluator.evaluate('2 ^ 3'), equals(8.0));
    });

    test('電學專用公式與常數 (sqrt3, pi) 動態環境變數求值', () {
      final pThreePhase = ElectricalAstEvaluator.evaluate(
        'sqrt3 * V * I * pf',
        {'V': 220.0, 'I': 50.0, 'pf': 0.85},
      );
      expect(pThreePhase, closeTo(16194.67, 0.1));

      final vvCapacity = ElectricalAstEvaluator.evaluate(
        'sqrt3 * P1',
        {'P1': 50.0},
      );
      expect(vvCapacity, closeTo(86.60, 0.05));

      final synchSpeed = ElectricalAstEvaluator.evaluate(
        '(120 * f) / P',
        {'f': 60.0, 'P': 4.0},
      );
      expect(synchSpeed, equals(1800.0));
    });

    test('AST 數學邊界異常防護 (除以零、未定義變數與負數根號拋出 FormatException)', () {
      expect(() => ElectricalAstEvaluator.evaluate('100 / 0'), throwsA(isA<FormatException>()));
      expect(() => ElectricalAstEvaluator.evaluate('V * unknownVar', {'V': 110.0}),
          throwsA(isA<FormatException>()));
      expect(() => ElectricalAstEvaluator.evaluate('sqrt(-4)'), throwsA(isA<FormatException>()));
    });

    test('案場工程計算機 (Voc、壓降、功因改善) 演算法邊界驗證', () {
      final vocRes = EngineeringCalculators.calcSolarVoc(
        vocSTC: 41.5,
        tempCoeff: -0.29,
        minTemp: 5.0,
        seriesCount: 22,
        maxInverterV: 1000.0,
      );
      expect(vocRes['singleMaxVoc'], isNotNull);
      expect(vocRes['safeMaxSeries'], isA<int>());
      expect(vocRes['isSafe'], isA<bool>());

      final vdRes = EngineeringCalculators.calcVoltageDrop(
        phaseType: '1P2W',
        voltage: 220.0,
        current: 20.0,
        length: 50.0,
        resistancePerKm: 3.57,
      );
      expect(vdRes['deltaV'], isNotNull);
      expect(vdRes['isCompliant'], isA<bool>());

      final pfRes = EngineeringCalculators.calcPowerFactor(
        powerKW: 100.0,
        currentPF: 0.72,
        targetPF: 0.95,
      );
      expect(pfRes.containsKey('qcKVAR'), isTrue);
      expect(pfRes['qcKVAR'], isNotNull);

      final errorPfRes = EngineeringCalculators.calcPowerFactor(
        powerKW: 100.0,
        currentPF: 1.5,
        targetPF: 0.95,
      );
      expect(errorPfRes.containsKey('error'), isTrue);
    });
  });

  group('【品管第三防線：全域狀態大腦與 Widget 渲染煙霧測試】', () {
    test('AppState 狀態機、FSRS 記憶評級與 Git 分支自洽性驗證', () {
      final state = AppState();
      expect(state.allQuestions, isNotEmpty);

      final firstQ = state.allQuestions.first;
      state.processQuestionReview(questionId: firstQ.id, rating: StudyRating.good);
      expect(state.memoryStates.containsKey(firstQ.id), isTrue);

      final commit = state.commitSkillMilestone('test: 品管測試提交');
      expect(commit.commitHash, isNotEmpty);
      expect(commit.branchName, equals('main'));

      final unlockSuccess = state.activateLicense('VIP888');
      expect(unlockSuccess, isTrue);
      expect(state.isPro, isTrue);
    });

    testWidgets('應用程式冷啟動掛載，5大導航分頁切換煙霧測試', (WidgetTester tester) async {
      await tester.pumpWidget(const ElectroSolarPassHeroApp());
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('戰情室'), findsWidgets);

      await tester.tap(find.text('刷題斬'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('模擬考'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('計算機'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('PRO解鎖'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PRO解鎖'), findsWidgets);
    });
  });
}
