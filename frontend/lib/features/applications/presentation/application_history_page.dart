import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import '../domain/application.dart';
import 'application_document.dart';

class ApplicationHistoryPage extends StatefulWidget {
  const ApplicationHistoryPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final ApplicationsRepository repository;
  @override
  State<ApplicationHistoryPage> createState() => _ApplicationHistoryPageState();
}

class _ApplicationHistoryPageState extends State<ApplicationHistoryPage> {
  ApplicationHistory? _data;
  bool _loading = true;
  int _page = 1, _generation = 0;
  String? _error;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = widget.session.session?.token;
    if (token == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await widget.repository.history(token, page: _page);
      if (mounted &&
          generation == _generation &&
          widget.session.session?.token == token) {
        setState(() => _data = data);
      }
    } on ApiFailure catch (e) {
      if (!mounted ||
          generation != _generation ||
          widget.session.session?.token != token) {
        return;
      }
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      if (e.status == 400 && e.fields.containsKey('page') && _page > 1) {
        _page = 1;
        await _load();
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _go(int page) async {
    _page = page;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Mis postulaciones',
    loading: _loading,
    error: _error,
    onRetry: _loading ? null : _load,
    scrollController: _scroll,
    actions: [
      TextButton(
        onPressed: () => context.go('/dashboard'),
        child: const Text('Volver al dashboard'),
      ),
      TextButton(
        onPressed: () => context.go('/offers/search'),
        child: const Text('Buscar ofertas'),
      ),
    ],
    children: [
      if (_loading) const Text('Cargando postulaciones…'),
      if (_data case final data?) ...[
        Text('${data.count} postulaciones registradas'),
        if (data.applications.isEmpty)
          const Text(
            'Todavía no tienes postulaciones. Busca una oferta activa para comenzar.',
          ),
        for (final item in data.applications)
          WorkspacePanel(
            title: item.offer.title,
            children: [
              ApplicationDetails(
                application: item,
                session: widget.session,
                repository: widget.repository,
              ),
            ],
          ),
        if (data.pages > 0)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: data.previous == null
                    ? null
                    : () => _go(data.previous!),
                child: const Text('Anterior'),
              ),
              Text('Página ${data.page} de ${data.pages}'),
              OutlinedButton(
                onPressed: data.next == null ? null : () => _go(data.next!),
                child: const Text('Siguiente'),
              ),
            ],
          ),
      ],
    ],
  );
}
