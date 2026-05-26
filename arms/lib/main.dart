import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/graphql/graphql_client.dart';
import 'core/debug/debug_service.dart';
import 'screens/login_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/attendance/attendance_config_screen.dart';
import 'screens/attendance/attendance_feed_screen.dart';
import 'widgets/debug_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();
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
        initialRoute: '/login',
        routes: {
          '/login': (_) => const LoginScreen(),
          '/shell': (_) => const ShellScreen(),
          '/attendance-config': (_) => const AttendanceConfigScreen(),
          '/attendance-feed': (_) => const AttendanceFeedScreen(),
        },
        builder: (context, child) {
          return DebugOverlay(
            debugService: debugService,
            child: child!,
          );
        },
      ),
    );
  }
}

