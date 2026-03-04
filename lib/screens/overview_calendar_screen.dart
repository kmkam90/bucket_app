import 'package:flutter/material.dart';

class OverviewCalendarScreen extends StatelessWidget {
  final int year;
  const OverviewCalendarScreen({Key? key, required this.year}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('전체 달력')),
      body: Center(
        child: Text('Overview calendar for $year'),
      ),
    );
  }
}
