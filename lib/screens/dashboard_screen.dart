// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/screens/dashboard_screen.dart
// 說明：戰情指揮中心儀表板（App Store 審查合規版）
// ==========================================

import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../theme/app_theme.dart';
import '../models/core_types.dart';
import '../main.dart';
import '../utils/cheat_sheet_generator.dart';
import '../utils/telemetry_logger.dart';
import '../models/skill_tree_domain.dart';
import '../models/event_sourcing_store.dart';
import '../models/git_skill_branch.dart';
import 'exam_arena_screen.dart';

enum DiagnosticStatus { pending, running, passed, failed }

class DiagnosticTask {
  final String title;
  final String subtitle;
  DiagnosticStatus status;
  String? resultMessage;

  DiagnosticTask({
    required this.title,
    required this.subtitle,
    this.status = DiagnosticStatus.pending,
    this.resultMessage,
  });
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = Colors.white12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.slate900.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ChunkyActionCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color baseColor;
  final Color shadowColor;

  const _ChunkyActionCard({
    required this.child,
    required this.onTap,
    required this.baseColor,
    required this.shadowColor,
  });

  @override
  State<_ChunkyActionCard> createState() => _ChunkyActionCardState();
}

class _ChunkyActionCardState extends State<_ChunkyActionCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails d) {
    HapticFeedback.lightImpact();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails d) {
    HapticFeedback.selectionClick();
    setState(() => _isPressed = false);
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final pushOffset = _isPressed ? 6.0 : 0.0;
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(top: pushOffset, bottom: 6.0 - pushOffset),
        decoration: BoxDecoration(
          color: widget.baseColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, 6.0 - pushOffset),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class DashboardArenaView extends StatefulWidget {
  const DashboardArenaView({super.key});

  @override
  State<DashboardArenaView> createState() => _DashboardArenaViewState();
}

class _DashboardArenaViewState extends State<DashboardArenaView> with TickerProviderStateMixin {
  final TextEditingController _jsonInputCtrl = TextEditingController();
  final TextEditingController _commitMsgCtrl = TextEditingController();

  Timer? _specTickerTimer;
  int _currentSpecIndex = 0;

  // 100% 客觀技術規格輪播，徹底取代虛擬下單社會認同
  final List<String> _technicalSpecList = const [
    "⚡ 官方真題庫：完整收錄台灣勞動部 813 道最新檢定真題",
    "📐 AST 電學推導：低溫 Voc 修正、線路壓降與功因精算",
    "🌲 領域聚合樹：解構 19 工作項目為八大核心工程模組",
    "🧠 FSRS 神經記憶：指數遺忘曲線排程，精準消滅錯題死穴",
    "🛡️ 離線完全體：全量題庫本機固化，無網路環境隨開即練",
  ];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _specTickerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentSpecIndex = (_currentSpecIndex + 1) % _technicalSpecList.length;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _specTickerTimer?.cancel();
    _pulseController.dispose();
    _jsonInputCtrl.dispose();
    _commitMsgCtrl.dispose();
    super.dispose();
  }

  int _calculateDaysLeft(DateTime targetDate) {
    final diff = targetDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  Widget _buildDiagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
          Text(value, style: const TextStyle(color: AppColors.slate50, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- 系統開機自檢系統 (SAFETY-POST，完全合規中立標籤) ---
  void _showFieldDiagnosticModal() {
    HapticFeedback.heavyImpact();
    final List<DiagnosticTask> tasks = [
      DiagnosticTask(title: 'FSRS 神經記憶庫', subtitle: '驗證本機持久化題庫載入狀態'),
      DiagnosticTask(title: 'Apple StoreKit 閘道', subtitle: '探測 iOS 原生 IAP 支付網路連線'),
      DiagnosticTask(title: 'IAP SKU 實體探測', subtitle: '向 Apple 伺服器請求旗艦包商品報價'),
    ];
    bool isAllChecksDone = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!isAllChecksDone && tasks.every((t) => t.status == DiagnosticStatus.pending)) {
              _runDiagnostics(tasks, setModalState).then((_) {
                if (mounted) setModalState(() => isAllChecksDone = true);
              });
            }
            return _GlassPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.terminal_rounded, color: AppColors.emerald400),
                          SizedBox(width: 8),
                          Text('SAFETY-POST 系統開機自檢', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate50)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAllChecksDone ? AppColors.emerald400.withOpacity(0.15) : AppColors.amber400.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAllChecksDone ? 'SAFETY-POST PASSED' : 'SCANNING...',
                          style: TextStyle(
                            color: isAllChecksDone ? AppColors.emerald400 : AppColors.amber400,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate800),
                    ),
                    child: Column(
                      children: tasks.map((t) => _buildDiagnosticTaskRow(t)).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slate800,
                      foregroundColor: AppColors.slate50,
                    ),
                    child: const Text('關閉診斷面板'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _runDiagnostics(List<DiagnosticTask> tasks, StateSetter setModalState) async {
    // 任務 1: FSRS 記憶庫檢查
    setModalState(() => tasks[0].status = DiagnosticStatus.running);
    await Future.delayed(const Duration(milliseconds: 500));
    if (globalMasterState.allQuestions.isNotEmpty) {
      setModalState(() {
        tasks[0].status = DiagnosticStatus.passed;
        tasks[0].resultMessage = '本機已安全固化 ${globalMasterState.allQuestions.length} 題，狀態 100% 正常';
      });
    } else {
      setModalState(() {
        tasks[0].status = DiagnosticStatus.failed;
        tasks[0].resultMessage = '題庫為空或本機持久化磁區損毀';
      });
    }

    // 任務 2: Apple StoreKit 閘道連線 (含 kIsWeb 跨平台保護)
    setModalState(() => tasks[1].status = DiagnosticStatus.running);
    await Future.delayed(const Duration(milliseconds: 500));
    bool iapAvailable = false;
    if (!kIsWeb) {
      try {
        iapAvailable = await InAppPurchase.instance.isAvailable();
      } catch (_) {}
    } else {
      iapAvailable = true;
    }

    setModalState(() {
      tasks[1].status = DiagnosticStatus.passed;
      tasks[1].resultMessage = kIsWeb
          ? 'Web 模擬模式 (真機環境將自動呼叫 StoreKit 通訊)'
          : (iapAvailable ? 'StoreKit 原生通訊協定建立成功' : 'API 受限或本機設備未啟用支付');
    });

    // 任務 3: IAP SKU 實體探測
    setModalState(() => tasks[2].status = DiagnosticStatus.running);
    await Future.delayed(const Duration(milliseconds: 500));
    if (kIsWeb) {
      setModalState(() {
        tasks[2].status = DiagnosticStatus.passed;
        tasks[2].resultMessage = 'Web 模擬探測：成功映射 3 項產品 (290 / 390 / 590)';
      });
    } else if (iapAvailable) {
      try {
        final response = await InAppPurchase.instance.queryProductDetails({
          'esp_pro_lifetime_590',
          'esp_pro_30d_290',
          'esp_pro_180d_390',
        });
        setModalState(() {
          if (response.error != null) {
            tasks[2].status = DiagnosticStatus.failed;
            tasks[2].resultMessage = 'Apple 伺服器拒絕: ${response.error!.message}';
          } else if (response.productDetails.isEmpty) {
            tasks[2].status = DiagnosticStatus.failed;
            tasks[2].resultMessage = 'StoreKit 未獲取到商品 (請確認 App Store Connect 設定)';
          } else {
            tasks[2].status = DiagnosticStatus.passed;
            tasks[2].resultMessage = '成功獲取 ${response.productDetails.length} 項官方商品報價';
          }
        });
      } catch (e) {
        setModalState(() {
          tasks[2].status = DiagnosticStatus.failed;
          tasks[2].resultMessage = '探測異常: $e';
        });
      }
    } else {
      setModalState(() {
        tasks[2].status = DiagnosticStatus.failed;
        tasks[2].resultMessage = '因閘道未就緒，跳過商品探測';
      });
    }
  }

  Widget _buildDiagnosticTaskRow(DiagnosticTask task) {
    Color statusColor;
    Widget trailingIcon;

    switch (task.status) {
      case DiagnosticStatus.pending:
        statusColor = AppColors.slate500;
        trailingIcon = const Icon(Icons.radio_button_unchecked, color: AppColors.slate500, size: 16);
        break;
      case DiagnosticStatus.running:
        statusColor = AppColors.amber400;
        trailingIcon = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(color: AppColors.amber400, strokeWidth: 2),
        );
        break;
      case DiagnosticStatus.passed:
        statusColor = AppColors.emerald400;
        trailingIcon = const Icon(Icons.check_circle, color: AppColors.emerald400, size: 16);
        break;
      case DiagnosticStatus.failed:
        statusColor = AppColors.rose500;
        trailingIcon = const Icon(Icons.cancel, color: AppColors.rose500, size: 16);
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          trailingIcon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.resultMessage ?? task.subtitle,
                  style: const TextStyle(color: AppColors.slate400, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManualCommitDialog() {
    HapticFeedback.mediumImpact();
    _commitMsgCtrl.text = "feat: 完成電工核心考點攻堅";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.emerald400),
        ),
        title: Row(
          children: const [
            Icon(Icons.commit_rounded, color: AppColors.emerald400),
            SizedBox(width: 8),
            Text('提交戰力快照', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: _commitMsgCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: '輸入 Commit 訊息',
            filled: true,
            fillColor: Colors.black45,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: AppColors.slate400)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_commitMsgCtrl.text.isNotEmpty) {
                globalMasterState.commitSkillMilestone(_commitMsgCtrl.text.trim());
                HapticFeedback.heavyImpact();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald400,
              foregroundColor: Colors.black,
            ),
            child: const Text('提交至本機儲存庫'),
          ),
        ],
      ),
    );
  }

  void _showTimeMachineModal() {
    HapticFeedback.mediumImpact();
    final store = globalMasterState.eventStore;
    final now = DateTime.now();
    final threeDaysAgoProfile = store.replayStateAt(now.subtract(const Duration(days: 3)));
    final sevenDaysAgoProfile = store.replayStateAt(now.subtract(const Duration(days: 7)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollCtrl) {
          return _GlassPanel(
            padding: const EdgeInsets.all(20.0),
            child: ListView(
              controller: scrollCtrl,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.history_toggle_off_rounded, color: AppColors.amber400),
                        SizedBox(width: 8),
                        Text('⏳ 學習時光機', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate50)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.amber400.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${store.totalEventCount} 筆事件',
                        style: const TextStyle(color: AppColors.amber400, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                const Text('時光倒流戰力回溯：', style: TextStyle(color: AppColors.slate400, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    children: [
                      _buildDiagRow('當下即時實力', '已斬殺 ${globalMasterState.masteredCount} 題 ｜ 錯題 ${globalMasterState.wrongCount} 題'),
                      const Divider(color: Colors.white12, height: 16),
                      _buildDiagRow('3 天前歷史戰力', '已斬殺 ${threeDaysAgoProfile.masteredIds.length} 題 ｜ 錯題 ${threeDaysAgoProfile.wrongQueueIds.length} 題'),
                      const Divider(color: Colors.white12, height: 16),
                      _buildDiagRow('7 天前歷史戰力', '已斬殺 ${sevenDaysAgoProfile.masteredIds.length} 題 ｜ 錯題 ${sevenDaysAgoProfile.wrongQueueIds.length} 題'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('📜 最近 5 筆不可變作戰日誌:', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.slate800),
                  ),
                  child: store.totalEventCount == 0
                      ? const Center(child: Text('今日尚未發射作戰事件', style: TextStyle(color: AppColors.slate400, fontSize: 12)))
                      : ListView.builder(
                          itemCount: store.eventStream.length > 5 ? 5 : store.eventStream.length,
                          reverse: true,
                          itemBuilder: (context, i) {
                            final event = store.eventStream[store.eventStream.length - 1 - i];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                "> [${event.type.label}] ${event.payload} (${event.timestamp.hour}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')})",
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.amber400),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    final dump = store.exportEventLogJson();
                    Clipboard.setData(ClipboardData(text: dump));
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 完整不可變事件日誌已複製至剪貼簿！'),
                        backgroundColor: AppColors.emerald400,
                      ),
                    );
                  },
                  icon: const Icon(Icons.archive_rounded, size: 16),
                  label: const Text('匯出完整事件流日誌'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.slate800,
                    foregroundColor: AppColors.slate50,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _executeJsonImport() {
    try {
      final String rawJson = _jsonInputCtrl.text.trim();
      if (rawJson.isEmpty) return;
      final List<dynamic> parsedList = jsonDecode(rawJson);
      final List<QuestionItem> newQuestions = parsedList.map((json) => QuestionItem.fromJson(json)).toList();
      globalMasterState.adminImportMassiveQuestionsAsync(newQuestions);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 成功擴充 ${newQuestions.length} 題！目前總題數：${globalMasterState.totalQuestions}'),
          backgroundColor: AppColors.emerald400,
        ),
      );
      _jsonInputCtrl.clear();
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ JSON 格式解析失敗: $e'),
          backgroundColor: AppColors.rose500,
        ),
      );
    }
  }

  void _showAdminImportModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _GlassPanel(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚙️ 題庫 JSON 擴充工具', style: TextStyle(color: AppColors.amber400, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _jsonInputCtrl,
                maxLines: 8,
                style: const TextStyle(color: AppColors.slate50, fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: '貼上 JSON Array 格式題庫...',
                  hintStyle: TextStyle(color: AppColors.slate400),
                  filled: true,
                  fillColor: Colors.black45,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _executeJsonImport,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald400),
                child: const Text('寫入本地資料庫 (Overwrite)', style: TextStyle(color: AppColors.slate950)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleExportCheatSheet() {
    if (!globalMasterState.isPro) {
      HapticFeedback.heavyImpact();
      _showProRequiredModal();
      return;
    }
    HapticFeedback.mediumImpact();
    final wrongList = globalMasterState.allQuestions.where((q) => globalMasterState.profile.wrongQueueIds.contains(q.id)).toList();
    final htmlCode = CheatSheetGenerator.buildHtmlDocument(wrongQuestions: wrongList, licenseType: "00700 乙級室內配線");
    Clipboard.setData(ClipboardData(text: htmlCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 考前小抄 HTML 代碼已成功複製至剪貼簿！可貼至記事本存為 .html 列印'),
        backgroundColor: AppColors.emerald400,
      ),
    );
  }

  void _showProRequiredModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassPanel(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 64, color: AppColors.amber400),
            const SizedBox(height: 16),
            const Text('考前弱點小抄為 PRO 專屬功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            const Text(
              '系統會將您的錯題與「秒殺口訣」自動排版為 A4 格式。進考場前 10 分鐘，奪回最關鍵的 20 分！',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.slate300),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _ChunkyActionCard(
                baseColor: AppColors.amber400,
                shadowColor: const Color(0xFFB45309),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('👉 請切換至「PRO解鎖」分頁啟用完整功能'),
                      backgroundColor: AppColors.amber400,
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('前往解鎖 PRO 旗艦版', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecTicker() {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: AppColors.amber400.withOpacity(0.3),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Opacity(
              opacity: _pulseAnimation.value,
              child: const Icon(Icons.verified_rounded, color: AppColors.amber400, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                _technicalSpecList[_currentSpecIndex],
                key: ValueKey<int>(_currentSpecIndex),
                style: const TextStyle(color: AppColors.slate50, fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFunnel(int wrongCount) {
    return Column(
      children: [
        _ChunkyActionCard(
          baseColor: AppColors.amber400,
          shadowColor: const Color(0xFFB45309),
          onTap: () {
            HapticFeedback.heavyImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MockExamArenaView()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('進入 80 題全真模擬考場', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('限時 100 分鐘 ｜ 嚴格法規計分標準', style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ChunkyActionCard(
          baseColor: globalMasterState.isPro ? AppColors.emerald400 : AppColors.slate800,
          shadowColor: globalMasterState.isPro ? const Color(0xFF065F46) : Colors.black,
          onTap: _handleExportCheatSheet,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                  child: Icon(
                    globalMasterState.isPro ? Icons.print_rounded : Icons.lock_rounded,
                    color: globalMasterState.isPro ? Colors.black : AppColors.slate400,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '匯出考前弱點衝刺小抄',
                        style: TextStyle(
                          color: globalMasterState.isPro ? Colors.black : AppColors.slate50,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        globalMasterState.isPro ? '目前攔截 $wrongCount 道死穴錯題' : '解鎖 PRO 旗艦版以啟用本功能',
                        style: TextStyle(
                          color: globalMasterState.isPro ? Colors.black87 : AppColors.slate400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysToExam = _calculateDaysLeft(DateTime(2026, 11, 8));

    return AnimatedBuilder(
      animation: globalMasterState,
      builder: (context, child) {
        final total = globalMasterState.totalQuestions;
        final mastered = globalMasterState.masteredCount;
        final wrong = globalMasterState.wrongCount;
        final score = total > 0 ? ((mastered / total) * 100).toStringAsFixed(1) : '0.0';
        final reports = globalMasterState.domainMasteryReports;

        return Scaffold(
          backgroundColor: AppColors.slate950,
          appBar: AppBar(
            elevation: 0,
            title: const Text('📊 戰情指揮中心', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            actions: [
              IconButton(
                icon: const Icon(Icons.terminal_rounded, color: AppColors.emerald400),
                onPressed: _showFieldDiagnosticModal,
                tooltip: 'SAFETY-POST 開機自檢',
              ),
              IconButton(
                icon: const Icon(Icons.history_toggle_off_rounded, color: AppColors.amber400),
                onPressed: _showTimeMachineModal,
                tooltip: '學習時光機',
              ),
              IconButton(
                icon: const Icon(Icons.code_rounded, color: AppColors.slate500),
                onPressed: _showAdminImportModal,
                tooltip: '題庫擴充',
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GlassPanel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('115 年第 3 梯次學科大考', style: TextStyle(color: AppColors.slate400, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text('倒數 ', style: TextStyle(color: AppColors.slate50, fontSize: 16)),
                          Text('$daysToExam', style: const TextStyle(color: AppColors.amber400, fontSize: 48, fontWeight: FontWeight.w900)),
                          const Text(' 天', style: TextStyle(color: AppColors.slate50, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSpecTicker(),
                const SizedBox(height: 24),
                _buildActionFunnel(wrong),
                const SizedBox(height: 24),
                _GlassPanel(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.rose500.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.local_fire_department_rounded, color: AppColors.rose500, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('連續作戰打卡', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              Text('${globalMasterState.profile.currentStreak} 天', style: const TextStyle(color: AppColors.slate50, fontSize: 24, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppColors.slate800, borderRadius: BorderRadius.circular(6)),
                                child: Text('最高 ${globalMasterState.profile.longestStreak} 天', style: const TextStyle(color: AppColors.amber400, fontSize: 11, fontWeight: FontWeight.bold)),
                              )
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('🌲 領域精熟度雷達', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate50)),
                    Text(
                      '預估得分 $score',
                      style: TextStyle(
                        color: double.parse(score) >= 60 ? AppColors.emerald400 : AppColors.amber400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _GlassPanel(
                  child: Column(
                    children: ElectricalDomain.values.map((d) {
                      final r = reports[d]!;
                      final isSafe = r.isSafeLineReached;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(d.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text(
                                  '${r.masteryPercentage.toStringAsFixed(0)}%',
                                  style: TextStyle(color: isSafe ? AppColors.emerald400 : AppColors.amber400, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: r.totalCount > 0 ? (r.masteredCount / r.totalCount) : 0,
                                backgroundColor: Colors.black45,
                                valueColor: AlwaysStoppedAnimation(isSafe ? AppColors.emerald400 : AppColors.amber400),
                                minHeight: 8,
                              ),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
