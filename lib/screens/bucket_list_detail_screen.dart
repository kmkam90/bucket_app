import 'package:flutter/material.dart';
import '../models/goal.dart';

import '../storage/goal_storage.dart';
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
    final text = await _showItemDialog();
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _bucketList.items.add(BucketItem(text: text.trim()));
    });
    await _save();
  }

  Future<void> _editItem(int index) async {
    final text = await _showItemDialog(initialText: _bucketList.items[index].text);
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _bucketList.items[index].text = text.trim();
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
    setState(() {
      _bucketList.items[index].isDone = !_bucketList.items[index].isDone;
    });
    await _save();
  }

  Future<void> _save() async {
    final lists = await GoalStorage.loadBucketLists();
    if (widget.listIndex >= 0 && widget.listIndex < lists.length) {
      lists[widget.listIndex] = _bucketList;
      await GoalStorage.saveBucketLists(lists);
    }
  }

  Future<String?> _showItemDialog({String? initialText}) async {
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialText == null ? '세부 목표 추가' : '세부 목표 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 마라톤 완주하기'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _bucketList.items.length;
    final done = _bucketList.items.where((e) => e.isDone).length;
    final rate = total > 0 ? (done / total * 100) : 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_bucketList.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
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
          ? Center(
              child: Text('세부 목표를 추가해보세요!', style: Theme.of(context).textTheme.bodyLarge),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('달성률: ${rate.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(width: 16),
                      Text('($done / $total)', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: total,
                    itemBuilder: (context, index) {
                      final item = _bucketList.items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: ListTile(
                          leading: Checkbox(
                            value: item.isDone,
                            onChanged: (_) => _toggleDone(index),
                          ),
                          title: Text(item.text),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: '수정',
                                onPressed: () => _editItem(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: '삭제',
                                onPressed: () => _deleteItem(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
