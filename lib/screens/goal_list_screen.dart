import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../models/goal.dart';
import '../state/app_state.dart';
import 'goal_detail_screen.dart';

class GoalListScreen extends StatefulWidget {
  final int listIndex;
  final BucketList bucketList;

  const GoalListScreen({
    super.key,
    required this.listIndex,
    required this.bucketList,
  });

  @override
  State<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends State<GoalListScreen> {
  late BucketList _bucketList;

  @override
  void initState() {
    super.initState();
    _bucketList = BucketList(
      title: widget.bucketList.title,
      items: List.from(widget.bucketList.items),
    );
  }

  Future<void> _save() async {
    if (!mounted) return;
    await context.read<AppState>().updateBucketList(widget.listIndex, _bucketList);
  }

  Future<void> _addGoal() async {
    final result = await _showGoalDialog();
    if (!mounted || result == null) return;
    setState(() {
      _bucketList.items.add(result);
    });
    await _save();
  }

  Future<void> _editGoal(int index) async {
    final result = await _showGoalDialog(existingItem: _bucketList.items[index]);
    if (!mounted || result == null) return;
    setState(() {
      _bucketList.items[index] = result;
    });
    await _save();
  }

  Future<void> _deleteGoal(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('목표 삭제'),
        content: Text('"${_bucketList.items[index].text}"를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Color(0xFFDC6B6B))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _bucketList.items.removeAt(index);
    });
    await _save();
  }

  Future<void> _navigateToDetail(int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GoalDetailScreen(
          listIndex: widget.listIndex,
          itemIndex: index,
          bucketList: _bucketList,
        ),
      ),
    );
    if (!mounted) return;
    // Refresh from state
    final updatedList = context.read<AppState>().bucketLists;
    if (widget.listIndex < updatedList.length) {
      setState(() {
        _bucketList = BucketList(
          title: updatedList[widget.listIndex].title,
          items: List.from(updatedList[widget.listIndex].items),
        );
      });
    }
  }

  Future<BucketItem?> _showGoalDialog({BucketItem? existingItem}) async {
    final isEdit = existingItem != null;
    final nameController = TextEditingController(text: existingItem?.text);
    final targetController = TextEditingController(
      text: existingItem != null && existingItem.targetValue > 0
          ? existingItem.targetValue.toString()
          : '',
    );
    final timesPerWeekController = TextEditingController(
      text: existingItem?.timesPerWeek.toString() ?? '3',
    );
    final unitController = TextEditingController(text: existingItem?.unit ?? '');
    var selectedMode = existingItem?.targetMode ?? GoalTargetMode.total;
    DateTime? selectedDeadline = existingItem?.deadline;

    return showDialog<BucketItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '목표 수정' : '목표 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '예: 독서 10권, 운동 주 3회',
                      labelText: '목표 이름',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '목표 유형',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeChip(
                          label: '반복 (주간)',
                          icon: Icons.repeat_rounded,
                          isSelected: selectedMode == GoalTargetMode.frequency,
                          onTap: () => setDialogState(() => selectedMode = GoalTargetMode.frequency),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ModeChip(
                          label: '누적 달성',
                          icon: Icons.trending_up_rounded,
                          isSelected: selectedMode == GoalTargetMode.total,
                          onTap: () => setDialogState(() => selectedMode = GoalTargetMode.total),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (selectedMode == GoalTargetMode.frequency) ...[
                    TextField(
                      controller: timesPerWeekController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '주 몇 회',
                        suffixText: '회 / 주',
                        hintText: '3',
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '목표 수치',
                        hintText: '예: 10',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: '단위',
                        hintText: '예: 권, 회, km',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded, color: Color(0xFF7B8CDE)),
                    title: Text(
                      selectedDeadline != null
                          ? DateFormat('yyyy.MM.dd').format(selectedDeadline!)
                          : '마감일 (선택)',
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedDeadline != null
                            ? const Color(0xFF2D3142)
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                    trailing: selectedDeadline != null
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setDialogState(() => selectedDeadline = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDeadline ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDeadline = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final item = BucketItem(
                    text: name,
                    isDone: existingItem?.isDone ?? false,
                    completedAt: existingItem?.completedAt,
                    deadline: selectedDeadline,
                    goalType: selectedMode == GoalTargetMode.frequency
                        ? BucketItemType.count
                        : BucketItemType.count,
                    targetMode: selectedMode,
                    timesPerWeek: int.tryParse(timesPerWeekController.text) ?? 3,
                    targetValue: selectedMode == GoalTargetMode.total
                        ? (int.tryParse(targetController.text) ?? 0)
                        : 0,
                    currentValue: existingItem?.currentValue ?? 0,
                    unit: unitController.text.trim(),
                    completedDates: existingItem?.completedDates ?? [],
                  );
                  Navigator.of(context).pop(item);
                },
                child: const Text('확인'),
              ),
            ],
          );
        },
      ),
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
              child: const Icon(Icons.flag_rounded, size: 36, color: Color(0xFFA8B5E2)),
            ),
            const SizedBox(height: 24),
            const Text(
              '아직 목표가 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 8),
            const Text(
              '+ 버튼으로 목표를 추가해보세요!',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(int index) {
    final item = _bucketList.items[index];
    final now = DateTime.now();
    final isFrequency = item.targetMode == GoalTargetMode.frequency;
    final completed = item.isCompleted;

    // Progress info
    String subtitleText;
    double progressValue;
    String progressText;

    if (isFrequency) {
      subtitleText = '주 ${item.timesPerWeek}회 반복';
      final monthRate = item.monthlyAchievementRate(now.year, now.month);
      final yearRate = item.yearlyAchievementRate(now.year);
      progressValue = monthRate;
      progressText = '이번달 ${(monthRate * 100).toStringAsFixed(0)}%  |  올해 ${(yearRate * 100).toStringAsFixed(0)}%';
    } else {
      final unitStr = item.unit.isNotEmpty ? ' ${item.unit}' : '';
      subtitleText = '목표: ${item.targetValue}$unitStr';
      progressValue = item.progressRate;
      progressText = '${item.currentValue} / ${item.targetValue}$unitStr  (${(progressValue * 100).toStringAsFixed(0)}%)';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed ? const Color(0xFF6BCB8B).withValues(alpha: 0.5) : const Color(0xFFE5E7EB),
          width: completed ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3142).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToDetail(index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: completed
                          ? const Color(0xFF6BCB8B).withValues(alpha: 0.15)
                          : isFrequency
                              ? const Color(0xFF7B8CDE).withValues(alpha: 0.1)
                              : const Color(0xFFE8A87C).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      completed
                          ? Icons.check_circle_rounded
                          : isFrequency
                              ? Icons.repeat_rounded
                              : Icons.trending_up_rounded,
                      color: completed
                          ? const Color(0xFF6BCB8B)
                          : isFrequency
                              ? const Color(0xFF7B8CDE)
                              : const Color(0xFFE8A87C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.text,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: completed ? const Color(0xFF9CA3AF) : const Color(0xFF2D3142),
                            decoration: completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9CA3AF)),
                    onPressed: () => _editGoal(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC6B6B)),
                    onPressed: () => _deleteGoal(index),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: const Color(0xFFF0F1F3),
                  valueColor: AlwaysStoppedAnimation(
                    completed ? const Color(0xFF6BCB8B) : const Color(0xFF7B8CDE),
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      progressText,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                    ),
                  ),
                  if (item.deadline != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_rounded, size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MM.dd').format(item.deadline!),
                          style: TextStyle(
                            fontSize: 12,
                            color: item.deadline!.isBefore(DateTime.now()) && !completed
                                ? const Color(0xFFDC6B6B)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final total = _bucketList.items.length;
    final done = _bucketList.items.where((e) => e.isCompleted).length;
    final rate = total > 0 ? done / total : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B8CDE), Color(0xFFA8B5E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B8CDE).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: rate,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '전체 달성률',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 4),
              Text(
                '$done / $total 완료',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_bucketList.title} 목표'),
      ),
      body: _bucketList.items.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildSummaryHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _bucketList.items.length,
                    itemBuilder: (context, index) => _buildGoalCard(index),
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

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7B8CDE) : const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B8CDE) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
