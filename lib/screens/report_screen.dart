import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/enums.dart';
import '../models/goal.dart';
import '../models/year_plan.dart';
import '../storage/year_plan_repository.dart';

class ReportScreen extends StatefulWidget {
	const ReportScreen({super.key});

	@override
	State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
	final _repo = YearPlanRepository();
	static const _selectedYearKey = 'report_selected_year';
	final _currentYear = DateTime.now().year;
	YearPlan? _plan;
	List<YearPlan> _plans = [];
	int? _selectedYear;
	bool _loading = true;

	@override
	void initState() {
		super.initState();
		_load();
	}

	Future<void> _load() async {
		final prefs = await SharedPreferences.getInstance();
		final savedYear = prefs.getInt(_selectedYearKey);
		final plans = await _repo.loadYearPlans();
		final years = plans.map((p) => p.year).toSet().toList()..sort((a, b) => b.compareTo(a));
		final selectedYear = _selectedYear ??
				((savedYear != null && years.contains(savedYear))
					? savedYear
					: (years.contains(_currentYear) ? _currentYear : (years.isNotEmpty ? years.first : _currentYear)));
		final plan = plans.where((p) => p.year == selectedYear).cast<YearPlan?>().firstWhere(
					(p) => p != null,
					orElse: () => null,
				);
		if (!mounted) return;
		setState(() {
			_plans = plans;
			_selectedYear = selectedYear;
			_plan = plan;
			_loading = false;
		});
	}

	Future<void> _saveSelectedYear(int year) async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setInt(_selectedYearKey, year);
	}

	Map<int, int> _monthlyActivity(List<Goal> goals, int year) {
		final map = <int, int>{for (int i = 1; i <= 12; i++) i: 0};
		for (final goal in goals) {
			for (final log in goal.logs) {
				if (log.date.year == year && (log.value > 0)) {
					map[log.date.month] = (map[log.date.month] ?? 0) + 1;
				}
			}
		}
		return map;
	}

	int _goalScore(Goal goal, int year) {
		return goal.logs.where((l) => l.date.year == year && l.value > 0).length;
	}

	int _targetValue(Goal goal) {
		if (goal.metricType == GoalMetricType.habit) {
			return (goal.target.timesPerWeek ?? 1) * 52;
		}
		return (goal.target.targetTotalValue ?? 0).round();
	}

	double _goalProgress(Goal goal, int year) {
		final target = _targetValue(goal);
		if (target <= 0) return 0;
		final achieved = goal.logs
				.where((l) => l.date.year == year)
				.fold<int>(0, (sum, l) => sum + (l.value > 0 ? l.value : 0));
		return (achieved / target).clamp(0, 1).toDouble();
	}

	String _typeLabel(GoalMetricType type) {
		switch (type) {
			case GoalMetricType.habit:
				return '습관';
			case GoalMetricType.count:
				return '카운트';
			case GoalMetricType.duration:
				return '시간';
		}
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) {
			return const Scaffold(body: Center(child: CircularProgressIndicator()));
		}

		final availableYears = _plans.map((e) => e.year).toSet().toList()..sort((a, b) => b.compareTo(a));
		final selectedYear = _selectedYear ?? (availableYears.isNotEmpty ? availableYears.first : _currentYear);
		final selectedPlan = _plans.where((p) => p.year == selectedYear).cast<YearPlan?>().firstWhere(
					(p) => p != null,
					orElse: () => null,
				) ?? _plan;

		final goals = selectedPlan?.goals ?? const [];
		final completed = goals.where((g) => _goalProgress(g, selectedYear) >= 1).length;
		final inProgress = goals.where((g) => _goalProgress(g, selectedYear) > 0 && _goalProgress(g, selectedYear) < 1).length;
		final completionRate = goals.isEmpty ? 0.0 : (completed / goals.length);
		final monthly = _monthlyActivity(goals, selectedYear);
		final maxMonthly = monthly.values.fold<int>(0, (a, b) => a > b ? a : b);
		final activeGoals = List<Goal>.from(goals)
			..sort((a, b) => _goalScore(b, selectedYear).compareTo(_goalScore(a, selectedYear)));
		final topGoals = activeGoals.where((g) => _goalScore(g, selectedYear) > 0).take(5).toList();
		final typeCount = <GoalMetricType, int>{
			GoalMetricType.habit: goals.where((g) => g.metricType == GoalMetricType.habit).length,
			GoalMetricType.count: goals.where((g) => g.metricType == GoalMetricType.count).length,
			GoalMetricType.duration: goals.where((g) => g.metricType == GoalMetricType.duration).length,
		};

		return Scaffold(
			appBar: AppBar(title: const Text('리포트')),
			body: RefreshIndicator(
				onRefresh: _load,
				child: ListView(
					padding: const EdgeInsets.all(16),
					children: [
						Text('$selectedYear년 요약', style: Theme.of(context).textTheme.titleLarge),
						const SizedBox(height: 8),
						if (availableYears.isNotEmpty)
							DropdownButtonFormField<int>(
								initialValue: selectedYear,
								decoration: const InputDecoration(
									labelText: '연도 선택',
									border: OutlineInputBorder(),
								),
								items: availableYears
									.map((year) => DropdownMenuItem<int>(
											value: year,
											child: Text('$year년'),
										))
									.toList(),
								onChanged: (value) {
									if (value == null) return;
									setState(() {
										_selectedYear = value;
										_plan = _plans.where((p) => p.year == value).cast<YearPlan?>().firstWhere(
												(p) => p != null,
												orElse: () => null,
											);
									});
									_saveSelectedYear(value);
								},
							),
						const SizedBox(height: 12),
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text('완료율 ${(completionRate * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleMedium),
										const SizedBox(height: 8),
										LinearProgressIndicator(value: completionRate),
										const SizedBox(height: 12),
										Row(
											children: [
												Expanded(child: Text('전체 목표 ${goals.length}개')),
												Expanded(child: Text('완료 $completed개')),
												Expanded(child: Text('진행중 $inProgress개')),
											],
										),
									],
								),
							),
						),
						const SizedBox(height: 12),
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text('목표 유형 분포', style: Theme.of(context).textTheme.titleMedium),
										const SizedBox(height: 8),
										for (final entry in typeCount.entries)
											Padding(
												padding: const EdgeInsets.symmetric(vertical: 2),
												child: Text('${_typeLabel(entry.key)}: ${entry.value}개'),
											),
									],
								),
							),
						),
						const SizedBox(height: 12),
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text('월별 활동', style: Theme.of(context).textTheme.titleMedium),
										const SizedBox(height: 10),
										Row(
											crossAxisAlignment: CrossAxisAlignment.end,
											children: [
												for (int month = 1; month <= 12; month++)
													Expanded(
														child: Padding(
															padding: const EdgeInsets.symmetric(horizontal: 2),
															child: Column(
																mainAxisSize: MainAxisSize.min,
																children: [
																	Container(
																		height: maxMonthly == 0 ? 4 : (64 * (monthly[month]! / maxMonthly)).clamp(4, 64).toDouble(),
																		decoration: BoxDecoration(
																			color: Theme.of(context).colorScheme.primary,
																			borderRadius: BorderRadius.circular(4),
																		),
																	),
																	const SizedBox(height: 4),
																	Text('$month', style: Theme.of(context).textTheme.labelSmall),
																],
															),
														),
													),
											],
										),
									],
								),
							),
						),
						const SizedBox(height: 12),
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text('가장 활동이 많은 목표', style: Theme.of(context).textTheme.titleMedium),
										const SizedBox(height: 8),
										if (topGoals.isEmpty)
											const Text('기록된 활동이 아직 없습니다.')
										else
											for (final goal in topGoals)
												ListTile(
													contentPadding: EdgeInsets.zero,
													title: Text(goal.title),
													subtitle: Text('${_typeLabel(goal.metricType)} · 진행률 ${(_goalProgress(goal, selectedYear) * 100).toStringAsFixed(1)}%'),
													trailing: Text('${_goalScore(goal, selectedYear)}회'),
												),
									],
								),
							),
						),
						if (goals.isEmpty)
							const Padding(
								padding: EdgeInsets.only(top: 12),
								child: Text('아직 리포트할 목표가 없습니다.'),
							),
					],
				),
			),
		);
	}
}

