import 'package:flutter/material.dart';


class GoalEditorDialog extends StatelessWidget {
  const GoalEditorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      title: Text('Goal Editor Dialog (minimal)'),
      content: Text('Minimal implementation.'),
    );
  }
}
