import 'package:flutter/material.dart';
import '../widgets/arms_bottom_nav_bar.dart';
import 'dashboard_screen.dart';
import 'attendance/attendance_config_screen.dart';

/// Shell screen with bottom navigation.
/// Wraps Home, Attendance, and Exams tabs using IndexedStack for state retention.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(
            onNavigateToAttendance: () => _switchTab(1),
            onNavigateToExams: () => _switchTab(2),
          ),
          const AttendanceConfigScreen(),
          _examsPlaceholder(),
        ],
      ),
      bottomNavigationBar: ArmsBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }

  Widget _examsPlaceholder() {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Exams — Coming Soon'),
          ],
        ),
      ),
    );
  }
}
