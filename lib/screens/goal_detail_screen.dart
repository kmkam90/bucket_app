
import 'package:flutter/material.dart';
import '../models/goal.dart';

class GoalDetailScreen extends StatelessWidget {
  final Goal goal;
  const GoalDetailScreen({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(goal.title)),
      body: Center(
        child: Text('Goal detail for "${goal.title}"'),
      ),
    );
  }
}
