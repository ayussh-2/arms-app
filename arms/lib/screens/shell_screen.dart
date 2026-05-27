import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/arms_bottom_nav_bar.dart';
import 'dashboard_screen.dart';
import 'attendance/attendance_config_screen.dart';
import 'exams/exam_list_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => ShellScreenState();
}

class ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (_currentIndex > 0) {
          switchTab(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardScreen(
              onNavigateToAttendance: () => switchTab(1),
              onNavigateToExams: () => switchTab(2),
            ),
            const AttendanceConfigScreen(),
            const ExamListScreen(),
          ],
        ),
        bottomNavigationBar: ArmsBottomNavBar(
          currentIndex: _currentIndex,
          onTap: switchTab,
        ),
      ),
    );
  }
}
