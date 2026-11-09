import 'package:worknet/features/administration/admin_page.dart';
import 'package:flutter/material.dart';
import 'package:worknet/features/statistics/statistics_page.dart';
import 'package:worknet/features/notifications/notifications_page.dart';
import 'package:worknet/features/applications/presentation/apply_page.dart';
import 'package:worknet/features/applications/presentation/application_history_page.dart';
import 'package:worknet/features/applications/presentation/application_detail_page.dart';
import 'package:worknet/features/applicants/presentation/applicant_offers_page.dart';
import 'package:worknet/features/applicants/presentation/applicants_page.dart';
import 'package:worknet/features/applicants/presentation/applicant_detail_page.dart';
import 'package:worknet/features/applicants/domain/applicant.dart';
import 'package:worknet/features/messages/presentation/conversations_page.dart';
import 'package:worknet/features/messages/presentation/chat_page.dart';
import 'package:worknet/features/offers/presentation/publish_offer_page.dart';
import 'package:worknet/features/offers/presentation/active_offers_page.dart';
import 'package:worknet/features/offers/presentation/offer_search_page.dart';
import 'package:worknet/features/offers/presentation/saved_offers_page.dart';
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
  final _messageObserver = RouteObserver<ModalRoute<dynamic>>();
  var _generatedKey = GlobalKey<GeneratedCurriculumPageState>();
  int? _returnOffer(GoRouterState state) {
    final id = int.tryParse(state.uri.queryParameters['apply_offer'] ?? '');
    return id != null && id > 0 ? id : null;
  }

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
    // Reflejar las rutas enlazables con push permite recargar Guardados y
    // Postular, conservando la consulta anterior cuando se vuelve atrás.
    GoRouter.optionURLReflectsImperativeAPIs = true;
    const protected = {
      '/dashboard',
      '/notifications',
      '/statistics',
      '/offers/search',
      '/offers/saved',
      '/applications',
      '/profile',
      '/curriculum',
      '/curriculum/create',
      '/account',
      '/company',
      '/company-dashboard',
      '/company/offers/new',
      '/admin-dashboard',
      '/company-reviews',
      '/admin/accounts',
      '/admin/events',
      '/choose-role',
      '/access-pending',
    };
    _router = GoRouter(
      observers: [_messageObserver],
      initialLocation: widget.initialLocation ?? '/login',
      overridePlatformDefaultLocation: widget.initialLocation != null,
      refreshListenable: _session,
      redirect: (_, state) {
        if (_session.restoring) return null;
        final path = state.uri.path, role = _session.session?.role;
        final companyFeature =
            path == '/company/applicants' ||
            path == '/company/offers' ||
            path.startsWith('/company/offers/');
        final applicationForm = RegExp(r'^/offers/[^/]+/apply$').hasMatch(path);
        final applicationDetail = path.startsWith('/applications/');
        final messageFeature =
            path == '/messages' || path.startsWith('/messages/');
        if ((protected.contains(path) ||
                companyFeature ||
                messageFeature ||
                applicationForm ||
                applicationDetail) &&
            role == null) {
          return '/login';
        }
        if (role != null) {
          if (path == '/login' || path == '/access-pending') return _home();
          if (role == 'unassigned' &&
              (protected.contains(path) ||
                  companyFeature ||
                  messageFeature ||
                  applicationForm ||
                  applicationDetail) &&
              path != '/choose-role') {
            return '/choose-role';
          }
          if (path == '/choose-role' && role != 'unassigned') return _home();
          if (messageFeature && !['candidato', 'empresa'].contains(role)) {
            return _home();
          }
          if (path == '/statistics' &&
              !['candidato', 'empresa'].contains(role)) {
            return _home();
          }
          if (path == '/statistics' &&
              role == 'empresa' &&
              _session.session?.companyState != 'approved') {
            return '/company';
          }
          if ([
                '/dashboard',
                '/offers/search',
                '/offers/saved',
                '/applications',
                '/profile',
                '/curriculum',
                '/curriculum/create',
              ].contains(path) &&
              role != 'candidato') {
            return _home();
          }
          if (applicationForm && role != 'candidato') return _home();
          if (applicationDetail && role != 'candidato') return _home();
          if ((companyFeature ||
                  [
                    '/company',
                    '/company-dashboard',
                    '/company/offers/new',
                  ].contains(path)) &&
              role != 'empresa') {
            return _home();
          }
          if ([
                '/admin-dashboard',
                '/company-reviews',
                '/admin/accounts',
                '/admin/events',
              ].contains(path) &&
              role != 'admin') {
            return _home();
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/admin/accounts',
          builder: (_, _) => _protected(
            'admin',
            () => AdminAccountsPage(
              session: _session,
              repository: _dependencies.administration,
            ),
          ),
        ),
        GoRoute(
          path: '/admin/events',
          builder: (_, _) => _protected(
            'admin',
            () => AdminEventsPage(
              session: _session,
              repository: _dependencies.administration,
            ),
          ),
        ),
        GoRoute(
          path: '/statistics',
          builder: (_, _) => _protected(
            null,
            () => StatisticsPage(
              key: ValueKey(_session.session?.token),
              session: _session,
              repository: _dependencies.statistics,
              routeObserver: _messageObserver,
            ),
          ),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => _protected(
            null,
            () => NotificationsPage(
              key: ValueKey(_session.session?.token),
              session: _session,
              repository: _dependencies.notifications,
            ),
          ),
        ),
        GoRoute(
          path: '/messages',
          builder: (_, state) => _protected(
            null,
            () => ConversationsPage(
              key: ValueKey('${_session.session?.token}:${state.uri}'),
              session: _session,
              repository: _dependencies.messages,
              query: state.uri.queryParameters['q'] ?? '',
              page: int.tryParse(state.uri.queryParameters['page'] ?? '1') ?? 1,
            ),
          ),
        ),
        GoRoute(
          path: '/messages/:id',
          builder: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null || id <= 0) {
              return const Scaffold(
                body: Center(child: Text('Conversación no válida.')),
              );
            }
            return _protected(
              null,
              () => ChatPage(
                key: ValueKey('${_session.session?.token}:chat:$id'),
                session: _session,
                repository: _dependencies.messages,
                routeObserver: _messageObserver,
                returnToNotifications: state.extra == 'notifications',
                id: id,
              ),
            );
          },
        ),
        GoRoute(
          path: '/company/applicants',
          builder: (_, _) => _protected(
            'empresa',
            () => ApplicantOffersPage(
              key: ValueKey('${_session.session?.token}:applicant-offers'),
              session: _session,
              repository: _dependencies.applicants,
            ),
          ),
        ),
        GoRoute(
          path: '/company/offers/:id/applicants',
          builder: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null || id <= 0) {
              return const Scaffold(
                body: Center(child: Text('Oferta no válida.')),
              );
            }
            return _protected(
              'empresa',
              () => ApplicantsPage(
                key: ValueKey('${_session.session?.token}:${state.uri}'),
                session: _session,
                repository: _dependencies.applicants,
                exports: _dependencies.applicantExports,
                download: _dependencies.applicantExportDownload,
                offerId: id,
                query: ApplicantQuery.fromUri(state.uri),
                returnToStatistics: state.extra == 'statistics',
              ),
            );
          },
        ),
        GoRoute(
          path: '/company/offers/:id/applicants/:applicationId',
          builder: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? ''),
                application = int.tryParse(
                  state.pathParameters['applicationId'] ?? '',
                );
            if (id == null ||
                id <= 0 ||
                application == null ||
                application <= 0) {
              return const Scaffold(
                body: Center(child: Text('Postulación no válida.')),
              );
            }
            return _protected(
              'empresa',
              () => ApplicantDetailPage(
                key: ValueKey(
                  '${_session.session?.token}:applicant:$id:$application',
                ),
                session: _session,
                repository: _dependencies.applicants,
                statuses: _dependencies.statuses,
                messages: _dependencies.messages,
                offerId: id,
                id: application,
              ),
            );
          },
        ),
        GoRoute(
          path: '/applications/:id',
          builder: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null || id <= 0) {
              return const Scaffold(
                body: Center(child: Text('Postulación no válida.')),
              );
            }
            return _protected(
              'candidato',
              () => ApplicationDetailPage(
                key: ValueKey('${_session.session?.token}:application:$id'),
                session: _session,
                repository: _dependencies.applications,
                messages: _dependencies.messages,
                id: id,
              ),
            );
          },
        ),
        GoRoute(
          path: '/applications',
          builder: (_, state) => _protected(
            'candidato',
            () => ApplicationHistoryPage(
              key: ValueKey('${_session.session?.token}:applications'),
              session: _session,
              repository: _dependencies.applications,
              returnToStatistics: state.extra == 'statistics',
            ),
          ),
        ),
        GoRoute(
          path: '/offers/:id/apply',
          builder: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null || id <= 0) {
              return const Scaffold(
                body: Center(child: Text('Oferta no válida.')),
              );
            }
            return _protected(
              'candidato',
              () => ApplyPage(
                key: ValueKey('${_session.session?.token}:apply:$id'),
                session: _session,
                repository: _dependencies.applications,
                offerId: id,
              ),
            );
          },
        ),
        GoRoute(
          path: '/offers/saved',
          builder: (_, _) => _protected(
            'candidato',
            () => SavedOffersPage(
              key: ValueKey('${_session.session?.token}:saved'),
              session: _session,
              repository: _dependencies.favorites,
            ),
          ),
        ),
        GoRoute(
          path: '/offers/search',
          builder: (_, _) => _protected(
            'candidato',
            () => OfferSearchPage(
              key: ValueKey('${_session.session?.token}:search'),
              session: _session,
              repository: _dependencies.search,
              favorites: _dependencies.favorites,
            ),
          ),
        ),
        GoRoute(
          path: '/company/offers',
          builder: (context, _) => _protected(
            'empresa',
            () => ActiveOffersPage(
              key: ValueKey('${_session.session?.token}:active'),
              session: _session,
              repository: _dependencies.offers,
              lifecycle: _dependencies.offers,
              onToggle: () => context.go('/company/offers/preserved'),
            ),
          ),
        ),
        GoRoute(
          path: '/company/offers/preserved',
          builder: (context, _) => _protected(
            'empresa',
            () => ActiveOffersPage(
              key: ValueKey('${_session.session?.token}:preserved'),
              session: _session,
              repository: _dependencies.offers,
              lifecycle: _dependencies.offers,
              initialPreserved: true,
              onToggle: () => context.go('/company/offers'),
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
          builder: (_, state) {
            final editorKey = _generatedKey;
            return _protected(
              'candidato',
              () => GeneratedCurriculumPage(
                key: editorKey,
                session: _session,
                repository: _dependencies.generatedCurriculum,
                download: _dependencies.curriculumDownload,
                returnToOfferId: _returnOffer(state),
              ),
            );
          },
        ),
        GoRoute(
          path: '/curriculum',
          builder: (_, state) => _protected(
            'candidato',
            () => CurriculumPage(
              key: ValueKey(_session.session?.token),
              session: _session,
              repository: _dependencies.curriculum,
              picker: _dependencies.pdfPicker,
              returnToOfferId: _returnOffer(state),
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
              favorites: _dependencies.favorites,
              notifications: _dependencies.notifications,
              messages: _dependencies.messages,
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
              notifications: _dependencies.notifications,
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
              notifications: _dependencies.notifications,
              messages: _dependencies.messages,
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
              notifications: _dependencies.notifications,
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
