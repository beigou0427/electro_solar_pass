// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/main.dart
// 說明：[主程式入口] 非阻塞極速秒開與 Watchdog 防禦完全體
// ==========================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'utils/telemetry_logger.dart';

import 'screens/dashboard_screen.dart';
import 'screens/quiz_screen.dart';
import 'screens/exam_arena_screen.dart';
import 'screens/calculators_screen.dart';
import 'screens/paywall_screen.dart';

// 【全域大腦初始化】
final AppState globalMasterState = AppState();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 全域異常安全隔離盾
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    telemetry.logEvent(
      eventName: 'SYSTEM_FAULT_INTERCEPTED',
      parameters: {
        'exception': details.exception.toString(),
        'library': details.library ?? 'framework',
      },
    );
  };

  // 2. 🚀 【核心防禦】：先啟動畫面 (runApp)，0 延遲秒開進大廳，絕對不阻塞首幀！
  runApp(const ElectroSolarPassHeroApp());

  // 3. StoreKit 探測改為「背景非同步」，徹底封殺 iOS Watchdog 19.5秒超時閃退
  if (kDebugMode) {
    _runAsyncStoreKitPreflight();
  }
}

void _runAsyncStoreKitPreflight() async {
  debugPrint('\n=================================================================');
  debugPrint('🚀 [SYSTEM BOOT] 啟動電光證照霸 PRO 背景非同步自檢程序...');
  if (!kIsWeb) {
    try {
      final bool iapAvailable = await InAppPurchase.instance.isAvailable();
      debugPrint('  • StoreKit 狀態: ${iapAvailable ? "🟢 就緒" : "⚠️ 離線/未就緒"}');
    } catch (e) {
      debugPrint('  • 探測異常 (已優雅隔離): $e');
    }
  }
  debugPrint('=================================================================\n');
}

class ElectroSolarPassHeroApp extends StatelessWidget {
  const ElectroSolarPassHeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 🍎 與桌面名稱、審查文案保持 1:1 絕對一致
      title: '電光證照霸 PRO - 乙級室內配線',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const DashboardShellNavigator(),
    );
  }
}

class DashboardShellNavigator extends StatefulWidget {
  const DashboardShellNavigator({super.key});

  @override
  State<DashboardShellNavigator> createState() => _DashboardShellNavigatorState();
}

class _DashboardShellNavigatorState extends State<DashboardShellNavigator> {
  int _activeModuleIndex = 0;

  final List<Widget> _strategicModules = const [
    DashboardArenaView(),
    ElectroQuizArenaView(),
    MockExamArenaView(),
    FieldEngineerToolboxView(),
    HardcorePaywallView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _activeModuleIndex,
        children: _strategicModules,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _activeModuleIndex,
        onTap: (newIndex) => setState(() => _activeModuleIndex = newIndex),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.slate900,
        selectedItemColor: AppColors.amber400,
        unselectedItemColor: AppColors.slate400,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: '戰情室'),
          BottomNavigationBarItem(icon: Icon(Icons.bolt_rounded), label: '刷題斬'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in_rounded), label: '模擬考'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate_rounded), label: '計算機'),
          BottomNavigationBarItem(icon: Icon(Icons.workspace_premium_rounded), label: 'PRO解鎖'),
        ],
      ),
    );
  }
}
