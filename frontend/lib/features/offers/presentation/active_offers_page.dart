import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import '../domain/offer.dart';

class ActiveOffersPage extends StatefulWidget {
  const ActiveOffersPage({
    super.key,
    required this.session,
    required this.repository,
    this.lifecycle,
    this.initialPreserved = false,
    this.onToggle,
  });
  final SessionController session;
  final OfferEditingRepository repository;
  final OfferLifecycleRepository? lifecycle;
  final bool initialPreserved;
  final VoidCallback? onToggle;
  @override
  State<ActiveOffersPage> createState() => _ActiveOffersPageState();
}

class _ActiveOffersPageState extends State<ActiveOffersPage> {
  ActiveOffers? _data;
  int _page = 1;
  bool _loading = true;
  String? _error;
  String? _notice;
  bool _preserved = false;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _preserved = widget.initialPreserved;
    _load();
  }

  Future<void> _load() async {
    final token = widget.session.session?.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = _preserved
          ? await widget.lifecycle!.preserved(token, page: _page)
          : await widget.repository.active(token, page: _page);
      if (mounted && widget.session.session?.token == token) {
        setState(() => _data = data);
      }
    } on ApiFailure catch (e) {
      if (mounted && widget.session.session?.token == token) {
        if (e.status == 401) await widget.session.expire();
        if (mounted) setState(() => _error = e.message);
      }
    } finally {
      if (mounted && widget.session.session?.token == token) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _transition(EditableOffer offer, bool archive) async {
    if (_saving || _loading) return;
    final token = widget.session.session?.token;
    if (token == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          archive ? '¿Archivar esta oferta?' : '¿Cerrar esta oferta?',
        ),
        content: Text(
          '${offer.draft.title}\n\n'
          '${archive ? 'Quedará archivada' : 'Dejará de estar activa'}: no recibirá nuevas postulaciones ni aparecerá en consultas activas. '
          'No podrás seguir editándola ni reabrirla. Su información y las postulaciones existentes se conservarán en Ofertas conservadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(archive ? 'Confirmar archivado' : 'Confirmar cierre'),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        widget.session.session?.token != token) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.lifecycle!.transition(token, offer.id, archive: archive);
      if (!mounted || widget.session.session?.token != token) return;
      _notice = archive
          ? 'Oferta archivada correctamente.'
          : 'Oferta cerrada correctamente.';
      _page = 1;
      await _load();
    } on ApiFailure catch (e) {
      if (mounted && widget.session.session?.token == token) {
        if (e.status == 401) await widget.session.expire();
        if (mounted) {
          setState(
            () => _error =
                '${e.fields.isEmpty ? e.message : e.fields.values.join('\n')} Consulta el listado para comprobar el estado antes de repetir la acción.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: _preserved ? 'Ofertas conservadas' : 'Mis ofertas activas',
    loading: _loading || _saving,
    error: _error,
    onRetry: _saving || _loading ? null : _load,
    actions: [
      TextButton(
        onPressed: () => context.go('/company-dashboard'),
        child: const Text('Volver al dashboard'),
      ),
      if (widget.lifecycle != null)
        OutlinedButton(
          onPressed: _loading || _saving
              ? null
              : () {
                  if (widget.onToggle != null) {
                    widget.onToggle!();
                    return;
                  }
                  _preserved = !_preserved;
                  _page = 1;
                  _notice = null;
                  _load();
                },
          child: Text(
            _preserved ? 'Ver ofertas activas' : 'Ver ofertas conservadas',
          ),
        ),
    ],
    children: [
      if (_notice != null) Text(_notice!, semanticsLabel: _notice),
      if (_data case final data?) ...[
        Text('${data.count} ofertas ${_preserved ? 'conservadas' : 'activas'}'),
        if (data.offers.isEmpty)
          Text(
            _preserved
                ? 'No tienes ofertas cerradas o archivadas.'
                : 'No tienes ofertas activas para editar.',
          ),
        for (final offer in data.offers)
          WorkspacePanel(
            title: offer.draft.title,
            children: [
              Text(offer.draft.location),
              if (_preserved) ...[
                Text(
                  offer.status == 'closed'
                      ? 'Estado: Cerrada'
                      : 'Estado: Archivada',
                ),
                Text(offer.draft.description),
                Text('Requisitos: ${offer.draft.requirements}'),
                Text(
                  'Salario: ${offer.draft.salary.isEmpty ? 'Sin especificar' : offer.draft.salary}',
                ),
                Text('Categoría: ${offer.draft.category}'),
                Text('Contrato: ${offer.draft.contractType}'),
                const Text(
                  'Información y postulaciones conservadas. Esta oferta no admite edición ni nuevas postulaciones.',
                ),
              ],
              if (!_preserved)
                TextButton(
                  key: Key('edit_offer_${offer.id}'),
                  onPressed: _saving
                      ? null
                      : () => context.go('/company/offers/${offer.id}/edit'),
                  child: const Text('Editar oferta'),
                ),
              if (widget.lifecycle != null)
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (!_preserved)
                      OutlinedButton(
                        key: Key('close_offer_${offer.id}'),
                        onPressed: _loading || _saving
                            ? null
                            : () => _transition(offer, false),
                        child: const Text('Cerrar oferta'),
                      ),
                    if (offer.status != 'archived')
                      OutlinedButton(
                        key: Key('archive_offer_${offer.id}'),
                        onPressed: _loading || _saving
                            ? null
                            : () => _transition(offer, true),
                        child: const Text('Archivar oferta'),
                      ),
                  ],
                ),
            ],
          ),
        Wrap(
          spacing: 12,
          children: [
            if (data.previousPage case final previous?)
              OutlinedButton(
                onPressed: _loading || _saving
                    ? null
                    : () {
                        _page = previous;
                        _load();
                      },
                child: const Text('Página anterior'),
              ),
            if (data.nextPage case final next?)
              OutlinedButton(
                onPressed: _loading || _saving
                    ? null
                    : () {
                        _page = next;
                        _load();
                      },
                child: const Text('Siguiente página'),
              ),
          ],
        ),
      ],
    ],
  );
}
