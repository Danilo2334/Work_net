import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/access/domain/access.dart';
import 'package:worknet/core/widgets/auth_shell.dart';
import 'package:worknet/core/widgets/error_notice.dart';
import 'package:worknet/features/registration/domain/registration.dart';

class RecoveryRequestPage extends StatefulWidget {
  const RecoveryRequestPage({super.key, required this.repository});
  final AccessRepository repository;
  @override
  State<RecoveryRequestPage> createState() => _RecoveryRequestPageState();
}

class _RecoveryRequestPageState extends State<RecoveryRequestPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false, _sent = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.requestRecovery(_email.text);
      if (mounted) setState(() => _sent = true);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.fields['email'] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    headline: 'Recupera tu\nacceso.',
    description: 'Te acompañamos para que puedas volver a tu cuenta.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          _sent ? Icons.mark_email_unread_outlined : Icons.lock_reset,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          _sent ? 'Revisa tu correo' : 'Recuperar contraseña',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Text(
          _sent
              ? 'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña. Revisa también la carpeta de correo no deseado.'
              : 'Escribe el correo de tu cuenta y te enviaremos un enlace de recuperación.',
        ),
        const SizedBox(height: 28),
        if (!_sent)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ErrorNotice(_error),
                TextFormField(
                  key: const Key('recovery_email'),
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: RegistrationValidation.email,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                  onFieldSubmitted: (_) => _request(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('request_recovery'),
                  onPressed: _busy ? null : _request,
                  child: Text(_busy ? 'Solicitando enlace…' : 'Enviar enlace'),
                ),
              ],
            ),
          ),
        if (_sent)
          OutlinedButton(
            onPressed: () => setState(() {
              _sent = false;
              _error = null;
            }),
            child: const Text('Usar otro correo'),
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _busy ? null : () => context.go('/login'),
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    ),
  );
}

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.repository,
    required this.uid,
    required this.token,
    required this.onReset,
  });
  final AccessRepository repository;
  final String? uid, token;
  final Future<void> Function() onReset;
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController(),
      _confirmation = TextEditingController();
  bool _busy = false, _visible = false;
  String? _error;
  Map<String, String> _fields = {};
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _fields = {};
    });
    try {
      await widget.repository.resetPassword(
        widget.uid!,
        widget.token!,
        _password.text,
        _confirmation.text,
      );
      _password.clear();
      _confirmation.clear();
      await widget.onReset();
      if (mounted) context.replace('/password-updated');
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _fields = e.fields;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validLink =
        (widget.uid?.isNotEmpty ?? false) &&
        (widget.token?.isNotEmpty ?? false);
    return AuthShell(
      headline: 'Un nuevo\ncomienzo.',
      description: 'Elige una contraseña segura para proteger tu cuenta.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nueva contraseña',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          if (!validLink)
            const ErrorNotice(
              'El enlace de recuperación no es válido. Solicita uno nuevo.',
            ),
          if (validLink)
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ErrorNotice(_error),
                  TextFormField(
                    key: const Key('new_password'),
                    controller: _password,
                    obscureText: !_visible,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) => value == null || value.length < 8
                        ? 'Usa al menos 8 caracteres.'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      errorText: _fields['new_password'],
                      helperText:
                          'Mínimo 8 caracteres. Evita contraseñas comunes.',
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _visible = !_visible),
                        tooltip: _visible
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        icon: Icon(
                          _visible ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('new_password_confirm'),
                    controller: _confirmation,
                    obscureText: !_visible,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (value) => RegistrationValidation.confirmation(
                      value,
                      _password.text,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                      errorText: _fields['new_password_confirm'],
                    ),
                    onFieldSubmitted: (_) => _confirm(),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const Key('confirm_recovery'),
                    onPressed: _busy ? null : _confirm,
                    child: Text(
                      _busy ? 'Guardando contraseña…' : 'Cambiar contraseña',
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _busy ? null : () => context.go('/forgot-password'),
            child: const Text('Solicitar otro enlace'),
          ),
          TextButton(
            onPressed: _busy ? null : () => context.go('/login'),
            child: const Text('Volver a iniciar sesión'),
          ),
        ],
      ),
    );
  }
}

class PasswordUpdatedPage extends StatelessWidget {
  const PasswordUpdatedPage({super.key});
  @override
  Widget build(BuildContext context) => AuthShell(
    headline: 'Acceso\nrecuperado.',
    description: 'Tu cuenta está lista para continuar.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Contraseña actualizada',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const Text('Ya puedes iniciar sesión con tu nueva contraseña.'),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: const Text('Iniciar sesión'),
        ),
      ],
    ),
  );
}
