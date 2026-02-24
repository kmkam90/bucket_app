import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../models/enums.dart';

class FilterBar extends StatelessWidget {
  final int year;
  final List<Goal> goals;
  final Goal? selectedGoal;
  final GoalCategory? selectedCategory;
  final ValueChanged<Goal?> onGoalChanged;
  final ValueChanged<GoalCategory?> onCategoryChanged;

  const FilterBar({
    super.key,
    required this.year,
    required this.goals,
    required this.selectedGoal,
    required this.selectedCategory,
    required this.onGoalChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final categories = GoalCategory.values;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          DropdownButton<Goal?>(
            value: selectedGoal,
            hint: const Text('전체 목표'),
            items: [null, ...goals].map((g) => DropdownMenuItem(
              value: g,
              child: Text(g == null ? '전체 목표' : g.title),
            )).toList(),
            onChanged: onGoalChanged,
          ),
          const SizedBox(width: 16),
          DropdownButton<GoalCategory?>(
            value: selectedCategory,
            hint: const Text('카테고리'),
            items: [null, ...categories].map((c) => DropdownMenuItem(
              value: c,
              child: Text(c == null ? '전체' : c.name),
            )).toList(),
            onChanged: onCategoryChanged,
          ),
        ],
      ),
    );
  }
}
