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
  });
  final SessionController session;
  final OfferEditingRepository repository;
  @override
  State<ActiveOffersPage> createState() => _ActiveOffersPageState();
}

class _ActiveOffersPageState extends State<ActiveOffersPage> {
  ActiveOffers? _data;
  int _page = 1;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
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
      final data = await widget.repository.active(token, page: _page);
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

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Mis ofertas activas',
    loading: _loading,
    error: _error,
    onRetry: _load,
    actions: [
      TextButton(
        onPressed: () => context.go('/company-dashboard'),
        child: const Text('Volver al dashboard'),
      ),
    ],
    children: [
      if (_data case final data?) ...[
        Text('${data.count} ofertas activas'),
        if (data.offers.isEmpty)
          const Text('No tienes ofertas activas para editar.'),
        for (final offer in data.offers)
          WorkspacePanel(
            title: offer.draft.title,
            children: [
              Text(offer.draft.location),
              TextButton(
                key: Key('edit_offer_${offer.id}'),
                onPressed: () => context.go('/company/offers/${offer.id}/edit'),
                child: const Text('Editar oferta'),
              ),
            ],
          ),
        Wrap(
          spacing: 12,
          children: [
            if (data.previousPage case final previous?)
              OutlinedButton(
                onPressed: () {
                  _page = previous;
                  _load();
                },
                child: const Text('Página anterior'),
              ),
            if (data.nextPage case final next?)
              OutlinedButton(
                onPressed: () {
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
