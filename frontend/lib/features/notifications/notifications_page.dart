import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import 'notifications_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final NotificationsRepository repository;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final String? _token = widget.session.session?.token;
  NoticePage? _data;
  Map<String, bool>? _preferences;
  String _status = 'all';
  String? _error, _success;
  bool _loading = true, _busy = false;
  int _generation = 0;
  bool get _current =>
      mounted && _token != null && widget.session.session?.token == _token;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted && !_current) {
      _generation++;
      setState(() {
        _data = null;
        _preferences = null;
        _error = null;
        _success = null;
        _loading = false;
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    super.dispose();
  }

  Future<void> _failure(ApiFailure e) async {
    if (!_current) return;
    if (e.status == 401) {
      await widget.session.expire();
      return;
    }
    setState(() => _error = e.message);
  }

  Future<void> _load({int page = 1, int? anchor}) async {
    if (!_current) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final result = await widget.repository.list(
        _token!,
        page: page,
        status: _status,
        anchor: anchor,
      );
      if (!_current || generation != _generation) return;
      final prefs = await widget.repository.preferences(_token);
      if (_current && generation == _generation) {
        setState(() {
          _data = result;
          _preferences = prefs;
        });
      }
    } on ApiFailure catch (e) {
      if (generation == _generation) await _failure(e);
    } finally {
      if (_current && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _read(AccountNotice n) async {
    if (!_current || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.repository.read(_token!, n.id);
      if (_current) {
        setState(() => _success = 'Notificación marcada como leída.');
        await _load();
      }
    } on ApiFailure catch (e) {
      await _failure(e);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_current || _busy || _preferences == null) return;
    final values = Map<String, bool>.from(_preferences!);
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final result = await widget.repository.savePreferences(_token!, values);
      if (_current) {
        setState(() {
          _preferences = result;
          _success = 'Preferencias guardadas para los eventos nuevos.';
        });
      }
    } on ApiFailure catch (e) {
      await _failure(e);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  String _home() => switch (widget.session.session?.role) {
    'candidato' => '/dashboard',
    'admin' => '/admin-dashboard',
    _ =>
      widget.session.session?.companyState == 'approved'
          ? '/company-dashboard'
          : '/company',
  };
  String? _destination(AccountNotice n) {
    final s = widget.session.session;
    if (n.kind == 'company_reviewed') return '/company';
    if (s?.role == 'empresa' && s?.companyState != 'approved') {
      return '/company';
    }
    if (n.conversationId != null) return '/messages/${n.conversationId}';
    if (n.applicationId != null) {
      if (s?.role == 'candidato') return '/applications/${n.applicationId}';
      if (s?.role == 'empresa' && n.offerId != null) {
        return '/company/offers/${n.offerId}/applicants/${n.applicationId}';
      }
    }
    return null;
  }

  String _date(DateTime d) =>
      '${d.toLocal().toString().split('.').first} (hora local)';
  @override
  Widget build(BuildContext context) {
    final d = _current ? _data : null;
    return Workspace(
      title: 'Centro de notificaciones',
      loading: _loading,
      error: _error,
      onRetry: _load,
      actions: [
        TextButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(_home());
            }
          },
          child: const Text('Volver al dashboard'),
        ),
        TextButton(
          onPressed: _busy || _loading ? null : () => _load(),
          child: const Text('Actualizar notificaciones'),
        ),
      ],
      children: [
        if (_success != null) Text(_success!),
        if (d != null)
          Text(
            'Notificaciones pendientes: ${d.unread}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: const InputDecoration(
            labelText: 'Mostrar notificaciones',
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Todas')),
            DropdownMenuItem(value: 'unread', child: Text('Pendientes')),
            DropdownMenuItem(value: 'read', child: Text('Leídas')),
          ],
          onChanged: _busy || _loading
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _status = value);
                    _load();
                  }
                },
        ),
        const SizedBox(height: 16),
        if (d != null && d.rows.isEmpty)
          const Text('No hay notificaciones para este filtro.'),
        if (d != null) ...[
          for (final n in d.rows)
            WorkspacePanel(
              title: n.title,
              children: [
                Text(
                  '${_date(n.createdAt)} · ${n.readAt == null ? 'Pendiente' : 'Leída'}',
                ),
                if (n.readAt != null) Text('Leída: ${_date(n.readAt!)}'),
                Wrap(
                  spacing: 12,
                  children: [
                    if (n.readAt == null)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _read(n),
                        child: const Text('Marcar como leída'),
                      ),
                    if (_destination(n) != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await context.push(_destination(n)!);
                                if (_current) await _load();
                              },
                        child: const Text('Consultar evento'),
                      ),
                  ],
                ),
              ],
            ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: _busy || _loading || d.page <= 1
                    ? null
                    : () => _load(page: d.page - 1, anchor: d.anchor),
                child: const Text('Página anterior'),
              ),
              Text(
                'Página ${d.page} de ${d.pages == 0 ? 1 : d.pages} · ${d.count} notificaciones',
              ),
              OutlinedButton(
                onPressed: _busy || _loading || d.page >= d.pages
                    ? null
                    : () => _load(page: d.page + 1, anchor: d.anchor),
                child: const Text('Página siguiente'),
              ),
            ],
          ),
        ],
        if (_current && _preferences != null)
          WorkspacePanel(
            title: 'Preferencias de notificaciones',
            children: [
              const Text(
                'Se aplican a los eventos nuevos. El historial y las lecturas anteriores se conservan. Leer un aviso no marca el mensaje como leído.',
              ),
              for (final entry in noticeLabels.entries)
                SwitchListTile(
                  title: Text(entry.value),
                  value: _preferences![entry.key]!,
                  onChanged: _busy
                      ? null
                      : (value) =>
                            setState(() => _preferences![entry.key] = value),
                ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Guardar preferencias'),
              ),
            ],
          ),
      ],
    );
  }
}

class NotificationsEntry extends StatefulWidget {
  const NotificationsEntry({
    super.key,
    required this.session,
    this.repository,
    this.onReturn,
  });
  final SessionController session;
  final NotificationsRepository? repository;
  final VoidCallback? onReturn;
  @override
  State<NotificationsEntry> createState() => _NotificationsEntryState();
}

class _NotificationsEntryState extends State<NotificationsEntry> {
  late final String? _token = widget.session.session?.token;
  int? _count;
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_changed);
    _load();
  }

  void _changed() {
    if (mounted && widget.session.session?.token != _token) {
      setState(() {
        _count = null;
        _error = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    super.dispose();
  }

  Future<void> _load() async {
    if (_token == null || widget.repository == null) return;
    setState(() {
      _loading = true;
      _count = null;
      _error = null;
    });
    try {
      final count = await widget.repository!.summary(_token);
      if (mounted && widget.session.session?.token == _token) {
        setState(() => _count = count);
      }
    } on ApiFailure catch (e) {
      if (!mounted || widget.session.session?.token != _token) return;
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      setState(() => _error = e.message);
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
        onPressed: widget.repository == null
            ? null
            : () async {
                await context.push('/notifications');
                if (mounted && widget.session.session?.token == _token) {
                  await _load();
                  widget.onReturn?.call();
                }
              },
        icon: const Icon(Icons.notifications_none),
        label: const Text('Notificaciones'),
      ),
      if (_loading) const Text('Consultando notificaciones pendientes…'),
      if (_count != null && widget.session.session?.token == _token)
        Text('Avisos pendientes: $_count'),
      if (_error != null) ...[
        Text(_error!),
        TextButton(
          onPressed: _load,
          child: const Text('Reintentar contador de avisos'),
        ),
      ],
    ],
  );
}
