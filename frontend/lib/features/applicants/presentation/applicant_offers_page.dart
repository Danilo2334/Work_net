import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import '../domain/applicant.dart';

class ApplicantOffersPage extends StatefulWidget {
  const ApplicantOffersPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final ApplicantsRepository repository;
  @override
  State<ApplicantOffersPage> createState() => _ApplicantOffersPageState();
}

class _ApplicantOffersPageState extends State<ApplicantOffersPage> {
  ApplicantOffers? _data;
  String? _error;
  bool _loading = true;
  int _page = 1, _generation = 0;
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
      _data = null;
      _error = null;
      _loading = true;
    });
    try {
      final data = await widget.repository.offers(token, page: _page);
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

  Future<void> _open(int id) async {
    await context.push('/company/offers/$id/applicants');
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Gestión de postulantes',
    loading: _loading,
    error: _error,
    onRetry: _loading ? null : _load,
    scrollController: _scroll,
    actions: [
      TextButton(
        onPressed: () => context.go('/company-dashboard'),
        child: const Text('Volver al dashboard'),
      ),
      TextButton(
        onPressed: _loading ? null : _load,
        child: const Text('Actualizar ofertas'),
      ),
    ],
    children: [
      const Text(
        'Selecciona una oferta propia. También puedes consultar postulaciones conservadas de ofertas cerradas o archivadas.',
      ),
      if (_loading) const Text('Cargando ofertas…'),
      if (_data case final data?) ...[
        Text('${data.count} ofertas propias'),
        if (data.offers.isEmpty)
          const Text('Todavía no tienes ofertas para consultar postulantes.'),
        for (final offer in data.offers)
          WorkspacePanel(
            title: offer.title,
            children: [
              Text('Estado de la oferta: ${offer.stateLabel}'),
              Text('${offer.count} postulantes'),
              OutlinedButton(
                key: Key('open_applicants_${offer.id}'),
                onPressed: () => _open(offer.id),
                child: const Text('Ver postulantes'),
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
