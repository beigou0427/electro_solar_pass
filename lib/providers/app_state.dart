// ==========================================
// 專案名稱：電光證照霸 PRO (ElectroSolar Pass)
// 檔案：lib/providers/app_state.dart
// 說明：[全域狀態完全體] 整合連勝防護卡、FSRS 記憶、Git 分支、DDD 技能樹
// ==========================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/core_types.dart';
import '../data/question_bank.dart';
import '../utils/telemetry_logger.dart';
import '../utils/preflight_inspector.dart';
import '../utils/memory_engine.dart';
import '../utils/bitwise_index.dart';
import '../utils/semantic_vector_engine.dart';
import '../models/skill_tree_domain.dart';
import '../models/event_sourcing_store.dart';
import '../utils/cognitive_load_engine.dart';
import '../models/git_skill_branch.dart';
import '../utils/app_persistence.dart';

class EnhancedUserProfile extends UserProfile {
  int currentStreak;
  int longestStreak;
  int streakFreezes; // 🛡️ 連勝防護卡數量 (預設贈送 2 張)
  int streakFreezesUsed; // 統計保護成功次數
  DateTime? lastLoginDate;

  EnhancedUserProfile({
    super.licenseTier = LicenseTier.free,
    super.masteredIds = const [],
    super.wrongQueueIds = const [],
    super.bookmarkedIds = const [],
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.streakFreezes = 2,
    this.streakFreezesUsed = 0,
    this.lastLoginDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'tier': licenseTier.value,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'streakFreezes': streakFreezes,
      'streakFreezesUsed': streakFreezesUsed,
      'lastLogin': lastLoginDate?.toIso8601String(),
      'mastered': masteredIds,
      'wrong': wrongQueueIds,
      'bookmarked': bookmarkedIds,
    };
  }

  factory EnhancedUserProfile.fromMap(Map<String, dynamic> map) {
    LicenseTier tier = LicenseTier.free;
    final tierVal = map['tier'] ?? 'FREE';
    if (tierVal == 'PRO') tier = LicenseTier.proLifetime;

    return EnhancedUserProfile(
      licenseTier: tier,
      currentStreak: map['currentStreak'] ?? 0,
      longestStreak: map['longestStreak'] ?? 0,
      streakFreezes: map['streakFreezes'] ?? 2,
      streakFreezesUsed: map['streakFreezesUsed'] ?? 0,
      lastLoginDate: map['lastLogin'] != null ? DateTime.tryParse(map['lastLogin']) : null,
      masteredIds: List<String>.from(map['mastered'] ?? []),
      wrongQueueIds: List<String>.from(map['wrong'] ?? []),
      bookmarkedIds: List<String>.from(map['bookmarked'] ?? []),
    );
  }
}

class AppState extends ChangeNotifier {
  EnhancedUserProfile _profile = EnhancedUserProfile();
  List<QuestionItem> _allQuestions = [];
  bool _isProcessingMassiveData = false;
  PreflightReport? _preflightReport;
  final Map<String, MemoryCardState> _memoryStates = {};
  BitwiseQuestionIndex? _bitwiseIndex;
  final Map<String, List<QuestionItem>> _semanticSimilarityCache = {};
  final EventSourcingStore _eventStore = EventSourcingStore();
  CognitiveState _cognitiveState = CognitiveState.initial();
  final SkillBranchManager _branchManager = SkillBranchManager();

  Timer? _debounceSaveTimer;

  AppState() {
    _runPreflightDiagnostic();
    _initGitGenesisCommit();
    _loadStateFromDisk();
  }

  Future<void> _loadStateFromDisk() async {
    try {
      final savedToken = await AppPersistence.loadBattleState();
      if (savedToken != null && savedToken.isNotEmpty) {
        final success = restoreStateFromBackup(savedToken);
        if (success) {
          telemetry.logEvent(eventName: 'PERSISTENCE_RESTORE_SUCCESS');
        }
      }
    } catch (e) {
      telemetry.logEvent(eventName: 'PERSISTENCE_RESTORE_FAILED', parameters: {'err': e.toString()});
    } finally {
      _processDailyLoginStreak();
      notifyListeners();
    }
  }

  void _scheduleAutoSave() {
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final token = exportStateBackup();
        await AppPersistence.saveBattleState(token);
      } catch (_) {}
    });
  }

  void _initGitGenesisCommit() {
    if (_branchManager.getHeadCommit() == null) {
      _branchManager.commitMilestone(
        message: "init: 813 題官方真題韌體開機固化",
        masteredCount: 0,
        wrongCount: 0,
        retentionRate: 0.0,
      );
    }
  }

  void _runPreflightDiagnostic() {
    _preflightReport = AerospacePreflightInspector.inspectAndSanitize(
      rawBank: initialQuestionBank,
      onBankSanitized: (sanitizedList) {
        _allQuestions = sanitizedList;
        _rebuildBitwiseIndex();
      },
    );

    telemetry.logEvent(
      eventName: 'PREFLIGHT_DIAGNOSTIC_COMPLETED',
      parameters: {
        'total': _preflightReport?.totalScanned ?? 0,
        'healthy': _preflightReport?.healthyCount ?? 0,
        'quarantined': _preflightReport?.quarantinedCount ?? 0,
      },
    );
  }

  void _rebuildBitwiseIndex() {
    _bitwiseIndex = BitwiseQuestionIndex.build(_allQuestions);
  }

  // --- Getters 供 UI 綁定 ---
  EnhancedUserProfile get profile => _profile;
  List<QuestionItem> get allQuestions => _allQuestions;
  bool get isPro => _profile.licenseTier == LicenseTier.proLifetime;
  bool get isProcessingMassiveData => _isProcessingMassiveData;
  PreflightReport? get preflightReport => _preflightReport;
  Map<String, MemoryCardState> get memoryStates => Map.unmodifiable(_memoryStates);
  BitwiseQuestionIndex? get bitwiseIndex => _bitwiseIndex;
  EventSourcingStore get eventStore => _eventStore;
  CognitiveState get cognitiveState => _cognitiveState;
  SkillBranchManager get branchManager => _branchManager;
  String get activeBranch => _branchManager.activeBranch;

  int get totalQuestions => _allQuestions.length;
  int get masteredCount => _profile.masteredIds.length;
  int get wrongCount => _profile.wrongQueueIds.length;

  // --- FSRS 瀕危遺忘考題卡包 (Due Deck) ---
  int get dueForReviewCount {
    int count = 0;
    for (final state in _memoryStates.values) {
      if (AdvancedMemoryEngine.isDueForReview(state)) count++;
    }
    return count;
  }

  List<QuestionItem> get dueQuestions {
    final dueIds = _memoryStates.entries
        .where((e) => AdvancedMemoryEngine.isDueForReview(e.value))
        .map((e) => e.key)
        .toSet();
    return _allQuestions.where((q) => dueIds.contains(q.id)).toList();
  }

  // --- 連勝打卡與連勝防護卡 (Streak Freeze) 演算法 ---
  void _processDailyLoginStreak() {
    final now = DateTime.now();
    if (_profile.lastLoginDate == null) {
      _profile.currentStreak = 1;
      _profile.longestStreak = 1;
    } else {
      final last = _profile.lastLoginDate!;
      final lastMidnight = DateTime(last.year, last.month, last.day);
      final nowMidnight = DateTime(now.year, now.month, now.day);
      final daysDiff = nowMidnight.difference(lastMidnight).inDays;

      if (daysDiff == 1) {
        // 正常隔日登入，連勝 +1
        _profile.currentStreak++;
        if (_profile.currentStreak > _profile.longestStreak) {
          _profile.longestStreak = _profile.currentStreak;
        }
      } else if (daysDiff == 2) {
        // 漏打卡 1 天：自動觸發連勝防護卡
        if (_profile.streakFreezes > 0) {
          _profile.streakFreezes--;
          _profile.streakFreezesUsed++;
          telemetry.logEvent(
            eventName: 'STREAK_FREEZE_CONSUMED',
            parameters: {
              'preservedStreak': _profile.currentStreak,
              'remainingFreezes': _profile.streakFreezes,
            },
          );
        } else {
          _profile.currentStreak = 1;
        }
      } else if (daysDiff > 2) {
        // 漏打卡超過 1 天，連勝中斷
        _profile.currentStreak = 1;
      }
    }
    _profile.lastLoginDate = now;

    _eventStore.appendEvent(
      type: StudyEventType.streakMaintained,
      payload: {
        'streak': _profile.currentStreak,
        'freezesRemaining': _profile.streakFreezes,
      },
    );

    telemetry.logEvent(
      eventName: 'APP_LAUNCH',
      parameters: {
        'streak': _profile.currentStreak,
        'freezes': _profile.streakFreezes,
      },
    );
    _scheduleAutoSave();
  }

  // --- Git 分支與里程碑 ---
  SkillCommit commitSkillMilestone(String message) {
    final commit = _branchManager.commitMilestone(
      message: message,
      masteredCount: masteredCount,
      wrongCount: wrongCount,
      retentionRate: overallRetentionRate,
    );

    telemetry.logEvent(
      eventName: 'SKILL_COMMIT_RECORDED',
      parameters: {
        'hash': commit.commitHash,
        'branch': commit.branchName,
        'msg': message,
        'mastered': masteredCount,
      },
    );

    notifyListeners();
    _scheduleAutoSave();
    return commit;
  }

  void switchBranch(String branchName) {
    if (_branchManager.checkoutBranch(branchName)) {
      telemetry.logEvent(eventName: 'GIT_BRANCH_CHECKOUT', parameters: {'branch': branchName});
      notifyListeners();
      _scheduleAutoSave();
    }
  }

  void createAndCheckoutBranch(String branchName) {
    _branchManager.createBranch(branchName);
    telemetry.logEvent(eventName: 'GIT_BRANCH_CREATED', parameters: {'branch': branchName});
    notifyListeners();
    _scheduleAutoSave();
  }

  // --- 自適應心流推薦 ---
  QuestionItem getFlowAlignedNextQuestion(List<QuestionItem> pool) {
    return CognitiveLoadEngine.selectFlowAlignedQuestion(
      pool: pool.isNotEmpty ? pool : _allQuestions,
      cognitive: _cognitiveState,
    );
  }

  // --- 今日事件即時統計 ---
  int get todayQuestionsAttempted {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _eventStore.eventStream.where((e) =>
      e.type == StudyEventType.ratingApplied && e.timestamp.isAfter(todayStart)
    ).length;
  }

  double get todayAccuracyRate {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEvents = _eventStore.eventStream.where((e) =>
      e.type == StudyEventType.ratingApplied && e.timestamp.isAfter(todayStart)
    ).toList();
    if (todayEvents.isEmpty) return 0.0;

    final correctEvents = todayEvents.where((e) {
      final r = e.payload['rating'] as String?;
      return r == 'good' || r == 'easy';
    }).length;

    return double.parse(((correctEvents / todayEvents.length) * 100.0).toStringAsFixed(1));
  }

  UserProfile getHistoricalProfileAt(DateTime time) {
    return _eventStore.replayStateAt(time);
  }

  // --- 八大技能樹矩陣 ---
  Map<ElectricalDomain, DomainMasteryReport> get domainMasteryReports {
    final Map<ElectricalDomain, int> totalMap = {};
    final Map<ElectricalDomain, int> masteredMap = {};
    final Map<ElectricalDomain, int> wrongMap = {};

    for (final domain in ElectricalDomain.values) {
      totalMap[domain] = 0;
      masteredMap[domain] = 0;
      wrongMap[domain] = 0;
    }

    for (final q in _allQuestions) {
      final domain = SkillTreeDomainMapper.resolveDomain(q);
      totalMap[domain] = (totalMap[domain] ?? 0) + 1;

      if (_profile.masteredIds.contains(q.id)) {
        masteredMap[domain] = (masteredMap[domain] ?? 0) + 1;
      } else if (_profile.wrongQueueIds.contains(q.id)) {
        wrongMap[domain] = (wrongMap[domain] ?? 0) + 1;
      }
    }

    final Map<ElectricalDomain, DomainMasteryReport> reports = {};
    for (final domain in ElectricalDomain.values) {
      final tot = totalMap[domain] ?? 0;
      final mast = masteredMap[domain] ?? 0;
      final wrg = wrongMap[domain] ?? 0;
      reports[domain] = DomainMasteryReport(
        domain: domain,
        totalCount: tot,
        masteredCount: mast,
        wrongCount: wrg,
        untouchedCount: tot - mast - wrg,
      );
    }

    return reports;
  }

  ElectricalDomain? get mostVulnerableDomain {
    final reports = domainMasteryReports.values.toList();
    reports.sort((a, b) => b.vulnerabilityRatio.compareTo(a.vulnerabilityRatio));
    if (reports.isNotEmpty && reports.first.wrongCount > 0) {
      return reports.first.domain;
    }
    return null;
  }

  List<QuestionItem> getQuestionsByDomain(ElectricalDomain domain) {
    return _allQuestions.where((q) => SkillTreeDomainMapper.resolveDomain(q) == domain).toList();
  }

  // --- 語意向量推薦管線 ---
  List<QuestionItem> getRelatedQuestions(QuestionItem target, {int topK = 3}) {
    if (_semanticSimilarityCache.containsKey(target.id)) {
      return _semanticSimilarityCache[target.id]!;
    }

    final results = SemanticVectorEngine.findSimilarQuestions(
      target: target,
      pool: _allQuestions,
      topK: topK,
    );

    _semanticSimilarityCache[target.id] = results;
    return results;
  }

  // --- 二進位位元索引極速過濾 ---
  List<QuestionItem> queryQuestionsFast({
    int queryMask = CarmackBitFlags.matchAll,
    bool onlyWrong = false,
    bool onlyMastered = false,
    bool onlyDue = false,
  }) {
    if (_bitwiseIndex == null || _allQuestions.isEmpty) {
      return _allQuestions;
    }

    final matchedIndices = _bitwiseIndex!.queryIndices(
      queryMask: queryMask,
      dynamicStateProvider: (questionId) {
        int dynamicBits = 0;
        if (_profile.masteredIds.contains(questionId)) dynamicBits |= CarmackBitFlags.statusMastered;
        if (_profile.wrongQueueIds.contains(questionId)) dynamicBits |= CarmackBitFlags.statusWrong;
        if (_profile.bookmarkedIds.contains(questionId)) dynamicBits |= CarmackBitFlags.statusBookmarked;
        final mem = _memoryStates[questionId];
        if (mem != null && AdvancedMemoryEngine.isDueForReview(mem)) dynamicBits |= CarmackBitFlags.statusDue;
        return dynamicBits;
      },
    );

    final List<QuestionItem> result = [];
    for (int i = 0; i < matchedIndices.length; i++) {
      final q = _allQuestions[matchedIndices[i]];
      if (onlyWrong && !_profile.wrongQueueIds.contains(q.id)) continue;
      if (onlyMastered && !_profile.masteredIds.contains(q.id)) continue;
      if (onlyDue) {
        final mem = _memoryStates[q.id];
        if (mem == null || !AdvancedMemoryEngine.isDueForReview(mem)) continue;
      }
      result.add(q);
    }

    return result;
  }

  // --- FSRS 神經記憶留存率指標 ---
  double get overallRetentionRate {
    if (_memoryStates.isEmpty) return 0.0;
    double sum = 0.0;
    for (final state in _memoryStates.values) {
      sum += AdvancedMemoryEngine.calculateCurrentRetention(state);
    }
    final avg = (sum / _memoryStates.length) * 100.0;
    return double.parse(avg.clamp(0.0, 100.0).toStringAsFixed(1));
  }

  MemoryCardState getCardState(String questionId) {
    return _memoryStates[questionId] ?? MemoryCardState(questionId: questionId);
  }

  // --- 全功能作答與事件反應 ---
  void processQuestionReview({
    required String questionId,
    required StudyRating rating,
  }) {
    final currentState = getCardState(questionId);
    final newState = AdvancedMemoryEngine.processReview(
      currentState: currentState,
      rating: rating,
    );
    _memoryStates[questionId] = newState;

    _eventStore.appendEvent(
      type: StudyEventType.ratingApplied,
      payload: {
        'questionId': questionId,
        'rating': rating.name,
        'stability': newState.stability,
        'difficulty': newState.difficulty,
      },
    );

    final isCorrect = rating == StudyRating.good || rating == StudyRating.easy;
    final currentQ = _allQuestions.firstWhere(
      (item) => item.id == questionId,
      orElse: () => QuestionItem(
        id: questionId, category: CategoryType.roomWiring, categoryLabel: '', workItem: '',
        type: 'single', difficulty: 2, isFree: false, question: '', options: [], answer: [],
        explanation: Explanation(quickHack: '', formula: '', stepByStep: '', fieldNote: ''),
      ),
    );

    _cognitiveState = CognitiveLoadEngine.processInteraction(
      prevState: _cognitiveState,
      isCorrect: isCorrect,
      questionDifficulty: currentQ.difficulty,
      timeSpentSeconds: 15,
    );

    if (rating == StudyRating.again) {
      if (!_profile.wrongQueueIds.contains(questionId)) {
        _profile.wrongQueueIds.add(questionId);
      }
      _profile.masteredIds.remove(questionId);
    } else {
      if (newState.repetitions >= 2) {
        if (!_profile.masteredIds.contains(questionId)) {
          _profile.masteredIds.add(questionId);
          if (_profile.masteredIds.length % 10 == 0) {
            commitSkillMilestone("feat: 突破里程碑！累計斬殺 ${_profile.masteredIds.length} 題");
          }
        }
        _profile.wrongQueueIds.remove(questionId);
      }
    }

    notifyListeners();
    _scheduleAutoSave();
  }

  void recordWrongAnswer(String questionId) {
    processQuestionReview(questionId: questionId, rating: StudyRating.again);
  }

  void markAsMastered(String questionId) {
    processQuestionReview(questionId: questionId, rating: StudyRating.easy);
  }

  void toggleBookmark(String questionId) {
    if (_profile.bookmarkedIds.contains(questionId)) {
      _profile.bookmarkedIds.remove(questionId);
    } else {
      _profile.bookmarkedIds.add(questionId);
    }
    notifyListeners();
    _scheduleAutoSave();
  }

  bool activateLicense(String code) {
    final cleanCode = code.trim().toUpperCase();
    telemetry.logEvent(eventName: 'PAYWALL_ATTEMPT', parameters: {'code': cleanCode});

    if (cleanCode == 'VIP888' || cleanCode == 'PASS2026') {
      _profile.licenseTier = LicenseTier.proLifetime;

      _eventStore.appendEvent(
        type: StudyEventType.licenseUnlocked,
        payload: {'code': cleanCode, 'tier': 'PRO'},
      );

      commitSkillMilestone("finance: 啟用 PRO 旗艦版終身權限");
      telemetry.logEvent(eventName: 'PAYWALL_SUCCESS', parameters: {'tier': 'PRO'});
      notifyListeners();
      _scheduleAutoSave();
      return true;
    }
    telemetry.logEvent(eventName: 'PAYWALL_FAILED', parameters: {'reason': 'invalid_code'});
    return false;
  }

  String exportStateBackup() {
    try {
      final memoryMap = _memoryStates.map((k, v) => MapEntry(k, v.toMap()));
      final dataMap = {
        'version': '2026.4-GITTREES',
        'exportedAt': DateTime.now().toIso8601String(),
        'user': _profile.toMap(),
        'memoryStates': memoryMap,
        'eventLogs': _eventStore.exportEventLogJson(),
        'gitBranches': _branchManager.exportBranchesJson(),
      };
      final jsonStr = jsonEncode(dataMap);
      return base64Encode(utf8.encode(jsonStr));
    } catch (e) {
      return '';
    }
  }

  bool restoreStateFromBackup(String backupToken) {
    try {
      final cleanToken = backupToken.trim();
      if (cleanToken.isEmpty) return false;

      final decodedJson = utf8.decode(base64Decode(cleanToken));
      final Map<String, dynamic> dataMap = jsonDecode(decodedJson);

          if (dataMap.containsKey('user')) {
            _profile = EnhancedUserProfile.fromMap(Map<String, dynamic>.from(dataMap['user']));
          }

          if (dataMap.containsKey('memoryStates')) {
            _memoryStates.clear();
            final rawMem = Map<String, dynamic>.from(dataMap['memoryStates']);
            rawMem.forEach((k, v) {
              _memoryStates[k] = MemoryCardState.fromMap(Map<String, dynamic>.from(v));
            });
          }

          if (dataMap.containsKey('eventLogs')) {
            _eventStore.importEventLogJson(dataMap['eventLogs'] as String);
          }

          if (dataMap.containsKey('gitBranches')) {
            _branchManager.importBranchesJson(dataMap['gitBranches'] as String);
          }

          notifyListeners();
          return true;
        } catch (e) {
          return false;
        }
      }

      Future<void> adminImportMassiveQuestionsAsync(List<QuestionItem> newQuestions) async {
        if (_isProcessingMassiveData) return;
        _isProcessingMassiveData = true;
        notifyListeners();

        await Future.delayed(const Duration(milliseconds: 50));

        List<QuestionItem> cleanNewBatch = [];
        AerospacePreflightInspector.inspectAndSanitize(
          rawBank: newQuestions,
          onBankSanitized: (sanitized) => cleanNewBatch = sanitized,
        );

        final existingIds = _allQuestions.map((q) => q.id).toSet();
        int addedCount = 0;

        for (var newQ in cleanNewBatch) {
          if (!existingIds.contains(newQ.id)) {
            _allQuestions.add(newQ);
            existingIds.add(newQ.id);
            addedCount++;
          }
        }

        _rebuildBitwiseIndex();
        _semanticSimilarityCache.clear();

        commitSkillMilestone("admin: 批量注入 $addedCount 道全新考題物料");

        _isProcessingMassiveData = false;
        telemetry.logEvent(eventName: 'ADMIN_IMPORT', parameters: {'added': addedCount});
        notifyListeners();
        _scheduleAutoSave();
      }
    }
