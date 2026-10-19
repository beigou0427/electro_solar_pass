// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/models/skill_tree_domain.dart
// CTO 注入：Martin Fowler (ThoughtWorks) - 第 1/3 段：領域驅動考點技能樹
// 說明：[DDD 架構] 解構官僚工作項目，建立八大電工領域聚合根與技能圖譜模型
// ==========================================

import 'core_types.dart';

/// Martin Fowler 八大電工領域聚合根 (Domain Aggregate Roots)
enum ElectricalDomain {
  transformer(
    id: "DOM-01",
    name: "變壓器與電磁系統",
    iconCode: 0xe84f, // Icons.flash_on
    weight: 0.18,
    description: "變壓器結線(V-V/Δ-Y)、容量試算、阻抗百分比、鐵損銅損與變比測試",
  ),
  motorControl(
    id: "DOM-02",
    name: "電動機與工控動力",
    iconCode: 0xe566, // Icons.settings
    weight: 0.20,
    description: "三相感應馬達、轉差率計算、Y-Δ降壓啟動、正反轉互鎖與過載保護",
  ),
  wiringConduit(
    id: "DOM-03",
    name: "低壓配線與管槽工程",
    iconCode: 0xe558, // Icons.cable
    weight: 0.15,
    description: "導線安培容量、金屬管/PVC配管、線槽40%佔有率、壓降計算",
  ),
  groundingSafety(
    id: "DOM-04",
    name: "接地防護與人身工安",
    iconCode: 0xe577, // Icons.shield
    weight: 0.14,
    description: "特種/一/二/三種接地歐姆值、漏電斷路器30mA/0.1s、高空作業與CPR",
  ),
  powerDistribution(
    id: "DOM-05",
    name: "高低壓受配電與儀表",
    iconCode: 0xe8d4, // Icons.dashboard
    weight: 0.12,
    description: "配電箱分路、高壓VCB/GIS、MOF變比器、電度表配裝與比流器負擔",
  ),
  powerFactor(
    id: "DOM-06",
    name: "電容器與功因改善",
    iconCode: 0xe1a4, // Icons.battery_charging_full
    weight: 0.08,
    description: "功因95%改善原則、並聯電容器kVAR試算、串聯電抗器與台電獎懲",
  ),
  automation(
    id: "DOM-07",
    name: "自動化 PLC 與變頻器",
    iconCode: 0xe97a, // Icons.developer_board
    weight: 0.08,
    description: "可程式控制器階梯圖、Modbus通訊協定、變頻器V/f控制與煞車電阻",
  ),
  regulations(
    id: "DOM-08",
    name: "國家電業法規與規章",
    iconCode: 0xe8ef, // Icons.gavel
    weight: 0.05,
    description: "台電營業規章、需量契約容量計算、甲級承裝業資本額與技師簽證門檻",
  );

  final String id;
  final String name;
  final int iconCode;
  final double weight;
  final String description;

  const ElectricalDomain({
    required this.id,
    required this.name,
    required this.iconCode,
    required this.weight,
    required this.description,
  });
}

/// 領域精熟度診斷報告實體 (Domain Competency Value Object)
class DomainMasteryReport {
  final ElectricalDomain domain;
  final int totalCount;
  final int masteredCount;
  final int wrongCount;
  final int untouchedCount;

  const DomainMasteryReport({
    required this.domain,
    required this.totalCount,
    required this.masteredCount,
    required this.wrongCount,
    required this.untouchedCount,
  });

  /// 技能掌握率 (0.0% ~ 100.0%)
  double get masteryPercentage =>
      totalCount > 0 ? (masteredCount / totalCount) * 100.0 : 0.0;

  /// 弱點暴露率 (0.0% ~ 100.0%)：衡量該領域是否急需補強
  double get vulnerabilityRatio =>
      totalCount > 0 ? (wrongCount / totalCount) * 100.0 : 0.0;

  /// 是否達到考前安全防護線 (掌握率 ≥ 75%)
  bool get isSafeLineReached => masteryPercentage >= 75.0;
}

/// Martin Fowler 領域對映器 (Domain Mapper & Knowledge Graph Bridge)
class SkillTreeDomainMapper {
  /// 將官方 19 個官僚工作項目，精準歸納投影至八大工程領域聚合根
  static ElectricalDomain resolveDomain(QuestionItem q) {
    final wi = q.workItem;
    final text = q.question;

    // 1. 變壓器領域
    if (wi.contains('變壓器') || text.contains('V-V') || text.contains('變壓比') || text.contains('自耦')) {
      return ElectricalDomain.transformer;
    }
    // 2. 電動機工控領域
    if (wi.contains('電動機') || text.contains('馬達') || text.contains('轉差率') || text.contains('Y-Δ')) {
      return ElectricalDomain.motorControl;
    }
    // 3. 自動化與變頻領域
    if (wi.contains('可程式控制器') || wi.contains('變頻器') || text.contains('PLC') || text.contains('Modbus')) {
      return ElectricalDomain.automation;
    }
    // 4. 接地與安全領域
    if (wi.contains('接地') || wi.contains('工作安全') || text.contains('感電') || text.contains('CPR')) {
      return ElectricalDomain.groundingSafety;
    }
    // 5. 電容器與功因領域
    if (wi.contains('電容器') || text.contains('功率因數') || text.contains('kVAR')) {
      return ElectricalDomain.powerFactor;
    }
    // 6. 受配電與儀表領域
    if (wi.contains('配電盤') || wi.contains('儀表') || wi.contains('開關') || text.contains('VCB') || text.contains('斷路器')) {
      return ElectricalDomain.powerDistribution;
    }
    // 7. 法規與營業規章領域
    if (wi.contains('法規') || text.contains('台電') || text.contains('承裝業') || text.contains('營業規章')) {
      return ElectricalDomain.regulations;
    }
    // 8. 配線管槽預設領域 (涵蓋工作項目 03、04、05、10、15、17)
    return ElectricalDomain.wiringConduit;
  }
}
