import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import '../domain/favorites.dart';

class SavedOffersPage extends StatefulWidget {
  const SavedOffersPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final SavedOffersRepository repository;
  @override
  State<SavedOffersPage> createState() => _SavedOffersPageState();
}

class _SavedOffersPageState extends State<SavedOffersPage> {
  SavedOffers? _data;
  int _page = 1, _generation = 0;
  bool _loading = true, _saving = false;
  String? _error, _notice;
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
      final result = await widget.repository.load(token, page: _page);
      if (mounted &&
          generation == _generation &&
          widget.session.session?.token == token) {
        setState(() => _data = result);
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

  Future<void> _remove(int id) async {
    final token = widget.session.session?.token;
    if (token == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.repository.setSaved(token, id, false);
      if (!mounted || widget.session.session?.token != token) return;
      _notice = 'Oferta retirada de Guardados.';
      if (_data?.offers.length == 1 && _page > 1) _page--;
      await _load();
    } on ApiFailure catch (e) {
      if (!mounted || widget.session.session?.token != token) return;
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      setState(
        () => _error =
            '${e.message} Pulsa Reintentar para consultar el estado actual.',
      );
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _go(int page) async {
    _page = page;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _load();
  }

  Future<void> _apply(int id) async {
    if (_saving || _loading) return;
    final token = widget.session.session?.token;
    await context.push('/offers/$id/apply');
    if (mounted && widget.session.session?.token == token) {
      _notice = null;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Guardados',
    loading: _loading || _saving,
    error: _error,
    onRetry: _loading || _saving ? null : _load,
    scrollController: _scroll,
    actions: [
      TextButton(
        onPressed: _saving
            ? null
            : () => context.canPop()
                  ? context.pop()
                  : context.go('/offers/search'),
        child: const Text('Volver al buscador'),
      ),
      TextButton(
        onPressed: _saving ? null : () => context.go('/dashboard'),
        child: const Text('Volver al dashboard'),
      ),
    ],
    children: [
      if (_loading) const Text('Cargando Guardados…'),
      if (_notice != null) Text(_notice!),
      if (_data case final data?) ...[
        Text(
          '${data.count} ofertas guardadas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (data.offers.isEmpty)
          const Text(
            'Todavía no tienes ofertas guardadas. Encuentra una oferta y pulsa Guardar oferta.',
          ),
        for (final item in data.offers)
          WorkspacePanel(
            title: item.offer.title,
            children: [
              Text(
                'Estado: ${item.statusLabel}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(item.offer.companyName),
              Text('${item.offer.location} · ${item.offer.contractType}'),
              Text(
                item.offer.salary == null
                    ? 'Salario no informado'
                    : 'Salario: ${item.offer.salary}',
              ),
              Text(
                'Guardada: ${item.savedAt.toLocal().toIso8601String().substring(0, 10)}',
              ),
              if (item.availability != 'active')
                const Text(
                  'Esta oferta ya no aparece en las búsquedas activas. Puedes quitarla de Guardados.',
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed:
                      _saving || _loading || item.availability != 'active'
                      ? null
                      : () => _apply(item.offer.id),
                  child: const Text('Postularme'),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: ValueKey('remove_saved_${item.offer.id}'),
                  onPressed: _saving || _loading
                      ? null
                      : () => _remove(item.offer.id),
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  label: const Text('Quitar de Guardados'),
                ),
              ),
            ],
          ),
        if (data.totalPages > 0)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _saving || data.previousPage == null
                    ? null
                    : () => _go(data.previousPage!),
                child: const Text('Anterior'),
              ),
              Text('Página ${data.page} de ${data.totalPages}'),
              OutlinedButton(
                onPressed: _saving || data.nextPage == null
                    ? null
                    : () => _go(data.nextPage!),
                child: const Text('Siguiente'),
              ),
            ],
          ),
      ],
    ],
  );
}
