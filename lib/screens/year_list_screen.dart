import 'package:flutter/material.dart';
import '../models/year_plan.dart';
import '../storage/repository.dart';
import '../utils/platform.dart';
import 'goal_list_screen.dart';

class YearListScreen extends StatefulWidget {
  const YearListScreen({Key? key}) : super(key: key);

  @override
  State<YearListScreen> createState() => _YearListScreenState();
}

class _YearListScreenState extends State<YearListScreen> {
  List<YearPlan> _years = [];
  final _repo = YearPlanRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final years = await _repo.loadYearPlans();
    setState(() => _years = years);
  }

  void _addYear() async {
    final controller = TextEditingController();
    final year = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('연도 추가'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '예: 2026'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('추가')),
        ],
      ),
    );
    if (year != null && year.isNotEmpty) {
      final yearNum = int.tryParse(RegExp(r'\d{4}').stringMatch(year) ?? '');
      if (yearNum != null) {
        // 중복 연도 체크
        if (_years.any((y) => y.year == yearNum)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$yearNum년은 이미 존재합니다.')),
            );
          }
          return;
        }
        setState(() {
          _years.add(YearPlan.create(yearNum));
        });
        await _repo.saveYearPlans(_years);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('올바른 연도(숫자 4자리)를 입력하세요.')),
          );
        }
      }
    }
  }

  void _deleteYear(int index) async {
    final y = _years[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${y.year}년 삭제'),
        content: Text('${y.year}년의 모든 목표가 삭제됩니다. 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _years.removeAt(index);
      });
      await _repo.saveYearPlans(_years);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobilePlatform();
    return Scaffold(
      appBar: AppBar(
        title: const Text('연도별 목표'),
        actions: [
          if (_years.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: '모든 연도 삭제',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('모든 연도 삭제'),
                    content: const Text('정말 모든 연도를 삭제하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                    ],
                  ),
                );
                if (confirm == true) {
                  setState(() => _years.clear());
                  await _repo.saveYearPlans(_years);
                }
              },
            ),
        ],
      ),
      body: _years.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('아직 등록된 연도가 없어요', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('아래 + 버튼으로 연도를 추가해보세요!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _years.length,
              itemBuilder: (ctx, i) {
                final y = _years[i];
                final goalCount = y.goals.length;
                final tile = ListTile(
                  title: Text('${y.year}년'),
                  subtitle: Text('목표 $goalCount개'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: '삭제',
                        onPressed: () => _deleteYear(i),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoalListScreen(
                          yearPlan: y,
                          onChanged: (updated) {
                            setState(() => _years[i] = updated);
                          },
                        ),
                      ),
                    );
                    // GoalListScreen에서 돌아오면 최신 데이터 로드
                    await _load();
                  },
                );

                if (mobile) {
                  return Dismissible(
                    key: ValueKey(y.year),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('${y.year}년 삭제'),
                          content: Text('${y.year}년의 모든 목표가 삭제됩니다.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
                          ],
                        ),
                      ) ?? false;
                    },
                    onDismissed: (_) async {
                      setState(() {
                        _years.removeAt(i);
                      });
                      await _repo.saveYearPlans(_years);
                    },
                    child: tile,
                  );
                } else {
                  return tile;
                }
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addYear,
        tooltip: '연도 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
