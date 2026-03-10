import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/goal.dart';
import '../models/enums.dart';
import '../state/app_state.dart';
import 'bucket_list_detail_screen.dart';
import '../utils/platform.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _deleteMode = false;
  final Set<int> _selectedListIndexes = {};

  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      _selectedListIndexes.clear();
    });
  }

  Future<void> _deleteSelectedLists() async {
    await context.read<AppState>().deleteBucketLists(_selectedListIndexes);
    if (!mounted) return;
    setState(() {
      _selectedListIndexes.clear();
      _deleteMode = false;
    });
  }

  Future<void> _addBucketList() async {
    final state = context.read<AppState>();
    final title = await _showBucketListDialog();
    if (title == null || title.trim().isEmpty) return;
    await state.addBucketList(BucketList(
      title: title.trim(),
      category: null,
      items: [],
    ));
  }

  Future<void> _editBucketList(int index) async {
    final state = context.read<AppState>();
    final bucketLists = state.bucketLists;
    final title = await _showBucketListDialog(
      initialText: bucketLists[index].title,
    );
    if (title == null || title.trim().isEmpty) return;
    final updated = BucketList(
      title: title.trim(),
      category: bucketLists[index].category,
      items: List.from(bucketLists[index].items),
    );
    await state.updateBucketList(index, updated);
  }

  Future<void> _deleteBucketList(int index) async {
    await context.read<AppState>().deleteBucketList(index);
  }

  Future<String?> _showBucketListDialog({String? initialText}) async {
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialText == null ? '버킷리스트 추가' : '버킷리스트 이름 수정'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 여행, 자기개발, 건강'),
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

  Future<void> _navigateToDetail(int index, BucketList list) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BucketListDetailScreen(
          listIndex: index,
          bucketList: list,
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
              child: const Icon(Icons.format_list_bulleted_rounded, size: 36, color: Color(0xFFA8B5E2)),
            ),
            const SizedBox(height: 24),
            const Text(
              '아직 버킷리스트가 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 8),
            const Text(
              '아래 + 버튼으로 버킷리스트를 추가해보세요!',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBucketCard(int index, BucketList list) {
    final total = list.items.length;
    final done = list.items.where((i) => i.isDone).length;
    final progress = total > 0 ? done / total : 0.0;

    final cardContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
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
        onTap: () => _navigateToDetail(index, list),
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
                      color: list.category != null
                          ? goalCategoryColor(list.category!).withValues(alpha: 0.15)
                          : const Color(0xFFE8EAF0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      list.category != null ? goalCategoryIcon(list.category!) : Icons.checklist_rounded,
                      color: list.category != null ? goalCategoryColor(list.category!) : const Color(0xFF7B8CDE),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      list.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF9CA3AF)),
                    tooltip: '이름 수정',
                    onPressed: () => _editBucketList(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC6B6B)),
                    tooltip: '삭제',
                    onPressed: () => _deleteBucketList(index),
                  ),
                ],
              ),
              if (total > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFF0F1F3),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7B8CDE)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '$done / $total 완료',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7B8CDE)),
                    ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '세부 목표를 추가해보세요',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (isMobilePlatform()) {
      return Dismissible(
        key: ValueKey('${list.title}_$index'),
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFDC6B6B),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        direction: DismissDirection.endToStart,
        onDismissed: (_) async {
          await context.read<AppState>().deleteBucketList(index);
        },
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildDeleteModeCard(int index, BucketList list) {
    final isSelected = _selectedListIndexes.contains(index);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                _selectedListIndexes.add(index);
              } else {
                _selectedListIndexes.remove(index);
              }
            });
          },
        ),
        title: Text(
          list.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF2D3142)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bucketLists = context.watch<AppState>().bucketLists;

    return Scaffold(
      appBar: AppBar(
        title: const Text('버킷리스트'),
        actions: [
          if (bucketLists.isNotEmpty && !_deleteMode)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF9CA3AF)),
              tooltip: '버킷리스트 선택 삭제',
              onPressed: _toggleDeleteMode,
            ),
          if (_deleteMode)
            IconButton(
              icon: Icon(
                Icons.delete_forever_rounded,
                color: _selectedListIndexes.isNotEmpty ? const Color(0xFFDC6B6B) : const Color(0xFF9CA3AF),
              ),
              tooltip: '선택 삭제',
              onPressed: _selectedListIndexes.isNotEmpty ? _deleteSelectedLists : null,
            ),
          if (_deleteMode)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
              tooltip: '취소',
              onPressed: _toggleDeleteMode,
            ),
        ],
      ),
      body: bucketLists.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: bucketLists.length,
              itemBuilder: (context, index) {
                final list = bucketLists[index];
                if (_deleteMode) {
                  return _buildDeleteModeCard(index, list);
                }
                return _buildBucketCard(index, list);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBucketList,
        tooltip: '버킷리스트 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
