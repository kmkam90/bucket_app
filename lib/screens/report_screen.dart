import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/goal.dart';
import '../state/app_state.dart';
import '../core/result.dart';
import '../utils/statistics.dart';
import '../services/file_service.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bucketLists = state.bucketLists;
    final yearPlans = state.yearPlans;
    final allGoals = yearPlans.expand((yp) => yp.goals).toList();

    int totalGoals = 0;
    for (final bl in bucketLists) {
      totalGoals += bl.items.length;
    }
    for (final yp in yearPlans) {
      totalGoals += yp.goals.length;
    }

    if (totalGoals == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('리포트'),
          actions: const [_BackupMenuButton()],
        ),
        body: _buildEmptyState(),
      );
    }

    int completedCount = 0;
    for (final bl in bucketLists) {
      completedCount += bl.items.where((i) => i.isDone).length;
    }
    for (final yp in yearPlans) {
      completedCount += yp.goals.where((g) => g.logs.isNotEmpty).length;
    }

    final completionRate = totalGoals > 0
        ? ((completedCount / totalGoals) * 100).toStringAsFixed(0)
        : '0';

    int activeStreaks = 0;
    for (final g in allGoals) {
      if (DashboardStatistics.getCurrentStreak(g) > 0) activeStreaks++;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('리포트'),
        actions: const [_BackupMenuButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            _buildStatsOverview(totalGoals, completionRate, activeStreaks),
            _buildWeeklyChart(allGoals, bucketLists),
            _buildMonthlyTrendChart(allGoals),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(int totalGoals, String completionRate, int activeStreaks) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3142).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatCard('총 목표', '$totalGoals', Icons.flag_rounded, const Color(0xFF7B8CDE)),
          Container(width: 1, height: 60, color: const Color(0xFFF0F1F3)),
          _buildStatCard('달성률', '$completionRate%', Icons.check_circle_rounded, const Color(0xFF6BCB8B)),
          Container(width: 1, height: 60, color: const Color(0xFFF0F1F3)),
          _buildStatCard('스트릭', '$activeStreaks', Icons.local_fire_department, const Color(0xFFE8A87C)),
        ],
      ),
    );
  }

  List<double> _weeklyData(List<Goal> allGoals, List<BucketList> bucketLists) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final data = List<double>.filled(7, 0);

    for (int d = 0; d < 7; d++) {
      final day = DateTime(monday.year, monday.month, monday.day + d);
      int count = 0;
      for (final goal in allGoals) {
        if (goal.logs.any((l) =>
            l.date.year == day.year &&
            l.date.month == day.month &&
            l.date.day == day.day &&
            l.value >= 1)) {
          count++;
        }
      }
      for (final bl in bucketLists) {
        for (final item in bl.items) {
          if (item.completedAt != null &&
              item.completedAt!.year == day.year &&
              item.completedAt!.month == day.month &&
              item.completedAt!.day == day.day) {
            count++;
          }
        }
      }
      data[d] = count.toDouble();
    }
    return data;
  }

  List<double> _monthlyData(List<Goal> allGoals) {
    final currentYear = DateTime.now().year;
    final data = List<double>.filled(12, 0);
    if (allGoals.isEmpty) return data;

    for (int m = 1; m <= 12; m++) {
      int total = 0;
      int completed = 0;
      for (final goal in allGoals) {
        total++;
        if (goal.logs.any((l) => l.date.year == currentYear && l.date.month == m && l.value >= 1)) {
          completed++;
        }
      }
      if (total > 0) {
        data[m - 1] = (completed / total) * 100;
      }
    }
    return data;
  }

  Widget _buildWeeklyChart(List<Goal> allGoals, List<BucketList> bucketLists) {
    final data = _weeklyData(allGoals, bucketLists);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final days = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3142).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 주 달성 현황',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY > 0 ? maxY + 1 : 5,
                barGroups: List.generate(7, (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i],
                      color: const Color(0xFF7B8CDE),
                      width: 24,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY > 0 ? maxY + 1 : 5,
                        color: const Color(0xFFF0F1F3),
                      ),
                    ),
                  ],
                )),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          days[value.toInt()],
                          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()}개 완료',
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendChart(List<Goal> allGoals) {
    final data = _monthlyData(allGoals);
    final months = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3142).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateTime.now().year}년 월별 추이',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(12, (i) => FlSpot(i.toDouble(), data[i])),
                    color: const Color(0xFF7B8CDE),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: const Color(0xFF7B8CDE),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF7B8CDE).withValues(alpha: 0.08),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 25,
                      getTitlesWidget: _leftTitleWidget,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= 12) return const SizedBox();
                        if (idx % 2 != 0) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            months[idx],
                            style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFF0F1F3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) => LineTooltipItem(
                      '${spot.y.toStringAsFixed(0)}%',
                      const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => const _EmptyReportState();

  static Widget _leftTitleWidget(double value, TitleMeta meta) {
    return Text(
      '${value.toInt()}%',
      style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
    );
  }
}

class _BackupMenuButton extends StatelessWidget {
  const _BackupMenuButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)),
      onSelected: (value) => _onSelected(context, value),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.download_rounded, size: 20, color: Color(0xFF6B7280)),
              SizedBox(width: 12),
              Text('데이터 백업'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.upload_rounded, size: 20, color: Color(0xFF6B7280)),
              SizedBox(width: 12),
              Text('데이터 복원'),
            ],
          ),
        ),
      ],
    );
  }

  void _onSelected(BuildContext context, String value) {
    if (value == 'export') {
      _export(context);
    } else if (value == 'import') {
      _import(context);
    }
  }

  Future<void> _export(BuildContext context) async {
    final state = context.read<AppState>();
    final result = await state.export();

    if (!context.mounted) return;

    switch (result) {
      case Ok(:final data):
        final now = DateTime.now();
        final filename = 'bucket_backup_'
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
            '.json';
        final success = await FileService.downloadJson(data, filename);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '백업 파일이 다운로드되었습니다.' : '다운로드에 실패했습니다.'),
          ),
        );
      case Err(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('백업 실패: $message')),
        );
    }
  }

  Future<void> _import(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('데이터 복원'),
        content: const Text(
          '백업 파일에서 데이터를 복원하면 현재 데이터가 덮어씌워집니다.\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('복원'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final jsonString = await FileService.pickJsonFile();
    if (jsonString == null || !context.mounted) return;

    final state = context.read<AppState>();
    final result = await state.import(jsonString);

    if (!context.mounted) return;

    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데이터가 복원되었습니다.')),
        );
      case Err(:final message):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('복원 실패: $message')),
        );
    }
  }
}

class _EmptyReportState extends StatelessWidget {
  const _EmptyReportState();

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.bar_chart_rounded, size: 36, color: Color(0xFFA8B5E2)),
            ),
            const SizedBox(height: 24),
            const Text(
              '아직 데이터가 없어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
            ),
            const SizedBox(height: 8),
            const Text(
              '목표를 추가하고 기록을 시작해보세요!',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
