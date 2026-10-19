// ==========================================
// 專案名稱：電光證照霸 PRO
// 檔案：lib/widgets/aha_moment_feedback.dart
// CMO 注入：Phil Schiller (情緒價值引擎)
// ==========================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/premium_styles.dart';
import 'duolingo_ui_kit.dart';

class AhaMomentFeedback extends StatefulWidget {
  final bool isSuccess;
  final String title;
  final String subtitle;
  final VoidCallback onDismiss;

  const AhaMomentFeedback({
    super.key, required this.isSuccess, required this.title, required this.subtitle, required this.onDismiss,
  });

  static void trigger(BuildContext context, {required bool isSuccess, required String title, required String subtitle}) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: 'Dismiss', barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim, secondaryAnim) => AhaMomentFeedback(isSuccess: isSuccess, title: title, subtitle: subtitle, onDismiss: () => Navigator.of(context).pop()),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(opacity: anim, child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: anim, curve: PremiumStyles.springCurve)), child: child));
      },
    );
  }

  @override
  State<AhaMomentFeedback> createState() => _AhaMomentFeedbackState();
}

class _AhaMomentFeedbackState extends State<AhaMomentFeedback> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 4.0, end: 20.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.isSuccess ? AppColors.emerald400 : AppColors.rose500;
    final icon = widget.isSuccess ? Icons.workspace_premium_rounded : Icons.local_fire_department_rounded;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: _glowAnimation.value, spreadRadius: _glowAnimation.value / 2)]),
              child: child,
            );
          },
          child: PremiumStyles.glassBox(
            blur: 24.0, opacity: 0.8, padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 80, color: primaryColor),
                const SizedBox(height: 24),
                PremiumStyles.gradientText(widget.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.2), colors: [primaryColor, Colors.white]),
                const SizedBox(height: 12),
                Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.slate300, height: 1.5)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: DuoChunkyButton(text: '繼續推進', color: primaryColor, shadowColor: primaryColor.withOpacity(0.5), onPressed: widget.onDismiss),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
