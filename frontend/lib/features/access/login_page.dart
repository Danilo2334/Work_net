import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/worknet_api.dart';
import '../../core/widgets/auth_shell.dart';
import '../../core/widgets/error_notice.dart';
import '../registration/domain/registration.dart';
import 'session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final SessionController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _remember = false, _visible = false, _busy = false;
  String? _error;
  Map<String, String> _fields = {};
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy ||
        widget.controller.restoring ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _fields = {};
    });
    try {
      await widget.controller.login(
        _email.text,
        _password.text,
        remember: _remember,
      );
      _password.clear();
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) => AuthShell(
    headline: 'Tu próximo\npaso te\nespera.',
    description:
        'Vuelve a tus oportunidades y continúa construyendo tu futuro.',
    child: Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bienvenido de nuevo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text('Inicia sesión para continuar en WorkNet.'),
            const SizedBox(height: 28),
            ErrorNotice(_error ?? widget.controller.notice),
            TextFormField(
              key: const Key('login_email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: RegistrationValidation.email,
              onChanged: (_) => setState(() {
                _fields.remove('email');
                _error = null;
              }),
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                errorText: _fields['email'],
              ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              key: const Key('login_password'),
              controller: _password,
              enabled: !_busy,
              obscureText: !_visible,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: const [AutofillHints.password],
              validator: (value) => value == null || value.isEmpty
                  ? 'Escribe tu contraseña.'
                  : null,
              onChanged: (_) => setState(() {
                _fields.remove('password');
                _error = null;
              }),
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                errorText: _fields['password'],
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
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                key: const Key('remember_session'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Recordar sesión'),
                value: _remember,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _remember = value ?? false),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => context.go('/forgot-password'),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('submit_login'),
              onPressed: _busy || widget.controller.restoring ? null : _login,
              child: Text(
                _busy
                    ? 'Iniciando sesión…'
                    : widget.controller.restoring
                    ? 'Restaurando sesión…'
                    : 'Iniciar sesión',
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _busy ? null : () => context.go('/register'),
              child: const Text('¿Aún no tienes cuenta? Regístrate'),
            ),
          ],
        ),
      ),
    ),
  );
}
