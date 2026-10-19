// ==========================================
// 專案名稱：電光證照霸 PRO - 三大工程計算機業務邏輯
// 檔案：lib/utils/calculators.dart
// ==========================================

import 'dart:math';

class EngineeringCalculators {
  // =========================================
  // 1. 太陽光電串列開路電壓 (Voc) 低溫修正計算機
  // =========================================
  static Map<String, dynamic> calcSolarVoc({
    required double vocSTC,       // 單片 STC 開路電壓 (V)
    required double tempCoeff,    // 溫度係數 (%/℃)，通常為負值，如 -0.29
    required double minTemp,      // 歷史最低溫度 (℃)
    required int seriesCount,     // 串聯片數
    required double maxInverterV, // 逆變器最大耐壓 (V)
  }) {
    // 溫差 (通常 STC 基準為 25℃)
    double deltaT = minTemp - 25.0;
    // 溫度電壓上升比例 (%)
    double voltageRisePct = deltaT * (tempCoeff / 100.0);
    // 單片低溫最大 Voc
    double singleMaxVoc = vocSTC * (1 + voltageRisePct);
    // 整串最大 Voc
    double stringMaxVoc = singleMaxVoc * seriesCount;
    // 安全建議最大串聯數 (向下取整)
    int safeMaxSeries = (maxInverterV / singleMaxVoc).floor();
    
    bool isSafe = stringMaxVoc <= maxInverterV;

    return {
      'singleMaxVoc': singleMaxVoc.toStringAsFixed(2),
      'stringMaxVoc': stringMaxVoc.toStringAsFixed(2),
      'safeMaxSeries': safeMaxSeries,
      'isSafe': isSafe,
      'voltageRisePct': (voltageRisePct * 100).abs().toStringAsFixed(2),
    };
  }

  // =========================================
  // 2. 單相/三相線路壓降 (ΔV) 檢核計算機
  // =========================================
  static Map<String, dynamic> calcVoltageDrop({
    required String phaseType, // '1P2W', '1P3W', '3P3W', '3P4W'
    required double voltage,   // 系統電壓 (V)
    required double current,   // 負載電流 (A)
    required double length,    // 單程配線距離 (m)
    required double resistancePerKm, // 導線每公里電阻 (Ω/km)
  }) {
    double lengthInKm = length / 1000.0;
    double r = resistancePerKm * lengthInKm;
    double deltaV = 0.0;

    switch (phaseType) {
      case '1P2W':
        // 單相兩線式 (需計算來回)
        deltaV = 2 * current * r; 
        break;
      case '3P3W':
        // 三相三線式
        deltaV = sqrt(3) * current * r;
        break;
      case '1P3W':
      case '3P4W':
        // 單相三線 / 三相四線 (相電壓壓降，假設負載平衡，中性線無電流)
        deltaV = current * r;
        break;
      default:
        deltaV = 0.0;
    }

    double dropPercentage = (deltaV / voltage) * 100.0;
    bool isCompliant = dropPercentage <= 3.0; // 法規分路壓降 <= 3%

    return {
      'deltaV': deltaV.toStringAsFixed(2),
      'dropPercentage': dropPercentage.toStringAsFixed(2),
      'endVoltage': (voltage - deltaV).toStringAsFixed(2),
      'isCompliant': isCompliant,
    };
  }

  // =========================================
  // 3. 功率因數改善與台電電費獎懲試算機
  // =========================================
  static Map<String, dynamic> calcPowerFactor({
    required double powerKW,     // 有效功率 (kW)
    required double currentPF,   // 目前功率因數 (如 0.72)
    required double targetPF,    // 目標功率因數 (預設法規 0.95)
  }) {
    // 防止輸入錯誤導致數學運算異常
    if (currentPF <= 0.0 || currentPF > 1.0 || targetPF <= 0.0 || targetPF > 1.0) {
      return {'error': 'PF 必須介於 0.01 與 1.0 之間'};
    }

    // 計算角度 (徑度)
    double angle1 = acos(currentPF);
    double angle2 = acos(targetPF);

    // Qc = P * (tanθ1 - tanθ2)
    double qcKVAR = powerKW * (tan(angle1) - tan(angle2));
    
    // 台電電費折扣試算 (基準 80%，每超出 1% 減收千分之1.5)
    // 假設原先低於 80%，改善到 95%
    double currentDiscount = 0.0;
    double targetDiscount = 0.0;

    if (currentPF >= 0.8) {
      currentDiscount = (currentPF - 0.8) * 100 * 0.15;
    } else {
      currentDiscount = -((0.8 - currentPF) * 100 * 0.3); // 低於 80% 每 1% 加收 0.3%
    }

    if (targetPF >= 0.8) {
      targetDiscount = (targetPF - 0.8) * 100 * 0.15;
    }
    
    double savedPercentage = targetDiscount - currentDiscount;

    return {
      'qcKVAR': qcKVAR > 0 ? qcKVAR.toStringAsFixed(2) : '0.00',
      'targetDiscountPct': targetDiscount.toStringAsFixed(2),
      'savedPercentagePct': savedPercentage.toStringAsFixed(2),
    };
  }
}
