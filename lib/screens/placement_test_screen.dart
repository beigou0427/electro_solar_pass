// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/screens/placement_test_screen.dart
// 說明：[10分鐘實力落點快測] 跨 8 大領域 15 題抽樣診斷與得分預測 (依賴補齊版)
// ==========================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/core_types.dart';
import '../models/skill_tree_domain.dart';
import '../utils/telemetry_logger.dart'; // 🚀 補齊 telemetry 遙測探針引用
import '../main.dart';

/// 實力快測診斷報告模型
class PlacementDiagnosticReport {
  final int totalQuestions;
  final int correctCount;
  final double predictedScore;
  final ElectricalDomain weakestDomain;
  final Map<ElectricalDomain, int> domainScores;

  const PlacementDiagnosticReport({
    required this.totalQuestions,
    required this.correctCount,
    required this.predictedScore,
    required this.weakestDomain,
    required this.domainScores,
  });

  bool get isPredictedPass => predictedScore >= 60.0;
}

class PlacementTestScreen extends StatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  State<PlacementTestScreen> createState() => _PlacementTestScreenState();
}

class _PlacementTestScreenState extends State<PlacementTestScreen> {
  List<QuestionItem> _paper = [];
  final Map<int, List<int>> _userAnswers = {};
  int _currentIndex = 0;
  bool _isFinished = false;
  PlacementDiagnosticReport? _report;

  @override
  void initState() {
    super.initState();
    _generatePlacementPaper();
  }

  /// 跨 8 大領域精準抽樣 15 題（每個領域 1~2 題）
  void _generatePlacementPaper() {
    final allQuestions = globalMasterState.allQuestions;
    if (allQuestions.isEmpty) return;

    final random = math.Random();
    final List<QuestionItem> selected = [];

    // 1. 遍歷 8 大領域，各隨機抽取 1~2 題
    for (final domain in ElectricalDomain.values) {
      final domainQuestions = allQuestions.where(
        (q) => SkillTreeDomainMapper.resolveDomain(q) == domain
      ).toList();

      if (domainQuestions.isNotEmpty) {
        domainQuestions.shuffle(random);
        final takeCount = math.min(domainQuestions.length, 2);
        selected.addAll(domainQuestions.take(takeCount));
      }
    }

    // 2. 若總數不足 15 題，從全池隨機補足至 15 題
    if (selected.length < 15 && allQuestions.length >= 15) {
      final selectedIds = selected.map((q) => q.id).toSet();
      final remaining = allQuestions.where((q) => !selectedIds.contains(q.id)).toList()..shuffle(random);
      selected.addAll(remaining.take(15 - selected.length));
    }

    // 3. 切割為精準 15 題並打亂順序
    selected.shuffle(random);
    _paper = selected.take(15).toList();
  }

  void _onOptionTapped(int optionIndex) {
    HapticFeedback.selectionClick();
    final q = _paper[_currentIndex];
    final optionNumber = optionIndex + 1;
    final currentSelected = List<int>.from(_userAnswers[_currentIndex] ?? []);

    setState(() {
      if (q.type == 'single') {
        _userAnswers[_currentIndex] = [optionNumber];
      } else {
        if (currentSelected.contains(optionNumber)) {
          currentSelected.remove(optionNumber);
        } else {
          currentSelected.add(optionNumber);
        }
        if (currentSelected.isEmpty) {
          _userAnswers.remove(_currentIndex);
        } else {
          _userAnswers[_currentIndex] = currentSelected;
        }
      }
    });
  }

  void _submitAndCalculateReport() {
    HapticFeedback.heavyImpact();
    int correctCount = 0;
    final Map<ElectricalDomain, int> domainTotal = {};
    final Map<ElectricalDomain, int> domainCorrect = {};

    for (final domain in ElectricalDomain.values) {
      domainTotal[domain] = 0;
      domainCorrect[domain] = 0;
    }

    for (int i = 0; i < _paper.length; i++) {
      final q = _paper[i];
      final domain = SkillTreeDomainMapper.resolveDomain(q);
      domainTotal[domain] = (domainTotal[domain] ?? 0) + 1;

      final userSelected = _userAnswers[i] ?? [];
      final officialAns = q.answer;

      bool isCorrect = false;
      if (q.type == 'single') {
        if (userSelected.isNotEmpty && officialAns.contains(userSelected.first)) {
          isCorrect = true;
        }
      } else {
        final uSet = userSelected.toSet();
        final oSet = officialAns.toSet();
        if (uSet.length == oSet.length && uSet.containsAll(oSet)) {
          isCorrect = true;
        }
      }

      if (isCorrect) {
        correctCount++;
        domainCorrect[domain] = (domainCorrect[domain] ?? 0) + 1;
      } else {
        globalMasterState.recordWrongAnswer(q.id);
      }
    }

    final double predicted = (correctCount / _paper.length) * 100.0;

    // 判定最弱領域 (答對率最低者)
    ElectricalDomain weakest = ElectricalDomain.transformer;
    double minRate = 2.0;

    for (final domain in ElectricalDomain.values) {
      final tot = domainTotal[domain] ?? 0;
      if (tot > 0) {
        final rate = (domainCorrect[domain] ?? 0) / tot;
        if (rate < minRate) {
          minRate = rate;
          weakest = domain;
        }
      }
    }

    final report = PlacementDiagnosticReport(
      totalQuestions: _paper.length,
      correctCount: correctCount,
      predictedScore: double.parse(predicted.toStringAsFixed(1)),
      weakestDomain: weakest,
      domainScores: domainCorrect,
    );

    telemetry.logEvent(
      eventName: 'PLACEMENT_TEST_COMPLETED',
      parameters: {
        'predictedScore': report.predictedScore,
        'weakestDomain': report.weakestDomain.name,
        'isPass': report.isPredictedPass,
      },
    );

    setState(() {
      _report = report;
      _isFinished = true;
    });
  }

  Widget _buildOptionTile(int index, String text, QuestionItem q) {
    final optionNumber = index + 1;
    final userSelected = _userAnswers[_currentIndex] ?? [];
    final isSelected = userSelected.contains(optionNumber);

    return GestureDetector(
      onTap: () => _onOptionTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.amber400.withOpacity(0.15) : AppColors.slate900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.amber400 : AppColors.slate800,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.amber400 : AppColors.slate800,
              ),
              child: Text(
                '$optionNumber',
                style: TextStyle(
                  color: isSelected ? AppColors.slate950 : AppColors.slate400,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isSelected ? AppColors.amber400 : AppColors.slate50,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportView() {
    if (_report == null) return const SizedBox.shrink();
    final rep = _report!;
    final isPass = rep.isPredictedPass;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.slate900.withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isPass ? AppColors.emerald400 : AppColors.rose500, width: 2),
            ),
            child: Column(
              children: [
                Icon(
                  isPass ? Icons.verified_rounded : Icons.warning_amber_rounded,
                  size: 56,
                  color: isPass ? AppColors.emerald400 : AppColors.rose500,
                ),
                const SizedBox(height: 12),
                Text(
                  isPass ? '測驗結果：預估及格' : '測驗結果：預估尚未及格',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isPass ? AppColors.emerald400 : AppColors.rose500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${rep.predictedScore}',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: isPass ? AppColors.emerald400 : AppColors.rose500,
                    fontFamily: 'monospace',
                  ),
                ),
                const Text('10 分鐘落點快測預估得分 (及格線 60 分)', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.rose500.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.rose500.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.vaccines_rounded, color: AppColors.rose500, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('診斷致命弱點領域：', style: TextStyle(color: AppColors.rose500, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        rep.weakestDomain.name,
                        style: const TextStyle(color: AppColors.slate50, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rep.weakestDomain.description,
                        style: const TextStyle(color: AppColors.slate400, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.flash_on_rounded, color: AppColors.slate950),
            label: const Text('消滅弱點領域死穴', style: TextStyle(color: AppColors.slate950, fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber400, padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.slate800), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('返回戰情室', style: TextStyle(color: AppColors.slate300)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionView() {
    if (_paper.isEmpty) return const SizedBox.shrink();
    final q = _paper[_currentIndex];
    final domain = SkillTreeDomainMapper.resolveDomain(q);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blue500.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.blue500.withOpacity(0.4)),
                ),
                child: Text(
                  domain.name,
                  style: const TextStyle(color: AppColors.blue500, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '#${_currentIndex + 1} / ${_paper.length}',
                style: const TextStyle(color: AppColors.slate400, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            q.question,
            style: const TextStyle(fontSize: 18, color: AppColors.slate50, height: 1.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 28),
          ...List.generate(q.options.length, (idx) => _buildOptionTile(idx, q.options[idx], q)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_paper.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.slate950,
        appBar: AppBar(title: const Text('🎯 10分鐘實力落點快測')),
        body: const Center(
          child: Text('題庫初始化中或無可用考題...', style: TextStyle(color: AppColors.slate400)),
        ),
      );
    }

    if (_isFinished) {
      return Scaffold(
        backgroundColor: AppColors.slate950,
        appBar: AppBar(
          title: const Text('🎯 診斷報告與落點預測'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(child: _buildReportView()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        title: const Text('🎯 10分鐘實力落點快測'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.slate800, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${_currentIndex + 1} / ${_paper.length}',
                  style: const TextStyle(color: AppColors.amber400, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _paper.length,
              backgroundColor: AppColors.slate900,
              valueColor: const AlwaysStoppedAnimation(AppColors.amber400),
              minHeight: 4,
            ),
            Expanded(child: _buildQuestionView()),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.slate950,
                border: Border(top: BorderSide(color: AppColors.slate800)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.slate700),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('上一題', style: TextStyle(color: AppColors.slate300)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _currentIndex < _paper.length - 1
                        ? ElevatedButton(
                            onPressed: () => setState(() => _currentIndex++),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amber400,
                              foregroundColor: AppColors.slate950,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('下一題', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        : ElevatedButton.icon(
                            onPressed: _submitAndCalculateReport,
                            icon: const Icon(Icons.analytics_rounded, color: AppColors.slate950),
                            label: const Text('交卷並產出落點報告', style: TextStyle(color: AppColors.slate950, fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald400,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
