import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../models/goal.dart';
import '../state/app_state.dart';

class GoalDetailScreen extends StatefulWidget {
  final int listIndex;
  final int itemIndex;
  final BucketList bucketList;

  const GoalDetailScreen({
    super.key,
    required this.listIndex,
    required this.itemIndex,
    required this.bucketList,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late BucketList _bucketList;
  late BucketItem _item;

  @override
  void initState() {
    super.initState();
    _bucketList = BucketList(
      title: widget.bucketList.title,
      items: List.from(widget.bucketList.items),
    );
    _item = _bucketList.items[widget.itemIndex];
  }

  Future<void> _save() async {
    if (!mounted) return;
    _bucketList.items[widget.itemIndex] = _item;
    await context.read<AppState>().updateBucketList(widget.listIndex, _bucketList);
  }

  Future<void> _updateProgress(int delta) async {
    setState(() {
      _item.currentValue = (_item.currentValue + delta).clamp(0, _item.targetValue);
      if (_item.isCompleted && _item.completedAt == null) {
        _item.completedAt = DateTime.now();
      } else if (!_item.isCompleted) {
        _item.completedAt = null;
      }
    });
    await _save();
  }

  Future<void> _toggleToday() async {
    setState(() {
      _item.toggleDate(DateTime.now());
    });
    await _save();
  }

  Widget _buildFrequencyView() {
    final now = DateTime.now();
    final todayCompleted = _item.isDateCompleted(now);
    final weekday = now.weekday;
    final weekStart = DateTime(now.year, now.month, now.day - (weekday - 1));

    return Column(
      children: [
        // Today's check-in
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: todayCompleted
                  ? [const Color(0xFF6BCB8B), const Color(0xFF8FD9A8)]
                  : [const Color(0xFF7B8CDE), const Color(0xFFA8B5E2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (todayCompleted ? const Color(0xFF6BCB8B) : const Color(0xFF7B8CDE))
                    .withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                DateFormat('M월 d일').format(now),
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _toggleToday,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: todayCompleted ? 0.3 : 0.15),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    todayCompleted ? Icons.check_rounded : Icons.add_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                todayCompleted ? '완료!' : '탭하여 체크',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
        // This week's progress
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '이번 주',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (i) {
                  final date = weekStart.add(Duration(days: i));
                  final done = _item.isDateCompleted(date);
                  final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
                  final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
                  return GestureDetector(
                    onTap: () async {
                      setState(() {
                        _item.toggleDate(date);
                      });
                      await _save();
                    },
                    child: Column(
                      children: [
                        Text(
                          dayLabels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                            color: isToday ? const Color(0xFF7B8CDE) : const Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done
                                ? const Color(0xFF6BCB8B)
                                : isToday
                                    ? const Color(0xFF7B8CDE).withValues(alpha: 0.1)
                                    : const Color(0xFFF0F1F3),
                            border: isToday && !done
                                ? Border.all(color: const Color(0xFF7B8CDE), width: 2)
                                : null,
                          ),
                          child: done
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '목표: 주 ${_item.timesPerWeek}회',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                  Text(
                    '달성: ${_item.completedDates.where((ds) {
                      final d = DateTime.tryParse(ds);
                      return d != null && !d.isBefore(weekStart) && d.isBefore(weekStart.add(const Duration(days: 7)));
                    }).length}회',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7B8CDE)),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Stats cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(child: _buildStatCard(
                '이번달',
                '${(_item.monthlyAchievementRate(now.year, now.month) * 100).toStringAsFixed(0)}%',
                Icons.calendar_month_rounded,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(
                '올해',
                '${(_item.yearlyAchievementRate(now.year) * 100).toStringAsFixed(0)}%',
                Icons.emoji_events_rounded,
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalView() {
    final unitStr = _item.unit.isNotEmpty ? ' ${_item.unit}' : '';
    final progress = _item.progressRate;
    final completed = _item.isCompleted;

    return Column(
      children: [
        // Progress header
        Container(
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: completed
                  ? [const Color(0xFF6BCB8B), const Color(0xFF8FD9A8)]
                  : [const Color(0xFFE8A87C), const Color(0xFFF0C9A8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (completed ? const Color(0xFF6BCB8B) : const Color(0xFFE8A87C))
                    .withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '진행률',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_item.currentValue} / ${_item.targetValue}$unitStr',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    if (_item.targetValue > _item.currentValue)
                      Text(
                        '${_item.targetValue - _item.currentValue}$unitStr 남음',
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // +/- controls
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
          ),
          child: Column(
            children: [
              const Text(
                '진행 기록',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildControlButton(
                    icon: Icons.remove_rounded,
                    onTap: _item.currentValue > 0 ? () => _updateProgress(-1) : null,
                  ),
                  const SizedBox(width: 24),
                  Column(
                    children: [
                      Text(
                        '${_item.currentValue}',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFF2D3142)),
                      ),
                      Text(
                        unitStr.trim(),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  _buildControlButton(
                    icon: Icons.add_rounded,
                    onTap: !completed ? () => _updateProgress(1) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF7B8CDE).withValues(alpha: 0.1) : const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? const Color(0xFF7B8CDE).withValues(alpha: 0.3) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Icon(
          icon,
          size: 28,
          color: enabled ? const Color(0xFF7B8CDE) : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF7B8CDE)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF2D3142)),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFrequency = _item.targetMode == GoalTargetMode.frequency;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.text),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            if (_item.deadline != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 16, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Text(
                      '마감: ${DateFormat('yyyy.MM.dd').format(_item.deadline!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _item.deadline!.isBefore(DateTime.now()) && !_item.isCompleted
                            ? const Color(0xFFDC6B6B)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            if (isFrequency) _buildFrequencyView() else _buildTotalView(),
          ],
        ),
      ),
    );
  }
}
