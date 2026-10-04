import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/landing_page.dart';
import 'pages/admin_dashboard.dart';
import 'pages/company_dashboard.dart';
import 'pages/candidate_dashboard.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(const WorkNetApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LandingPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const RegisterPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/admin',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AdminDashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/company',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CompanyDashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/candidate',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CandidateDashboard(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    ),
    GoRoute(
      path: '/settings/:role',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: SettingsPage(role: state.pathParameters['role'] ?? 'candidate'),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ),
    ),
  ],
);

class WorkNetApp extends StatelessWidget {
  const WorkNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WorkNet',
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F62FE), // primary-blue
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: Colors.white,
      ),
    );
  }
}
