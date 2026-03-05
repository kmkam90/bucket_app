import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/year_plan.dart';
import '../state/app_state.dart';
import '../utils/platform.dart';
import 'goal_list_screen.dart';

class YearListScreen extends StatefulWidget {
  const YearListScreen({super.key});

  @override
  State<YearListScreen> createState() => _YearListScreenState();
}

class _YearListScreenState extends State<YearListScreen> {
  Future<void> _addYear() async {
    final state = context.read<AppState>();
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
    if (!mounted) return;
    if (year != null && year.isNotEmpty) {
      final yearNum = int.tryParse(RegExp(r'\d{4}').stringMatch(year) ?? '');
      if (yearNum != null) {
        if (state.yearPlans.any((y) => y.year == yearNum)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$yearNum년은 이미 존재합니다.')),
          );
          return;
        }
        await state.addYearPlan(YearPlan.create(yearNum));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('올바른 연도(숫자 4자리)를 입력하세요.')),
        );
      }
    }
  }

  Future<void> _deleteYear(String id) async {
    final state = context.read<AppState>();
    final plan = state.yearPlans.firstWhere((y) => y.id == id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${plan.year}년 삭제'),
        content: Text('${plan.year}년의 모든 목표가 삭제됩니다. 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Color(0xFFDC6B6B))),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirm == true) {
      await state.deleteYearPlan(id);
    }
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
              '아직 등록된 연도가 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 8),
            const Text(
              '아래 + 버튼으로 연도를 추가해보세요!',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearCard(YearPlan y) {
    final goalCount = y.goals.length;
    final activeGoals = y.goals.where((g) => g.logs.isNotEmpty).length;
    final progress = goalCount > 0 ? activeGoals / goalCount : 0.0;

    final card = Container(
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GoalListScreen(yearPlan: y),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(
                '${y.year}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D3142),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '목표 $goalCount개',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
                    ),
                    if (activeGoals > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$activeGoals개 진행 중',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6BCB8B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              if (goalCount > 0) ...[
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFFF0F1F3),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF7B8CDE)),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFD1D5DB)),
                tooltip: '삭제',
                onPressed: () => _deleteYear(y.id),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
            ],
          ),
        ),
      ),
    );

    if (isMobilePlatform()) {
      return Dismissible(
        key: ValueKey(y.id),
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
          await context.read<AppState>().deleteYearPlan(y.id);
        },
        child: card,
      );
    }

    return card;
  }

  @override
  Widget build(BuildContext context) {
    final years = context.watch<AppState>().yearPlans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('연도별 목표'),
        actions: [
          if (years.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFF9CA3AF)),
              tooltip: '모든 연도 삭제',
              onPressed: () async {
                final s = context.read<AppState>();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('모든 연도 삭제'),
                    content: const Text('정말 모든 연도를 삭제하시겠습니까?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('삭제', style: TextStyle(color: Color(0xFFDC6B6B))),
                      ),
                    ],
                  ),
                );
                if (!mounted) return;
                if (confirm == true) {
                  final ids = s.yearPlans.map((y) => y.id).toList();
                  for (final id in ids) {
                    await s.deleteYearPlan(id);
                  }
                }
              },
            ),
        ],
      ),
      body: years.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: years.length,
              itemBuilder: (ctx, i) => _buildYearCard(years[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addYear,
        tooltip: '연도 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
