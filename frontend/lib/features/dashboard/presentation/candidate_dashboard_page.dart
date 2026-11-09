import 'package:flutter/material.dart';
import 'package:worknet/features/notifications/notifications_page.dart';
import 'package:worknet/features/notifications/notifications_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/dashboard/domain/candidate_summary.dart';
import 'package:worknet/core/theme/worknet_theme.dart';
import 'package:worknet/core/widgets/error_notice.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/offers/domain/favorites.dart';
import 'package:worknet/features/messages/domain/message.dart';
import 'package:worknet/features/messages/presentation/message_access.dart';

class CandidateDashboardPage extends StatefulWidget {
  const CandidateDashboardPage({
    super.key,
    required this.controller,
    required this.repository,
    this.favorites,
    this.messages,
    this.notifications,
  });
  final SessionController controller;
  final CandidateDashboardRepository repository;
  final SavedOffersRepository? favorites;
  final MessagesRepository? messages;
  final NotificationsRepository? notifications;
  @override
  State<CandidateDashboardPage> createState() => _CandidateDashboardPageState();
}

class _CandidateDashboardPageState extends State<CandidateDashboardPage> {
  CandidateSummary? _summary;
  String? _error, _actionError;
  bool _loading = true, _loggingOut = false;
  int _generation = 0;
  int? _savingId;
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
      final summary = await widget.repository.load(session.token);
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
          () => _error = 'No pudimos interpretar los datos del dashboard. Vuelve a intentarlo.',
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

  Future<void> _toggle(JobPreview job) async {
    final token = widget.controller.session?.token;
    if (token == null || _savingId != null || widget.favorites == null) return;
    setState(() {
      _savingId = job.id;
      _actionError = null;
    });
    try {
      await widget.favorites!.setSaved(token, job.id, !job.isSaved);
      if (mounted && widget.controller.session?.token == token) await _load();
    } on ApiFailure catch (e) {
      if (!mounted || widget.controller.session?.token != token) return;
      if (e.status == 401) {
        await widget.controller.expire();
        return;
      }
      setState(
        () => _actionError =
            '${e.message} Pulsa Actualizar Guardados para consultar el estado actual.',
      );
    } finally {
      if (mounted) setState(() => _savingId = null);
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
          key: const Key('open_saved_offers'),
          onPressed: () => context.go('/offers/saved'),
          icon: const Icon(Icons.bookmark_border),
          label: const Text('Guardados'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const Key('open_offer_search'),
          onPressed: () => context.go('/offers/search'),
          icon: const Icon(Icons.search),
          label: const Text('Buscar ofertas'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const Key('open_candidate_profile'),
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.person_outline),
          label: const Text('Perfil del candidato'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const Key('open_curriculum'),
          onPressed: () => context.go('/curriculum'),
          icon: const Icon(Icons.description_outlined),
          label: const Text('Mi currículum'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const Key('open_applications'),
          onPressed: () => context.go('/applications'),
          icon: const Icon(Icons.history),
          label: const Text('Mis postulaciones'),
        ),
        const SizedBox(height: 12),
        MessagesEntry(
          key: ValueKey(
            '${widget.controller.session?.token}:messages:$_generation',
          ),
          session: widget.controller,
          repository: widget.messages,
        ),
        NotificationsEntry(
          key: ValueKey(
            '${widget.controller.session?.token}:notices:$_generation',
          ),
          session: widget.controller,
          repository: widget.notifications,
          onReturn: _load,
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
                    job.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(job.companyName),
                  const SizedBox(height: 8),
                  Text(
                    '${job.location} · ${job.contractType}',
                    style: const TextStyle(color: WorkNetColors.muted),
                  ),
                  if (widget.favorites != null)
                    TextButton.icon(
                      key: ValueKey('dashboard_save_${job.id}'),
                      onPressed: _savingId != null ? null : () => _toggle(job),
                      icon: Icon(
                        job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                      label: Text(
                        job.isSaved ? 'Quitar de Guardados' : 'Guardar oferta',
                      ),
                    ),
                ],
              ),
            ),
          ),
        const Text(
          'Consulta el detalle y postúlate desde Buscar ofertas.',
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
                    if (_actionError != null)
                      OutlinedButton(
                        onPressed: _savingId != null
                            ? null
                            : () {
                                setState(() => _actionError = null);
                                _load();
                              },
                        child: const Text('Actualizar Guardados'),
                      ),
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
    const SizedBox(height: 20),
    _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Últimos avisos', style: Theme.of(context).textTheme.titleLarge),
          if (summary.notices.isEmpty) const Text('Todavía no tienes avisos.'),
          for (final notice in summary.notices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title),
                  Text(
                    '${notice.createdAt.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')} (hora local) · ${notice.pending ? 'Pendiente' : 'Leído'}',
                  ),
                  if (notice.applicationId != null)
                    TextButton(
                      onPressed: () async {
                        await context.push(
                          '/applications/${notice.applicationId}',
                        );
                        if (mounted) await _load();
                      },
                      child: const Text('Consultar postulación del aviso'),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: 32),
  ];
}
