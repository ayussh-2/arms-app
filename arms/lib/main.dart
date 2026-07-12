import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/graphql/graphql_client.dart';
import 'core/debug/debug_service.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/attendance/attendance_config_screen.dart';
import 'screens/attendance/attendance_feed_screen.dart';
import 'screens/attendance/leave_apply_screen.dart';
import 'screens/attendance/leave_history_screen.dart';
import 'screens/exams/exam_view_screen.dart';
import 'screens/exams/mark_entry_screen.dart';
import 'screens/exams/exam_create_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/demo_screen.dart';
import 'screens/students_screen.dart';

import 'core/auth/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();
  await AuthService.init();
  runApp(const ArmsApp());
}

class ArmsApp extends StatefulWidget {
  const ArmsApp({super.key});

  @override
  State<ArmsApp> createState() => _ArmsAppState();
}

class _ArmsAppState extends State<ArmsApp> {
  late DebugService debugService;
  late ValueNotifier<GraphQLClient> graphQLClient;

  @override
  void initState() {
    super.initState();
    debugService = DebugService();
    graphQLClient = ArmsGraphQLClient.initClient(debugService: debugService);
  }

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: graphQLClient,
      child: MaterialApp(
        title: 'ARMS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AuthService.isLoggedIn ? '/shell' : '/login',
        routes: {
          '/login': (_) => const LoginScreen(),
          '/shell': (_) => const ShellScreen(),
          '/attendance-config': (_) => const AttendanceConfigScreen(),
          '/attendance-feed': (_) => const AttendanceFeedScreen(),
          '/leave-apply': (_) => const LeaveApplyScreen(),
          '/leave-history': (_) => const LeaveHistoryScreen(),
          '/exam-view': (_) => const ExamViewScreen(),
          '/mark-entry': (_) => const MarkEntryScreen(),
          '/exam-create': (_) => const ExamCreateScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/demo': (_) => const ExamReportDemoScreen(),
          '/students': (_) => const StudentsScreen(),
        },
        builder: (context, child) {
          return child!;
        },
      ),
    );
  }
}
