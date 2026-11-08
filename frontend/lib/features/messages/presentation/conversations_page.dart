import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import '../domain/message.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({
    super.key,
    required this.session,
    required this.repository,
    this.query = '',
    this.page = 1,
  });
  final SessionController session;
  final MessagesRepository repository;
  final String query;
  final int page;
  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  late final _search = TextEditingController(text: widget.query);
  late final String? _token = widget.session.session?.token;
  ConversationPage? _data;
  String? _error;
  bool _loading = true;
  int _generation = 0;
  bool get _current =>
      mounted && _token != null && widget.session.session?.token == _token;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (mounted && widget.session.session?.token != _token) {
      setState(() {
        _data = null;
        _search.clear();
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current) return;
    final generation = ++_generation;
    setState(() {
      _data = null;
      _error = null;
      _loading = true;
    });
    try {
      final result = await widget.repository.conversations(
        _token!,
        query: widget.query,
        page: widget.page,
      );
      if (_current && generation == _generation) {
        if (result.rows.any(
          (c) =>
              c.contactId == widget.session.session!.id ||
              c.contactRole == widget.session.session!.role,
        )) {
          throw const ApiFailure(
            'El contacto de la conversación no es válido.',
          );
        }
        setState(() => _data = result);
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

  void _go(int page, {String? query}) {
    final q = (query ?? widget.query).trim();
    if (q.runes.length > 100) {
      setState(() => _error = 'Busca con un texto de hasta 100 caracteres.');
      return;
    }
    if (q == widget.query && page == widget.page) {
      _load();
      return;
    }
    context.go(
      Uri(
        path: '/messages',
        queryParameters: {
          if (q.isNotEmpty) 'q': q,
          if (page != 1) 'page': '$page',
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Mensajes',
    loading: _loading,
    error: _error,
    onRetry: _load,
    actions: [
      TextButton(
        onPressed: () => context.go(
          widget.session.session?.role == 'empresa'
              ? '/company-dashboard'
              : '/dashboard',
        ),
        child: const Text('Volver al dashboard'),
      ),
      TextButton(
        onPressed: _loading ? null : _load,
        child: const Text('Actualizar conversaciones'),
      ),
    ],
    children: [
      WorkspacePanel(
        title: 'Buscar conversaciones',
        children: [
          TextField(
            controller: _search,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Contacto u oferta'),
            onSubmitted: (_) => _go(1, query: _search.text),
          ),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: _loading ? null : () => _go(1, query: _search.text),
                child: const Text('Buscar conversaciones'),
              ),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        _search.clear();
                        _go(1, query: '');
                      },
                child: const Text('Limpiar búsqueda'),
              ),
            ],
          ),
        ],
      ),
      if (_data case final data? when _current) ...[
        Text('Conversaciones encontradas: ${data.count}'),
        if (data.rows.isEmpty)
          const Text(
            'No hay conversaciones para esta búsqueda. Puedes iniciar una desde el detalle de una postulación autorizada.',
          ),
        for (final c in data.rows)
          WorkspacePanel(
            title: c.contactName.trim().isEmpty
                ? 'Contacto del proceso'
                : c.contactName,
            children: [
              Text('Oferta: ${c.offerTitle} · ${c.company}'),
              Text('Postulación #${c.applicationId}'),
              Text('Mensajes sin leer: ${c.unread}'),
              if (c.lastText != null)
                Text(
                  c.lastText!.length > 120
                      ? '${c.lastText!.substring(0, 120)}…'
                      : c.lastText!,
                ),
              Text(
                'Actividad: ${c.activityAt.toLocal().toIso8601String().substring(0, 19).replaceFirst('T', ' ')} (hora local)',
              ),
              FilledButton(
                onPressed: () async {
                  await context.push('/messages/${c.id}');
                  if (_current) await _load();
                },
                child: const Text('Abrir conversación'),
              ),
            ],
          ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: data.previous == null
                  ? null
                  : () => _go(data.previous!),
              child: const Text('Conversaciones anteriores'),
            ),
            Text('Página ${data.page} de ${data.pages == 0 ? 1 : data.pages}'),
            TextButton(
              onPressed: data.next == null ? null : () => _go(data.next!),
              child: const Text('Más conversaciones'),
            ),
          ],
        ),
      ],
    ],
  );
}
