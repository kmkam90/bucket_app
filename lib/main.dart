import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/year_list_screen.dart';
import 'screens/overview_calendar_screen.dart';
import 'screens/report_screen.dart';

void main() {
  runApp(const BucketApp());
}

class BucketApp extends StatelessWidget {
  const BucketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '버킷리스트',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const MainTabScreen(),
    );
  }
}

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardScreen(),
      const YearListScreen(),
      OverviewCalendarScreen(year: DateTime.now().year),
      const ReportScreen(),
    ];
    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.flag), label: '목표'),
          NavigationDestination(icon: Icon(Icons.grid_view), label: '전체'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '리포트'),
        ],
      ),
    );
  }
}


