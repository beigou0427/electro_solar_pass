// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/models/git_skill_branch.dart
// CTO 注入：Linus Torvalds (Linux/Git) - 第 1/3 段：Git 技能分支與 DAG 提交引擎
// 說明：[Git 模式] 支援多線作戰分支、不可變 Commit 歷史鏈與實力增量 Diff 對比
// ==========================================

import 'dart:convert';

/// Linus Torvalds 技能提交節點 (Skill Commit in DAG)
class SkillCommit {
  final String commitHash;      // 8 位元 SHA 風格雜湊 (例如 e4b19c2a)
  final String? parentHash;     // 父提交節點雜湊 (形成 DAG 鏈條)
  final String branchName;     // 所屬作戰分支 (main / cram-sprint / custom)
  final String message;        // 提交訊息 (例如: 斬殺 10 題變壓器計算)
  final DateTime timestamp;    // 提交時間戳
  final int masteredCount;     // 快照：已斬殺總數
  final int wrongCount;        // 快照：待消滅錯題數
  final double retentionRate;  // 快照：當時全域留存率

  const SkillCommit({
    required this.commitHash,
    required this.parentHash,
    required this.branchName,
    required this.message,
    required this.timestamp,
    required this.masteredCount,
    required this.wrongCount,
    required this.retentionRate,
  });

  Map<String, dynamic> toMap() => {
    'hash': commitHash,
    'parent': parentHash,
    'branch': branchName,
    'msg': message,
    'ts': timestamp.toIso8601String(),
    'mastered': masteredCount,
    'wrong': wrongCount,
    'retention': retentionRate,
  };

  factory SkillCommit.fromMap(Map<String, dynamic> map) {
    return SkillCommit(
      commitHash: map['hash'] as String? ?? '00000000',
      parentHash: map['parent'] as String?,
      branchName: map['branch'] as String? ?? 'main',
      message: map['msg'] as String? ?? '',
      timestamp: DateTime.tryParse(map['ts'] as String? ?? '') ?? DateTime.now(),
      masteredCount: map['mastered'] as int? ?? 0,
      wrongCount: map['wrong'] as int? ?? 0,
      retentionRate: (map['retention'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Linus Torvalds 技能分支與版本控制大腦
class SkillBranchManager {
  final Map<String, List<SkillCommit>> _branchMap = {
    'main': [],          // 預設長期主幹
    'cram-sprint': [],   // 考前 14 天急救突擊分支
  };

  String _activeBranch = 'main';

  String get activeBranch => _activeBranch;
  List<String> get availableBranches => _branchMap.keys.toList();
  List<SkillCommit> get activeCommitHistory => List.unmodifiable(_branchMap[_activeBranch] ?? []);

  /// 切換作戰分支 (git checkout <branch>)
  bool checkoutBranch(String branchName) {
    if (_branchMap.containsKey(branchName)) {
      _activeBranch = branchName;
      return true;
    }
    return false;
  }

  /// 建立全新專項突擊分支 (git checkout -b <newBranch>)
  void createBranch(String branchName) {
    if (!_branchMap.containsKey(branchName)) {
      // 複製當前分支的最新 Commit 作為起點
      final currentHead = getHeadCommit();
      _branchMap[branchName] = currentHead != null ? [currentHead] : [];
      _activeBranch = branchName;
    }
  }

  /// 取得當前分支的 HEAD 提交
  SkillCommit? getHeadCommit() {
    final list = _branchMap[_activeBranch];
    if (list != null && list.isNotEmpty) {
      return list.last;
    }
    return null;
  }

  /// 提交技能里程碑 (git commit -m "message")
  SkillCommit commitMilestone({
    required String message,
    required int masteredCount,
    required int wrongCount,
    required double retentionRate,
    DateTime? commitTime,
  }) {
    final now = commitTime ?? DateTime.now();
    final parent = getHeadCommit();
    final hash = _generateFastHash(now, message, masteredCount);

    final newCommit = SkillCommit(
      commitHash: hash,
      parentHash: parent?.commitHash,
      branchName: _activeBranch,
      message: message,
      timestamp: now,
      masteredCount: masteredCount,
      wrongCount: wrongCount,
      retentionRate: retentionRate,
    );

    _branchMap[_activeBranch] ??= [];
    _branchMap[_activeBranch]!.add(newCommit);
    return newCommit;
  }

  /// 【Linus 極速增量 Diff】：對比兩次提交之間的戰力增長
  Map<String, dynamic> diffCommits(SkillCommit base, SkillCommit target) {
    return {
      'masteredDelta': target.masteredCount - base.masteredCount,
      'wrongDelta': target.wrongCount - base.wrongCount,
      'retentionDelta': (target.retentionRate - base.retentionRate).toStringAsFixed(1),
      'elapsedHours': (target.timestamp.difference(base.timestamp).inMinutes / 60.0).toStringAsFixed(1),
    };
  }

  /// 產生 8 位元 FNV-1a 極速雜湊
  static String _generateFastHash(DateTime ts, String msg, int seed) {
    int hash = 0x811c9dc5;
    final str = "${ts.microsecondsSinceEpoch}_${msg}_$seed";
    for (int i = 0; i < str.length; i++) {
      hash ^= str.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0').substring(0, 8);
  }

  /// 序列化所有分支提交圖譜 (供備份金鑰使用)
  String exportBranchesJson() {
    final Map<String, dynamic> out = {
      'active': _activeBranch,
      'branches': _branchMap.map((k, v) => MapEntry(k, v.map((c) => c.toMap()).toList())),
    };
    return jsonEncode(out);
  }

  /// 還原分支圖譜
  void importBranchesJson(String jsonStr) {
    try {
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      _activeBranch = map['active'] as String? ?? 'main';
      final rawBranches = Map<String, dynamic>.from(map['branches'] ?? {});
      _branchMap.clear();
      rawBranches.forEach((k, v) {
        final list = List<dynamic>.from(v ?? []);
        _branchMap[k] = list.map((c) => SkillCommit.fromMap(Map<String, dynamic>.from(c))).toList();
      });
    } catch (_) {}
  }
}
