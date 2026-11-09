import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/account/domain/account.dart';
import 'package:worknet/core/theme/worknet_theme.dart';
import 'package:worknet/core/widgets/error_notice.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.controller,
    required this.repository,
  });
  final SessionController controller;
  final AccountRepository repository;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _nameForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = true, _busy = false;
  bool _push = false, _savedPush = false;
  AccountInfo? _user;
  Map<String, String> _fields = {};
  String? _loadError, _error, _success;
  String? _operationToken;

  bool _isCurrent(String? token) =>
      mounted && token != null && widget.controller.session?.token == token;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final field in [_name, _current, _newPassword, _confirmation]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final owner = widget.controller.session;
    final token = owner?.token;
    if (!_isCurrent(token)) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await widget.repository.load(owner!);
      if (!_isCurrent(token)) return;
      final user = result.user;
      final push = result.push;
      await widget.controller.update(name: user.name);
      if (!_isCurrent(token)) return;
      setState(() {
        _user = user;
        _name.text = user.name;
        _push = _savedPush = push;
      });
    } on ApiFailure catch (e) {
      if (!_isCurrent(token)) return;
      if (e.status == 401) await widget.controller.expire();
      if (_isCurrent(token)) setState(() => _loadError = e.message);
    } finally {
      if (_isCurrent(token)) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<String> Function(UserSession owner) action) async {
    final owner = widget.controller.session;
    final token = owner?.token;
    if (_busy || !_isCurrent(token)) return;
    _operationToken = token;
    setState(() {
      _busy = true;
      _error = _success = null;
      _fields = {};
    });
    try {
      final message = await action(owner!);
      if (_isCurrent(_operationToken)) setState(() => _success = message);
    } on ApiFailure catch (e) {
      if (!_isCurrent(token)) return;
      if (e.status == 401) await widget.controller.expire();
      if (_isCurrent(token)) {
        setState(() {
          _error = e.fields.isEmpty ? e.message : e.fields.values.join('\n');
          _fields = e.fields;
        });
      }
    } finally {
      if (_isCurrent(_operationToken)) {
        setState(() => _busy = false);
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  Future<void> _saveName() async {
    if (!_nameForm.currentState!.validate()) return;
    await _run((owner) async {
      final user = await widget.repository.rename(owner, _name.text);
      if (!_isCurrent(owner.token)) return '';
      await widget.controller.update(name: user.name);
      if (_isCurrent(owner.token)) {
        setState(() {
          _user = user;
          _name.text = user.name;
        });
      }
      return 'Nombre actualizado correctamente.';
    });
  }

  Future<void> _savePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    await _run((owner) async {
      final token = await widget.repository.changePassword(
        owner.token,
        _current.text,
        _newPassword.text,
        _confirmation.text,
      );
      if (!_isCurrent(owner.token)) return '';
      await widget.controller.update(token: token);
      _operationToken = token;
      if (_isCurrent(token)) {
        _current.clear();
        _newPassword.clear();
        _confirmation.clear();
      }
      return 'Contraseña actualizada. Tu sesión sigue activa.';
    });
  }

  Future<void> _savePreferences() => _run((owner) async {
    final push = await widget.repository.setPush(owner.token, _push);
    if (_isCurrent(owner.token)) setState(() => _push = _savedPush = push);
    return 'Preferencias guardadas correctamente.';
  });

  Future<void> _deleteAccount() async {
    final token = widget.controller.session?.token;
    if (!_isCurrent(token)) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteConfirmation(),
    );
    if (!_isCurrent(token) || password == null) return;
    await _run((owner) async {
      await widget.repository.delete(owner.token, password);
      if (!_isCurrent(owner.token)) return '';
      await widget.controller.expire(announce: false);
      if (mounted && widget.controller.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta eliminada correctamente.')),
        );
      }
      return 'Cuenta eliminada correctamente.';
    });
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Completa este campo.' : null;

  InputDecoration _decoration(String label, String field) =>
      InputDecoration(labelText: label, errorText: _fields[field]);

  Widget _panel(String title, List<Widget> children, {bool danger = false}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: danger ? Colors.red.shade200 : WorkNetColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      );

  Widget _details() => _panel('Información de cuenta', [
    Form(
      key: _nameForm,
      child: TextFormField(
        key: const Key('account_name'),
        controller: _name,
        enabled: !_busy,
        maxLength: 150,
        validator: _required,
        decoration: _decoration('Nombre completo', 'full_name'),
      ),
    ),
    const SizedBox(height: 12),
    const Text('Correo electrónico'),
    SelectableText(_user!.email, key: const Key('account_email')),
    const SizedBox(height: 12),
    Text(
      'Rol: ${switch (_user!.role) {
        'candidato' => 'Candidato',
        'empresa' => 'Empresa',
        _ => 'Administrador',
      }}',
    ),
    Text(
      _user!.verified == true ? 'Correo verificado' : 'Correo sin verificar',
    ),
    const SizedBox(height: 8),
    const Text(
      'El correo, el rol y la verificación son de solo lectura.',
      style: TextStyle(color: WorkNetColors.muted),
    ),
    const SizedBox(height: 20),
    FilledButton(
      onPressed: _busy ? null : _saveName,
      key: const Key('save_account_name'),
      child: const Text('Guardar nombre'),
    ),
  ]);

  Widget _preferences() => _panel('Notificaciones', [
    Material(
      color: Colors.transparent,
      child: SwitchListTile(
        key: const Key('account_push'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Notificaciones push'),
        subtitle: const Text('Elige si deseas recibir estas notificaciones.'),
        value: _push,
        onChanged: _busy ? null : (value) => setState(() => _push = value),
      ),
    ),
    const SizedBox(height: 20),
    FilledButton(
      key: const Key('save_account_preferences'),
      onPressed: _busy || _push == _savedPush ? null : _savePreferences,
      child: const Text('Guardar preferencias'),
    ),
  ]);

  Widget _password() => _panel('Cambiar contraseña', [
    Form(
      key: _passwordForm,
      child: Column(
        children: [
          TextFormField(
            key: const Key('account_current_password'),
            controller: _current,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            validator: _required,
            decoration: _decoration('Contraseña actual', 'current_password'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('account_new_password'),
            controller: _newPassword,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            validator: _required,
            decoration: _decoration('Nueva contraseña', 'new_password'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('account_confirm_password'),
            controller: _confirmation,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) =>
                _required(value) ??
                (value != _newPassword.text
                    ? 'Las contraseñas no coinciden.'
                    : null),
            decoration: _decoration(
              'Confirmar nueva contraseña',
              'new_password_confirm',
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    FilledButton(
      key: const Key('save_account_password'),
      onPressed: _busy ? null : _savePassword,
      child: const Text('Actualizar contraseña'),
    ),
  ]);

  Widget _danger() => widget.controller.session?.role == 'admin'
      ? _panel('Cuenta administrativa protegida', [
          const Text(
            'Las cuentas administrativas no se eliminan desde configuración. Su estado y autoridad se gestionan con los permisos correspondientes.',
          ),
        ])
      : _panel('Eliminar cuenta', [
          const Text(
            'Esta acción eliminará tu cuenta de forma permanente. Te pediremos la contraseña actual y una confirmación antes de continuar.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('request_delete_account'),
            onPressed: _busy ? null : _deleteAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade800,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar mi cuenta'),
          ),
        ], danger: true);

  Widget _pair(Widget left, Widget right) => LayoutBuilder(
    builder: (_, constraints) => constraints.maxWidth >= 800
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 24),
              Expanded(child: right),
            ],
          )
        : Column(children: [left, const SizedBox(height: 24), right]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('close_account'),
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back),
        onPressed: _busy ? null : () => context.go('/login'),
      ),
      title: const Text('Configuración de cuenta'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loadError != null)
                      _panel('No pudimos cargar tu cuenta', [
                        ErrorNotice(_loadError),
                        FilledButton(
                          key: const Key('retry_account'),
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ]),
                    if (_user != null && _loadError == null) ...[
                      const Text(
                        'Administra tu información, seguridad y preferencias.',
                      ),
                      const SizedBox(height: 20),
                      if (_busy) const LinearProgressIndicator(),
                      ErrorNotice(_error),
                      if (_success != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _success!,
                              style: const TextStyle(
                                color: WorkNetColors.green,
                              ),
                            ),
                          ),
                        ),
                      _pair(_details(), _preferences()),
                      const SizedBox(height: 24),
                      _pair(_password(), _danger()),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ),
  );
}

class _DeleteConfirmation extends StatefulWidget {
  const _DeleteConfirmation();
  @override
  State<_DeleteConfirmation> createState() => _DeleteConfirmationState();
}

class _DeleteConfirmationState extends State<_DeleteConfirmation> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _confirmed = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('¿Eliminar tu cuenta?'),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('La eliminación es permanente y no se puede deshacer.'),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('delete_account_password'),
              controller: _password,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
              validator: (value) => value == null || value.isEmpty
                  ? 'Escribe tu contraseña actual.'
                  : null,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('confirm_delete_account'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Confirmo que quiero eliminar mi cuenta.'),
              value: _confirmed,
              onChanged: (value) => setState(() => _confirmed = value == true),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        key: const Key('cancel_delete_account'),
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('submit_delete_account'),
        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
        onPressed: !_confirmed
            ? null
            : () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _password.text);
                }
              },
        child: const Text('Eliminar definitivamente'),
      ),
    ],
  );
}
