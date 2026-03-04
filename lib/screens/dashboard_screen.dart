import 'package:flutter/material.dart';
import '../models/year_plan.dart';
import '../models/goal.dart';
import '../models/enums.dart';
import '../storage/repository.dart';
import '../utils/statistics.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ...existing code...
  List<Goal> _goals = [];
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = YearPlanRepository();
    final years = await repo.loadYearPlans();
    final yearPlan = years.firstWhere(
      (y) => y.year == _year,
      orElse: () => YearPlan(id: '', year: _year, goals: []),
    );
    setState(() {
      _goals = yearPlan.goals;
    });
  }

  Future<void> _toggleTodayHabit(Goal goal) async {
    DashboardStatistics.toggleHabitOnDate(goal, DateTime.now());
    await _saveGoal(goal);
    setState(() {});
  }

  Future<void> _saveGoal(Goal goal) async {
    final repo = YearPlanRepository();
    final years = await repo.loadYearPlans();
    final idx = years.indexWhere((y) => y.year == _year);
    if (idx >= 0) {
      final goalIdx = years[idx].goals.indexWhere((g) => g.id == goal.id);
      if (goalIdx >= 0) {
        years[idx].goals[goalIdx] = goal;


      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Dashboard Screen (minimal)')),
    );
  }
}
