import 'package:flutter/material.dart';
import 'package:worknet/features/offers/presentation/publish_offer_page.dart';
import 'package:worknet/features/offers/presentation/active_offers_page.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/composition.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/core/theme/worknet_theme.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/access/presentation/login_page.dart';
import 'package:worknet/features/access/presentation/recovery_pages.dart';
import 'package:worknet/features/access/presentation/choose_role_page.dart';
import 'package:worknet/features/account/presentation/account_page.dart';
import 'package:worknet/features/profile/presentation/profile_page.dart';
import 'package:worknet/features/curriculum/presentation/curriculum_page.dart';
import 'package:worknet/features/curriculum/presentation/generated_curriculum_page.dart';
import 'package:worknet/features/dashboard/presentation/candidate_dashboard_page.dart';
import 'package:worknet/features/registration/data/registration_api.dart';
import 'package:worknet/features/registration/presentation/registration_page.dart';
import 'package:worknet/features/company/presentation/company_page.dart';
import 'package:worknet/features/company/presentation/company_reviews_page.dart';
import 'package:worknet/features/company/presentation/role_dashboard_page.dart';

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
  late final AppDependencies _dependencies = AppDependencies(
    _api,
    widget.sessionStore ?? const SecureSessionStore(),
  );
  late final RegistrationApi _registration =
      widget.registrationApi ?? RegistrationApi();
  SessionController get _session => _dependencies.session;
  late final GoRouter _router;
  var _generatedKey = GlobalKey<GeneratedCurriculumPageState>();
  String _home() => switch (_session.session?.role) {
    'candidato' => '/dashboard',
    'empresa' =>
      _session.session?.companyState == 'approved'
          ? '/company-dashboard'
          : '/company',
    'admin' => '/admin-dashboard',
    _ => '/choose-role',
  };
  Widget _protected(String? role, Widget Function() child) => ListenableBuilder(
    listenable: _session,
    builder: (_, _) =>
        _session.restoring ||
            _session.session == null ||
            (role != null && _session.session?.role != role)
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : child(),
  );
  @override
  void initState() {
    super.initState();
    const protected = {
      '/dashboard',
      '/profile',
      '/curriculum',
      '/curriculum/create',
      '/account',
      '/company',
      '/company-dashboard',
      '/company/offers/new',
      '/admin-dashboard',
      '/company-reviews',
      '/choose-role',
      '/access-pending',
    };
    _router = GoRouter(
      initialLocation: widget.initialLocation ?? '/login',
      overridePlatformDefaultLocation: widget.initialLocation != null,
      refreshListenable: _session,
      redirect: (_, state) {
        if (_session.restoring) return null;
        final path = state.uri.path, role = _session.session?.role;
        final companyOffer =
            path == '/company/offers' || path.startsWith('/company/offers/');
        if ((protected.contains(path) || companyOffer) && role == null) {
          return '/login';
        }
        if (role != null) {
          if (path == '/login' || path == '/access-pending') return _home();
          if (role == 'unassigned' &&
              (protected.contains(path) || companyOffer) &&
              path != '/choose-role') {
            return '/choose-role';
          }
          if (path == '/choose-role' && role != 'unassigned') return _home();
          if ([
                '/dashboard',
                '/profile',
                '/curriculum',
                '/curriculum/create',
              ].contains(path) &&
              role != 'candidato') {
            return _home();
          }
          if ((companyOffer ||
                  [
                    '/company',
                    '/company-dashboard',
                    '/company/offers/new',
                  ].contains(path)) &&
              role != 'empresa') {
            return _home();
          }
          if (['/admin-dashboard', '/company-reviews'].contains(path) &&
              role != 'admin') {
            return _home();
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/company/offers',
          builder: (_, _) => _protected(
            'empresa',
            () => ActiveOffersPage(
              key: ValueKey(_session.session?.token),
              session: _session,
              repository: _dependencies.offers,
            ),
          ),
        ),
        GoRoute(
          path: '/company/offers/:id/edit',
          builder: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null || id <= 0) {
              return const Scaffold(
                body: Center(child: Text('Oferta no válida.')),
              );
            }
            return _protected(
              'empresa',
              () => PublishOfferPage(
                key: ValueKey('${_session.session?.token}:$id'),
                session: _session,
                repository: _dependencies.offers,
                editingRepository: _dependencies.offers,
                offerId: id,
              ),
            );
          },
        ),
        GoRoute(
          path: '/company/offers/new',
          builder: (_, _) => _protected(
            'empresa',
            () => PublishOfferPage(
              key: ValueKey(_session.session?.token),
              session: _session,
              repository: _dependencies.offers,
            ),
          ),
        ),
        GoRoute(
          path: '/curriculum/create',
          onExit: (_, _) async {
            final leave =
                await (_generatedKey.currentState?.confirmLeave() ??
                    Future.value(true));
            if (leave) {
              // La página saliente puede seguir animándose al volver al editor.
              // Otra entrada necesita su propio estado y una nueva consulta.
              _generatedKey = GlobalKey<GeneratedCurriculumPageState>();
            }
            return leave;
          },
          builder: (_, _) {
            final editorKey = _generatedKey;
            return _protected(
              'candidato',
              () => GeneratedCurriculumPage(
                key: editorKey,
                session: _session,
                repository: _dependencies.generatedCurriculum,
                download: _dependencies.curriculumDownload,
              ),
            );
          },
        ),
        GoRoute(
          path: '/curriculum',
          builder: (_, _) => _protected(
            'candidato',
            () => CurriculumPage(
              key: ValueKey(_session.session?.token),
              session: _session,
              repository: _dependencies.curriculum,
              picker: _dependencies.pdfPicker,
            ),
          ),
        ),
        GoRoute(path: '/', redirect: (_, _) => '/login'),
        GoRoute(
          path: '/login',
          builder: (_, _) => LoginPage(controller: _session),
        ),
        GoRoute(
          path: '/register',
          builder: (context, _) => RegistrationPage(
            repository: _registration,
            onLogin: () => context.go('/login'),
          ),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, _) =>
              RecoveryRequestPage(repository: _dependencies.access),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (_, s) => ResetPasswordPage(
            repository: _dependencies.access,
            uid: s.uri.queryParameters['uid'],
            token: s.uri.queryParameters['token'],
            onReset: () => _session.expire(announce: false),
          ),
        ),
        GoRoute(
          path: '/password-updated',
          builder: (_, _) => const PasswordUpdatedPage(),
        ),
        GoRoute(
          path: '/choose-role',
          builder: (_, _) => _protected(
            'unassigned',
            () => ChooseRolePage(
              session: _session,
              repository: _dependencies.access,
            ),
          ),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (_, _) => _protected(
            'candidato',
            () => CandidateDashboardPage(
              controller: _session,
              repository: _dependencies.dashboard,
            ),
          ),
        ),
        GoRoute(
          path: '/account',
          builder: (_, _) => _protected(
            null,
            () => AccountPage(
              controller: _session,
              repository: _dependencies.account,
            ),
          ),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => _protected(
            'candidato',
            () => ProfilePage(
              controller: _session,
              repository: _dependencies.profile,
            ),
          ),
        ),
        GoRoute(
          path: '/company',
          builder: (_, _) => _protected(
            'empresa',
            () => CompanyPage(
              session: _session,
              repository: _dependencies.company,
            ),
          ),
        ),
        GoRoute(
          path: '/company-dashboard',
          builder: (_, _) => _protected(
            'empresa',
            () => RoleDashboardPage(
              session: _session,
              repository: _dependencies.company,
              admin: false,
            ),
          ),
        ),
        GoRoute(
          path: '/admin-dashboard',
          builder: (_, _) => _protected(
            'admin',
            () => RoleDashboardPage(
              session: _session,
              repository: _dependencies.company,
              admin: true,
            ),
          ),
        ),
        GoRoute(
          path: '/company-reviews',
          builder: (_, _) => _protected(
            'admin',
            () => CompanyReviewsPage(
              session: _session,
              repository: _dependencies.company,
            ),
          ),
        ),
        GoRoute(path: '/access-pending', redirect: (_, _) => _home()),
      ],
      errorBuilder: (context, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Esta página no está disponible. Ir al inicio.'),
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
    if (widget.registrationApi == null) _registration.close();
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
