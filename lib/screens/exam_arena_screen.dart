import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/core_types.dart';
import '../main.dart';

enum ExamPhase { lobby, active, result }

class _DataPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  const _DataPanel({required this.child, this.padding = const EdgeInsets.all(16), this.borderColor = Colors.white12});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.slate900.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  final String text; final Color color; final VoidCallback onPressed; final IconData? icon;
  const _SolidButton({required this.text, required this.color, required this.onPressed, this.icon});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () { HapticFeedback.mediumImpact(); onPressed(); },
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: AppColors.slate950, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)], Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5))]),
    );
  }
}

class _DevOpsFourKeysDashboard extends StatelessWidget {
  final double failureRate; final int avgSecondsPerQuestion;
  const _DevOpsFourKeysDashboard({required this.failureRate, required this.avgSecondsPerQuestion});
  @override
  Widget build(BuildContext context) {
    return _DataPanel(
      borderColor: AppColors.blue500.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Row(children: [Icon(Icons.speed_rounded, color: AppColors.blue500, size: 20), SizedBox(width: 8), Text('DevOps DORA 四大作戰指標', style: TextStyle(color: AppColors.slate50, fontSize: 15, fontWeight: FontWeight.bold))]), Text('DORA Metrics', style: TextStyle(color: AppColors.blue500, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold))]),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: _buildMetricCard('變更失敗率 (錯題率)', '${failureRate.toStringAsFixed(1)}%', failureRate < 25 ? AppColors.emerald400 : AppColors.rose500)), const SizedBox(width: 10), Expanded(child: _buildMetricCard('平均前置時間 (解題)', '${avgSecondsPerQuestion}s / 題', avgSecondsPerQuestion < 45 ? AppColors.emerald400 : AppColors.amber400))]),
        ],
      ),
    );
  }
  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: AppColors.slate400, fontSize: 10, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace'))]),
    );
  }
}

class MockExamArenaView extends StatefulWidget {
  const MockExamArenaView({super.key});
  @override
  State<MockExamArenaView> createState() => _MockExamArenaViewState();
}

class _MockExamArenaViewState extends State<MockExamArenaView> {
  ExamPhase _phase = ExamPhase.lobby;
  List<QuestionItem> _examQuestions = [];
  final Map<int, List<int>> _answers = {};
  final Set<int> _flaggedIndices = {};
  Timer? _timer;
  int _secondsRemaining = 6000;
  int _currentIndex = 0;
  int _singleScore = 0;
  int _multiScore = 0;
  int _totalScore = 0;
  List<QuestionItem> _wrongQuestions = [];

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  void _startExam() {
    HapticFeedback.heavyImpact();
    final all = globalMasterState.allQuestions;
    final singles = all.where((q) => q.type == 'single').toList()..shuffle();
    final multiples = all.where((q) => q.type == 'multiple').toList()..shuffle();
    final paper = <QuestionItem>[];
    paper.addAll(singles.take(60)); paper.addAll(multiples.take(20));
    setState(() { _examQuestions = paper; _answers.clear(); _flaggedIndices.clear(); _secondsRemaining = 6000; _currentIndex = 0; _phase = ExamPhase.active; _wrongQuestions.clear(); });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_secondsRemaining > 0) setState(() => _secondsRemaining--); else _finishExam(isTimeOut: true);
    });
  }

  void _finishExam({bool isTimeOut = false}) {
    _timer?.cancel(); HapticFeedback.heavyImpact();
    int singlePts = 0; int multiPts = 0; final wrongs = <QuestionItem>[];
    for (int i = 0; i < _examQuestions.length; i++) {
      final q = _examQuestions[i]; final userSelected = _answers[i] ?? []; final officialAns = q.answer;
      bool passed = false;
      if (q.type == 'single') { if (userSelected.isNotEmpty && officialAns.contains(userSelected.first)) { passed = true; singlePts += 1; } }
      else { final uSet = userSelected.toSet(); final oSet = officialAns.toSet(); if (uSet.length == oSet.length && uSet.containsAll(oSet)) { passed = true; multiPts += 2; } }
      if (!passed) wrongs.add(q);
    }
    setState(() { _singleScore = singlePts; _multiScore = multiPts; _totalScore = singlePts + multiPts; _wrongQuestions = wrongs; _phase = ExamPhase.result; });
    if (isTimeOut && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⏰ 時間已到！系統已自動封存閱卷。'), backgroundColor: AppColors.rose500));
  }

  void _onOptionTapped(int optionIndex) {
    HapticFeedback.selectionClick();
    final q = _examQuestions[_currentIndex]; final optionNumber = optionIndex + 1; final currentSelected = List<int>.from(_answers[_currentIndex] ?? []);
    if (q.type == 'single') {
      _answers[_currentIndex] = [optionNumber];
      if (_currentIndex < _examQuestions.length - 1) { Future.delayed(const Duration(milliseconds: 300), () { if (mounted && _phase == ExamPhase.active) setState(() => _currentIndex++); }); }
    } else {
      if (currentSelected.contains(optionNumber)) currentSelected.remove(optionNumber); else currentSelected.add(optionNumber);
      if (currentSelected.isEmpty) _answers.remove(_currentIndex); else _answers[_currentIndex] = currentSelected;
    }
    setState(() {});
  }

  void _showSubmitConfirmationDialog() {
    HapticFeedback.mediumImpact();
    final unanswered = _examQuestions.length - _answers.keys.length;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.slate900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.amber400, width: 2)),
          title: const Text('⚠️ 確認封存交卷？', style: TextStyle(color: AppColors.slate50, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('剩餘時間：${_formatTime(_secondsRemaining)}', style: const TextStyle(color: AppColors.amber400, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12), Text(unanswered > 0 ? '警告：您還有 $unanswered 題尚未填答！' : '系統檢測：80 題已全數填答完畢。', style: TextStyle(color: unanswered > 0 ? AppColors.rose500 : AppColors.emerald400, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('交卷後將無法修改答案，並立即進入資料分析程序。', style: TextStyle(color: AppColors.slate400, fontSize: 12))]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('返回作答', style: TextStyle(color: AppColors.slate400))), ElevatedButton(onPressed: () { Navigator.pop(context); _finishExam(); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.amber400, foregroundColor: AppColors.slate950), child: const Text('確認交卷', style: TextStyle(fontWeight: FontWeight.bold)))],
        );
      },
    );
  }

  void _showAnswerSheetModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (context, scrollCtrl) {
            return _DataPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Container(width: 40, height: 5, margin: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: AppColors.slate700, borderRadius: BorderRadius.circular(4))),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('📊 全景狀態矩陣 (答題卡)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate50)), Text('完成度: ${_answers.length}/${_examQuestions.length}', style: const TextStyle(color: AppColors.emerald400, fontWeight: FontWeight.w900, fontFamily: 'monospace'))]),
                  const Divider(color: AppColors.slate800, height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildLegendDot(AppColors.emerald400, '已答'), _buildLegendDot(AppColors.rose500, '標記疑問'), _buildLegendDot(AppColors.slate800, '未作答')]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollCtrl, physics: const BouncingScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: _examQuestions.length,
                      itemBuilder: (context, i) {
                        final isAnswered = _answers.containsKey(i); final isFlagged = _flaggedIndices.contains(i); final isCurrent = i == _currentIndex;
                        Color tileBg = AppColors.slate800; Color textCol = AppColors.slate400; Color borderCol = Colors.transparent;
                        if (isFlagged) { tileBg = AppColors.rose500.withOpacity(0.2); textCol = AppColors.rose500; borderCol = AppColors.rose500; }
                        else if (isAnswered) { tileBg = AppColors.emerald400.withOpacity(0.2); textCol = AppColors.emerald400; }
                        if (isCurrent) borderCol = AppColors.amber400;
                        return GestureDetector(onTap: () { HapticFeedback.selectionClick(); setState(() => _currentIndex = i); Navigator.pop(context); }, child: Container(decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderCol, width: isCurrent ? 2.5 : 1)), alignment: Alignment.center, child: Text('${i + 1}', style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 13))));
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 4), Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 12))]);
  }
  String _formatTime(int totalSeconds) { final m = (totalSeconds ~/ 60).toString().padLeft(2, '0'); final s = (totalSeconds % 60).toString().padLeft(2, '0'); return '$m:$s'; }

  Widget _buildLobbyView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DataPanel(borderColor: AppColors.amber400, padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16), child: Column(children: const [Icon(Icons.gavel_rounded, size: 56, color: AppColors.amber400), SizedBox(height: 16), Text('勞動部 00700 乙級學科', style: TextStyle(fontSize: 14, color: AppColors.slate400, letterSpacing: 2.0)), SizedBox(height: 4), Text('全真模擬考場', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.slate50))])),
          const SizedBox(height: 24), const Text('⚖️ 國家考試規範配置：', style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.slate900, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.slate800)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('• 總題數：80 題隨機抽取', style: TextStyle(color: AppColors.slate50, fontSize: 14, height: 1.6)), Text('• 題型分佈：單選 60 題 (每題 1 分) + 複選 20 題 (每題 2 分)', style: TextStyle(color: AppColors.slate50, fontSize: 14, height: 1.6)), Text('• 考試時間：100 分鐘 (時間到強制收卷)', style: TextStyle(color: AppColors.slate50, fontSize: 14, height: 1.6)), Text('• 合格標準：總分達 60 分', style: TextStyle(color: AppColors.emerald400, fontSize: 14, fontWeight: FontWeight.bold, height: 1.6)), Text('• 注意事項：複選題全對才給分，答錯不倒扣。', style: TextStyle(color: AppColors.rose500, fontSize: 14, fontWeight: FontWeight.bold, height: 1.6))])),
          const SizedBox(height: 32), _SolidButton(text: '系統就緒，立即進入考場', color: AppColors.amber400, icon: Icons.play_arrow_rounded, onPressed: _startExam),
        ],
      ),
    );
  }

  Widget _buildActiveExamView() {
    final q = _examQuestions[_currentIndex]; final userSelected = _answers[_currentIndex] ?? []; final isFlagged = _flaggedIndices.contains(_currentIndex); final isUrgent = _secondsRemaining < 600;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: const BoxDecoration(color: AppColors.slate950, border: Border(bottom: BorderSide(color: AppColors.slate800, width: 2))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(Icons.timer_outlined, color: isUrgent ? AppColors.rose500 : AppColors.amber400, size: 22), const SizedBox(width: 8), Text(_formatTime(_secondsRemaining), style: TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w900, color: isUrgent ? AppColors.rose500 : AppColors.amber400, letterSpacing: 1.0))]),
              Row(children: [IconButton(icon: Icon(isFlagged ? Icons.flag_rounded : Icons.outlined_flag_rounded, color: isFlagged ? AppColors.rose500 : AppColors.slate400, size: 26), onPressed: () { HapticFeedback.lightImpact(); setState(() { isFlagged ? _flaggedIndices.remove(_currentIndex) : _flaggedIndices.add(_currentIndex); }); }), const SizedBox(width: 4), IconButton(icon: const Icon(Icons.grid_view_rounded, color: AppColors.slate300, size: 26), onPressed: _showAnswerSheetModal)]),
            ],
          ),
        ),
        LinearProgressIndicator(value: (_currentIndex + 1) / _examQuestions.length, backgroundColor: AppColors.slate900, valueColor: const AlwaysStoppedAnimation(AppColors.blue500), minHeight: 3),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: q.type == 'single' ? AppColors.blue500 : AppColors.rose500, borderRadius: BorderRadius.circular(6)), child: Text(q.type == 'single' ? '單選 (1分)' : '⚠️ 複選 (2分)', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))), Text('#${_currentIndex + 1} / 80', style: const TextStyle(color: AppColors.slate400, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14))]),
                const SizedBox(height: 24), Text(q.question, style: const TextStyle(fontSize: 18, color: AppColors.slate50, height: 1.6, fontWeight: FontWeight.w600)), const SizedBox(height: 32),
                ...List.generate(q.options.length, (optIdx) {
                  final optNum = optIdx + 1; final isSelected = userSelected.contains(optNum);
                  return GestureDetector(
                    onTap: () => _onOptionTapped(optIdx),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: isSelected ? AppColors.amber400.withOpacity(0.15) : AppColors.slate900, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? AppColors.amber400 : AppColors.slate800, width: isSelected ? 2 : 1)),
                      child: Row(children: [Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? AppColors.amber400 : AppColors.slate800), child: Text('$optNum', style: TextStyle(color: isSelected ? AppColors.slate950 : AppColors.slate400, fontWeight: FontWeight.bold))), const SizedBox(width: 16), Expanded(child: Text(q.options[optIdx], style: TextStyle(color: isSelected ? AppColors.amber400 : AppColors.slate50, fontSize: 16)))]),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: AppColors.slate950, border: Border(top: BorderSide(color: AppColors.slate800))),
          child: Row(
            children: [
              Expanded(flex: 2, child: OutlinedButton(onPressed: _currentIndex > 0 ? () => setState(() => _currentIndex--) : null, style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.slate700), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('上一題', style: TextStyle(color: AppColors.slate300)))),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: _currentIndex < _examQuestions.length - 1 ? _SolidButton(text: '下一題', color: AppColors.amber400, onPressed: () => setState(() => _currentIndex++)) : _SolidButton(text: '交卷', color: AppColors.rose500, icon: Icons.outbox_rounded, onPressed: _showSubmitConfirmationDialog)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final isPassed = _totalScore >= 60;
    final failureRate = (_wrongQuestions.length / 80) * 100;
    final elapsedSeconds = 6000 - _secondsRemaining;
    final avgSecPerQ = elapsedSeconds ~/ 80;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DataPanel(
            borderColor: isPassed ? AppColors.emerald400 : AppColors.rose500, padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(isPassed ? Icons.verified_rounded : Icons.dangerous_rounded, size: 64, color: isPassed ? AppColors.emerald400 : AppColors.rose500), const SizedBox(height: 12), Text(isPassed ? '判定結果：合格' : '判定結果：不合格', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isPassed ? AppColors.emerald400 : AppColors.rose500)), const SizedBox(height: 16), Text('$_totalScore', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: isPassed ? AppColors.emerald400 : AppColors.rose500, fontFamily: 'monospace')), const Text('最終測驗總分 (滿分 100)', style: TextStyle(color: AppColors.slate400, fontSize: 13)), const Divider(color: AppColors.slate800, height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround, // ✅ 已修復 MainAxisAlignment 拼寫錯誤
                  children: [
                    Column(children: [Text('$_singleScore / 60', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate50)), const SizedBox(height: 4), const Text('單選題得分', style: TextStyle(color: AppColors.slate400, fontSize: 12))]),
                    Container(height: 40, width: 1, color: AppColors.slate700),
                    Column(children: [Text('$_multiScore / 40', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate50)), const SizedBox(height: 4), const Text('複選題得分', style: TextStyle(color: AppColors.slate400, fontSize: 12))]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DevOpsFourKeysDashboard(failureRate: failureRate, avgSecondsPerQuestion: avgSecPerQ),
          const SizedBox(height: 20),
          if (_wrongQuestions.isNotEmpty) ...[
            _DataPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [Icon(Icons.analytics_rounded, color: AppColors.amber400, size: 20), SizedBox(width: 8), Text('CIO 戰損資料復盤', style: TextStyle(color: AppColors.slate50, fontSize: 16, fontWeight: FontWeight.bold))]), const SizedBox(height: 12), Text('本次測驗共產生 ${_wrongQuestions.length} 道錯誤判斷 (包含未答或未完全答對之複選題)。', style: const TextStyle(color: AppColors.slate400, fontSize: 13, height: 1.5)), const SizedBox(height: 16),
                  _SolidButton(
                    text: '封裝錯題並寫入 FSRS 資料庫', color: AppColors.amber400, icon: Icons.memory_rounded,
                    onPressed: () {
                      for (final q in _wrongQuestions) globalMasterState.recordWrongAnswer(q.id);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 成功將 ${_wrongQuestions.length} 題寫入急診佇列！'), backgroundColor: AppColors.emerald400));
                      setState(() { _wrongQuestions.clear(); });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            onPressed: () { HapticFeedback.selectionClick(); setState(() => _phase = ExamPhase.lobby); },
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate50), label: const Text('返回大廳重啟測驗', style: TextStyle(color: AppColors.slate50)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.slate700), padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(title: const Text('🏛️ 全真模擬考場', style: TextStyle(fontWeight: FontWeight.w900)), elevation: 0),
      body: SafeArea(child: _phase == ExamPhase.active ? _buildActiveExamView() : (_phase == ExamPhase.result ? _buildResultView() : _buildLobbyView())),
    );
  }
}
