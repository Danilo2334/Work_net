import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import '../domain/application.dart';
import 'application_document.dart';

class ApplyPage extends StatefulWidget {
  const ApplyPage({
    super.key,
    required this.session,
    required this.repository,
    required this.offerId,
  });
  final SessionController session;
  final ApplicationsRepository repository;
  final int offerId;
  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  ApplicationContext? _data;
  JobApplication? _receipt;
  String? _source, _error, _notice;
  bool _loading = true, _sending = false, _review = false, _uncertain = false;
  final _scroll = ScrollController();
  int _generation = 0;
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

  CvChoice? get _choice {
    for (final c in _data?.choices ?? <CvChoice>[]) {
      if (c.source == _source) return c;
    }
    return null;
  }

  Future<void> _load() async {
    final token = widget.session.session?.token;
    if (token == null) return;
    final generation = ++_generation, wasUncertain = _uncertain;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _review = false;
    });
    try {
      final data = await widget.repository.context(token, widget.offerId);
      if (!mounted ||
          generation != _generation ||
          widget.session.session?.token != token) {
        return;
      }
      setState(() {
        _data = data;
        _receipt = data.existing;
        _uncertain = false;
        if (!data.choices.any((c) => c.source == _source)) {
          _source = data.choices.isEmpty ? null : data.choices.first.source;
        }
        _notice = wasUncertain && data.existing == null
            ? 'No hay una postulación registrada. Revisa los datos antes de enviarla.'
            : null;
      });
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
      setState(
        () =>
            _error = e.fields.isEmpty ? e.message : e.fields.values.join('\n'),
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submit() async {
    final token = widget.session.session?.token, cv = _choice;
    if (token == null || cv == null || _sending || _uncertain) return;
    setState(() {
      _sending = true;
      _error = null;
      _notice = null;
    });
    try {
      final item = await widget.repository.submit(token, widget.offerId, cv);
      if (mounted && widget.session.session?.token == token) {
        setState(() => _receipt = item);
      }
    } on ApiFailure catch (e) {
      if (!mounted || widget.session.session?.token != token) return;
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      setState(() {
        _error = e.fields.isEmpty ? e.message : e.fields.values.join('\n');
        _uncertain = true;
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/offers/search');
    }
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Postular a oferta',
    loading: _loading || _sending,
    error: _error,
    onRetry: _loading || _sending ? null : _load,
    scrollController: _scroll,
    actions: [
      TextButton(
        onPressed: _sending ? null : _back,
        child: const Text('Volver a ofertas'),
      ),
      TextButton(
        onPressed: _sending ? null : () => context.go('/applications'),
        child: const Text('Mis postulaciones'),
      ),
    ],
    children: [
      if (_loading) const Text('Cargando postulación…'),
      if (_sending) const Text('Enviando postulación…'),
      if (_notice != null) Text(_notice!),
      if (_receipt case final item?) ...[
        const Text('Postulación registrada correctamente.'),
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
      ] else if (_data case final data?) ...[
        WorkspacePanel(
          title: data.offer.title,
          children: [
            Text(data.offer.company),
            Text('${data.offer.location} · ${data.offer.contract}'),
            Text('Perfil: ${data.candidateName}'),
          ],
        ),
        if (!data.offer.active)
          const Text(
            'Esta oferta ya no está activa y no recibe nuevas postulaciones.',
          )
        else if (data.choices.isEmpty) ...[
          const Text(
            'Necesitas un currículum antes de postular. Sube un PDF o guarda un CV creado en la plataforma.',
          ),
          OutlinedButton(
            onPressed: () =>
                context.go('/curriculum?apply_offer=${widget.offerId}'),
            child: const Text('Ir a Mi currículum'),
          ),
          TextButton(
            onPressed: _load,
            child: const Text('Actualizar currículums'),
          ),
        ] else if (_uncertain) ...[
          const Text(
            'Comprueba si la postulación quedó registrada antes de repetir el envío.',
          ),
          FilledButton(
            onPressed: _sending ? null : _load,
            child: const Text('Comprobar postulación'),
          ),
        ] else if (!_review) ...[
          const Text('Elige el currículum que quieres enviar.'),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Currículum'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _source,
                isExpanded: true,
                items: [
                  for (final cv in data.choices)
                    DropdownMenuItem(
                      value: cv.source,
                      child: Text(
                        '${cv.typeLabel}: ${cv.label}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _sending ? null : (v) => setState(() => _source = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _choice == null || _sending
                ? null
                : () => setState(() => _review = true),
            child: const Text('Continuar'),
          ),
        ] else ...[
          Text(
            'Revisa tu postulación',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('${_choice!.typeLabel}: ${_choice!.label}'),
          const Text(
            'Se enviará una copia de este CV. Los cambios posteriores de tu currículum no modificarán esta postulación.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sending ? null : _submit,
            child: const Text('Confirmar postulación'),
          ),
          TextButton(
            onPressed: _sending ? null : () => setState(() => _review = false),
            child: const Text('Cambiar currículum'),
          ),
        ],
      ],
    ],
  );
}
