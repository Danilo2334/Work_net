import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'statistics_repository.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.session,
    required this.repository,
    this.routeObserver,
  });
  final SessionController session;
  final StatisticsRepository repository;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with RouteAware {
  late final String? _token = widget.session.session?.token;
  late final String? _role = widget.session.session?.role;
  bool get _company => _role == 'empresa';
  bool get _current =>
      mounted &&
      _token != null &&
      widget.session.session?.token == _token &&
      widget.session.session?.role == _role &&
      (!_company || widget.session.session?.companyState == 'approved');
  StatisticsSummary? _data;
  bool _loading = true;
  String? _error;
  int _generation = 0;
  int _page = 1;
  ModalRoute<dynamic>? _route;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted && !_current) {
      _generation++;
      setState(() {
        _data = null;
        _error = null;
        _loading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      widget.routeObserver?.unsubscribe(this);
      _route = route;
      widget.routeObserver?.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    if (_current) _load(page: _page);
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    widget.routeObserver?.unsubscribe(this);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    if (!_current) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await widget.repository.load(
        _token!,
        company: _company,
        page: page,
      );
      if (_current && generation == _generation) {
        setState(() {
          _data = data;
          _page = data.page;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_current && generation == _generation && _scroll.hasClients) {
            _scroll.jumpTo(0);
          }
        });
      }
    } on ApiFailure catch (e) {
      if (!_current || generation != _generation) return;
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (_current && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(String path) async {
    final page = _data?.page ?? 1;
    await context.push(path, extra: 'statistics');
    if (widget.routeObserver == null && _current) await _load(page: page);
  }

  Widget _states(Map<String, int> states, int total, {bool chart = true}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in statisticLabels.entries)
            if (e.key != 'other' || states[e.key]! > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e.value}: ${states[e.key]}'),
                    if (chart) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: total == 0 ? 0 : states[e.key]! / total,
                        semanticsLabel:
                            '${e.value}: ${states[e.key]} de $total',
                      ),
                    ],
                  ],
                ),
              ),
        ],
      );
  @override
  Widget build(BuildContext context) {
    final d = _current ? _data : null;
    return Workspace(
      title: 'Estadísticas',
      scrollController: _scroll,
      loading: _loading,
      error: _error,
      onRetry: _load,
      actions: [
        TextButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(_company ? '/company-dashboard' : '/dashboard');
            }
          },
          child: const Text('Volver al dashboard'),
        ),
        TextButton(
          onPressed: _loading ? null : () => _load(),
          child: const Text('Actualizar estadísticas'),
        ),
      ],
      children: [
        if (d != null) ...[
          Text(
            'Actualizado: ${d.at.toLocal().toString().split('.').first} (hora local)',
          ),
          const SizedBox(height: 16),
          WorkspacePanel(
            title: 'Resumen de actividad',
            children: [
              Text(
                '${_company ? 'Postulaciones recibidas' : 'Postulaciones realizadas'}: ${d.total}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_company) ...[
                const SizedBox(height: 16),
                Text(
                  'Ofertas activas: ${d.activeOffers}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text('Ofertas propias publicadas y no vencidas.'),
              ],
              const SizedBox(height: 16),
              const Text(
                'Incluye todo el historial propio, también de ofertas cerradas o archivadas. Los conteos no se limitan a esta página.',
              ),
              if (d.total == 0) ...[
                const SizedBox(height: 16),
                const Text('Todavía no hay postulaciones para mostrar.'),
              ],
            ],
          ),
          WorkspacePanel(
            title: 'Estados de las postulaciones',
            children: [_states(d.states, d.total)],
          ),
          if (!_company)
            TextButton(
              onPressed: () => _open('/applications'),
              child: const Text('Consultar mi historial'),
            ),
          if (_company) ...[
            Text(
              'Postulaciones por oferta',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (d.offers.isEmpty) const Text('Todavía no has creado ofertas.'),
            for (final offer in d.offers)
              WorkspacePanel(
                title: offer.title,
                children: [
                  Text(
                    offer.active
                        ? 'Activa'
                        : 'No activa · ${{'published': 'Publicada', 'closed': 'Cerrada', 'archived': 'Archivada', 'draft': 'Borrador'}[offer.status]}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Postulaciones recibidas: ${offer.total}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _states(offer.states, offer.total, chart: false),
                  TextButton(
                    onPressed: () =>
                        _open('/company/offers/${offer.id}/applicants'),
                    child: Text('Consultar postulantes de ${offer.title}'),
                  ),
                ],
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: d.page > 1 && !_loading
                      ? () => _load(page: d.page - 1)
                      : null,
                  child: const Text('Página anterior'),
                ),
                Text(
                  d.offerCount == 0
                      ? 'Sin ofertas · 0 resultados'
                      : 'Página ${d.page} de ${d.pages} · ${d.offerCount} ofertas',
                ),
                OutlinedButton(
                  onPressed: d.page < d.pages && !_loading
                      ? () => _load(page: d.page + 1)
                      : null,
                  child: const Text('Página siguiente'),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}
