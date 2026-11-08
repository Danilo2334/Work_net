import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/api/operation_id.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import '../domain/message.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.session,
    required this.repository,
    required this.id,
    this.routeObserver,
  });
  final SessionController session;
  final MessagesRepository repository;
  final int id;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with RouteAware {
  final _text = TextEditingController();
  late final String? _token = widget.session.session?.token;
  MessagePage? _data;
  MessageDraft? _pending;
  List<int> _readIds = [];
  int _generation = 0, _unread = 0;
  int _presentedGeneration = -1;
  bool _loading = true,
      _sending = false,
      _reading = false,
      _notRecorded = false;
  String? _error, _sendError, _readError, _notice;
  bool get _current =>
      mounted && _token != null && widget.session.session?.token == _token;
  bool get _visible => _current && (ModalRoute.of(context)?.isCurrent ?? false);
  ModalRoute<dynamic>? _route;
  int get _me => widget.session.session!.id;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _load();
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
    if (_current) _load();
  }

  void _sessionChanged() {
    if (mounted && widget.session.session?.token != _token) {
      setState(() {
        _data = null;
        _pending = null;
        _readIds = [];
        _text.clear();
      });
    }
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    widget.session.removeListener(_sessionChanged);
    _text.dispose();
    super.dispose();
  }

  Future<void> _failure(ApiFailure e, void Function(String) show) async {
    if (!_current) return;
    if (e.status == 401) {
      await widget.session.expire();
      return;
    }
    if (e.status == 403 || e.status == 404) setState(() => _data = null);
    setState(() => show(e.message));
  }

  Future<void> _load({int page = 1, int? throughId}) async {
    if (!_current) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _readError = null;
      _readIds = [];
      _presentedGeneration = -1;
      _data = null;
    });
    try {
      final result = await widget.repository.messages(
        _token!,
        widget.id,
        page: page,
        throughId: throughId,
      );
      if (!_current || generation != _generation) return;
      if (result.conversation.contactId == _me ||
          result.conversation.contactRole == widget.session.session!.role ||
          result.rows.any(
            (m) => !m.between(_me, result.conversation.contactId),
          )) {
        throw const ApiFailure('El contexto de los mensajes no es válido.');
      }
      setState(() {
        _data = result;
        _unread = result.conversation.unread;
        _loading = false;
        _readIds = [
          for (final m in result.rows)
            if (m.recipientId == _me && m.readAt == null) m.id,
        ];
      });
      // Solo confirma la ventana que se acaba de presentar, nunca todos los pendientes.
      await WidgetsBinding.instance.endOfFrame;
      if (_visible && generation == _generation && _readIds.isNotEmpty) {
        _presentedGeneration = generation;
        await _ack(generation: generation);
      }
    } on ApiFailure catch (e) {
      if (_current && generation == _generation) {
        await _failure(e, (s) => _error = s);
      }
    } finally {
      if (_current && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _ack({int? generation}) async {
    final active = generation ?? _generation;
    if (!_visible ||
        _reading ||
        _readIds.isEmpty ||
        _presentedGeneration != active ||
        active != _generation) {
      return;
    }
    final ids = List<int>.of(_readIds);
    setState(() {
      _reading = true;
      _readError = null;
    });
    try {
      final remaining = await widget.repository.read(_token!, widget.id, ids);
      if (_current && active == _generation) {
        setState(() {
          _unread = remaining;
          _readIds = [];
        });
      }
    } on ApiFailure catch (e) {
      if (_current && active == _generation) {
        await _failure(e, (s) => _readError = s);
      }
    } finally {
      if (_current) setState(() => _reading = false);
      if (_visible &&
          active != _generation &&
          _presentedGeneration == _generation &&
          _readIds.isNotEmpty &&
          _readError == null) {
        await _ack(generation: _generation);
      }
    }
  }

  Future<void> _compose() async {
    if (!_current ||
        _sending ||
        _reading ||
        _pending != null ||
        _data == null) {
      return;
    }
    final text = _text.text.trim().replaceAll('\r\n', '\n');
    if (text.isEmpty || text.runes.length > 4000) {
      setState(() => _sendError = 'Escribe un mensaje de 1 a 4000 caracteres.');
      return;
    }
    setState(() {
      _pending = MessageDraft(id: newOperationId(), text: text);
      _notRecorded = false;
      _notice = null;
    });
    await _send();
  }

  Future<void> _done(SelectionMessage message) async {
    if (!_current) return;
    if (message.senderId != _me ||
        message.recipientId != _data?.conversation.contactId) {
      throw const ApiFailure(
        'No pudimos confirmar el destinatario del mensaje. Comprueba el envío.',
      );
    }
    setState(() {
      _pending = null;
      _notRecorded = false;
      _sendError = null;
      _text.clear();
      _notice = 'Mensaje enviado correctamente.';
    });
    await _load();
  }

  Future<void> _send() async {
    if (!_current || _pending == null) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await _done(await widget.repository.send(_token!, widget.id, _pending!));
    } on ApiFailure catch (e) {
      if (!_current) return;
      if ([400, 403, 404, 409].contains(e.status)) {
        setState(() => _pending = null);
      }
      await _failure(e, (s) => _sendError = s);
    } finally {
      if (_current) setState(() => _sending = false);
    }
  }

  Future<void> _lookup() async {
    if (!_current || _pending == null) return;
    setState(() {
      _sending = true;
      _sendError = null;
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
          _sendError =
              'El mensaje no está registrado. Puedes reintentar el mismo envío sin duplicarlo.';
        });
      } else {
        await _failure(e, (s) => _sendError = s);
      }
    } finally {
      if (_current) setState(() => _sending = false);
    }
  }

  String _date(DateTime date) =>
      '${date.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')} (hora local)';
  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Conversación del proceso',
    loading: _loading,
    error: _error,
    onRetry: () => _load(),
    actions: [
      TextButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/messages');
          }
        },
        child: const Text('Volver a conversaciones'),
      ),
      TextButton(
        onPressed: _loading || _sending || _reading ? null : () => _load(),
        child: const Text('Actualizar conversación'),
      ),
    ],
    children: [
      if (_notice != null && _current) Text(_notice!),
      if (_sendError != null && _current) Text(_sendError!),
      if (_data case final data? when _current) ...[
        WorkspacePanel(
          title: data.conversation.contactName.trim().isEmpty
              ? 'Contacto del proceso'
              : data.conversation.contactName,
          children: [
            Text(
              'Oferta: ${data.conversation.offerTitle} · ${data.conversation.company}',
            ),
            Text('Postulación #${data.conversation.applicationId}'),
            Text('Pendientes de lectura en esta conversación: $_unread'),
            if (_unread > 0)
              const Text(
                'Actualiza para consultar los mensajes nuevos o abre las páginas anteriores para leer los pendientes.',
              ),
            if (_readError != null) ...[
              Text('Lectura sin confirmar: $_readError'),
              TextButton(
                onPressed: _reading ? null : () => _ack(),
                child: const Text('Reintentar lectura'),
              ),
            ],
            TextButton(
              onPressed: () => context.push(
                widget.session.session?.role == 'empresa'
                    ? '/company/offers/${data.conversation.offerId}/applicants/${data.conversation.applicationId}'
                    : '/applications/${data.conversation.applicationId}',
              ),
              child: const Text('Consultar postulación del proceso'),
            ),
          ],
        ),
        if (data.rows.isEmpty)
          const Text('Esta conversación todavía no tiene mensajes.'),
        for (final message in data.rows)
          LayoutBuilder(
            builder: (context, constraints) {
              final mine = message.senderId == _me;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .88,
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: mine
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mine
                            ? 'Tú · Enviado'
                            : '${data.conversation.contactName} · Recibido',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(message.text),
                      const SizedBox(height: 6),
                      Text(_date(message.createdAt)),
                      if (mine)
                        Text(
                          message.readAt == null
                              ? 'Enviado'
                              : 'Leído: ${_date(message.readAt!)}',
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: data.next == null || _loading || _sending || _reading
                  ? null
                  : () => _load(page: data.next!, throughId: data.throughId),
              child: const Text('Ver mensajes anteriores'),
            ),
            Text(
              'Ventana ${data.page} de ${data.pages == 0 ? 1 : data.pages} · ${data.count} mensajes',
            ),
            TextButton(
              onPressed:
                  data.previous == null || _loading || _sending || _reading
                  ? null
                  : () =>
                        _load(page: data.previous!, throughId: data.throughId),
              child: const Text('Ver mensajes más recientes'),
            ),
          ],
        ),
        WorkspacePanel(
          title: 'Escribir mensaje',
          children: [
            TextField(
              controller: _text,
              enabled: !_sending && _pending == null,
              minLines: 2,
              maxLines: 5,
              maxLength: 4000,
              decoration: const InputDecoration(labelText: 'Mensaje de texto'),
            ),
            if (_pending == null)
              FilledButton(
                onPressed: _sending || _loading || _reading ? null : _compose,
                child: const Text('Enviar mensaje'),
              )
            else ...[
              const Text(
                'El resultado del envío está pendiente de comprobar. Conservamos el mismo mensaje y su identificador para evitar duplicados.',
              ),
              OutlinedButton(
                onPressed: _sending || _loading ? null : _lookup,
                child: const Text('Comprobar envío'),
              ),
              if (_notRecorded)
                FilledButton(
                  onPressed: _sending || _loading ? null : _send,
                  child: const Text('Reintentar mismo envío'),
                ),
            ],
          ],
        ),
      ],
    ],
  );
}
