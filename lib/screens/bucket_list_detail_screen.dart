import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/enums.dart';
import '../models/goal.dart';
import '../state/app_state.dart';
import 'bucket_list_calendar_screen.dart';

class BucketListDetailScreen extends StatefulWidget {
  final int listIndex;
  final BucketList bucketList;

  const BucketListDetailScreen({
    super.key,
    required this.listIndex,
    required this.bucketList,
  });

  @override
  State<BucketListDetailScreen> createState() => _BucketListDetailScreenState();
}

class _BucketListDetailScreenState extends State<BucketListDetailScreen> {
  late BucketList _bucketList;

  @override
  void initState() {
    super.initState();
    _bucketList = BucketList(
      title: widget.bucketList.title,
      items: List.from(widget.bucketList.items),
    );
  }

  Future<void> _addItem() async {
    final result = await _showItemDialog();
    if (!mounted || result == null) return;
    setState(() {
      _bucketList.items.add(result);
    });
    await _save();
  }

  Future<void> _editItem(int index) async {
    final result = await _showItemDialog(existingItem: _bucketList.items[index]);
    if (!mounted || result == null) return;
    setState(() {
      _bucketList.items[index] = result;
    });
    await _save();
  }

  Future<void> _deleteItem(int index) async {
    setState(() {
      _bucketList.items.removeAt(index);
    });
    await _save();
  }

  Future<void> _toggleDone(int index) async {
    final item = _bucketList.items[index];
    if (item.goalType != BucketItemType.check) return;
    setState(() {
      item.isDone = !item.isDone;
      item.completedAt = item.isDone ? DateTime.now() : null;
    });
    await _save();
  }

  Future<void> _updateProgress(int index, int delta) async {
    final item = _bucketList.items[index];
    if (item.goalType == BucketItemType.check) return;
    setState(() {
      item.currentValue = (item.currentValue + delta).clamp(0, item.targetValue);
      if (item.isCompleted && item.completedAt == null) {
        item.completedAt = DateTime.now();
      } else if (!item.isCompleted) {
        item.completedAt = null;
      }
    });
    await _save();
  }

  Future<void> _save() async {
    if (!mounted) return;
    await context.read<AppState>().updateBucketList(widget.listIndex, _bucketList);
  }

  Future<BucketItem?> _showItemDialog({BucketItem? existingItem}) async {
    final isEdit = existingItem != null;
    final textController = TextEditingController(text: existingItem?.text);
    final targetController = TextEditingController(
      text: existingItem != null && existingItem.targetValue > 0
          ? existingItem.targetValue.toString()
          : '',
    );
    var selectedType = existingItem?.goalType ?? BucketItemType.check;
    DateTime? selectedDeadline = existingItem?.deadline;

    return showDialog<BucketItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final showTarget = selectedType != BucketItemType.check;
          return AlertDialog(
            title: Text(isEdit ? '세부 목표 수정' : '세부 목표 추가'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '예: 마라톤 완주하기',
                      labelText: '목표',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '목표 유형',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: BucketItemType.values.map((type) {
                      final isSelected = selectedType == type;
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              bucketItemTypeIcon(type),
                              size: 16,
                              color: isSelected ? Colors.white : const Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 4),
                            Text(bucketItemTypeLabel(type)),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF7B8CDE),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF2D3142),
                          fontSize: 13,
                        ),
                        onSelected: (_) {
                          setDialogState(() => selectedType = type);
                        },
                      );
                    }).toList(),
                  ),
                  if (showTarget) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '목표치',
                        suffixText: bucketItemTypeUnit(selectedType),
                        hintText: '예: 10',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
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
                        firstDate: DateTime.now(),
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
                  final text = textController.text.trim();
                  if (text.isEmpty) return;
                  final targetVal = int.tryParse(targetController.text) ?? 0;
                  final item = BucketItem(
                    text: text,
                    isDone: existingItem?.isDone ?? false,
                    completedAt: existingItem?.completedAt,
                    deadline: selectedDeadline,
                    goalType: selectedType,
                    targetValue: selectedType == BucketItemType.check ? 0 : targetVal,
                    currentValue: existingItem?.currentValue ?? 0,
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

  Widget _buildProgressHeader() {
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
                '달성률',
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

  Widget _buildItemCard(int index) {
    final item = _bucketList.items[index];
    final isCheck = item.goalType == BucketItemType.check;
    final completed = item.isCompleted;

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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isCheck)
                  GestureDetector(
                    onTap: () => _toggleDone(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completed ? const Color(0xFF6BCB8B) : Colors.transparent,
                        border: Border.all(
                          color: completed ? const Color(0xFF6BCB8B) : const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                      ),
                      child: completed ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  )
                else
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed
                          ? const Color(0xFF6BCB8B).withValues(alpha: 0.15)
                          : const Color(0xFF7B8CDE).withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      bucketItemTypeIcon(item.goalType),
                      size: 16,
                      color: completed ? const Color(0xFF6BCB8B) : const Color(0xFF7B8CDE),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: completed ? const Color(0xFF9CA3AF) : const Color(0xFF2D3142),
                          decoration: completed ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFF9CA3AF),
                        ),
                      ),
                      if (item.deadline != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.event_rounded, size: 12, color: Color(0xFF9CA3AF)),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('yyyy.MM.dd').format(item.deadline!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: item.deadline!.isBefore(DateTime.now()) && !completed
                                      ? const Color(0xFFDC6B6B)
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFD1D5DB)),
                  tooltip: '수정',
                  onPressed: () => _editItem(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC6B6B)),
                  tooltip: '삭제',
                  onPressed: () => _deleteItem(index),
                ),
              ],
            ),
            if (!isCheck) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item.progressRate,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF0F1F3),
                            valueColor: AlwaysStoppedAnimation(
                              completed ? const Color(0xFF6BCB8B) : const Color(0xFF7B8CDE),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.currentValue} / ${item.targetValue} ${bucketItemTypeUnit(item.goalType)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildProgressButton(
                    icon: Icons.remove,
                    onTap: item.currentValue > 0 ? () => _updateProgress(index, -1) : null,
                  ),
                  const SizedBox(width: 4),
                  _buildProgressButton(
                    icon: Icons.add,
                    onTap: !completed ? () => _updateProgress(index, 1) : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressButton({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF7B8CDE).withValues(alpha: 0.1) : const Color(0xFFF0F1F3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF7B8CDE) : const Color(0xFFD1D5DB),
        ),
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
              child: const Icon(Icons.playlist_add_rounded, size: 36, color: Color(0xFFA8B5E2)),
            ),
            const SizedBox(height: 24),
            const Text(
              '세부 목표를 추가해보세요!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 8),
            const Text(
              '+ 버튼으로 달성하고 싶은 목표를 추가하세요',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _bucketList.items.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_bucketList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF7B8CDE)),
            tooltip: '달성률 캘린더',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => BucketListCalendarScreen(bucketList: _bucketList),
                ),
              );
            },
          ),
        ],
      ),
      body: total == 0
          ? _buildEmptyState()
          : Column(
              children: [
                _buildProgressHeader(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: total,
                    itemBuilder: (context, index) => _buildItemCard(index),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        tooltip: '세부 목표 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
