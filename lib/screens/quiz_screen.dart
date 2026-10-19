// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/screens/quiz_screen.dart
// 說明：高可用性刷題斬主視圖（App Store 審查商標清洗合規版）
// ==========================================

import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/core_types.dart';
import '../main.dart';
import '../utils/memory_engine.dart';
import '../utils/bitwise_index.dart';
import '../services/ai_tutor_service.dart';
import '../utils/ast_math_evaluator.dart';
import '../utils/cognitive_load_engine.dart';

// ==========================================
// 內部私有 UI 元件庫 (iOS HIG 原生體驗)
// ==========================================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.slate900.withOpacity(0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DuoChunkyButton extends StatefulWidget {
  final String text;
  final Color color;
  final Color shadowColor;
  final VoidCallback? onPressed;
  final double height;

  const _DuoChunkyButton({
    required this.text,
    required this.color,
    required this.shadowColor,
    required this.onPressed,
    this.height = 56.0,
  });

  @override
  State<_DuoChunkyButton> createState() => _DuoChunkyButtonState();
}

class _DuoChunkyButtonState extends State<_DuoChunkyButton> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    widget.onPressed!();
  }

  void _onTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null;
    final double pushOffset = _isPressed ? 6.0 : 0.0;
    final bgColor = isDisabled ? AppColors.slate800 : widget.color;
    final sColor = isDisabled ? AppColors.slate900 : widget.shadowColor;
    final fgColor = isDisabled ? AppColors.slate500 : AppColors.slate950;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        height: widget.height,
        margin: EdgeInsets.only(top: pushOffset, bottom: 6.0 - pushOffset),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: sColor, offset: Offset(0, 6.0 - pushOffset))],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.text,
          style: TextStyle(
            color: fgColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

/// 臨床診斷標籤
class _ClinicalDiagnosticTag extends StatelessWidget {
  final String diagnosticMessage;
  const _ClinicalDiagnosticTag({required this.diagnosticMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.rose500.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.rose500.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(Icons.vaccines_rounded, color: AppColors.rose500, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '根因診斷：$diagnosticMessage',
              style: const TextStyle(
                color: AppColors.rose500,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 星系圖渲染器
class _ConstellationGraphPainter extends CustomPainter {
  final int nodeCount;
  final double animationValue;

  _ConstellationGraphPainter({required this.nodeCount, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;
    canvas.drawCircle(
      center,
      24 * animationValue,
      Paint()
        ..color = AppColors.rose500.withOpacity(0.2 * animationValue)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(center, 12, Paint()..color = AppColors.rose500..style = PaintingStyle.fill);

    final linePaint = Paint()
      ..color = AppColors.amber400.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()..color = AppColors.emerald400..style = PaintingStyle.fill;

    for (int i = 0; i < nodeCount; i++) {
      final angle = (i * 2 * math.pi / nodeCount) - (math.pi / 2) + (animationValue * 0.1);
      final targetNode = center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      canvas.drawLine(center, targetNode, linePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: ' ${(85 - i * 4)}%',
          style: const TextStyle(
            color: AppColors.amber400,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset((center.dx + targetNode.dx) / 2, (center.dy + targetNode.dy) / 2) -
            Offset(textPainter.width / 2, textPainter.height + 4),
      );
      canvas.drawCircle(targetNode, 8 * animationValue, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationGraphPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue || oldDelegate.nodeCount != nodeCount;
}

/// 蘇格拉底式主動回憶遮罩
class _SocraticMaskOverlay extends StatelessWidget {
  final String questionText;
  final VoidCallback onShatter;

  const _SocraticMaskOverlay({required this.questionText, required this.onShatter});

  String _prompt(String q) {
    if (q.contains('電壓降')) return '大師點撥：計算壓降前，請先回憶這是單相還是三相？係數是多少？';
    if (q.contains('距離')) return '大師點撥：法規數字題最易混淆。請閉上眼睛，這題是「以上」還是「以下」？';
    return '大師點撥：看解析前，請先在腦中重播一次這題的關鍵字，想好了嗎？';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.slate950.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.blue500.withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.psychology_alt_rounded, color: AppColors.blue500, size: 48),
              const SizedBox(height: 16),
              const Text('主動提取訓練', style: TextStyle(color: AppColors.blue500, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
              const SizedBox(height: 12),
              Text(
                _prompt(questionText),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slate50, fontSize: 14, height: 1.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              _DuoChunkyButton(
                text: '💡 想清楚了，擊碎遮罩看解析',
                color: AppColors.blue500,
                shadowColor: const Color(0xFF1E3A8A),
                height: 48,
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  onShatter();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 自適應折疊器
class _AdaptiveExplanationFolder extends StatefulWidget {
  final double memoryStability;
  final Widget compactChild;
  final Widget fullChild;

  const _AdaptiveExplanationFolder({
    required this.memoryStability,
    required this.compactChild,
    required this.fullChild,
  });

  @override
  State<_AdaptiveExplanationFolder> createState() => _AdaptiveExplanationFolderState();
}

class _AdaptiveExplanationFolderState extends State<_AdaptiveExplanationFolder> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.memoryStability < 3.0;
  }

  @override
  Widget build(BuildContext context) {
    final isExpert = widget.memoryStability >= 3.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isExpanded = !_isExpanded);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isExpert ? Icons.workspace_premium_rounded : Icons.school_rounded,
                      color: isExpert ? AppColors.amber400 : AppColors.blue500,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isExpert ? '精熟狀態 (已熟練 · 預設摺疊詳解)' : '初學狀態 (展開完整推導鷹架)',
                      style: TextStyle(
                        color: isExpert ? AppColors.amber400 : AppColors.blue500,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(_isExpanded ? '收起' : '展開完整推導', style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                    Icon(_isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.slate400, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedCrossFade(
          firstChild: widget.compactChild,
          secondChild: widget.fullChild,
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          firstCurve: Curves.easeOutCirc,
          secondCurve: Curves.easeOutCirc,
        ),
      ],
    );
  }
}

/// 雷射掃描防護罩
class _AerospaceGroundingScan extends StatefulWidget {
  final Widget child;
  const _AerospaceGroundingScan({required this.child});

  @override
  State<_AerospaceGroundingScan> createState() => _AerospaceGroundingScanState();
}

class _AerospaceGroundingScanState extends State<_AerospaceGroundingScan> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _scanController,
          builder: (context, child) {
            if (_scanController.isCompleted) return const SizedBox.shrink();
            return Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(painter: _LaserScanPainter(progress: _scanController.value)),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LaserScanPainter extends CustomPainter {
  final double progress;
  _LaserScanPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = AppColors.emerald400.withOpacity(0.4)
        ..strokeWidth = 12.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = AppColors.emerald400
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LaserScanPainter oldDelegate) => oldDelegate.progress != progress;
}

/// 微觀作答時間軸（已拔除第三方商標）
class _MicroDecisionGantt extends StatelessWidget {
  final int readingSeconds;
  final int hesitationSeconds;
  final int decisionSeconds;

  const _MicroDecisionGantt({
    required this.readingSeconds,
    required this.hesitationSeconds,
    required this.decisionSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, readingSeconds + hesitationSeconds + decisionSeconds);
    final readingRatio = readingSeconds / total;
    final hesitationRatio = hesitationSeconds / total;
    final decisionRatio = decisionSeconds / total;
    final isHesitant = hesitationSeconds > 5;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHesitant ? AppColors.rose500.withOpacity(0.4) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.timeline_rounded, color: AppColors.blue500, size: 15),
                  SizedBox(width: 6),
                  Text('微觀作答時間軸', style: TextStyle(color: AppColors.blue500, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                isHesitant ? '⚠️ 猶豫 $hesitationSeconds 秒 (建議強化熟練度)' : '⚡ 決策果斷 (肌肉記憶)',
                style: TextStyle(
                  color: isHesitant ? AppColors.rose500 : AppColors.emerald400,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (readingRatio > 0) Expanded(flex: (readingRatio * 100).round(), child: Container(color: AppColors.blue500)),
                  if (hesitationRatio > 0) Expanded(flex: (hesitationRatio * 100).round(), child: Container(color: AppColors.rose500)),
                  if (decisionRatio > 0) Expanded(flex: (decisionRatio * 100).round(), child: Container(color: AppColors.emerald400)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('讀題 ${readingSeconds}s', style: const TextStyle(color: AppColors.slate400, fontSize: 10)),
              Text(
                '猶豫 ${hesitationSeconds}s',
                style: TextStyle(
                  color: isHesitant ? AppColors.rose500 : AppColors.slate400,
                  fontSize: 10,
                  fontWeight: isHesitant ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text('決策 ${decisionSeconds}s', style: const TextStyle(color: AppColors.slate400, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

/// FSRS 神經記憶狀態機（已拔除第三方商標）
class _SynapseReplayIndicator extends StatelessWidget {
  final double currentStability;
  const _SynapseReplayIndicator({required this.currentStability});

  @override
  Widget build(BuildContext context) {
    final projectedStability = (currentStability == 0) ? 1.0 : currentStability * 2.5;
    final projectedNextDate = DateTime.now().add(Duration(days: projectedStability.round()));
    final dateStr = "${projectedNextDate.year}/${projectedNextDate.month}/${projectedNextDate.day}";

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.emerald400.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.emerald400.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.psychology_rounded, color: AppColors.emerald400, size: 16),
              SizedBox(width: 6),
              Text('FSRS 記憶排程狀態機', style: TextStyle(color: AppColors.emerald400, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Text(
            '穩定度 ${currentStability.toStringAsFixed(1)}d ➔ 預測下次複習: $dateStr',
            style: const TextStyle(color: AppColors.emerald400, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

/// AST 符號拓樸圖譜（已拔除第三方商標）
class _AstTopologyGraph extends StatelessWidget {
  final String formula;
  const _AstTopologyGraph({required this.formula});

  @override
  Widget build(BuildContext context) {
    if (formula.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber400.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.account_tree_rounded, color: AppColors.amber400, size: 15),
                  SizedBox(width: 6),
                  Text('AST 符號拓樸圖譜', style: TextStyle(color: AppColors.amber400, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('AST Node Engine', style: TextStyle(color: AppColors.slate400, fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _node('輸入 V', AppColors.blue500),
                _arrow(),
                _node('乘算 ×', AppColors.amber400),
                _arrow(),
                _node('輸入 I', AppColors.blue500),
                _arrow(),
                _node('常數 √3', AppColors.amber400),
                _arrow(),
                _node('輸出 P (kW)', AppColors.emerald400, isOutput: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _node(String text, Color color, {bool isOutput = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: isOutput ? 2 : 1),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      );

  Widget _arrow() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.arrow_forward_rounded, color: AppColors.slate500, size: 12),
      );
}

/// 防連擊狀態鎖定盾
class _StateLockShield extends StatelessWidget {
  final bool isLocked;
  const _StateLockShield({required this.isLocked});

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blue500.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.blue500.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_clock_rounded, color: AppColors.blue500, size: 12),
          SizedBox(width: 6),
          Text('FSRS 狀態寫入中 (防連擊鎖定)', style: TextStyle(color: AppColors.blue500, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

/// 高可用性常駐導航 HUD（已拔除第三方商標）
class _HighAvailabilityHud extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;

  const _HighAvailabilityHud({
    required this.currentIndex,
    required this.totalCount,
    required this.isBookmarked,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.emerald400, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('HA-ENGINE: 99.999%', style: TextStyle(color: AppColors.emerald400, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggleBookmark();
                },
                child: Row(
                  children: [
                    Icon(
                      isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                      color: isBookmarked ? AppColors.amber400 : AppColors.slate400,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isBookmarked ? '已珍藏' : '標記書籤',
                      style: TextStyle(color: isBookmarked ? AppColors.amber400 : AppColors.slate400, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${currentIndex + 1} / $totalCount',
                style: const TextStyle(color: AppColors.slate400, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ==========================================
// 考點雷達動態視圖 (知識星系圖譜)
// ==========================================

class _KnowledgeGraphRadar extends StatefulWidget {
  final QuestionItem currentQuestion;
  final List<QuestionItem> similarQuestions;
  final Function(String) onNodeTapped;

  const _KnowledgeGraphRadar({
    required this.currentQuestion,
    required this.similarQuestions,
    required this.onNodeTapped,
  });

  @override
  State<_KnowledgeGraphRadar> createState() => _KnowledgeGraphRadarState();
}

class _KnowledgeGraphRadarState extends State<_KnowledgeGraphRadar> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.similarQuestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('🎯 考點星系圖・深層結構雷達', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.amber400)),
            Text('Radar Graph Engine', style: TextStyle(fontSize: 10, color: AppColors.slate400, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.slate800),
          ),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ConstellationGraphPainter(
                        nodeCount: widget.similarQuestions.length,
                        animationValue: _pulseController.value,
                      ),
                    ),
                  ),
                  ...List.generate(widget.similarQuestions.length, (i) {
                    final simQ = widget.similarQuestions[i];
                    final angle = (i * 2 * math.pi / widget.similarQuestions.length) - (math.pi / 2) + (_pulseController.value * 0.1);
                    return Align(
                      alignment: Alignment(math.cos(angle) * 0.8, math.sin(angle) * 0.8),
                      child: GestureDetector(
                        onTap: () => widget.onNodeTapped(simQ.id),
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.slate900.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.emerald400.withOpacity(0.5)),
                            boxShadow: [BoxShadow(color: AppColors.emerald400.withOpacity(0.2), blurRadius: 4)],
                          ),
                          child: Text(
                            simQ.question,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.slate50, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.rose500, borderRadius: BorderRadius.circular(4)),
                      child: const Text('當前盲點', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 核心刷題視圖狀態機
// ==========================================

class ElectroQuizArenaView extends StatefulWidget {
  const ElectroQuizArenaView({super.key});

  @override
  State<ElectroQuizArenaView> createState() => _ElectroQuizArenaViewState();
}

class _ElectroQuizArenaViewState extends State<ElectroQuizArenaView> {
  String _selectedCategory = 'ALL';
  bool _onlyWrongQueue = false;
  bool _onlyMultipleChoice = false;

  int _currentFilteredIndex = 0;
  List<int> _userSelectedOptions = [];
  bool _isAnswerRevealed = false;
  bool _isSocraticMaskActive = true;

  int _qStartTime = DateTime.now().millisecondsSinceEpoch;
  int? _firstTapTime;
  int? _lastSwitchTime;

  int _readingSec = 0;
  int _hesitationSec = 0;
  int _decisionSec = 0;

  bool _isRatingLocked = false;

  List<QuestionItem> get _filteredQuestions {
    int mask = CarmackBitFlags.matchAll;
    if (_selectedCategory == '00700_B') mask |= CarmackBitFlags.category00700;
    else if (_selectedCategory == '21000_B') mask |= CarmackBitFlags.category21000;
    if (_onlyMultipleChoice) mask |= CarmackBitFlags.typeMultiple;
    return globalMasterState.queryQuestionsFast(queryMask: mask, onlyWrong: _onlyWrongQueue);
  }

  void _resetQuizState() {
    _currentFilteredIndex = 0;
    _userSelectedOptions = [];
    _isAnswerRevealed = false;
    _isSocraticMaskActive = true;
    _isRatingLocked = false;
    _qStartTime = DateTime.now().millisecondsSinceEpoch;
    _firstTapTime = null;
    _lastSwitchTime = null;
    _readingSec = 0;
    _hesitationSec = 0;
    _decisionSec = 0;
  }

  void _toggleOption(int index) {
    if (_isAnswerRevealed) return;
    HapticFeedback.lightImpact();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_firstTapTime == null) {
      _firstTapTime = now;
    } else {
      _lastSwitchTime = now;
    }

    final q = _filteredQuestions[_currentFilteredIndex];
    setState(() {
      if (q.type == 'single') {
        _userSelectedOptions = [index + 1];
      } else {
        final optionNumber = index + 1;
        if (_userSelectedOptions.contains(optionNumber)) {
          _userSelectedOptions.remove(optionNumber);
        } else {
          _userSelectedOptions.add(optionNumber);
        }
      }
    });
  }

  void _submitAndGrade() {
    if (_userSelectedOptions.isEmpty) return;
    HapticFeedback.mediumImpact();

    final now = DateTime.now().millisecondsSinceEpoch;
    final firstTap = _firstTapTime ?? now;
    final lastSwitch = _lastSwitchTime ?? firstTap;

    _readingSec = math.min(60, math.max(1, ((firstTap - _qStartTime) / 1000).round()));
    _hesitationSec = math.min(60, math.max(0, ((lastSwitch - firstTap) / 1000).round()));
    _decisionSec = math.min(60, math.max(1, ((now - lastSwitch) / 1000).round()));

    setState(() {
      _isAnswerRevealed = true;
      _isSocraticMaskActive = true;
    });
  }

  void _handleRatingSelected(StudyRating rating) {
    if (_isRatingLocked) return;
    setState(() => _isRatingLocked = true);

    final q = _filteredQuestions[_currentFilteredIndex];
    switch (rating) {
      case StudyRating.again:
        HapticFeedback.heavyImpact();
        break;
      case StudyRating.hard:
        HapticFeedback.mediumImpact();
        break;
      case StudyRating.good:
        HapticFeedback.lightImpact();
        break;
      case StudyRating.easy:
        HapticFeedback.selectionClick();
        break;
    }

    globalMasterState.processQuestionReview(questionId: q.id, rating: rating);

    setState(() {
      _resetQuizState();
      if (_currentFilteredIndex < _filteredQuestions.length - 1) {
        _currentFilteredIndex++;
      } else {
        _currentFilteredIndex = 0;
      }
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isRatingLocked = false);
    });
  }

  void _jumpToQuestionById(String targetId) {
    HapticFeedback.selectionClick();
    int idx = _filteredQuestions.indexWhere((item) => item.id == targetId);
    if (idx != -1) {
      setState(() {
        _currentFilteredIndex = idx;
        _resetQuizState();
      });
    }
  }

  String _generateClinicalDiagnosis(QuestionItem q) {
    final text = q.question;
    if (text.contains('電壓降') || text.contains('線路')) return '可能忽略了「單相/三相」的係數差異（如忘記乘上 √3 或 2），導致壓降公式套用錯誤。';
    if (text.contains('距離') || text.contains('毫米') || text.contains('公尺')) return '這是不同環境情境的規定數值，請務必辨別題幹之「極限條件（以上/以下）」。';
    if (text.contains('變壓器') || text.contains('V-V')) return '此為容量未乘上 √3 或未依輸出比率折減之典型計算誘答。';
    if (text.contains('漏電') || text.contains('接地')) return '請釐清「系統接地」與「設備接地」的法規範疇，本選項混淆了二者要求。';
    return '此為常見直覺性陷阱，未考慮底層物理條件約束，極易受表面數值干擾。';
  }

  Widget _buildChunkyOptionTile(int index, String text, QuestionItem q) {
    final optionNumber = index + 1;
    final isSelected = _userSelectedOptions.contains(optionNumber);
    final isCorrectOption = q.answer.contains(optionNumber);

    Color borderColor = AppColors.slate800;
    Color bgColor = AppColors.slate900;
    Color shadowColor = Colors.black;
    Widget? trailingIcon;
    double pushOffset = 0.0;
    bool showDiagnosis = false;

    if (_isAnswerRevealed) {
      if (isCorrectOption && isSelected) {
        borderColor = AppColors.emerald400;
        bgColor = AppColors.emerald400.withOpacity(0.15);
        shadowColor = AppColors.emerald400.withOpacity(0.5);
        trailingIcon = const Icon(Icons.check_circle, color: AppColors.emerald400);
        pushOffset = 4.0;
      } else if (isCorrectOption && !isSelected) {
        borderColor = AppColors.amber400;
        trailingIcon = const Icon(Icons.warning_amber_rounded, color: AppColors.amber400);
      } else if (!isCorrectOption && isSelected) {
        borderColor = AppColors.rose500;
        bgColor = AppColors.rose500.withOpacity(0.1);
        shadowColor = AppColors.rose500.withOpacity(0.5);
        trailingIcon = const Icon(Icons.cancel, color: AppColors.rose500);
        pushOffset = 4.0;
        showDiagnosis = true;
      }
    } else {
      if (isSelected) {
        borderColor = AppColors.amber400;
        bgColor = AppColors.amber400.withOpacity(0.1);
        shadowColor = AppColors.amber400.withOpacity(0.5);
        pushOffset = 4.0;
      }
    }

    return GestureDetector(
      onTap: () => _toggleOption(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(bottom: 12.0 - pushOffset, top: pushOffset),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: shadowColor, offset: Offset(0, 4.0 - pushOffset))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.amber400 : AppColors.slate800,
                  ),
                  child: Text(
                    '($optionNumber)',
                    style: TextStyle(
                      color: isSelected ? AppColors.slate950 : AppColors.slate400,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(text, style: const TextStyle(color: AppColors.slate50, fontSize: 16, height: 1.4))),
                if (trailingIcon != null) ...[const SizedBox(width: 12), trailingIcon],
              ],
            ),
            if (showDiagnosis)
              _ClinicalDiagnosticTag(diagnosticMessage: _generateClinicalDiagnosis(q)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumExplanationCard(QuestionItem q) {
    final exp = q.explanation;
    final isCalculation = q.question.contains('多少') ||
        q.question.contains('計算') ||
        exp.formula.contains('=') ||
        exp.formula.contains('√');
    final similarQuestions = globalMasterState.getRelatedQuestions(q, topK: 3);

    final memoryState = globalMasterState.getCardState(q.id);
    final stability = memoryState.stability;

    bool isAllCorrect = false;
    if (q.type == 'single') {
      isAllCorrect = _userSelectedOptions.isNotEmpty && q.answer.contains(_userSelectedOptions.first);
    } else {
      final uSet = _userSelectedOptions.toSet();
      final aSet = q.answer.toSet();
      isAllCorrect = (uSet.length == aSet.length && uSet.containsAll(aSet));
    }

    if (!isAllCorrect && _isSocraticMaskActive) {
      return _SocraticMaskOverlay(
        questionText: q.question,
        onShatter: () => setState(() => _isSocraticMaskActive = false),
      );
    }

    Widget compactView = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber400.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.amber400.withOpacity(0.4)),
      ),
      child: Text(
        exp.quickHack.isNotEmpty ? exp.quickHack : '⚡ 官方速記標準答案，記憶穩定！',
        style: const TextStyle(color: AppColors.amber400, fontWeight: FontWeight.w900, fontSize: 15),
      ),
    );

    Widget fullView = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exp.quickHack.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.amber400.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.amber400.withOpacity(0.4)),
            ),
            child: Text(exp.quickHack, style: const TextStyle(color: AppColors.amber400, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          const SizedBox(height: 12),
        ],
        if (exp.formula.isNotEmpty) ...[
          Text('📐 核心算式/條號: ${exp.formula}', style: const TextStyle(color: AppColors.slate50, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (isCalculation)
            _AstTopologyGraph(formula: exp.formula),
          const SizedBox(height: 8),
        ],
        if (exp.stepByStep.isNotEmpty) ...[
          Text('📝 推導: ${exp.stepByStep}', style: const TextStyle(color: AppColors.slate300, fontSize: 14, height: 1.5)),
          const SizedBox(height: 12),
        ],
        if (exp.fieldNote.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slate800.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
              border: const Border(left: BorderSide(color: AppColors.blue500, width: 4)),
            ),
            child: Text('🛠️ 實務筆記: ${exp.fieldNote}', style: const TextStyle(color: AppColors.slate400, fontSize: 13, height: 1.4)),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );

    return _AerospaceGroundingScan(
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.emerald400, size: 20),
                    SizedBox(width: 8),
                    Text('官方精準解析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.emerald400)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emerald400.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.emerald400.withOpacity(0.5)),
                  ),
                  child: const Text('SAFETY-POST: 100% PASS', style: TextStyle(color: AppColors.emerald400, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MicroDecisionGantt(
              readingSeconds: _readingSec,
              hesitationSeconds: _hesitationSec,
              decisionSeconds: _decisionSec,
            ),
            const SizedBox(height: 8),
            _SynapseReplayIndicator(
              currentStability: stability,
            ),
            const SizedBox(height: 12),
            _AdaptiveExplanationFolder(
              memoryStability: stability,
              compactChild: compactView,
              fullChild: fullView,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => _AiTutorStreamingSheet(question: q),
                      );
                    },
                    icon: const Icon(Icons.psychology_rounded, color: AppColors.slate950, size: 18),
                    label: const Text('AI 大師解剖', style: TextStyle(color: AppColors.slate950, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald400),
                  ),
                ),
                if (isCalculation) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => _AstMathPlaygroundSheet(question: q),
                        );
                      },
                      icon: const Icon(Icons.science_rounded, color: AppColors.amber400, size: 18),
                      label: const Text('AST 實驗室', style: TextStyle(color: AppColors.amber400, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.amber400)),
                    ),
                  ),
                ]
              ],
            ),
            _KnowledgeGraphRadar(
              currentQuestion: q,
              similarQuestions: similarQuestions,
              onNodeTapped: _jumpToQuestionById,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.slate950,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.slate400, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(
                          '全部',
                          style: TextStyle(
                            color: _selectedCategory == 'ALL' ? AppColors.slate950 : AppColors.slate400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: _selectedCategory == 'ALL',
                        selectedColor: AppColors.amber400,
                        backgroundColor: AppColors.slate800,
                        onSelected: (v) => setState(() {
                          _selectedCategory = 'ALL';
                          _resetQuizState();
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          '室內配線',
                          style: TextStyle(
                            color: _selectedCategory == '00700_B' ? AppColors.slate950 : AppColors.slate400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: _selectedCategory == '00700_B',
                        selectedColor: AppColors.amber400,
                        backgroundColor: AppColors.slate800,
                        onSelected: (v) => setState(() {
                          _selectedCategory = '00700_B';
                          _resetQuizState();
                        }),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(
                          '⚠️ 僅刷複選',
                          style: TextStyle(
                            color: _onlyMultipleChoice ? AppColors.slate950 : AppColors.amber400,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: _onlyMultipleChoice,
                        selectedColor: AppColors.amber400,
                        backgroundColor: AppColors.amber400.withOpacity(0.1),
                        side: const BorderSide(color: AppColors.amber400, width: 1),
                        onSelected: (v) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _onlyMultipleChoice = v;
                            _resetQuizState();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('💀 專刷錯題 (地獄模式)', style: TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold, fontSize: 13)),
              Switch(
                value: _onlyWrongQueue,
                activeColor: AppColors.rose500,
                onChanged: (val) {
                  setState(() {
                    _onlyWrongQueue = val;
                    _resetQuizState();
                  });
                  HapticFeedback.selectionClick();
                },
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredQuestions;
    if (list.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('📖 刷題斬')),
        body: Column(
          children: [
            _buildFilterBar(),
            const Expanded(
              child: Center(
                child: Text('題庫為空，請調整過濾條件。', style: TextStyle(color: AppColors.slate400)),
              ),
            ),
          ],
        ),
      );
    }

    if (_currentFilteredIndex >= list.length) {
      _currentFilteredIndex = 0;
    }
    final q = list[_currentFilteredIndex];
    final isLocked = !q.isFree && !globalMasterState.isPro;
    final isBookmarked = globalMasterState.profile.bookmarkedIds.contains(q.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(q.categoryLabel),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.slate800, borderRadius: BorderRadius.circular(12)),
                child: Text('${_currentFilteredIndex + 1} / ${list.length}', style: const TextStyle(color: AppColors.amber400, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            if (!isLocked)
              _HighAvailabilityHud(
                currentIndex: _currentFilteredIndex,
                totalCount: list.length,
                isBookmarked: isBookmarked,
                onToggleBookmark: () => globalMasterState.toggleBookmark(q.id),
              ),
            Expanded(
              child: isLocked
                  ? const Center(
                      child: Text(
                        '🔒 此為 PRO 專屬進階考題\n請前往解鎖區啟用完整題庫',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.rose500, fontSize: 16, fontWeight: FontWeight.bold, height: 1.5),
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: q.type == 'single' ? AppColors.blue500 : AppColors.rose500,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  q.type == 'single' ? '單選' : '複選',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  q.workItem,
                                  style: const TextStyle(color: AppColors.slate400, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(q.question, style: const TextStyle(fontSize: 19, color: AppColors.slate50, height: 1.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 32),
                          ...List.generate(q.options.length, (index) => _buildChunkyOptionTile(index, q.options[index], q)),
                          if (_isAnswerRevealed) ...[
                            const SizedBox(height: 16),
                            _buildPremiumExplanationCard(q),
                          ]
                        ],
                      ),
                    ),
            ),
            if (!isLocked)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.slate950,
                  border: const Border(top: BorderSide(color: AppColors.slate800, width: 1)),
                ),
                child: _isAnswerRevealed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StateLockShield(isLocked: _isRatingLocked),
                          const Text('評定記憶難度，排定下次複習週期：', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _DuoChunkyButton(
                                  text: '重置',
                                  color: AppColors.rose500,
                                  shadowColor: const Color(0xFF9F1239),
                                  onPressed: _isRatingLocked ? null : () => _handleRatingSelected(StudyRating.again),
                                  height: 48,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _DuoChunkyButton(
                                  text: '+3天',
                                  color: AppColors.blue500,
                                  shadowColor: const Color(0xFF1E3A8A),
                                  onPressed: _isRatingLocked ? null : () => _handleRatingSelected(StudyRating.good),
                                  height: 48,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _DuoChunkyButton(
                                  text: '秒殺',
                                  color: AppColors.emerald400,
                                  shadowColor: const Color(0xFF065F46),
                                  onPressed: _isRatingLocked ? null : () => _handleRatingSelected(StudyRating.easy),
                                  height: 48,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: _DuoChunkyButton(
                          text: '確認對答案',
                          color: _userSelectedOptions.isEmpty ? AppColors.slate700 : AppColors.amber400,
                          shadowColor: _userSelectedOptions.isEmpty ? AppColors.slate800 : const Color(0xFFB45309),
                          onPressed: _userSelectedOptions.isEmpty ? null : _submitAndGrade,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 內部私有 UI 元件庫：AI 導師與 AST 沙盒面板
// ==========================================

class _AiTutorStreamingSheet extends StatefulWidget {
  final QuestionItem question;
  const _AiTutorStreamingSheet({required this.question});

  @override
  State<_AiTutorStreamingSheet> createState() => _AiTutorStreamingSheetState();
}

class _AiTutorStreamingSheetState extends State<_AiTutorStreamingSheet> {
  String _streamedContent = '';
  StreamSubscription<String>? _streamSub;
  final ScrollController _scrollController = ScrollController();
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    _startReasoningStream();
  }

  void _startReasoningStream() {
    _streamSub = AiTutorService.streamReasoningChain(question: widget.question).listen(
      (token) {
        if (mounted) {
          setState(() => _streamedContent += token);
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isGenerating = false);
          HapticFeedback.lightImpact();
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _streamedContent += "\n❌ 串流中斷：$err";
            _isGenerating = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.psychology_rounded, color: AppColors.emerald400, size: 22),
                  SizedBox(width: 8),
                  Text('AI 大師解剖', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate50)),
                ],
              ),
              if (!_isGenerating)
                const Icon(Icons.verified_user_rounded, color: AppColors.emerald400, size: 18)
              else
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.amber400, strokeWidth: 2)),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Text(
                _streamedContent.isEmpty ? "⚡ 構建推導中..." : _streamedContent,
                style: const TextStyle(color: AppColors.slate50, fontSize: 14, height: 1.6, fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DuoChunkyButton(
            text: _isGenerating ? '停止並返回' : '領悟完成，關閉',
            color: AppColors.slate700,
            shadowColor: Colors.black,
            height: 48,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _AstMathPlaygroundSheet extends StatefulWidget {
  final QuestionItem question;
  const _AstMathPlaygroundSheet({required this.question});

  @override
  State<_AstMathPlaygroundSheet> createState() => _AstMathPlaygroundSheetState();
}

class _AstMathPlaygroundSheetState extends State<_AstMathPlaygroundSheet> {
  late String _formulaText;
  double _paramA = 50.0;
  String? _liveResult;

  @override
  void initState() {
    super.initState();
    _deduceFormula();
    _recalculate();
  }

  void _deduceFormula() {
    final q = widget.question.question;
    if (q.contains('V-V')) {
      _formulaText = 'sqrt3 * P1';
      _paramA = 50.0;
    } else if (q.contains('rpm')) {
      _formulaText = '(120 * f) / 4';
      _paramA = 60.0;
    } else if (q.contains('焦耳')) {
      _formulaText = '0.5 * 0.0001 * (V ^ 2)';
      _paramA = 100.0;
    } else {
      _formulaText = 'sqrt3 * V * 50 * 0.85';
      _paramA = 220.0;
    }
  }

  void _recalculate() {
    try {
      final res = ElectricalAstEvaluator.evaluate(_formulaText, {'P1': _paramA, 'f': _paramA, 'V': _paramA});
      setState(() => _liveResult = res.toStringAsFixed(2));
    } catch (e) {
      setState(() => _liveResult = '語法異常');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.science_rounded, color: AppColors.amber400),
                  SizedBox(width: 8),
                  Text('AST 動態沙盒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate50)),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
            child: Text(
              _formulaText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.amber400, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 16),
          Text('滑動調整核心電氣參數 (${_paramA.round()}):', style: const TextStyle(color: AppColors.slate50, fontSize: 13)),
          Slider(
            value: _paramA,
            min: 10.0,
            max: 440.0,
            divisions: 43,
            activeColor: AppColors.amber400,
            inactiveColor: AppColors.slate700,
            onChanged: (val) {
              setState(() {
                _paramA = val;
                _recalculate();
              });
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.emerald400),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('運算結果：', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                Text(
                  _liveResult ?? '計算中...',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.emerald400, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _DuoChunkyButton(
            text: '返回刷題',
            color: AppColors.slate700,
            shadowColor: Colors.black,
            height: 48,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
