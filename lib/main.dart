import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'core/controller.dart';
import 'core/journal.dart';
import 'data/android_adapters.dart';
import 'data/demo_adapters.dart';
import 'data/web_planner_gateway_stub.dart'
    if (dart.library.js_interop) 'data/web_planner_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/plans_page.dart';
import 'pages/goals_page.dart';
import 'pages/focus_page.dart';
import 'pages/records_page.dart';
import 'pages/rest_page.dart';
import 'pages/apps_page.dart';
import 'pages/adopt_page.dart';
import 'pages/demo_page.dart';
import 'pages/settings_page.dart';
import 'pages/agent_page.dart';
import 'pages/me_page.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      final clock = RealClock();
      final initial = MemoryRepository(clock).load();
      final repository = await AndroidRepository.open(
        initial.copyWith(plans: const [], records: const []),
      );
      runApp(
        ProviderScope(
          overrides: [
            clockProvider.overrideWithValue(clock),
            repositoryProvider.overrideWithValue(repository),
            deviceProvider.overrideWithValue(AndroidDevice()),
          ],
          child: const FocusNestApp(),
        ),
      );
    } catch (_) {
      runApp(
        MaterialApp(
          theme: nestTheme(),
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('本地数据未能读取，已有数据已保留。'),
                  TextButton(onPressed: main, child: const Text('重新读取')),
                ],
              ),
            ),
          ),
        ),
      );
    }
  } else {
    final clock = DemoClock();
    final repo = MemoryRepository(clock);
    var demoAgent = true;
    if (kIsWeb) {
      try {
        demoAgent =
            (await createWebPlannerGateway().settings())['configured'] != true;
      } catch (_) {
        /* Static hosting can still demonstrate the UI. */
      }
    }
    repo.save(repo.load().copyWith(workspace: Workspace(demoAgent: demoAgent)));
    runApp(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(clock),
          repositoryProvider.overrideWithValue(repo),
        ],
        child: const FocusNestApp(),
      ),
    );
  }
}

final router = GoRouter(
  initialLocation: '/plans',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(path: '/agent', builder: (context, state) => const AgentPage()),
        GoRoute(path: '/me', builder: (context, state) => const MePage()),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/plans',
          builder: (context, state) => PlansPage(
            day: state.uri.queryParameters['day'],
            all: state.uri.queryParameters['all'] == 'true',
          ),
        ),
        GoRoute(path: '/goals', builder: (context, state) => const GoalsPage()),
        GoRoute(
          path: '/goals/:id',
          builder: (context, state) =>
              GoalDetailsPage(goalId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/focus',
          builder: (context, state) =>
              FocusPage(planId: state.uri.queryParameters['plan']),
        ),
        GoRoute(
          path: '/records',
          builder: (context, state) => const RecordsPage(),
        ),
        GoRoute(path: '/rest', builder: (context, state) => const RestPage()),
        GoRoute(path: '/apps', builder: (context, state) => const AppsPage()),
        GoRoute(path: '/adopt', builder: (context, state) => const AdoptPage()),
        GoRoute(path: '/demo', builder: (context, state) => const DemoPage()),
      ],
    ),
  ],
);

class FocusNestApp extends StatelessWidget {
  const FocusNestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: '伴学小屋 · Focus Nest',
    debugShowCheckedModeBanner: false,
    theme: nestTheme(),
    routerConfig: router,
  );
}
