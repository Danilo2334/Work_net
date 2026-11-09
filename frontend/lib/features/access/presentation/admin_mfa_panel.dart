import 'package:flutter/material.dart';
import 'package:worknet/core/widgets/auth_shell.dart';
import 'package:worknet/core/widgets/error_notice.dart';
import 'package:worknet/features/access/domain/admin_mfa.dart';
import 'package:worknet/core/domain/failure.dart';

import 'session_controller.dart';

class AdminMfaPanel extends StatefulWidget {
  const AdminMfaPanel({
    super.key,
    required this.challenge,
    required this.controller,
    required this.remember,
    required this.onCancel,
  });
  final MfaRequired challenge;
  final SessionController controller;
  final bool remember;
  final VoidCallback onCancel;
  @override
  State<AdminMfaPanel> createState() => _AdminMfaPanelState();
}

class _AdminMfaPanelState extends State<AdminMfaPanel> {
  late MfaRequired _challenge = widget.challenge;
  final _code = TextEditingController();
  MfaSetup? _setup;
  MfaResult? _result;
  bool _busy = false,
      _showSecret = false,
      _showRecovery = false,
      _recovery = false,
      _saved = false;
  String? _error;
  @override
  void dispose() {
    _code.dispose();
    _setup = null;
    _result = null;
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on MfaRequired catch (next) {
      if (mounted) {
        setState(() {
          _challenge = next;
          _setup = null;
          _result = null;
          _recovery = false;
          _showSecret = false;
        });
      }
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() => _run(() async {
    final code = _code.text.trim();
    if (!_recovery && !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ApiFailure('Escribe los seis dígitos del autenticador.');
    }
    if (_recovery && !RegExp(r'^[0-9a-f]{32}$').hasMatch(code)) {
      throw const ApiFailure('Escribe un código de recuperación completo.');
    }
    final result = await widget.controller.mfa!.verifyMfa(
      _challenge.challenge,
      code,
      recovery: _recovery,
    );
    _code.clear();
    _setup = null;
    _showSecret = false;
    if (!mounted) return;
    if (result.recoveryCodes.isEmpty) {
      await widget.controller.completeMfa(
        result.session,
        remember: widget.remember,
      );
    } else {
      setState(() => _result = result);
    }
  });

  @override
  Widget build(BuildContext context) => AuthShell(
    headline: 'Protege tu\nacceso\nadministrativo.',
    description:
        'El segundo factor es obligatorio para todas las cuentas administrativas.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _result != null
              ? 'Autenticador confirmado'
              : _challenge.enrollment
              ? 'Configurar doble factor'
              : 'Verificar doble factor',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 18),
        ErrorNotice(_error),
        if (_result != null) ...[
          const Text(
            'Guarda tus ocho códigos de recuperación en un lugar privado. Cada código solo sirve una vez y permite sustituir un autenticador perdido. Esta es la única vez que se muestran.',
          ),
          TextButton(
            key: const Key('mfa_show_recovery'),
            onPressed: _busy
                ? null
                : () => setState(() => _showRecovery = !_showRecovery),
            child: Text(
              _showRecovery
                  ? 'Ocultar códigos privados'
                  : 'Mostrar códigos privados',
            ),
          ),
          if (_showRecovery)
            SelectableText(
              _result!.recoveryCodes.join('\n'),
              key: const Key('mfa_private_recovery'),
            ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              key: const Key('mfa_codes_saved'),
              contentPadding: EdgeInsets.zero,
              value: _saved,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _saved = v ?? false),
              title: const Text('He guardado mis códigos de recuperación.'),
            ),
          ),
          FilledButton(
            key: const Key('mfa_continue'),
            onPressed: !_saved || _busy
                ? null
                : () => _run(
                    () => widget.controller.completeMfa(
                      _result!.session,
                      remember: widget.remember,
                    ),
                  ),
            child: const Text('Continuar a administración'),
          ),
        ] else ...[
          Text(
            _challenge.enrollment
                ? 'En tu aplicación de autenticación, añade una cuenta TOTP llamada WorkNet. Introduce su clave privada y después el código de seis dígitos. No compartas la clave ni hagas capturas de ella.'
                : 'Introduce el código de seis dígitos de tu autenticador. El acceso dura un máximo de doce horas.',
          ),
          const SizedBox(height: 16),
          if (_challenge.enrollment) ...[
            OutlinedButton(
              key: const Key('mfa_setup'),
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      final setup = await widget.controller.mfa!.setupMfa(
                        _challenge.challenge,
                      );
                      if (mounted) setState(() => _setup = setup);
                    }),
              child: const Text('Preparar autenticador'),
            ),
            if (_setup != null) ...[
              TextButton(
                key: const Key('mfa_show_secret'),
                onPressed: _busy
                    ? null
                    : () => setState(() => _showSecret = !_showSecret),
                child: Text(
                  _showSecret
                      ? 'Ocultar clave privada'
                      : 'Mostrar clave privada',
                ),
              ),
              if (_showSecret)
                SelectableText(
                  _setup!.secret,
                  key: const Key('mfa_private_secret'),
                ),
              const Text('TOTP · 6 dígitos · 30 segundos · SHA-1'),
            ],
          ],
          TextField(
            key: const Key('mfa_code'),
            controller: _code,
            enabled: !_busy,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            keyboardType: _recovery ? TextInputType.text : TextInputType.number,
            decoration: InputDecoration(
              labelText: _recovery
                  ? 'Código de recuperación privado'
                  : 'Código del autenticador',
            ),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('mfa_verify'),
            onPressed: _busy || (_challenge.enrollment && _setup == null)
                ? null
                : _verify,
            child: Text(_busy ? 'Verificando…' : 'Verificar segundo factor'),
          ),
          if (!_challenge.enrollment)
            TextButton(
              key: const Key('mfa_use_recovery'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _recovery = !_recovery;
                      _code.clear();
                      _error = null;
                    }),
              child: Text(
                _recovery ? 'Usar autenticador' : 'Perdí mi autenticador',
              ),
            ),
          if (_recovery)
            const Text(
              'Necesitas un código guardado. Se revocarán tus sesiones y tendrás que configurar y verificar un nuevo autenticador; el doble factor seguirá siendo obligatorio.',
            ),
          const SizedBox(height: 12),
          Text(
            'La autorización vence a las ${_challenge.expiresAt.toLocal().hour.toString().padLeft(2, '0')}:${_challenge.expiresAt.toLocal().minute.toString().padLeft(2, '0')}. Si caduca, vuelve a ingresar.',
          ),
        ],
        TextButton(
          key: const Key('mfa_cancel'),
          onPressed: _busy ? null : widget.onCancel,
          child: const Text('Volver a ingresar'),
        ),
      ],
    ),
  );
}
