import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/api/worknet_api.dart';
import 'core/theme/worknet_theme.dart';
import 'core/widgets/auth_shell.dart';
import 'core/widgets/error_notice.dart';
import 'features/access/login_page.dart';
import 'features/access/recovery_pages.dart';
import 'features/access/session.dart';
import 'features/dashboard/candidate_dashboard.dart';
import 'features/registration/data/registration_api.dart';
import 'features/registration/presentation/registration_page.dart';

class WorkNetApp extends StatefulWidget {
  const WorkNetApp({
    super.key,
    this.registrationApi,
    this.api,
    this.sessionStore,
    this.initialLocation,
  });
  final RegistrationApi? registrationApi;
  final WorkNetApi? api;
  final SessionStore? sessionStore;
  final String? initialLocation;
  @override
  State<WorkNetApp> createState() => _WorkNetAppState();
}

class _WorkNetAppState extends State<WorkNetApp> {
  late final WorkNetApi _api = widget.api ?? WorkNetApi();
  late final SessionController _session = SessionController(
    api: _api,
    store: widget.sessionStore ?? const SecureSessionStore(),
  );
  late final GoRouter _router;
  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: widget.initialLocation ?? '/login',
      overridePlatformDefaultLocation: widget.initialLocation != null,
      refreshListenable: _session,
      redirect: (context, state) {
        if (_session.restoring) return null;
        final path = state.uri.path;
        if (path == '/access-pending' &&
            _session.session?.role == 'candidato') {
          return '/dashboard';
        }
        if (['/dashboard', '/access-pending'].contains(path) &&
            _session.session == null) {
          return '/login';
        }
        if (path == '/login' && _session.session != null) {
          return _session.session!.role == 'candidato'
              ? '/dashboard'
              : '/access-pending';
        }
        if (path == '/dashboard' && _session.session?.role != 'candidato') {
          return '/access-pending';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/login'),
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginPage(controller: _session),
        ),
        GoRoute(
          path: '/register',
          builder: (context, _) => RegistrationPage(
            api: widget.registrationApi,
            onLogin: () => context.go('/login'),
          ),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, _) => RecoveryRequestPage(api: _api),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (_, state) => ResetPasswordPage(
            api: _api,
            uid: state.uri.queryParameters['uid'],
            token: state.uri.queryParameters['token'],
            onReset: () => _session.expire(announce: false),
          ),
        ),
        GoRoute(
          path: '/password-updated',
          builder: (_, _) => const PasswordUpdatedPage(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => ListenableBuilder(
            listenable: _session,
            builder: (_, _) => _session.restoring || _session.session == null
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : CandidateDashboardPage(controller: _session),
          ),
        ),
        GoRoute(
          path: '/access-pending',
          builder: (_, _) => ListenableBuilder(
            listenable: _session,
            builder: (_, _) => _session.restoring || _session.session == null
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : _PendingDestination(controller: _session),
          ),
        ),
      ],
      errorBuilder: (context, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Esta página no está disponible.'),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Ir al inicio de sesión'),
              ),
            ],
          ),
        ),
      ),
    );
    _session.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'WorkNet',
    debugShowCheckedModeBanner: false,
    theme: workNetTheme(),
    routerConfig: _router,
  );
}

class _PendingDestination extends StatefulWidget {
  const _PendingDestination({required this.controller});
  final SessionController controller;
  @override
  State<_PendingDestination> createState() => _PendingDestinationState();
}

class _PendingDestinationState extends State<_PendingDestination> {
  String? _error;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => AuthShell(
    headline: 'Tu cuenta\nen WorkNet.',
    description: 'El acceso corresponde al rol que confirma el servicio.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Inicio de sesión correcto',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Text(
          widget.controller.session?.role == 'empresa'
              ? 'El espacio de empresa todavía no está disponible. El estado de validación empresarial no está informado por el servicio actual.'
              : 'El espacio de administración todavía no está disponible.',
        ),
        const SizedBox(height: 24),
        ErrorNotice(_error),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await widget.controller.logout();
                  } on ApiFailure catch (e) {
                    if (mounted) setState(() => _error = e.message);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Saliendo…' : 'Cerrar sesión'),
        ),
      ],
    ),
  );
}
