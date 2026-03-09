import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final text = await _showItemDialog();
    if (!mounted || text == null || text.trim().isEmpty) return;
    setState(() {
      _bucketList.items.add(BucketItem(text: text.trim()));
    });
    await _save();
  }

  Future<void> _editItem(int index) async {
    final text = await _showItemDialog(initialText: _bucketList.items[index].text);
    if (!mounted || text == null || text.trim().isEmpty) return;
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
    if (!mounted) return;
    await context.read<AppState>().updateBucketList(widget.listIndex, _bucketList);
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

  Widget _buildProgressHeader() {
    final total = _bucketList.items.length;
    final done = _bucketList.items.where((e) => e.isDone).length;
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
              onTap: () => _toggleDone(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isDone ? const Color(0xFF6BCB8B) : Colors.transparent,
                  border: Border.all(
                    color: item.isDone ? const Color(0xFF6BCB8B) : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                ),
                child: item.isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: item.isDone ? const Color(0xFF9CA3AF) : const Color(0xFF2D3142),
                  decoration: item.isDone ? TextDecoration.lineThrough : null,
                  decorationColor: const Color(0xFF9CA3AF),
                ),
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
