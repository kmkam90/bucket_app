import 'package:flutter/foundation.dart';
import '../core/result.dart';
import '../models/goal.dart';
import '../models/goal_log.dart';
import '../models/year_plan.dart';
import '../storage/app_repository.dart';

class AppState extends ChangeNotifier {
  final AppRepository _repo;

  List<BucketList> _bucketLists = [];
  List<YearPlan> _yearPlans = [];
  bool _isLoading = true;
  List<String> _warnings = [];
  String? _lastError;

  /// Serializes persist writes so rapid mutations don't interleave.
  Future<void> _persistQueue = Future.value();

  AppState({AppRepository? repo}) : _repo = repo ?? AppRepository();

  // ─── Getters (read-only) ────────────────────────────────────
  List<BucketList> get bucketLists => _bucketLists;
  List<YearPlan> get yearPlans => _yearPlans;
  bool get isLoading => _isLoading;
  List<String> get warnings => _warnings;
  String? get lastError => _lastError;
  List<Goal> get allGoals => _yearPlans.expand((yp) => yp.goals).toList();

  void clearWarnings() {
    _warnings = [];
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // ─── Init ───────────────────────────────────────────────────
  Future<void> init() async {
    final result = await _repo.loadAll();
    switch (result) {
      case Ok(:final data, :final warnings):
        _bucketLists = data.bucketLists;
        _yearPlans = data.yearPlans;
        _warnings = warnings;
      case Err(:final message):
        _warnings = [message];
    }
    _isLoading = false;
    notifyListeners();
  }

  // ─── Bucket Lists ──────────────────────────────────────────
  Future<void> addBucketList(BucketList list) async {
    _bucketLists.add(list);
    notifyListeners();
    await _persistBucketLists();
  }

  Future<void> updateBucketList(int index, BucketList list) async {
    if (index < 0 || index >= _bucketLists.length) return;
    _bucketLists[index] = list;
    notifyListeners();
    await _persistBucketLists();
  }

  Future<void> deleteBucketList(int index) async {
    if (index < 0 || index >= _bucketLists.length) return;
    _bucketLists.removeAt(index);
    notifyListeners();
    await _persistBucketLists();
  }

  Future<void> deleteBucketLists(Set<int> indexes) async {
    final sorted = indexes.toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      if (i >= 0 && i < _bucketLists.length) _bucketLists.removeAt(i);
    }
    notifyListeners();
    await _persistBucketLists();
  }

  // ─── Year Plans ─────────────────────────────────────────────
  Future<void> addYearPlan(YearPlan plan) async {
    _yearPlans.add(plan);
    notifyListeners();
    await _persistYearPlans();
  }

  Future<void> updateYearPlan(YearPlan updated) async {
    final idx = _yearPlans.indexWhere((y) => y.id == updated.id);
    if (idx < 0) return;
    _yearPlans[idx] = updated;
    notifyListeners();
    await _persistYearPlans();
  }

  Future<void> deleteYearPlan(String id) async {
    _yearPlans.removeWhere((y) => y.id == id);
    notifyListeners();
    await _persistYearPlans();
  }

  // ─── Goal Mutations (convenience) ──────────────────────────
  Future<void> toggleHabit(
      String yearPlanId, String goalId, DateTime date, String logId) async {
    final yIdx = _yearPlans.indexWhere((y) => y.id == yearPlanId);
    if (yIdx < 0) return;
    final plan = _yearPlans[yIdx];
    final gIdx = plan.goals.indexWhere((g) => g.id == goalId);
    if (gIdx < 0) return;

    final goal = plan.goals[gIdx];
    final updated = goal.progress.toggleDate(date, generateId: () => logId);
    final newGoals = List<Goal>.from(plan.goals);
    newGoals[gIdx] = goal.copyWith(logs: updated.logs);
    _yearPlans[yIdx] = plan.copyWith(goals: newGoals);

    notifyListeners();
    await _persistYearPlans();
  }

  Future<void> addGoalLog(
      String yearPlanId, String goalId, GoalLog log) async {
    final yIdx = _yearPlans.indexWhere((y) => y.id == yearPlanId);
    if (yIdx < 0) return;
    final plan = _yearPlans[yIdx];
    final gIdx = plan.goals.indexWhere((g) => g.id == goalId);
    if (gIdx < 0) return;

    final goal = plan.goals[gIdx];
    final newLogs = [...goal.logs, log];
    final newGoals = List<Goal>.from(plan.goals);
    newGoals[gIdx] = goal.copyWith(logs: newLogs);
    _yearPlans[yIdx] = plan.copyWith(goals: newGoals);

    notifyListeners();
    await _persistYearPlans();
  }

  Future<void> removeGoalLog(
      String yearPlanId, String goalId, String logId) async {
    final yIdx = _yearPlans.indexWhere((y) => y.id == yearPlanId);
    if (yIdx < 0) return;
    final plan = _yearPlans[yIdx];
    final gIdx = plan.goals.indexWhere((g) => g.id == goalId);
    if (gIdx < 0) return;

    final goal = plan.goals[gIdx];
    final newLogs = goal.logs.where((l) => l.id != logId).toList();
    final newGoals = List<Goal>.from(plan.goals);
    newGoals[gIdx] = goal.copyWith(logs: newLogs);
    _yearPlans[yIdx] = plan.copyWith(goals: newGoals);

    notifyListeners();
    await _persistYearPlans();
  }

  // ─── Import/Export ─────────────────────────────────────────
  Future<Result<String>> export() => _repo.exportToJson();

  Future<Result<void>> import(String json) async {
    final result = await _repo.importFromJson(json);
    if (result is Ok) await init();
    return result;
  }

  // ─── Persist Helpers ──────────────────────────────────────

  /// Enqueues a persist operation so rapid mutations are serialized.
  Future<void> _enqueue(Future<void> Function() task) {
    _persistQueue = _persistQueue.then((_) => task());
    return _persistQueue;
  }

  Future<void> _persistBucketLists() => _enqueue(() async {
    final result = await _repo.saveBucketLists(_bucketLists);
    switch (result) {
      case Err(:final message):
        _lastError = message;
        notifyListeners();
      case Ok():
        break;
    }
  });

  Future<void> _persistYearPlans() => _enqueue(() async {
    final result = await _repo.saveYearPlans(_yearPlans);
    switch (result) {
      case Err(:final message):
        _lastError = message;
        notifyListeners();
      case Ok():
        break;
    }
  });
}
