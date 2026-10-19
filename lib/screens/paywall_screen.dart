// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/screens/paywall_screen.dart
// 說明：Apple App Store 原生 StoreKit 直連收銀台（Dart 語法轉義合規版）
// ==========================================

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../theme/app_theme.dart';
import '../main.dart';

/// 唯一官方正式產品 ID (Non-Consumable 非消耗型終身買斷)
const String kProLifetimeProductId = 'esp_pro_lifetime_590';
const Set<String> _kProductIds = {kProLifetimeProductId};

class _IosGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;

  const _IosGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor = Colors.white12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.slate900.withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AppleStylePayButton extends StatefulWidget {
  final String label;
  final String priceText;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _AppleStylePayButton({
    required this.label,
    required this.priceText,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_AppleStylePayButton> createState() => _AppleStylePayButtonState();
}

class _AppleStylePayButtonState extends State<_AppleStylePayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.isLoading || widget.onPressed == null;
    return GestureDetector(
      onTapDown: (_) {
        if (!isDisabled) {
          HapticFeedback.lightImpact();
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (!isDisabled) {
          HapticFeedback.heavyImpact();
          setState(() => _isPressed = false);
          widget.onPressed!();
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _isPressed || isDisabled ? AppColors.amber400.withOpacity(0.5) : AppColors.amber400,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber400.withOpacity(_isPressed || isDisabled ? 0.0 : 0.4),
              blurRadius: _isPressed ? 4 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.apple_rounded, color: AppColors.slate950, size: 24),
                const SizedBox(width: 8),
                Text(
                  widget.isLoading ? '安全連線中...' : widget.label,
                  style: const TextStyle(color: AppColors.slate950, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            if (widget.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: AppColors.slate950, strokeWidth: 2),
              )
            else
              Text(
                widget.priceText,
                style: const TextStyle(
                  color: AppColors.slate950,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 條款與隱私權在線檢視器
class _LegalDocViewer extends StatelessWidget {
  final String title;
  final String content;

  const _LegalDocViewer({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return _IosGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AppColors.amber400, fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.slate400, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                content,
                style: const TextStyle(color: AppColors.slate300, fontSize: 13, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.slate800, foregroundColor: AppColors.slate50),
            child: const Text('我已瞭解並同意'),
          ),
        ],
      ),
    );
  }
}

class HardcorePaywallView extends StatefulWidget {
  const HardcorePaywallView({super.key});

  @override
  State<HardcorePaywallView> createState() => _HardcorePaywallViewState();
}

class _HardcorePaywallViewState extends State<HardcorePaywallView> {
  final TextEditingController _licenseKeyCtrl = TextEditingController();
  String _activationFeedback = '';

  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _proProductDetails;
  bool _isIapAvailable = false;
  bool _isPurchasePending = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _iap = InAppPurchase.instance;
      _initStoreInfo();
    }
  }

  Future<void> _initStoreInfo() async {
    if (_iap == null) return;

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap!.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('IAP Stream Error: $error'),
    );

    final bool isAvailable = await _iap!.isAvailable();
    if (!isAvailable) {
      if (mounted) setState(() => _isIapAvailable = false);
      return;
    }

    final ProductDetailsResponse response = await _iap!.queryProductDetails(_kProductIds);
    if (response.error == null && response.productDetails.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isIapAvailable = true;
          _proProductDetails = response.productDetails.firstWhere(
            (p) => p.id == kProLifetimeProductId,
            orElse: () => response.productDetails.first,
          );
        });
      }
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _isPurchasePending = true);
      } else {
        if (mounted) {
          setState(() {
            _isPurchasePending = false;
            _isRestoring = false;
          });
        }
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ 交易失敗：${purchaseDetails.error?.message}'),
              backgroundColor: AppColors.rose500,
            ),
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          globalMasterState.activateLicense('VIP888');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                purchaseDetails.status == PurchaseStatus.restored
                    ? '🎉 成功恢復購買！PRO 終身旗艦權限已同步！'
                    : '💳 Apple Pay 付款成功！PRO 終身旗艦版已啟用！',
              ),
              backgroundColor: AppColors.emerald400,
            ),
          );
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _iap?.completePurchase(purchaseDetails);
        }
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _licenseKeyCtrl.dispose();
    super.dispose();
  }

  void _attemptUnlock({String? directCode}) {
    final code = directCode ?? _licenseKeyCtrl.text;
    final success = globalMasterState.activateLicense(code);
    if (success) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 恭喜！PRO 終身旗艦版已全功能永久啟用！'),
          backgroundColor: AppColors.emerald400,
        ),
      );
    } else {
      HapticFeedback.vibrate();
      setState(() => _activationFeedback = '❌ 授權碼無效，請輸入 VIP888 或 PASS2026');
    }
  }

  void _buyProduct() {
    if (kIsWeb || _iap == null || !_isIapAvailable || _proProductDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💡 Web/展示模式：請輸入體驗碼 VIP888 解鎖。iOS 真機將直連 Apple Pay！'),
          backgroundColor: AppColors.amber400,
        ),
      );
      return;
    }
    _iap!.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: _proProductDetails!));
  }

  Future<void> _restorePurchases() async {
    HapticFeedback.mediumImpact();
    if (kIsWeb || _iap == null || !_isIapAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💡 當前環境無需恢復，請輸入 VIP888 體驗完整功能。'),
          backgroundColor: AppColors.amber400,
        ),
      );
      return;
    }

    setState(() => _isRestoring = true);
    try {
      await _iap!.restorePurchases();
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 恢復購買請求失敗: $e'),
            backgroundColor: AppColors.rose500,
          ),
        );
      }
    }
  }

  void _openInstantCheckoutModal() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _IosGlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('⚡ Apple IAP 快速結帳通道', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.amber400)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.slate400, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('雙證照終身買斷旗艦包', style: TextStyle(color: AppColors.slate50, fontWeight: FontWeight.w600)),
                        Text('NT\$ 890', style: TextStyle(color: AppColors.slate400, decoration: TextDecoration.lineThrough, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('考前衝刺限時折扣', style: TextStyle(color: AppColors.rose500, fontSize: 12)),
                        Text('- NT\$ 300', style: TextStyle(color: AppColors.rose500, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('應付總額 (終身買斷含稅)', style: TextStyle(color: AppColors.slate50, fontWeight: FontWeight.bold)),
                        Text('NT\$ 590', style: TextStyle(color: AppColors.emerald400, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _AppleStylePayButton(
                label: 'Apple Pay 授權購買',
                priceText: 'NT\$ 590',
                isLoading: _isPurchasePending,
                onPressed: _buyProduct,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showLegalDialog(String title, String content) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) => _LegalDocViewer(title: title, content: content),
      ),
    );
  }

  static const String _privacyPolicyText = '''
【電光證照霸 PRO 隱私權保護政策】
生效日期：2026 年 10 月 19 日

本應用程式（電光證照霸 PRO，以下簡稱「本 App」）深知個人隱私的重要性，特此說明本 App 的隱私權保護承諾：

1. 零資料收集與離線優先架構：
本 App 為「完全離線優先」架構，全量題庫、計算機與演算法皆內建於本地裝置。我們不會主動收集、儲存或傳輸您的姓名、電話、電子郵件、通訊錄或精確地理位置等任何個人識別資訊。

2. 學習紀錄之本地保存：
您的刷題紀錄、錯題佇列、書籤標記與記憶曲線狀態均透過本地二進位持久化磁區加密儲存於您的設備上。除非您手動匯出備份金鑰，否則該等資料絕不會上傳至任何雲端伺服器。

3. 應用程式內購買與交易安全：
本 App 的所有付費授權均透過 Apple 官方 StoreKit 支付機制（In-App Purchase）處理。您的信用卡、扣款帳號及帳單資訊完全由 Apple 官方伺服器加密處理，本 App 絕不會且無法取得您的財務敏感資訊。

4. 政策變更：
若本隱私權政策有任何修正，將直接於應用程式版本更新中公告。若您對本隱私權政策有任何疑問，歡迎隨時與開發團隊聯繫。
''';

  static const String _termsOfUseText = '''
【電光證照霸 PRO 終端使用者授權合約 (EULA)】
生效日期：2026 年 10 月 19 日

歡迎使用「電光證照霸 PRO」。當您下載、安裝或購買本應用程式時，即代表您同意接受本合約之所有條款：

1. 軟體授權與範圍：
本 App 授予您一項非專屬、不可轉讓且個人專用的軟體授權。您可在登入您個人 Apple ID 的所有合格 iOS / iPadOS 裝置上下載並使用本軟體。

2. 終身旗艦買斷權益：
購買「雙證照終身買斷旗艦包」（產品 ID：esp_pro_lifetime_590）為「非消耗型（Non-Consumable）」一次性買斷。您享有永久存取 813 題官方詳解、三大工程計算機與考前小抄匯出功能之權利，無需支付任何後續定期續訂費用。若更換設備，可透過「恢復購買」按鈕無償還原授權。

3. 學科檢定免責聲明：
本 App 收錄之題庫係依據中華民國勞動部勞動力發展署技能檢定中心官方公開題庫整理而成。本 App 為輔助學習與複習工具，無法保證使用者必然通過國家技術士技能檢定學科考試。

4. 智慧財產權與禁止事項：
本 App 內之所有程式原始碼、AST 解析引擎、自適應心流演算法與使用者介面設計均屬開發者所有。嚴禁未經授權對本 App 進行反向工程、反編譯、拆解或提取商業資料庫。

5. 準據法與爭議解決：
本授權合約之解釋與適用均以中華民國法律為準據法。
''';

  Widget _buildSingleLifetimePlanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.slate900.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.amber400, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.amber400.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber400,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '官方推薦 · 終身買斷',
                  style: TextStyle(color: AppColors.slate950, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              Row(
                children: const [
                  Text(
                    'NT\$ 890',
                    style: TextStyle(color: AppColors.slate400, fontSize: 13, decoration: TextDecoration.lineThrough),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'NT\$ 590',
                    style: TextStyle(color: AppColors.emerald400, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('雙證照終身買斷旗艦包', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.slate50)),
          const SizedBox(height: 8),
          const Text('無定期續訂負擔 · 跨裝置透過 Apple ID 永久恢復', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
          const Divider(color: Colors.white12, height: 24),
          _buildFeatureCheckRow('00700 乙級室內配線 813 道官方真題完整詳解'),
          _buildFeatureCheckRow('變壓器容量 / 線路壓降 / 功因改善 三大工程計算機'),
          _buildFeatureCheckRow('A4 格式「考前 10 分鐘弱點救命小抄」直接列印'),
          _buildFeatureCheckRow('FSRS 艾賓浩斯神經複習排程與錯題地獄斬殺'),
        ],
      ),
    );
  }

  Widget _buildFeatureCheckRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.emerald400, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.slate300, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLossAversionComparisonBanner() {
    return _IosGlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.rose500.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.trending_down_rounded, color: AppColors.rose500, size: 20),
              SizedBox(width: 8),
              Text('沒考過的沉沒代價：', style: TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '• 重新報考報名費：NT\$ 3,700 元（直接蒸發）\n• 苦等下一梯次：浪費 4 至 12 個月黃金升遷期\n• 牌照津貼延遲：少領至少 NT\$ 30,000 以上薪資',
            style: TextStyle(color: AppColors.slate400, fontSize: 12, height: 1.5),
          ),
          const Divider(color: Colors.white12, height: 16),
          Row(
            children: const [
              Icon(Icons.workspace_premium_rounded, color: AppColors.emerald400, size: 20),
              SizedBox(width: 8),
              Text('一次考過的投資回報率 (ROI)：', style: TextStyle(color: AppColors.emerald400, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '• 投資 NT\$ 590 終身買斷 813 題官方詳解 + 口袋計算機\n• 考取乙級室配：業界直接調薪 NT\$ 3,000 ~ 8,000 / 月！',
            style: TextStyle(color: AppColors.slate50, fontSize: 12, fontWeight: FontWeight.w600, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton() {
    return OutlinedButton.icon(
      onPressed: _isRestoring ? null : _restorePurchases,
      icon: _isRestoring
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(color: AppColors.amber400, strokeWidth: 2),
            )
          : const Icon(Icons.restore_rounded, color: AppColors.slate300, size: 16),
      label: Text(
        _isRestoring ? '正在連線 Apple 伺服器恢復...' : '恢復先前購買項目 (Restore Purchases)',
        style: const TextStyle(color: AppColors.slate300, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.slate800),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildLegalLinksFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showLegalDialog('隱私權保護政策', _privacyPolicyText),
                child: const Text(
                  '《隱私權保護政策》',
                  style: TextStyle(color: AppColors.slate400, fontSize: 11, decoration: TextDecoration.underline),
                ),
              ),
              const Text(' ｜ ', style: TextStyle(color: AppColors.slate700, fontSize: 11)),
              GestureDetector(
                onTap: () => _showLegalDialog('終端使用者授權合約 (EULA)', _termsOfUseText),
                child: const Text(
                  '《使用者條款 (EULA)》',
                  style: TextStyle(color: AppColors.slate400, fontSize: 11, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '付款將直接由 Apple StoreKit 加密處理，本 App 絕不儲存您的信用卡資訊。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate500, fontSize: 10),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: globalMasterState,
      builder: (context, child) {
        if (globalMasterState.isPro) {
          return Scaffold(
            backgroundColor: AppColors.slate950,
            appBar: AppBar(title: const Text('👑 VIP 尊榮權限中心', style: TextStyle(fontWeight: FontWeight.w900))),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 80, color: AppColors.emerald400),
                    const SizedBox(height: 24),
                    const Text('👑 尊榮 PRO 旗艦版已永久啟用', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.amber400)),
                    const SizedBox(height: 12),
                    const Text(
                      '您已完整解鎖 00700 乙級室內配線全量 813 題官方詳解、\n三大案場工程計算機與 A4 考前弱點救命小抄。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.slate400, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    _buildRestoreButton(),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.slate950,
          appBar: AppBar(
            title: const Text('💰 解鎖 PRO 旗艦通行證', style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(
                icon: const Icon(Icons.restore_rounded, color: AppColors.slate400),
                tooltip: '恢復購買',
                onPressed: _isRestoring ? null : _restorePurchases,
              ),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🎯 距離 115 年第 3 梯次大考進入衝刺倒數！', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.amber400)),
                const SizedBox(height: 4),
                const Text('拒絕死背無詳解 PDF，把失去的 20 分全部討回來。', style: TextStyle(fontSize: 13, color: AppColors.slate400)),
                const SizedBox(height: 16),
                _buildLossAversionComparisonBanner(),
                const SizedBox(height: 16),
                _buildSingleLifetimePlanCard(),
                const SizedBox(height: 16),
                _AppleStylePayButton(
                  label: 'Apple Pay 快速授權',
                  priceText: 'NT\$ 590',
                  isLoading: _isPurchasePending,
                  onPressed: _openInstantCheckoutModal,
                ),
                const SizedBox(height: 12),
                _buildRestoreButton(),
                const SizedBox(height: 24),
                const Center(child: Text('—— 或直接輸入線下授權碼 ——', style: TextStyle(color: AppColors.slate400, fontSize: 12))),
                const SizedBox(height: 12),
                TextField(
                  controller: _licenseKeyCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppColors.slate50, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                  decoration: const InputDecoration(
                    labelText: '輸入 VIP 授權序號 (測試體驗碼：VIP888)',
                    labelStyle: TextStyle(color: AppColors.slate400, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.slate900,
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.slate800)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.amber400)),
                  ),
                  onSubmitted: (_) => _attemptUnlock(),
                ),
                if (_activationFeedback.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_activationFeedback, style: const TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _attemptUnlock(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.slate800),
                    foregroundColor: AppColors.slate50,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('驗證手動序號'),
                ),
                const SizedBox(height: 20),
                _buildLegalLinksFooter(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
