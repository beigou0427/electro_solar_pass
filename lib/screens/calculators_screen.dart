// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/screens/calculators_screen.dart
// CIO 注入：Ben Fried (Google) - 完全體整合修復版
// 說明：[響應式工具鏈] 支援輸入即運算與 AST 終端沙盒
// ==========================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/calculators.dart';
import '../utils/ast_math_evaluator.dart';

class FieldEngineerToolboxView extends StatefulWidget {
  const FieldEngineerToolboxView({super.key});

  @override
  State<FieldEngineerToolboxView> createState() => _FieldEngineerToolboxViewState();
}

class _FieldEngineerToolboxViewState extends State<FieldEngineerToolboxView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- 工具 A：Voc 修正 ---
  final TextEditingController _solarVocStcCtrl = TextEditingController(text: '41.5');
  final TextEditingController _solarTempCoeffCtrl = TextEditingController(text: '-0.29');
  final TextEditingController _solarMinTempCtrl = TextEditingController(text: '5');
  Map<String, dynamic>? _vocResult;

  // --- 工具 B：壓降檢核 ---
  String _phaseType = '1P2W';
  final TextEditingController _vdVoltageCtrl = TextEditingController(text: '220');
  final TextEditingController _vdCurrentCtrl = TextEditingController(text: '20');
  final TextEditingController _vdLengthCtrl = TextEditingController(text: '50');
  final TextEditingController _vdResistanceCtrl = TextEditingController(text: '3.57');
  Map<String, dynamic>? _vdResult;

  // --- 工具 C：功因改善 ---
  final TextEditingController _pfKwCtrl = TextEditingController(text: '100');
  final TextEditingController _pfCurrentCtrl = TextEditingController(text: '0.72');
  final TextEditingController _pfTargetCtrl = TextEditingController(text: '0.95');
  Map<String, dynamic>? _pfResult;

  // --- 工具 D：AST 終端實驗室 ---
  final TextEditingController _astFormulaCtrl = TextEditingController(text: 'sqrt3 * V * I * pf');
  final TextEditingController _astVarVCtrl = TextEditingController(text: '220');
  final TextEditingController _astVarICtrl = TextEditingController(text: '50');
  final TextEditingController _astVarPfCtrl = TextEditingController(text: '0.85');
  String? _astCalculatedValue;
  String? _astSyntaxError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _solarVocStcCtrl.addListener(_calcVoc);
    _solarTempCoeffCtrl.addListener(_calcVoc);
    _solarMinTempCtrl.addListener(_calcVoc);

    _vdVoltageCtrl.addListener(_calcVd);
    _vdCurrentCtrl.addListener(_calcVd);
    _vdLengthCtrl.addListener(_calcVd);
    _vdResistanceCtrl.addListener(_calcVd);

    _pfKwCtrl.addListener(_calcPf);
    _pfCurrentCtrl.addListener(_calcPf);
    _pfTargetCtrl.addListener(_calcPf);

    _astFormulaCtrl.addListener(_calcAst);
    _astVarVCtrl.addListener(_calcAst);
    _astVarICtrl.addListener(_calcAst);
    _astVarPfCtrl.addListener(_calcAst);

    _calcVoc(); _calcVd(); _calcPf(); _calcAst();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _solarVocStcCtrl.dispose(); _solarTempCoeffCtrl.dispose(); _solarMinTempCtrl.dispose();
    _vdVoltageCtrl.dispose(); _vdCurrentCtrl.dispose(); _vdLengthCtrl.dispose(); _vdResistanceCtrl.dispose();
    _pfKwCtrl.dispose(); _pfCurrentCtrl.dispose(); _pfTargetCtrl.dispose();
    _astFormulaCtrl.dispose(); _astVarVCtrl.dispose(); _astVarICtrl.dispose(); _astVarPfCtrl.dispose();
    super.dispose();
  }

  Widget _buildInput(String label, TextEditingController ctrl, {bool isMono = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: TextStyle(color: AppColors.slate50, fontFamily: isMono ? 'monospace' : null, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 12),
        filled: true,
        fillColor: AppColors.slate900,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.slate800), borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.blue500), borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _calcVoc() {
    final voc = double.tryParse(_solarVocStcCtrl.text);
    final coeff = double.tryParse(_solarTempCoeffCtrl.text);
    final temp = double.tryParse(_solarMinTempCtrl.text);
    if (voc != null && coeff != null && temp != null) {
      setState(() => _vocResult = EngineeringCalculators.calcSolarVoc(vocSTC: voc, tempCoeff: coeff, minTemp: temp, seriesCount: 22, maxInverterV: 1000.0));
    } else {
      setState(() => _vocResult = null);
    }
  }

  Widget _buildVocTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text('PV 模組低溫 Voc 修正 (1000V 防燒毀)', style: TextStyle(color: AppColors.amber400, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildInput('STC 開路電壓 (V)', _solarVocStcCtrl), const SizedBox(height: 12),
        _buildInput('溫度係數 (%/℃)', _solarTempCoeffCtrl), const SizedBox(height: 12),
        _buildInput('最低環境溫度 (℃)', _solarMinTempCtrl), const SizedBox(height: 24),
        if (_vocResult != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.slate950,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _vocResult!['isSafe'] ? AppColors.emerald400 : AppColors.rose500, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_vocResult!['isSafe'] ? Icons.check_circle : Icons.warning_amber_rounded, color: _vocResult!['isSafe'] ? AppColors.emerald400 : AppColors.rose500, size: 20),
                    const SizedBox(width: 8),
                    Text(_vocResult!['isSafe'] ? '安全：合乎變流器耐壓' : '危險：電壓將擊穿設備', style: TextStyle(color: _vocResult!['isSafe'] ? AppColors.emerald400 : AppColors.rose500, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                const Divider(color: AppColors.slate800, height: 24),
                _buildDataRow('修正後單片 Voc', '${_vocResult!['singleMaxVoc']} V'),
                _buildDataRow('1000V 系統串聯上限', '${_vocResult!['safeMaxSeries']} 片', isHighlight: true),
              ],
            ),
          )
      ],
    );
  }

  void _calcVd() {
    final v = double.tryParse(_vdVoltageCtrl.text);
    final i = double.tryParse(_vdCurrentCtrl.text);
    final l = double.tryParse(_vdLengthCtrl.text);
    final r = double.tryParse(_vdResistanceCtrl.text);
    if (v != null && i != null && l != null && r != null) {
      setState(() => _vdResult = EngineeringCalculators.calcVoltageDrop(phaseType: _phaseType, voltage: v, current: i, length: l, resistancePerKm: r));
    } else {
      setState(() => _vdResult = null);
    }
  }

  Widget _buildVdTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text('線路壓降 ΔV 檢核 (法規要求 ≤ 3%)', style: TextStyle(color: AppColors.amber400, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _phaseType, dropdownColor: AppColors.slate900, style: const TextStyle(color: AppColors.slate50, fontWeight: FontWeight.bold),
          decoration: InputDecoration(labelText: '供電系統相數', labelStyle: const TextStyle(color: AppColors.slate400, fontSize: 12), filled: true, fillColor: AppColors.slate900, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          items: const [ DropdownMenuItem(value: '1P2W', child: Text('單相兩線 (1Φ2W)')), DropdownMenuItem(value: '1P3W', child: Text('單相三線 (1Φ3W)')), DropdownMenuItem(value: '3P3W', child: Text('三相三線 (3Φ3W)')), DropdownMenuItem(value: '3P4W', child: Text('三相四線 (3Φ4W)')) ],
          onChanged: (val) { setState(() => _phaseType = val!); _calcVd(); },
        ),
        const SizedBox(height: 12),
        Row(children: [ Expanded(flex: 3, child: _buildInput('電壓 (V)', _vdVoltageCtrl)), const SizedBox(width: 8), Expanded(flex: 4, child: _buildInput('電流 (A)', _vdCurrentCtrl)) ]), const SizedBox(height: 12),
        Row(children: [ Expanded(flex: 3, child: _buildInput('距離 (m)', _vdLengthCtrl)), const SizedBox(width: 8), Expanded(flex: 4, child: _buildInput('線阻 (Ω/km)', _vdResistanceCtrl)) ]), const SizedBox(height: 24),
        if (_vdResult != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.slate950, borderRadius: BorderRadius.circular(12), border: Border.all(color: _vdResult!['isCompliant'] ? AppColors.emerald400 : AppColors.rose500, width: 2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_vdResult!['isCompliant'] ? Icons.check_circle : Icons.warning_amber_rounded, color: _vdResult!['isCompliant'] ? AppColors.emerald400 : AppColors.rose500, size: 20),
                    const SizedBox(width: 8),
                    Text(_vdResult!['isCompliant'] ? '檢驗合格 (合乎 3% 法規)' : '檢驗不合格 (需加大線徑)', style: TextStyle(color: _vdResult!['isCompliant'] ? AppColors.emerald400 : AppColors.rose500, fontWeight: FontWeight.w900, fontSize: 16)),
                  ],
                ),
                const Divider(color: AppColors.slate800, height: 24),
                _buildDataRow('實測壓降 ΔV', '${_vdResult!['deltaV']} V'),
                _buildDataRow('末端剩餘電壓', '${_vdResult!['endVoltage']} V'),
                _buildDataRow('壓降百分比', '${_vdResult!['dropPercentage']} %', isHighlight: true),
              ],
            ),
          )
      ],
    );
  }

  void _calcPf() {
    final kw = double.tryParse(_pfKwCtrl.text);
    final curr = double.tryParse(_pfCurrentCtrl.text);
    final tg = double.tryParse(_pfTargetCtrl.text);
    if (kw != null && curr != null && tg != null) {
      setState(() => _pfResult = EngineeringCalculators.calcPowerFactor(powerKW: kw, currentPF: curr, targetPF: tg));
    } else {
      setState(() => _pfResult = null);
    }
  }

  Widget _buildPfTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text('功因改善 (kVAR) 與電費試算', style: TextStyle(color: AppColors.amber400, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildInput('有效功率 (kW)', _pfKwCtrl), const SizedBox(height: 12),
        Row(children: [ Expanded(child: _buildInput('目前 PF (0~1)', _pfCurrentCtrl)), const SizedBox(width: 8), Expanded(child: _buildInput('目標 PF (0~1)', _pfTargetCtrl)) ]), const SizedBox(height: 24),
        if (_pfResult != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.slate950, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.blue500, width: 2)),
            child: _pfResult!.containsKey('error') 
              ? Row(children: [const Icon(Icons.error, color: AppColors.rose500), const SizedBox(width: 8), Text(_pfResult!['error'], style: const TextStyle(color: AppColors.rose500, fontWeight: FontWeight.bold))])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDataRow('所需並聯電容器容量', '${_pfResult!['qcKVAR']} kVAR', isHighlight: true, highlightColor: AppColors.amber400),
                    const Divider(color: AppColors.slate800, height: 24),
                    _buildDataRow('預估台電電費折扣', '${_pfResult!['targetDiscountPct']} %'),
                    _buildDataRow('改善後每月多省下', '${_pfResult!['savedPercentagePct']} %', isHighlight: true, highlightColor: AppColors.emerald400),
                  ],
                ),
          )
      ],
    );
  }

  void _calcAst() {
    final formula = _astFormulaCtrl.text.trim();
    final v = double.tryParse(_astVarVCtrl.text) ?? 0.0;
    final i = double.tryParse(_astVarICtrl.text) ?? 0.0;
    final pf = double.tryParse(_astVarPfCtrl.text) ?? 1.0;

    final contextMap = {
      'V': v, 'I': i, 'pf': pf, 'P1': v, 'C': 0.0001, 'f': 60.0, 'P': 4.0, 'Ns': 1800.0, 'Nr': 1710.0,
    };

    try {
      final res = ElectricalAstEvaluator.evaluate(formula, contextMap);
      setState(() {
        _astCalculatedValue = res.toStringAsFixed(3);
        _astSyntaxError = null;
      });
    } catch (e) {
      setState(() {
        _astCalculatedValue = null;
        _astSyntaxError = e.toString().replaceAll('FormatException: ', '');
      });
    }
  }

  Widget _buildFormulaChip(String label, String formula) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: AppColors.slate950, fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: AppColors.amber400,
      onPressed: () {
        HapticFeedback.selectionClick();
        _astFormulaCtrl.text = formula;
      },
    );
  }

  Widget _buildAstTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('AST 終端數學實驗室', style: TextStyle(color: AppColors.amber400, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Python AST Engine', style: TextStyle(color: AppColors.emerald400, fontSize: 10, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFormulaChip('三相功率', 'sqrt3 * V * I * pf'), const SizedBox(width: 8),
              _buildFormulaChip('V-V 容量', 'sqrt3 * P1'), const SizedBox(width: 8),
              _buildFormulaChip('同步轉速', '(120 * f) / P'), const SizedBox(width: 8),
              _buildFormulaChip('電容儲能', '0.5 * C * (V ^ 2)'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInput('公式指令 (支援 sqrt3, pi, 括號, ^)', _astFormulaCtrl, isMono: true),
        const SizedBox(height: 16),
        const Text('環境變數注入區 (Context):', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildInput('V', _astVarVCtrl)), const SizedBox(width: 8),
            Expanded(child: _buildInput('I', _astVarICtrl)), const SizedBox(width: 8),
            Expanded(child: _buildInput('pf', _astVarPfCtrl)),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black, 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: _astSyntaxError == null ? AppColors.emerald400 : AppColors.rose500, width: 2)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('> terminal_output', style: TextStyle(color: _astSyntaxError == null ? AppColors.emerald400 : AppColors.rose500, fontSize: 12, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              if (_astCalculatedValue != null)
                Text(_astCalculatedValue!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.emerald400, fontFamily: 'monospace'))
              else if (_astSyntaxError != null)
                Text('SyntaxError: $_astSyntaxError', style: const TextStyle(color: AppColors.rose500, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildDataRow(String label, String value, {bool isHighlight = false, Color highlightColor = AppColors.slate50}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 13)),
          Text(value, style: TextStyle(color: isHighlight ? highlightColor : AppColors.slate50, fontSize: isHighlight ? 20 : 16, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate950,
      appBar: AppBar(
        title: const Text('🧮 案場實務計算機', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.amber400,
          indicatorWeight: 3,
          labelColor: AppColors.amber400,
          unselectedLabelColor: AppColors.slate400,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: '☀️ Voc修正'),
            Tab(text: '⚡ 壓降核算'),
            Tab(text: '🔋 功因補償'),
            Tab(text: '🔬 AST沙盒'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildVocTab(),
          _buildVdTab(),
          _buildPfTab(),
          _buildAstTab(),
        ],
      ),
    );
  }
}
