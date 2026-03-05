import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/goal.dart';
import '../models/goal_log.dart';
import '../models/goal_progress.dart';
import '../state/app_state.dart';
import '../utils/date_utils.dart' as app_dates;

class GoalDetailScreen extends StatefulWidget {
  final String yearPlanId;
  final String goalId;

  const GoalDetailScreen({
    super.key,
    required this.yearPlanId,
    required this.goalId,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  DateTime _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Goal? _findGoal(AppState state) {
    for (final plan in state.yearPlans) {
      if (plan.id == widget.yearPlanId) {
        for (final g in plan.goals) {
          if (g.id == widget.goalId) return g;
        }
      }
    }
    return null;
  }

  void _toggleToday(Goal goal) {
    context.read<AppState>().toggleHabit(
      widget.yearPlanId,
      goal.id,
      DateTime.now(),
      const Uuid().v4(),
    );
  }

  void _showAddProgressDialog(Goal goal) {
    final controller = TextEditingController();
    final noteController = TextEditingController();
    final unitLabel = goal.target.unit != null
        ? goalUnitToString(goal.target.unit!)
        : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '수치',
                hintText: '예: 10',
                suffixText: unitLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                hintText: '예: 오늘 읽은 챕터',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value == null || value <= 0) return;
              Navigator.pop(ctx);
              final note = noteController.text.trim();
              context.read<AppState>().addGoalLog(
                widget.yearPlanId,
                goal.id,
                GoalLog(
                  id: const Uuid().v4(),
                  date: DateTime.now(),
                  value: value,
                  note: note.isEmpty ? null : note,
                ),
              );
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _onCalendarDayTap(Goal goal, DateTime day) {
    if (goal.metricType == GoalMetricType.habit) {
      context.read<AppState>().toggleHabit(
        widget.yearPlanId,
        goal.id,
        day,
        const Uuid().v4(),
      );
    } else {
      _showAddProgressDialog(goal);
    }
  }

  void _deleteLog(String logId) {
    context.read<AppState>().removeGoalLog(
      widget.yearPlanId,
      widget.goalId,
      logId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal = _findGoal(state);

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
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
                  child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFFA8B5E2)),
                ),
                const SizedBox(height: 24),
                const Text(
                  '목표를 찾을 수 없습니다',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                ),
                const SizedBox(height: 8),
                const Text(
                  '이 목표가 삭제되었을 수 있습니다',
                  style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('돌아가기'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final p = goal.progress;
    final isHabit = goal.metricType == GoalMetricType.habit;
    final isFrequency = goal.target.mode == GoalTargetMode.frequency;

    return Scaffold(
      appBar: AppBar(title: Text(goal.title)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(goal)),
          SliverToBoxAdapter(child: _buildProgressCard(goal, p)),
          if (isFrequency)
            SliverToBoxAdapter(child: _buildStreakCard(p)),
          SliverToBoxAdapter(child: _buildCalendar(goal, p)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                '기록 (${p.logs.length}개)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
              ),
            ),
          ),
          if (p.logs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Text(
                  '아직 기록이 없습니다',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
              ),
            )
          else
            _buildLogList(goal, p),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (isHabit) {
            _toggleToday(goal);
          } else {
            _showAddProgressDialog(goal);
          }
        },
        icon: Icon(isHabit ? Icons.check_rounded : Icons.add_rounded),
        label: Text(isHabit ? '오늘 완료' : '기록 추가'),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────

  Widget _buildHeader(Goal goal) {
    String metricLabel;
    if (goal.metricType == GoalMetricType.habit) {
      metricLabel = '습관 · 주간 ${goal.target.timesPerWeek ?? 1}회';
    } else if (goal.metricType == GoalMetricType.count) {
      final unit = goal.target.unit != null ? goalUnitToString(goal.target.unit!) : '';
      metricLabel = '카운트 · 목표 ${goal.target.targetTotalValue?.toInt() ?? ''}$unit';
    } else {
      final unit = goal.target.unit != null ? goalUnitToString(goal.target.unit!) : '분';
      metricLabel = '시간 · 목표 ${goal.target.targetTotalValue?.toInt() ?? ''}$unit';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (goal.category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: goalCategoryColor(goal.category!).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(goalCategoryIcon(goal.category!), size: 14, color: goalCategoryColor(goal.category!)),
                  const SizedBox(width: 4),
                  Text(
                    goalCategoryLabel(goal.category!),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: goalCategoryColor(goal.category!)),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              metricLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress Card ─────────────────────────────────────────

  Widget _buildProgressCard(Goal goal, GoalProgress p) {
    final isTotal = goal.target.mode == GoalTargetMode.total;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3142).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: (p.completionPercent / 100).clamp(0.0, 1.0),
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0xFFF0F1F3),
                  valueColor: AlwaysStoppedAnimation(
                    p.isCompleted ? const Color(0xFF6BCB8B) : const Color(0xFF7B8CDE),
                  ),
                ),
                if (p.isCompleted)
                  const Icon(Icons.check_rounded, size: 32, color: Color(0xFF6BCB8B))
                else
                  Text(
                    '${p.completionPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isTotal) ...[
                  _statRow('누적', _formatValue(p.totalValue, goal)),
                  const SizedBox(height: 6),
                  _statRow('남은 양', _formatValue(p.remaining, goal)),
                ] else ...[
                  _statRow('이번 주', '${p.currentWeekCompletions}/${goal.target.timesPerWeek ?? 1}회'),
                  const SizedBox(height: 6),
                  _statRow('활동일', '${p.activeDays}일'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
      ],
    );
  }

  String _formatValue(double value, Goal goal) {
    final unit = goal.target.unit != null ? goalUnitToString(goal.target.unit!) : '';
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$formatted$unit';
  }

  // ─── Streak Card ───────────────────────────────────────────

  Widget _buildStreakCard(GoalProgress p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3142).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _streakItem(
              Icons.local_fire_department,
              p.currentStreak > 0 ? const Color(0xFFE8A87C) : const Color(0xFFD1D5DB),
              '${p.currentStreak}일',
              '현재 연속',
            ),
          ),
          Container(width: 1, height: 40, color: const Color(0xFFF0F1F3)),
          Expanded(
            child: _streakItem(
              Icons.emoji_events_rounded,
              p.bestStreak > 0 ? const Color(0xFFF7D794) : const Color(0xFFD1D5DB),
              '${p.bestStreak}일',
              '최고 기록',
            ),
          ),
        ],
      ),
    );
  }

  Widget _streakItem(IconData icon, Color color, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
      ],
    );
  }

  // ─── Calendar ──────────────────────────────────────────────

  Widget _buildCalendar(Goal goal, GoalProgress p) {
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = firstDay.weekday - 1; // Monday = 0

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3142).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF9CA3AF)),
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(year, month - 1);
                }),
              ),
              Text(
                '$year년 $month월',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(year, month + 1);
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: ['월', '화', '수', '목', '금', '토', '일']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF))),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          ...List.generate(((startOffset + daysInMonth + 6) ~/ 7), (week) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: List.generate(7, (col) {
                  final dayNum = week * 7 + col - startOffset + 1;
                  if (dayNum < 1 || dayNum > daysInMonth) {
                    return const Expanded(child: SizedBox(height: 36));
                  }
                  final day = DateTime(year, month, dayNum);
                  final hasLog = p.hasLogOnDate(day);
                  final isToday = _isToday(day);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onCalendarDayTap(goal, day),
                      child: Container(
                        height: 36,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: hasLog
                              ? const Color(0xFF7B8CDE).withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday
                              ? Border.all(color: const Color(0xFF7B8CDE), width: 1.5)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: hasLog ? FontWeight.w700 : FontWeight.w400,
                              color: hasLog ? const Color(0xFF7B8CDE) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  bool _isToday(DateTime day) => app_dates.sameDate(day, DateTime.now());

  // ─── Log List ──────────────────────────────────────────────

  Widget _buildLogList(Goal goal, GoalProgress p) {
    final reversedLogs = p.logs.reversed.toList();
    final unitLabel = goal.target.unit != null ? goalUnitToString(goal.target.unit!) : '';

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final log = reversedLogs[index];
          final d = log.date;
          final dateStr = '${d.month}/${d.day}';
          final valueStr = log.value == log.value.roundToDouble()
              ? '${log.value.toInt()}$unitLabel'
              : '${log.value.toStringAsFixed(1)}$unitLabel';

          return Dismissible(
            key: ValueKey(log.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDC6B6B),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
            ),
            onDismissed: (_) => _deleteLog(log.id),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF7B8CDE),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    valueStr,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                  ),
                  if (log.note != null && log.note!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        log.note!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ),
          );
        },
        childCount: reversedLogs.length,
      ),
    );
  }
}
