import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/plans_page.dart';
import 'pages/focus_page.dart';
import 'pages/records_page.dart';
import 'pages/rest_page.dart';
import 'pages/apps_page.dart';
import 'pages/adopt_page.dart';
import 'pages/demo_page.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

void main() => runApp(const ProviderScope(child: FocusNestApp()));
final router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(path: '/plans', builder: (context, state) => const PlansPage()),
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
