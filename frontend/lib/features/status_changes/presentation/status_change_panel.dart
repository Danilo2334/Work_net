import 'package:flutter/material.dart';
import 'package:worknet/core/api/operation_id.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/applications/domain/application.dart';
import '../domain/status_change.dart';

class StatusChangePanel extends StatefulWidget {
  const StatusChangePanel({
    super.key,
    required this.session,
    required this.repository,
    required this.id,
    required this.onChanged,
  });
  final SessionController session;
  final StatusRepository repository;
  final int id;
  final Future<void> Function() onChanged;
  @override
  State<StatusChangePanel> createState() => _StatusChangePanelState();
}

class _StatusChangePanelState extends State<StatusChangePanel> {
  final _comment = TextEditingController();
  StatusContext? _context;
  StatusCommand? _pending;
  ApplicationStatus? _target;
  String? _error;
  bool _busy = false, _notRecorded = false;
  late final String? _token = widget.session.session?.token;
  bool get _current =>
      mounted && _token != null && widget.session.session?.token == _token;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current) return;
    setState(() {
      _busy = true;
      _context = null;
      _target = null;
    });
    try {
      final value = await widget.repository.load(_token!, widget.id);
      if (_current) setState(() => _context = value);
    } on ApiFailure catch (e) {
      await _failure(e);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _failure(ApiFailure e) async {
    if (!_current) return;
    if (e.status == 401) {
      await widget.session.expire();
      return;
    }
    setState(() => _error = e.message);
  }

  Future<void> _confirm() async {
    if (_context == null || _target == null || !_current) return;
    if (_comment.text.length > 2000) {
      setState(() => _error = 'El comentario admite hasta 2000 caracteres.');
      return;
    }
    final command = StatusCommand(
      id: newOperationId(),
      version: _context!.application.statusVersion,
      target: _target!,
      comment: _comment.text.trim().replaceAll('\r\n', '\n'),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Confirmar cambio de estado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cambiar a ${command.target.label}. El candidato recibirá un aviso interno.',
              ),
              if (command.comment.isNotEmpty)
                Text('Comentario: ${command.comment}'),
              const Text(
                'La decisión final Aceptada o Rechazada no se puede reabrir.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Confirmar cambio'),
          ),
        ],
      ),
    );
    if (confirmed != true || !_current) return;
    setState(() {
      _pending = command;
      _notRecorded = false;
    });
    await _send();
  }

  Future<void> _done(StatusContext result) async {
    if (!_current) return;
    setState(() {
      _pending = null;
      _notRecorded = false;
      _context = result;
      _error = null;
      _target = null;
      _comment.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cambio a ${result.recordedTarget!.label} registrado. Aviso interno enviado al candidato.',
        ),
      ),
    );
    await widget.onChanged();
  }

  Future<void> _send() async {
    if (!_current || _pending == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _done(
        await widget.repository.change(_token!, widget.id, _pending!),
      );
    } on ApiFailure catch (e) {
      if (!_current) return;
      if (e.status == 400 ||
          e.status == 403 ||
          e.status == 404 ||
          e.status == 409) {
        setState(() => _pending = null);
        if (e.status == 409) await _load();
      }
      await _failure(e);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _lookup() async {
    if (!_current || _pending == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _done(
        await widget.repository.lookup(_token!, widget.id, _pending!),
      );
    } on ApiFailure catch (e) {
      if (!_current) return;
      if (e.status == 404) {
        setState(() {
          _notRecorded = true;
          _error =
              'El cambio no está registrado. Puedes reintentar la misma operación confirmada.';
        });
      } else {
        await _failure(e);
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspacePanel(
    title: 'Cambiar estado de postulación',
    children: [
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      if (_pending != null) ...[
        const Text(
          'El resultado está pendiente de comprobación. Conservamos la operación confirmada para evitar duplicados.',
        ),
        OutlinedButton(
          onPressed: _busy ? null : _lookup,
          child: const Text('Comprobar cambio'),
        ),
        if (_notRecorded)
          FilledButton(
            onPressed: _busy ? null : _send,
            child: const Text('Reintentar mismo cambio'),
          ),
      ] else if (_context case final value?) ...[
        Text('Estado vigente: ${value.application.status.label}'),
        if (value.allowed.isEmpty)
          const Text(
            'Esta decisión es final. No hay cambios de estado disponibles.',
          )
        else ...[
          DropdownButtonFormField<ApplicationStatus>(
            key: ValueKey(
              '${value.application.statusVersion}-${_target?.code}',
            ),
            initialValue: _target,
            decoration: const InputDecoration(labelText: 'Nuevo estado'),
            isExpanded: true,
            items: [
              for (final state in value.allowed)
                DropdownMenuItem(value: state, child: Text(state.label)),
            ],
            onChanged: _busy
                ? null
                : (state) => setState(() {
                    _target = state;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            enabled: !_busy,
            maxLength: 2000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Comentario opcional'),
          ),
          FilledButton(
            onPressed: _busy || _target == null ? null : _confirm,
            child: const Text('Revisar cambio'),
          ),
        ],
      ] else if (!_busy)
        TextButton(onPressed: _load, child: const Text('Reintentar estado')),
    ],
  );
}
