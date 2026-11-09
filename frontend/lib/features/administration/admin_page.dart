import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import 'admin_repository.dart';

class AdminAccountsPage extends StatefulWidget {
  const AdminAccountsPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final AdminRepository repository;
  @override
  State<AdminAccountsPage> createState() => _AdminAccountsPageState();
}

class _AdminAccountsPageState extends State<AdminAccountsPage> {
  AdminListing? _data;
  bool _loading = true, _busy = false, _create = false;
  int _page = 1, _generation = 0;
  String? _error, _success;
  Administrator? _selected;
  String? _identity;
  @override
  void initState() {
    super.initState();
    _identity = widget.session.session?.token;
    widget.session.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _generation++;
    super.dispose();
  }

  void _sessionChanged() {
    if (_identity != widget.session.session?.token) {
      _generation++;
      if (mounted) {
        setState(() {
          _data = null;
          _loading = false;
          _selected = null;
          _create = false;
        });
      }
    }
  }

  Future<void> _load() async {
    final token = widget.session.session?.token;
    final generation = ++_generation;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final data = await widget.repository.list(token, _page);
      if (mounted &&
          generation == _generation &&
          token == widget.session.session?.token) {
        setState(() => _data = data);
      }
    } on ApiFailure catch (e) {
      if (e.status == 401 && token == widget.session.session?.token) {
        await widget.session.expire();
      }
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save(Map<String, dynamic> fields) async {
    if (_busy) return;
    final token = widget.session.session?.token;
    if (token == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      if (_create) {
        await widget.repository.create(token, fields);
      } else {
        await widget.repository.update(token, _selected!.id, {
          'version': _selected!.version,
          ...fields,
        });
      }
      if (!mounted || token != widget.session.session?.token) return;
      setState(() {
        _success = _create
            ? 'Cuenta creada. Debe verificar su correo y configurar el autenticador antes de acceder.'
            : 'Cambios guardados. Las sesiones afectadas por cambios de permisos o estado fueron revocadas.';
        _create = false;
        _selected = null;
        _page = 1;
      });
      await _load();
    } on ApiFailure catch (e) {
      if (e.status == 401 && token == widget.session.session?.token) {
        await widget.session.expire();
      }
      if (mounted && token == widget.session.session?.token) {
        setState(
          () => _error = e.fields.isEmpty
              ? e.message
              : e.fields.values.join('\n'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Workspace(
      title: 'Administradores y permisos',
      loading: _loading,
      error: _error,
      onRetry: _busy
          ? null
          : () {
              setState(() {
                _selected = null;
                _create = false;
              });
              _load();
            },
      actions: [
        OutlinedButton(
          onPressed: _busy ? null : () => context.go('/admin-dashboard'),
          child: const Text('Volver a administración'),
        ),
        if (data?.canCreate == true)
          FilledButton(
            key: const Key('admin_create'),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _create = true;
                    _selected = null;
                    _success = null;
                    _error = null;
                  }),
            child: const Text('Crear administrador'),
          ),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  setState(() {
                    _selected = null;
                    _create = false;
                  });
                  _load();
                },
          child: const Text('Actualizar listado'),
        ),
      ],
      children: [
        if (_success != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_success!, key: const Key('admin_success')),
          ),
        if (data != null && (_create || _selected != null))
          AdminEditor(
            key: ValueKey(
              '${_create ? 'new' : _selected!.id}:${_selected?.version}',
            ),
            administrator: _selected,
            listing: data,
            busy: _busy,
            onSave: _save,
            onCancel: () => setState(() {
              _create = false;
              _selected = null;
              _error = null;
            }),
          ),
        if (data != null) ...[
          Text(
            '${data.count} cuentas administrativas · Página ${data.page} de ${((data.count + data.pageSize - 1) ~/ data.pageSize).clamp(1, 100000)}',
          ),
          const SizedBox(height: 16),
          if (data.rows.isEmpty)
            const Text('No hay cuentas administrativas para mostrar.'),
          for (final admin in data.rows)
            WorkspacePanel(
              title: admin.name,
              children: [
                Text(admin.email),
                Text(
                  'Rol: ${admin.role} · Estado: ${admin.active ? 'Activa' : 'Inactiva'}',
                ),
                Text(
                  'Correo: ${admin.verified ? 'Verificado' : 'Pendiente de verificación'} · Doble factor: ${admin.enrolled ? 'Configurado' : 'Pendiente de configuración'}',
                ),
                Text(
                  'Permisos: ${admin.permissions.map((p) => data.catalog[p] ?? p).join(', ')}',
                ),
                if (admin.protected) const Text('Cuenta principal protegida.'),
                OutlinedButton(
                  key: Key('admin_edit_${admin.id}'),
                  onPressed:
                      _busy ||
                          admin.protected ||
                          admin.id == widget.session.session?.id
                      ? null
                      : () => setState(() {
                          _selected = admin;
                          _create = false;
                          _error = null;
                          _success = null;
                        }),
                  child: const Text('Configurar cuenta y permisos'),
                ),
              ],
            ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                key: const Key('admin_previous'),
                onPressed: _busy || data.page <= 1
                    ? null
                    : () {
                        setState(() {
                          _page--;
                          _selected = null;
                          _create = false;
                        });
                        _load();
                      },
                child: const Text('Anterior'),
              ),
              OutlinedButton(
                key: const Key('admin_next'),
                onPressed: _busy || data.page * data.pageSize >= data.count
                    ? null
                    : () {
                        setState(() {
                          _page++;
                          _selected = null;
                          _create = false;
                        });
                        _load();
                      },
                child: const Text('Siguiente'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class AdminEditor extends StatefulWidget {
  const AdminEditor({
    super.key,
    this.administrator,
    required this.listing,
    required this.busy,
    required this.onSave,
    required this.onCancel,
  });
  final Administrator? administrator;
  final AdminListing listing;
  final bool busy;
  final Future<void> Function(Map<String, dynamic>) onSave;
  final VoidCallback onCancel;
  @override
  State<AdminEditor> createState() => _AdminEditorState();
}

class _AdminEditorState extends State<AdminEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.administrator?.name);
  final _email = TextEditingController(), _password = TextEditingController();
  late String _role = widget.administrator?.role ?? 'revisor';
  late bool _active = widget.administrator?.active ?? true;
  late Set<String> _permissions = Set.of(
    widget.administrator?.permissions ?? widget.listing.roles[_role]!,
  );
  bool get _creating => widget.administrator == null;
  bool get _accounts =>
      _creating || widget.listing.myPermissions.contains('manage_admins');
  bool get _authority =>
      _creating || widget.listing.myPermissions.contains('manage_permissions');
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.busy || !(_form.currentState?.validate() ?? false)) return;
    final data = <String, dynamic>{
      if (_accounts) 'full_name': _name.text.trim(),
      if (_accounts) 'is_active': _active,
      if (_authority) 'administrative_role': _role,
      if (_authority) 'permissions': _permissions.toList()..sort(),
      if (_creating) 'email': _email.text.trim(),
      if (_creating) 'password': _password.text,
    };
    await widget.onSave(data);
    if (mounted) _password.clear();
  }

  @override
  Widget build(BuildContext context) => WorkspacePanel(
    title: _creating
        ? 'Nueva cuenta administrativa'
        : 'Configurar ${widget.administrator!.name}',
    children: [
      Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('admin_name'),
              controller: _name,
              enabled: _accounts && !widget.busy,
              maxLength: 150,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Escribe el nombre.' : null,
            ),
            if (_creating) ...[
              TextFormField(
                key: const Key('admin_email'),
                controller: _email,
                enabled: !widget.busy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                validator: (v) =>
                    v == null ||
                        !RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v.trim())
                    ? 'Escribe un correo válido.'
                    : null,
              ),
              TextFormField(
                key: const Key('admin_password'),
                controller: _password,
                enabled: !widget.busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Contraseña inicial privada',
                ),
                validator: (v) => (v?.length ?? 0) < 8
                    ? 'Usa una contraseña segura de al menos ocho caracteres.'
                    : null,
              ),
              const Text(
                'Entrega la contraseña por un canal privado. El nuevo administrador verificará su correo y configurará su autenticador.',
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('admin_role'),
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Rol administrativo',
              ),
              items: const [
                DropdownMenuItem(value: 'revisor', child: Text('Revisor')),
                DropdownMenuItem(value: 'gestor', child: Text('Gestor')),
              ],
              onChanged: !_authority || widget.busy
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() {
                          _role = v;
                          _permissions = _permissions.intersection(
                            widget.listing.roles[v]!,
                          );
                        });
                      }
                    },
            ),
            SwitchListTile(
              key: const Key('admin_active'),
              contentPadding: EdgeInsets.zero,
              title: Text(_active ? 'Cuenta activa' : 'Cuenta inactiva'),
              value: _active,
              onChanged: !_accounts || widget.busy
                  ? null
                  : (v) => setState(() => _active = v),
            ),
            Text(
              'Configuración de permisos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final permission in widget.listing.catalog.entries)
              CheckboxListTile(
                key: Key('admin_permission_${permission.key}'),
                contentPadding: EdgeInsets.zero,
                title: Text(permission.value),
                value: _permissions.contains(permission.key),
                onChanged:
                    !_authority ||
                        widget.busy ||
                        !widget.listing.roles[_role]!.contains(
                          permission.key,
                        ) ||
                        !widget.listing.myPermissions.contains(permission.key)
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _permissions.add(permission.key);
                        } else {
                          _permissions.remove(permission.key);
                        }
                      }),
              ),
            const Text(
              'Cambiar permisos, rol o estado revoca las sesiones de esa cuenta. No puedes modificar tu propia autoridad ni la cuenta principal.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton(
                  key: const Key('admin_save'),
                  onPressed: widget.busy ? null : _save,
                  child: Text(widget.busy ? 'Guardando…' : 'Guardar cambios'),
                ),
                TextButton(
                  onPressed: widget.busy ? null : widget.onCancel,
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final AdminRepository repository;
  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  List<String>? _events;
  bool _loading = true;
  String? _error;
  int _generation = 0;
  String? _identity;
  @override
  void initState() {
    super.initState();
    _identity = widget.session.session?.token;
    widget.session.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_changed);
    _generation++;
    super.dispose();
  }

  void _changed() {
    if (widget.session.session?.token != _identity) {
      _generation++;
      if (mounted) {
        setState(() {
          _events = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    final token = widget.session.session?.token, generation = ++_generation;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _events = null;
    });
    try {
      final events = await widget.repository.events(token);
      if (mounted && generation == _generation) {
        setState(() => _events = events);
      }
    } on ApiFailure catch (e) {
      if (e.status == 401 && token == widget.session.session?.token) {
        await widget.session.expire();
      }
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Eventos administrativos',
    loading: _loading,
    error: _error,
    onRetry: _load,
    actions: [
      OutlinedButton(
        onPressed: () => context.go('/admin-dashboard'),
        child: const Text('Volver a administración'),
      ),
      TextButton(
        onPressed: _loading ? null : _load,
        child: const Text('Actualizar eventos'),
      ),
    ],
    children: [
      const Text(
        'Últimos 50 eventos de cuentas y doble factor. Las decisiones empresariales se conservan en el panel administrativo.',
      ),
      if (_events != null)
        WorkspacePanel(
          title: 'Actividad administrativa',
          children: _events!.isEmpty
              ? [const Text('Todavía no hay eventos administrativos.')]
              : _events!
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(e),
                      ),
                    )
                    .toList(),
        ),
    ],
  );
}
