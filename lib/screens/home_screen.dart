import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../storage/goal_storage.dart';
import 'bucket_list_detail_screen.dart';
import '../utils/platform.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BucketList> bucketLists = [];
  bool _deleteMode = false;
  final Set<int> _selectedListIndexes = {};
  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      _selectedListIndexes.clear();
    });
  }

  Future<void> _deleteSelectedLists() async {
    await GoalStorage.deleteBucketListsByIndexes(_selectedListIndexes);
    setState(() {
      _selectedListIndexes.clear();
      _deleteMode = false;
    });
    await _loadBucketLists();
  }

	@override
	void initState() {
		super.initState();
		_loadBucketLists();
	}

	Future<void> _loadBucketLists() async {
		final lists = await GoalStorage.loadBucketLists();
		setState(() {
			bucketLists = lists;
		});
	}

	Future<void> _addBucketList() async {
		final title = await _showBucketListDialog();
		if (title == null || title.trim().isEmpty) return;
		setState(() {
			bucketLists.add(BucketList(title: title.trim(), items: []));
		});
		await GoalStorage.saveBucketLists(bucketLists);
	}

	Future<void> _editBucketList(int index) async {
		final title = await _showBucketListDialog(initialText: bucketLists[index].title);
		if (title == null || title.trim().isEmpty) return;
		setState(() {
			bucketLists[index].title = title.trim();
		});
		await GoalStorage.saveBucketLists(bucketLists);
	}

	Future<void> _deleteBucketList(int index) async {
		setState(() {
			bucketLists.removeAt(index);
		});
		await GoalStorage.saveBucketLists(bucketLists);
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
					decoration: const InputDecoration(hintText: '예: 2026년 버킷리스트'),
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
    final mobile = isMobilePlatform();
    return Scaffold(
      appBar: AppBar(
        title: const Text('버킷리스트'),
        centerTitle: true,
        elevation: 2,
        actions: [
          if (bucketLists.isNotEmpty && !_deleteMode)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '버킷리스트 선택 삭제',
              onPressed: _toggleDeleteMode,
            ),
          if (_deleteMode)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: '선택 삭제',
              onPressed: _selectedListIndexes.isNotEmpty ? _deleteSelectedLists : null,
            ),
          if (_deleteMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '취소',
              onPressed: _toggleDeleteMode,
            ),
        ],
      ),
      body: bucketLists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('아직 버킷리스트가 없어요', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('아래 + 버튼으로 버킷리스트를 추가해보세요!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: bucketLists.length,
              itemBuilder: (context, index) {
                final list = bucketLists[index];
                if (_deleteMode) {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListTile(
                      leading: Checkbox(
                        value: _selectedListIndexes.contains(index),
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
                      title: Text(list.title),
                    ),
                  );
                } else if (mobile) {
                  return Dismissible(
                    key: ValueKey(list.title),
                    background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: const Icon(Icons.delete, color: Colors.white)),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) async {
                      setState(() {
                        bucketLists.removeAt(index);
                      });
                      await GoalStorage.saveBucketLists(bucketLists);
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: ListTile(
                        title: Text(list.title),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: '이름 수정',
                              onPressed: () => _editBucketList(index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: '삭제',
                              onPressed: () => _deleteBucketList(index),
                            ),
                          ],
                        ),
                        onTap: () async {
                          // 상세 화면(세부 항목 관리)로 이동
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => BucketListDetailScreen(
                                listIndex: index,
                                bucketList: list,
                              ),
                            ),
                          );
                          _loadBucketLists(); // 돌아왔을 때 목록 갱신
                        },
                      ),
                    ),
                  );
                } else {
                  // PC/Desktop: 일반 ListTile, 선택삭제만 지원
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListTile(
                      title: Text(list.title),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: '이름 수정',
                            onPressed: () => _editBucketList(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: '삭제',
                            onPressed: () => _deleteBucketList(index),
                          ),
                        ],
                      ),
                      onTap: () async {
                        // 상세 화면(세부 항목 관리)로 이동
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BucketListDetailScreen(
                              listIndex: index,
                              bucketList: list,
                            ),
                          ),
                        );
                        _loadBucketLists(); // 돌아왔을 때 목록 갱신
                      },
                    ),
                  );
                }
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



