import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/year_plan.dart';
import '../models/goal.dart';
import '../models/enums.dart';
import '../models/goal_target.dart';
import '../state/app_state.dart';
import '../utils/statistics.dart';
import 'goal_detail_screen.dart';

class GoalListScreen extends StatefulWidget {
  final YearPlan yearPlan;
  const GoalListScreen({super.key, required this.yearPlan});

  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _deleteMode = false;
  final Set<String> _selectedGoalIds = {};
  GoalCategory? _selectedCategoryFilter;

  YearPlan get _currentPlan {
    final state = context.read<AppState>();
    return state.yearPlans.firstWhere(
      (y) => y.id == widget.yearPlan.id,
      orElse: () => widget.yearPlan,
    );
  }

  List<Goal> get _goals => _currentPlan.goals;

  Future<void> _saveGoals(List<Goal> goals) async {
    final updated = _currentPlan.copyWith(goals: goals);
    await context.read<AppState>().updateYearPlan(updated);
  }

  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      _selectedGoalIds.clear();
    });
  }

  Future<void> _deleteSelectedGoals() async {
    final goals = List<Goal>.from(_goals);
    goals.removeWhere((g) => _selectedGoalIds.contains(g.id));
    await _saveGoals(goals);
    if (!mounted) return;
    setState(() {
      _selectedGoalIds.clear();
      _deleteMode = false;
    });
  }

  Future<void> _deleteGoal(int index) async {
    final goals = List<Goal>.from(_goals);
    goals.removeAt(index);
    await _saveGoals(goals);
  }

  Future<Map<String, dynamic>?> _showGoalDialog({Goal? goal}) async {
    final titleController = TextEditingController(text: goal?.title ?? '');
    GoalMetricType? selectedType = goal?.metricType ?? GoalMetricType.habit;
    GoalCategory? selectedCategory = goal?.category;
    final countController = TextEditingController(
      text: goal == null
          ? ''
          : (selectedType == GoalMetricType.habit
              ? (goal.target.timesPerWeek ?? 1).toString()
              : (goal.target.targetTotalValue?.toInt() ?? 1).toString()),
    );
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(goal == null ? '목표 추가' : '목표 편집'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: '목표를 입력하세요',
                  labelText: '목표',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<GoalCategory?>(
                initialValue: selectedCategory,
                items: [
                  const DropdownMenuItem(value: null, child: Text('카테고리 없음')),
                  ...GoalCategory.values.map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(children: [
                      Icon(goalCategoryIcon(c), size: 18, color: goalCategoryColor(c)),
                      const SizedBox(width: 8),
                      Text(goalCategoryLabel(c)),
                    ]),
                  )),
                ],
                onChanged: (v) => selectedCategory = v,
                decoration: const InputDecoration(labelText: '카테고리'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<GoalMetricType>(
                initialValue: selectedType,
                items: const [
                  DropdownMenuItem(value: GoalMetricType.habit, child: Text('습관(횟수/주)')),
                  DropdownMenuItem(value: GoalMetricType.count, child: Text('카운트(예: 책 권수)')),
                  DropdownMenuItem(value: GoalMetricType.duration, child: Text('시간(분/시간)')),
                ],
                onChanged: (v) {
                  selectedType = v;
                  countController.text = '';
                },
                decoration: const InputDecoration(labelText: '목표 유형'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '예: 10',
                  labelText: selectedType == GoalMetricType.count
                      ? '목표 수치(예: 권수)'
                      : selectedType == GoalMetricType.duration
                          ? '목표 시간(분)'
                          : '주간 횟수',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'title': titleController.text,
                'type': selectedType,
                'category': selectedCategory,
                'count': countController.text,
              });
            },
            child: Text(goal == null ? '추가' : '저장'),
          ),
        ],
      ),
    );
  }

  GoalTarget _buildTarget(GoalMetricType type, int count) {
    if (type == GoalMetricType.habit) {
      return GoalTarget(mode: GoalTargetMode.frequency, timesPerWeek: count);
    } else if (type == GoalMetricType.count) {
      return GoalTarget(mode: GoalTargetMode.total, targetTotalValue: count.toDouble(), unit: GoalUnit.books);
    } else {
      return GoalTarget(mode: GoalTargetMode.total, targetTotalValue: count.toDouble(), unit: GoalUnit.minutes);
    }
  }

  Future<void> _addGoal() async {
    final result = await _showGoalDialog();
    if (!mounted || result == null || (result['title'] as String).isEmpty) return;
    final type = result['type'] as GoalMetricType? ?? GoalMetricType.habit;
    final category = result['category'] as GoalCategory?;
    final count = int.tryParse(result['count'] ?? '') ?? 1;
    final target = _buildTarget(type, count);
    final issues = target.validate();
    if (issues.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(issues.first)),
        );
      }
      return;
    }
    final goals = List<Goal>.from(_goals);
    goals.add(Goal(
      id: const Uuid().v4(),
      title: result['title'],
      metricType: type,
      category: category,
      target: target,
      logs: [],
    ));
    await _saveGoals(goals);
  }

  Future<void> _editGoal(int index) async {
    final goal = _goals[index];
    final result = await _showGoalDialog(goal: goal);
    if (!mounted || result == null || (result['title'] as String).isEmpty) return;
    final type = result['type'] as GoalMetricType? ?? GoalMetricType.habit;
    final category = result['category'] as GoalCategory?;
    final count = int.tryParse(result['count'] ?? '') ?? 1;
    final target = _buildTarget(type, count);
    final issues = target.validate();
    if (issues.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(issues.first)),
        );
      }
      return;
    }
    final goals = List<Goal>.from(_goals);
    goals[index] = goal.copyWith(
      title: result['title'],
      metricType: type,
      category: category,
      target: target,
    );
    await _saveGoals(goals);
  }

  String _goalSubtitleText(Goal goal) {
    if (goal.metricType == GoalMetricType.count) {
      return '목표: ${goal.target.targetTotalValue?.toInt() ?? ''}권';
    } else if (goal.metricType == GoalMetricType.duration) {
      return '목표: ${goal.target.targetTotalValue?.toInt() ?? ''}분';
    } else {
      return '주간 ${goal.target.timesPerWeek ?? 1}회';
    }
  }

  bool _isGoalDoneOnDate(Goal goal, DateTime date) {
    return goal.progress.hasLogOnDate(date);
  }

  Future<void> _toggleGoalDone(Goal goal, DateTime date) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx == -1) return;
    final updated = goal.progress.toggleDate(
      date,
      generateId: () => const Uuid().v4(),
    );
    final goals = List<Goal>.from(_goals);
    goals[idx] = goal.copyWith(logs: updated.logs);
    await _saveGoals(goals);
  }

  List<Goal> get _filteredGoals {
    if (_selectedCategoryFilter == null) return _goals;
    return _goals.where((g) => g.category == _selectedCategoryFilter).toList();
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(children: [
        FilterChip(
          label: const Text('전체'),
          selected: _selectedCategoryFilter == null,
          onSelected: (_) => setState(() => _selectedCategoryFilter = null),
          selectedColor: const Color(0xFFE8EAF0),
        ),
        const SizedBox(width: 8),
        ...GoalCategory.values.map((cat) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            avatar: Icon(goalCategoryIcon(cat), size: 16, color: goalCategoryColor(cat)),
            label: Text(goalCategoryLabel(cat)),
            selected: _selectedCategoryFilter == cat,
            onSelected: (_) => setState(() => _selectedCategoryFilter =
                _selectedCategoryFilter == cat ? null : cat),
            selectedColor: goalCategoryColor(cat).withValues(alpha: 0.15),
          ),
        )),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1F3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.track_changes_rounded, size: 36, color: Color(0xFFA8B5E2)),
            ),
            const SizedBox(height: 24),
            const Text(
              '목표를 추가해보세요!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 8),
            const Text(
              '이 연도의 첫 번째 목표를 설정하세요',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(int index, Goal goal) {
    final isDone = _isGoalDoneOnDate(goal, _selectedDate);
    final streak = DashboardStatistics.getCurrentStreak(goal);
    final bestStreak = DashboardStatistics.getBestStreak(goal);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3142).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleGoalDone(goal, _selectedDate),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? const Color(0xFF6BCB8B) : Colors.transparent,
                  border: Border.all(
                    color: isDone ? const Color(0xFF6BCB8B) : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
                child: isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 12),
            if (goal.category != null)
              Container(
                width: 4,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: goalCategoryColor(goal.category!),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoalDetailScreen(
                        yearPlanId: widget.yearPlan.id,
                        goalId: goal.id,
                      ),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDone ? const Color(0xFF9CA3AF) : const Color(0xFF2D3142),
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: const Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _goalSubtitleText(goal),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                    if (goal.metricType == GoalMetricType.habit) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 14,
                            color: streak > 0 ? const Color(0xFFE8A87C) : const Color(0xFFD1D5DB)),
                          const SizedBox(width: 4),
                          Text(
                            '$streak일 연속',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: streak > 0 ? const Color(0xFFE8A87C) : const Color(0xFF9CA3AF)),
                          ),
                          if (bestStreak > streak) ...[
                            const SizedBox(width: 8),
                            Text('최고 $bestStreak일',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFD1D5DB)),
              tooltip: '편집',
              onPressed: () => _editGoal(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC6B6B)),
              tooltip: '삭제',
              onPressed: () => _deleteGoal(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteModeCard(int index, Goal goal) {
    final isSelected = _selectedGoalIds.contains(goal.id);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFFDC6B6B) : const Color(0xFFE5E7EB),
          width: isSelected ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Checkbox(
          value: isSelected,
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                _selectedGoalIds.add(goal.id);
              } else {
                _selectedGoalIds.remove(goal.id);
              }
            });
          },
        ),
        title: Text(
          goal.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF2D3142)),
        ),
        subtitle: Text(
          _goalSubtitleText(goal),
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes to trigger rebuild
    context.watch<AppState>();
    final goals = _goals;
    final filteredGoals = _filteredGoals;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.yearPlan.year}년 목표'),
        actions: [
          if (goals.isNotEmpty && !_deleteMode)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF9CA3AF)),
              tooltip: '목표 선택 삭제',
              onPressed: _toggleDeleteMode,
            ),
          if (_deleteMode)
            IconButton(
              icon: Icon(
                Icons.delete_forever_rounded,
                color: _selectedGoalIds.isNotEmpty ? const Color(0xFFDC6B6B) : const Color(0xFF9CA3AF),
              ),
              tooltip: '선택 삭제',
              onPressed: _selectedGoalIds.isNotEmpty ? _deleteSelectedGoals : null,
            ),
          if (_deleteMode)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
              tooltip: '취소',
              onPressed: _toggleDeleteMode,
            ),
        ],
      ),
      body: Column(
        children: [
          // 캘린더 영역
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
            ),
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime(widget.yearPlan.year, 1, 1),
              lastDate: DateTime(widget.yearPlan.year, 12, 31),
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
              },
            ),
          ),
          // 카테고리 필터
          if (goals.isNotEmpty && !_deleteMode) _buildCategoryFilter(),
          // 선택 날짜 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_selectedDate.month}월 ${_selectedDate.day}일 목표',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                ),
                const Spacer(),
                Text(
                  '${filteredGoals.length}개',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          // 목표 리스트
          Expanded(
            child: filteredGoals.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filteredGoals.length,
                    itemBuilder: (ctx, i) {
                      final goal = filteredGoals[i];
                      final realIndex = goals.indexOf(goal);
                      if (_deleteMode) {
                        return _buildDeleteModeCard(realIndex, goal);
                      }
                      return _buildGoalCard(realIndex, goal);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        tooltip: '목표 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
