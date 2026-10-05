import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/admin_dashboard.dart';
import 'pages/candidate_dashboard.dart';
import 'pages/company_dashboard.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs =
      await SharedPreferences.getInstance();

  final rememberMe =
      prefs.getBool(
        'remember_me',
      ) ??
      false;

  final isLoggedIn =
      prefs.getBool(
        'is_logged_in',
      ) ??
      false;

  final role =
      prefs.getString(
        'user_role',
      );

  final token =
      prefs.getString(
        'auth_token',
      );

  String initialLocation = '/';

  // Solo restauramos la sesión si:
  // - Recordarme está activo
  // - Existe sesión
  // - Existe token
  // - Existe un rol válido
  if (
      rememberMe &&
      isLoggedIn &&
      token != null &&
      token.isNotEmpty) {
    initialLocation =
        _routeForRole(
      role,
    );
  }

  final router =
      _createRouter(
    initialLocation,
  );

  runApp(
    WorkNetApp(
      router: router,
    ),
  );
}

String _routeForRole(
  String? role,
) {
  switch (
      role?.toLowerCase().trim()) {
    case 'candidato':
    case 'candidate':
      return '/candidate';

    case 'empresa':
    case 'company':
      return '/company';

    case 'administrador':
    case 'admin':
      return '/admin';

    default:
      return '/';
  }
}

GoRouter _createRouter(
  String initialLocation,
) {
  return GoRouter(
    initialLocation:
        initialLocation,

    // Obliga a GoRouter a respetar la sesión restaurada
    // en lugar de priorizar la URL inicial del navegador.
    overridePlatformDefaultLocation:
        true,

    routes: [
      GoRoute(
        path: '/',
        pageBuilder:
            (context, state) =>
                CustomTransitionPage(
          key: state.pageKey,
          child:
              const LandingPage(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) =>
              FadeTransition(
            opacity:
                animation,
            child:
                child,
          ),
        ),
      ),

      GoRoute(
        path: '/login',
        pageBuilder:
            (context, state) =>
                CustomTransitionPage(
          key: state.pageKey,
          child:
              const LoginPage(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) =>
              FadeTransition(
            opacity:
                animation,
            child:
                child,
          ),
        ),
      ),

      GoRoute(
        path: '/register',
        pageBuilder:
            (context, state) =>
                CustomTransitionPage(
          key: state.pageKey,
          child:
              const RegisterPage(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) =>
              FadeTransition(
            opacity:
                animation,
            child:
                child,
          ),
        ),
      ),

      GoRoute(
        path: '/admin',
        pageBuilder:
            (context, state) =>
                CustomTransitionPage(
          key: state.pageKey,
          child:
              const AdminDashboard(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) =>
              FadeTransition(
            opacity:
                animation,
            child:
                child,
          ),
        ),
      ),

      GoRoute(
        path: '/company',
        pageBuilder:
            (context, state) =>
                CustomTransitionPage(
          key: state.pageKey,
          child:
              const CompanyDashboard(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) =>
              FadeTransition(
            opacity:
                animation,
            child:
                child,
          ),
        ),
      ),

      GoRoute(
        path: '/candidate',
        pageBuilder:
            (context, state) =>
                CustomTransitionPage(
          key: state.pageKey,
          child:
              const CandidateDashboard(),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) =>
              FadeTransition(
            opacity:
                animation,
            child:
                child,
          ),
        ),
      ),

      GoRoute(
        path: '/settings/:role',
        pageBuilder:
            (context, state) =>
                CustomTransitionPage(
          key: state.pageKey,
          child:
              SettingsPage(
            role:
                state.pathParameters[
                        'role'] ??
                    'candidate',
          ),
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) =>
              FadeTransition(
            opacity:
                animation,
            child:
                child,
          ),
        ),
      ),
    ],
  );
}

class WorkNetApp
    extends StatelessWidget {
  const WorkNetApp({
    super.key,
    this.router,
  });

  final GoRouter? router;

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp.router(
      title:
          'WorkNet',

      routerConfig:
          router ??
              _createRouter(
                '/',
              ),

      debugShowCheckedModeBanner:
          false,

      theme:
          ThemeData(
        useMaterial3:
            true,

        colorScheme:
            ColorScheme.fromSeed(
          seedColor:
              const Color(
            0xFF0F62FE,
          ),
          brightness:
              Brightness.light,
          surface:
              Colors.white,
        ),

        textTheme:
            GoogleFonts
                .interTextTheme(),

        scaffoldBackgroundColor:
            Colors.white,
      ),
    );
  }
}