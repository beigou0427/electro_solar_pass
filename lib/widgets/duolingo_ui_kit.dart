// ==========================================
// 專案名稱：電光證照霸 PRO
// 檔案：lib/widgets/duolingo_ui_kit.dart
// 戰略注入：Duolingo 級多巴胺微交互 (Juicy UI)
// 說明：實作帶有物理下壓回饋的 3D 按鈕與 Q 彈進度條
// ==========================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// 【Duolingo 經典 3D 物理按壓按鈕】
class DuoChunkyButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color shadowColor;
  final IconData? icon;
  final bool isSecondary;

  const DuoChunkyButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = AppColors.emerald400,
    this.shadowColor = const Color(0xFF059669), // 深綠色陰影
    this.icon,
    this.isSecondary = false,
  });

  @override
  State<DuoChunkyButton> createState() => _DuoChunkyButtonState();
}

class _DuoChunkyButtonState extends State<DuoChunkyButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    HapticFeedback.selectionClick();
    setState(() => _isPressed = false);
    widget.onPressed();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final double pushOffset = _isPressed ? 6.0 : 0.0; // 按壓時向下位移
    final bgColor = widget.isSecondary ? AppColors.slate800 : widget.color;
    final fgColor = widget.isSecondary ? AppColors.slate400 : AppColors.slate950;
    final sColor = widget.isSecondary ? AppColors.slate900 : widget.shadowColor;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: pushOffset, bottom: 6.0 - pushOffset),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSecondary ? AppColors.slate700 : Colors.transparent, 
            width: 2
          ),
          // 模擬 3D 厚度陰影
          boxShadow: [
            BoxShadow(
              color: sColor,
              offset: Offset(0, 6.0 - pushOffset),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: fgColor, size: 22),
              const SizedBox(width: 8),
            ],
            Text(
              widget.text,
              style: TextStyle(
                color: fgColor,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 【Duolingo 風格 Q 彈動畫進度條】
class DuoJuicyProgressBar extends StatelessWidget {
  final double progress; // 0.0 ~ 1.0
  final Color color;

  const DuoJuicyProgressBar({
    super.key,
    required this.progress,
    this.color = AppColors.amber400,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: AppColors.slate800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut, // Q 彈曲線
                width: constraints.maxWidth * progress,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // 進度條上的高光反光 (Juicy Shine Effect)
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                width: constraints.maxWidth * progress,
                margin: const EdgeInsets.only(top: 4, left: 8, right: 8),
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
