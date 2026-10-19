// ==========================================
// 專案名稱：電光證照霸 PRO - 全局視覺與色彩主題
// 檔案：lib/theme/app_theme.dart
// 說明：[CQO 修復版] 強制綁定本機系統字體，徹底消滅 CanvasKit 字體下載崩潰
// ==========================================

import 'package:flutter/material.dart';

class AppColors {
  static const Color slate950 = Color(0xFF020617);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate50  = Color(0xFFF8FAFC);

  static const Color amber400   = Color(0xFFFBBF24);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color rose500    = Color(0xFFF43F5E);
  static const Color blue500    = Color(0xFF3B82F6);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.slate950,
      primaryColor: AppColors.amber400,
      
      // 【核心修復】：強制使用 Windows / Mac 本機內建字體，阻斷網路字體下載
      fontFamily: 'Microsoft JhengHei',
      fontFamilyFallback: const ['PingFang TC', 'sans-serif'],

      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.slate50, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: AppColors.slate50, fontWeight: FontWeight.bold, fontSize: 20),
        bodyLarge: TextStyle(color: AppColors.slate50, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.slate400, fontSize: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber400,
          foregroundColor: AppColors.slate950,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.slate950,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.slate50),
        titleTextStyle: TextStyle(
          color: AppColors.slate50,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
