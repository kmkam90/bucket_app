import 'package:flutter/material.dart';
import '../models/year_plan.dart';
import '../storage/year_plan_repository.dart';
import 'goal_list_screen.dart';

class YearListScreen extends StatefulWidget {
  const YearListScreen({super.key});

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
        setState(() {
          _years.add(YearPlan(id: '', year: yearNum, goals: []));
        });
        await _repo.saveYearPlans(_years);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('올바른 연도(숫자 4자리)를 입력하세요.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('버킷리스트'),
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
      body: ListView.builder(
        itemCount: _years.length,
        itemBuilder: (ctx, i) {
          final y = _years[i];
          return Dismissible(
            key: ValueKey(y.year),
            background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: const Icon(Icons.delete, color: Colors.white)),
            direction: DismissDirection.endToStart,
            onDismissed: (_) async {
              setState(() {
                _years.removeAt(i);
              });
              await _repo.saveYearPlans(_years);
            },
            child: ListTile(
              title: Text('${y.year}년'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GoalListScreen(yearPlan: y, onChanged: (updated) async {
                    setState(() => _years[i] = updated);
                    await _repo.saveYearPlans(_years);
                  }),
                ),
              ),
            ),
          );
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
