import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/year_plan.dart';
import '../models/log_entry.dart';
import '../models/goal.dart';
import '../models/enums.dart';
import '../models/goal_target.dart';
import '../storage/repository.dart';
import '../utils/platform.dart';

class GoalListScreen extends StatefulWidget {
  final YearPlan yearPlan;
  final ValueChanged<YearPlan>? onChanged;
  const GoalListScreen({Key? key, required this.yearPlan, this.onChanged}) : super(key: key);

  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Goal> _goals = [];
  final _repo = YearPlanRepository();
  bool _deleteMode = false;
  final Set<String> _selectedGoalIds = {};

  @override
  void initState() {
    super.initState();
    _goals = List<Goal>.from(widget.yearPlan.goals);
  }

  /// 전체 YearPlan 리스트를 로드 → 현재 연도만 업데이트 → 전체 저장
  Future<void> _saveCurrentYearPlan() async {
    final updated = widget.yearPlan.copyWith(goals: _goals);
    widget.onChanged?.call(updated);

    final allPlans = await _repo.loadYearPlans();
    final idx = allPlans.indexWhere((y) => y.year == widget.yearPlan.year);
    if (idx >= 0) {
      allPlans[idx] = updated;
    } else {
      allPlans.add(updated);
    }
    await _repo.saveYearPlans(allPlans);
  }

  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      _selectedGoalIds.clear();
    });
  }

  void _deleteSelectedGoals() async {
    setState(() {
      _goals.removeWhere((g) => _selectedGoalIds.contains(g.id));
      _selectedGoalIds.clear();
      _deleteMode = false;
    });
    await _saveCurrentYearPlan();
  }

  void _deleteGoal(int index) async {
    setState(() {
      _goals.removeAt(index);
    });
    await _saveCurrentYearPlan();
  }

  Future<Map<String, dynamic>?> _showGoalDialog({Goal? goal}) async {
    final titleController = TextEditingController(text: goal?.title ?? '');
    GoalMetricType? selectedType = goal?.metricType ?? GoalMetricType.habit;
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
        title: Text(goal == null ? '버킷리스트 목표 추가' : '목표 편집'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('목표'),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: '목표를 입력하세요'),
            ),
            const SizedBox(height: 12),
            const Text('유형'),
            DropdownButtonFormField<GoalMetricType>(
              value: selectedType,
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
            const SizedBox(height: 12),
            const Text('횟수'),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'title': titleController.text,
                'type': selectedType,
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

  void _addGoal() async {
    final result = await _showGoalDialog();
    if (result != null && (result['title'] as String).isNotEmpty) {
      final type = result['type'] as GoalMetricType? ?? GoalMetricType.habit;
      final count = int.tryParse(result['count'] ?? '') ?? 1;
      setState(() {
        _goals.add(Goal(
          id: const Uuid().v4(),
          title: result['title'],
          metricType: type,
          category: null,
          target: _buildTarget(type, count),
          logs: [],
        ));
      });
      await _saveCurrentYearPlan();
    }
  }

  void _editGoal(int index) async {
    final goal = _goals[index];
    final result = await _showGoalDialog(goal: goal);
    if (result != null && (result['title'] as String).isNotEmpty) {
      final type = result['type'] as GoalMetricType? ?? GoalMetricType.habit;
      final count = int.tryParse(result['count'] ?? '') ?? 1;
      setState(() {
        _goals[index] = goal.copyWith(
          title: result['title'],
          metricType: type,
          target: _buildTarget(type, count),
        );
      });
      await _saveCurrentYearPlan();
    }
  }

  Widget _buildGoalSubtitle(Goal goal) {
    if (goal.metricType == GoalMetricType.count) {
      return Text('목표: ${goal.target.targetTotalValue?.toInt() ?? ''}권');
    } else if (goal.metricType == GoalMetricType.duration) {
      return Text('목표: ${goal.target.targetTotalValue?.toInt() ?? ''}분');
    } else {
      return Text('주간 횟수: ${goal.target.timesPerWeek ?? 1}회');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobilePlatform();
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.yearPlan.year}년 목표'),
        actions: [
          if (_goals.isNotEmpty && !_deleteMode)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '목표 선택 삭제',
              onPressed: _toggleDeleteMode,
            ),
          if (_deleteMode)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: '선택 삭제',
              onPressed: _selectedGoalIds.isNotEmpty ? _deleteSelectedGoals : null,
            ),
          if (_deleteMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '취소',
              onPressed: _toggleDeleteMode,
            ),
        ],
      ),
      body: Column(
        children: [
          CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime(widget.yearPlan.year, 1, 1),
            lastDate: DateTime(widget.yearPlan.year, 12, 31),
            onDateChanged: (date) {
              setState(() {
                _selectedDate = date;
              });
            },
          ),
          Expanded(
            child: _goals.isEmpty
                ? Center(
                    child: Text('목표를 추가해보세요!', style: Theme.of(context).textTheme.bodyLarge),
                  )
                : ListView.builder(
                    itemCount: _goals.length,
                    itemBuilder: (ctx, i) {
                      final goal = _goals[i];
                      if (_deleteMode) {
                        return ListTile(
                          leading: Checkbox(
                            value: _selectedGoalIds.contains(goal.id),
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
                          title: Text(goal.title),
                          subtitle: _buildGoalSubtitle(goal),
                        );
                      } else if (mobile) {
                        return Dismissible(
                          key: ValueKey(goal.id),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _deleteGoal(i),
                          child: ListTile(
                            title: Text(goal.title),
                            subtitle: _buildGoalSubtitle(goal),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: '목표 편집',
                                  onPressed: () => _editGoal(i),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: '삭제',
                                  onPressed: () => _deleteGoal(i),
                                ),
                                Icon(
                                  _isGoalDoneOnDate(goal, _selectedDate) ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: _isGoalDoneOnDate(goal, _selectedDate) ? Colors.green : null,
                                ),
                              ],
                            ),
                            onTap: () => _toggleGoalDone(goal, _selectedDate),
                          ),
                        );
                      } else {
                        // Web / Desktop: 삭제 버튼 직접 표시
                        return ListTile(
                          title: Text(goal.title),
                          subtitle: _buildGoalSubtitle(goal),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: '목표 편집',
                                onPressed: () => _editGoal(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: '삭제',
                                onPressed: () => _deleteGoal(i),
                              ),
                              GestureDetector(
                                onTap: () => _toggleGoalDone(goal, _selectedDate),
                                child: Icon(
                                  _isGoalDoneOnDate(goal, _selectedDate) ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: _isGoalDoneOnDate(goal, _selectedDate) ? Colors.green : null,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _toggleGoalDone(goal, _selectedDate),
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGoal,
        tooltip: '버킷리스트 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _isGoalDoneOnDate(Goal goal, DateTime date) {
    return goal.logs.any((log) =>
        log.date.year == date.year &&
        log.date.month == date.month &&
        log.date.day == date.day &&
        log.value == 1);
  }

  void _toggleGoalDone(Goal goal, DateTime date) async {
    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx == -1) return;
    final List<LogEntry> logs = List<LogEntry>.from(goal.logs);
    final logIdx = logs.indexWhere((log) =>
        log.date.year == date.year &&
        log.date.month == date.month &&
        log.date.day == date.day);
    if (logIdx >= 0) {
      logs.removeAt(logIdx);
    } else {
      logs.add(LogEntry(date: date, value: 1));
    }
    setState(() {
      _goals[idx] = goal.copyWith(logs: logs);
    });
    await _saveCurrentYearPlan();
  }
}
