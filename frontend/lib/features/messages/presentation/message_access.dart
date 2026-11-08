import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import '../domain/message.dart';

class MessagesEntry extends StatefulWidget {
  const MessagesEntry({super.key, required this.session, this.repository});
  final SessionController session;
  final MessagesRepository? repository;
  @override
  State<MessagesEntry> createState() => _MessagesEntryState();
}

class _MessagesEntryState extends State<MessagesEntry> {
  int? _unread;
  String? _error;
  bool _loading = false;
  late final String? _token = widget.session.session?.token;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (mounted && widget.session.session?.token != _token) {
      setState(() {
        _unread = null;
        _error = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.repository == null ||
        _token == null ||
        widget.session.session?.token != _token) {
      return;
    }
    setState(() {
      _loading = true;
      _unread = null;
      _error = null;
    });
    try {
      final count = await widget.repository!.unread(_token);
      if (mounted && widget.session.session?.token == _token) {
        setState(() => _unread = count);
      }
    } on ApiFailure catch (e) {
      if (!mounted || widget.session.session?.token != _token) return;
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      setState(() => _error = 'No pudimos consultar los mensajes pendientes.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton.icon(
        onPressed: () async {
          await context.push('/messages');
          if (mounted) await _load();
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Mensajes'),
      ),
      if (_loading) const Text('Consultando mensajes pendientes…'),
      if (_unread != null && widget.session.session?.token == _token)
        Text('Mensajes sin leer: $_unread'),
      if (_error != null) ...[
        Text(_error!),
        TextButton(
          onPressed: _loading ? null : _load,
          child: const Text('Reintentar contador de mensajes'),
        ),
      ],
    ],
  );
}

class StartConversationButton extends StatefulWidget {
  const StartConversationButton({
    super.key,
    required this.session,
    required this.repository,
    required this.applicationId,
    required this.label,
  });
  final SessionController session;
  final MessagesRepository repository;
  final int applicationId;
  final String label;
  @override
  State<StartConversationButton> createState() =>
      _StartConversationButtonState();
}

class _StartConversationButtonState extends State<StartConversationButton> {
  bool _busy = false;
  String? _error;
  Future<void> _start() async {
    final token = widget.session.session?.token;
    if (token == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await widget.repository.start(token, widget.applicationId);
      if (mounted && widget.session.session?.token == token) {
        await context.push('/messages/${c.id}');
      }
    } on ApiFailure catch (e) {
      if (!mounted || widget.session.session?.token != token) return;
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_error != null) Text(_error!),
      OutlinedButton(
        onPressed: _busy ? null : _start,
        child: Text(_busy ? 'Abriendo conversación…' : widget.label),
      ),
    ],
  );
}
