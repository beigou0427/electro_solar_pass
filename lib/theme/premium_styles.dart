// ==========================================
// 專案名稱：電光證照霸 PRO
// 檔案：lib/theme/premium_styles.dart
// CMO 注入：Phil Schiller (Apple) - 第 1/3 段：核心視覺美學引擎
// 說明：提供毛玻璃(Glassmorphism)、物理彈簧動畫與尊榮漸層
// ==========================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_theme.dart';

class PremiumStyles {
  /// Apple 風格毛玻璃背景 (Glassmorphism)
  /// 解決方案：利用 BackdropFilter 達成硬體加速的實時高斯模糊
  static Widget glassBox({
    required Widget child,
    double blur = 12.0,
    double opacity = 0.65,
    BorderRadiusGeometry? borderRadius,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.slate900.withOpacity(opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1), // 極細高光邊緣
          ),
          child: child,
        ),
      ),
    );
  }

  /// 尊榮級旗艦漸層文字 (用於強調「官方精準解析」等付費賣點)
  static Widget gradientText(String text, {required TextStyle style, required List<Color> colors}) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }

  /// 物理彈簧曲線 (模擬 Apple ProMotion 的自然滑順感)
  /// 摒棄死板的 Curves.easeInOut，改用具備減速物理特性的 Circ 曲線
  static const Curve springCurve = Curves.easeOutCirc;
}
