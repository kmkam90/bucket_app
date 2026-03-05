import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/goal.dart';
import '../utils/date_utils.dart' as app_dates;

class BucketListCalendarScreen extends StatefulWidget {
  final BucketList bucketList;
  const BucketListCalendarScreen({super.key, required this.bucketList});

  @override
  State<BucketListCalendarScreen> createState() => _BucketListCalendarScreenState();
}

class _BucketListCalendarScreenState extends State<BucketListCalendarScreen> {
  late final Map<int, List<BucketItem>> _doneMap;
  late final List<Color> _goalColors;

  @override
  void initState() {
    super.initState();
    _goalColors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    _doneMap = {};
    final today = app_dates.dateOnly(DateTime.now());
    final todayKey = app_dates.dateKey(today);
    for (int i = 0; i < widget.bucketList.items.length; i++) {
      final item = widget.bucketList.items[i];
      if (item.isDone) {
        _doneMap.putIfAbsent(todayKey, () => []).add(item);
      }
    }
  }

  List<Widget> _buildEventMarkers(DateTime day) {
    final items = _doneMap[app_dates.dateKey(day)] ?? [];
    return List.generate(items.length, (i) {
      final color = _goalColors[i % _goalColors.length];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.0),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.bucketList.items.length;
    final done = widget.bucketList.items.where((e) => e.isDone).length;
    final rate = total > 0 ? (done / total * 100) : 0;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bucketList.title} 달성률 캘린더'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('전체 달성률: ${rate.toStringAsFixed(1)}% ($done / $total)',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Expanded(
              child: TableCalendar(
                firstDay: DateTime(DateTime.now().year, 1, 1),
                lastDay: DateTime(DateTime.now().year, 12, 31),
                focusedDay: DateTime.now(),
                calendarFormat: CalendarFormat.month,
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final markers = _buildEventMarkers(day);
                    if (markers.isEmpty) return null;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: markers,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
