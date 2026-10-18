import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/worknet_api.dart';
import '../../core/theme/worknet_theme.dart';
import '../../core/widgets/error_notice.dart';
import '../access/session.dart';

class CandidateSummary {
  CandidateSummary(Map<String, dynamic> value) {
    final user = value['user'],
        profile = value['profile_completion'],
        metrics = value['metrics'];
    if (user is! Map ||
        user['full_name'] is! String ||
        user['role'] != 'candidato' ||
        profile is! Map ||
        metrics is! Map ||
        value['recent_jobs'] is! List) {
      throw const FormatException();
    }
    name = user['full_name'];
    percentage = integer(profile['percentage']);
    if (percentage > 100) throw const FormatException();
    applications = integer(metrics['applications_count']);
    saved = integer(metrics['saved_offers_count']);
    notifications = integer(metrics['pending_notifications_count']);
    jobs = (value['recent_jobs'] as List).map((job) {
      if (job is! Map ||
          job['id'] is! int ||
          [
            'title',
            'company_name',
            'location',
            'contract_type',
            'published_at',
          ].any((key) => job[key] is! String)) {
        throw const FormatException();
      }
      return Map<String, dynamic>.from(job);
    }).toList();
  }
  static int integer(dynamic value) {
    if (value is! int || value < 0) throw const FormatException();
    return value;
  }

  late final String name;
  late final int percentage, applications, saved, notifications;
  late final List<Map<String, dynamic>> jobs;
}

class CandidateDashboardPage extends StatefulWidget {
  const CandidateDashboardPage({super.key, required this.controller});
  final SessionController controller;
  @override
  State<CandidateDashboardPage> createState() => _CandidateDashboardPageState();
}

class _CandidateDashboardPageState extends State<CandidateDashboardPage> {
  CandidateSummary? _summary;
  String? _error, _actionError;
  bool _loading = true, _loggingOut = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final session = widget.controller.session;
    if (session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = CandidateSummary(
        await widget.controller.api.request(
          'dashboard/candidate/',
          token: session.token,
        ),
      );
      if (mounted && generation == _generation) {
        setState(() => _summary = summary);
      }
    } on ApiFailure catch (e) {
      if (!mounted || generation != _generation) return;
      if (e.status == 401) {
        await widget.controller.expire();
        return;
      }
      setState(() => _error = e.message);
    } on FormatException {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'No pudimos interpretar los datos del dashboard. Vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _loggingOut = true;
      _actionError = null;
    });
    try {
      await widget.controller.logout();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _actionError = e.message);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: WorkNetColors.line),
    ),
    child: child,
  );
  Widget _metric(String label, int value, IconData icon) => _panel(
    Row(
      children: [
        Icon(icon, color: WorkNetColors.green, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: Theme.of(context).textTheme.headlineMedium),
              Text(label),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _accesses() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tus accesos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const Key('open_candidate_profile'),
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.person_outline),
          label: const Text('Perfil del candidato'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Los siguientes módulos todavía no están disponibles. Aquí podrás encontrar sus accesos cuando estén implementados.',
          style: TextStyle(color: WorkNetColors.muted),
        ),
        const SizedBox(height: 16),
        for (final entry in const [
          (Icons.description_outlined, 'Currículum', 'Módulo de CV'),
          (Icons.search, 'Buscar ofertas', 'Búsqueda de ofertas'),
          (Icons.chat_bubble_outline, 'Mensajes', 'Mensajería'),
          (Icons.history, 'Historial de postulaciones', 'Postulaciones'),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(entry.$1, color: WorkNetColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.$2,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Pendiente · ${entry.$3}',
                        style: const TextStyle(color: WorkNetColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  Widget _jobs(CandidateSummary summary) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trabajos recientes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Ofertas publicadas disponibles en WorkNet.',
          style: TextStyle(color: WorkNetColors.muted),
        ),
        const SizedBox(height: 20),
        if (summary.jobs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Todavía no hay trabajos publicados. Vuelve a consultar más adelante.',
            ),
          ),
        for (final job in summary.jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: WorkNetColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job['title'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(job['company_name']),
                  const SizedBox(height: 8),
                  Text(
                    '${job['location']} · ${job['contract_type']}',
                    style: const TextStyle(color: WorkNetColors.muted),
                  ),
                ],
              ),
            ),
          ),
        const Text(
          'El detalle de ofertas y la postulación pertenecen a módulos pendientes.',
          style: TextStyle(color: WorkNetColors.muted),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('WorkNet'),
      actions: [
        IconButton(
          key: const Key('open_account'),
          tooltip: 'Configuración de cuenta',
          onPressed: () => context.go('/account'),
          icon: const Icon(Icons.settings_outlined),
        ),
        TextButton.icon(
          key: const Key('logout'),
          onPressed: _loggingOut ? null : _logout,
          icon: const Icon(Icons.logout, size: 20),
          label: Text(_loggingOut ? 'Saliendo…' : 'Cerrar sesión'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: _loading
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cargando tu dashboard…'),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ErrorNotice(_actionError),
                    if (_error != null)
                      _panel(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No pudimos cargar tu dashboard',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            ErrorNotice(_error),
                            FilledButton(
                              key: const Key('retry_dashboard'),
                              onPressed: _load,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    if (_error == null && _summary != null)
                      ..._content(_summary!),
                  ],
                ),
              ),
            ),
          ),
  );
  List<Widget> _content(CandidateSummary summary) => [
    const SizedBox(height: 12),
    Text(
      'Hola, ${summary.name}',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 8),
    const Text('Este es el resumen de tu actividad en WorkNet.'),
    const SizedBox(height: 20),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Actualizar datos'),
      ),
    ),
    const SizedBox(height: 12),
    _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completitud del perfil · ${summary.percentage}%',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: summary.percentage / 100,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 12),
          Text(
            summary.percentage == 100
                ? 'Tu perfil está completo.'
                : 'Tienes secciones pendientes de completar en tu perfil.',
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    LayoutBuilder(
      builder: (context, constraints) {
        final metrics = [
          _metric(
            'Postulaciones realizadas',
            summary.applications,
            Icons.send_outlined,
          ),
          _metric('Ofertas guardadas', summary.saved, Icons.bookmark_border),
          _metric(
            'Notificaciones pendientes',
            summary.notifications,
            Icons.notifications_none,
          ),
        ];
        if (constraints.maxWidth >= 760) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: metrics[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (final metric in metrics)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: metric,
              ),
          ],
        );
      },
    ),
    const SizedBox(height: 20),
    LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 1000
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _jobs(summary)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: _accesses()),
              ],
            )
          : Column(
              children: [
                _jobs(summary),
                const SizedBox(height: 20),
                _accesses(),
              ],
            ),
    ),
    const SizedBox(height: 32),
  ];
}
