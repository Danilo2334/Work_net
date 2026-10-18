import 'package:flutter/material.dart';

import '../../../core/theme/worknet_theme.dart';
import '../../../core/widgets/auth_shell.dart';
import '../data/registration_api.dart';
import '../domain/registration.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key, this.api});

  final RegistrationApi? api;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late final RegistrationApi _api = widget.api ?? RegistrationApi();

  Map<String, String> _serverErrors = {};
  String? _message;
  PublicRole? _role;
  RegisteredUser? _registeredUser;
  bool _choosingRole = false;
  bool _busy = false;
  bool _showPassword = false;
  bool _showConfirmation = false;

  @override
  void dispose() {
    for (final controller in [_fullName, _email, _password, _confirmation]) {
      controller.dispose();
    }
    if (widget.api == null) _api.close();
    super.dispose();
  }

  void _clearServerError(String field) {
    if (!_serverErrors.containsKey(field) && _message == null) return;
    setState(() {
      _serverErrors.remove(field);
      _message = null;
    });
  }

  void _continueToRole() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _choosingRole = true;
      _message = null;
      _serverErrors = {};
    });
  }

  Future<void> _register() async {
    if (_busy || _role == null) return;
    setState(() {
      _busy = true;
      _message = null;
      _serverErrors = {};
    });
    try {
      final registered = await _api.register(
        RegistrationData(
          fullName: _fullName.text,
          email: _email.text,
          password: _password.text,
          passwordConfirmation: _confirmation.text,
          role: _role!,
        ),
      );
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      setState(() => _registeredUser = registered);
    } on RegistrationFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _serverErrors = Map.of(failure.fieldErrors);
        _message = failure.message;
        const dataFields = [
          'full_name',
          'email',
          'password',
          'password_confirm',
        ];
        if (dataFields.any(_serverErrors.containsKey)) _choosingRole = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'No pudimos confirmar el registro. Revisa tu correo '
            'antes de volver a intentarlo.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startAgain() {
    for (final controller in [_fullName, _email, _password, _confirmation]) {
      controller.clear();
    }
    setState(() {
      _registeredUser = null;
      _role = null;
      _choosingRole = false;
      _serverErrors = {};
      _message = null;
      _showPassword = false;
      _showConfirmation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final registered = _registeredUser;
    return AuthShell(
      headline: registered != null
          ? 'Verifica tu\ncorreo.'
          : _choosingRole
          ? 'Un espacio\npara tu\npropósito.'
          : 'Tu próximo\npaso empieza\naquí.',
      description: registered != null
          ? 'Protegemos tu cuenta antes de que continúes.'
          : 'Encuentra oportunidades de empleo o conecta con talento '
                'para tu empresa.',
      child: registered != null
          ? _success(registered)
          : _choosingRole
          ? _roles()
          : _details(),
    );
  }

  Widget _heading(String title, String description, {required String step}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          step,
          style: const TextStyle(
            color: WorkNetColors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(color: WorkNetColors.muted, height: 1.6),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _errorNotice() {
    final error = _message;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            error,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
    );
  }

  Widget _details() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              'Crea tu cuenta',
              'Empieza con tus datos. Después elegirás cómo usar WorkNet.',
              step: 'Paso 1 de 2 · Tus datos',
            ),
            _errorNotice(),
            _field(
              id: 'full_name',
              label: 'Nombre completo',
              controller: _fullName,
              validator: RegistrationValidation.fullName,
              autofillHints: const [AutofillHints.name],
              capitalization: TextCapitalization.words,
            ),
            _field(
              id: 'email',
              label: 'Correo electrónico',
              controller: _email,
              validator: RegistrationValidation.email,
              keyboard: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            _field(
              id: 'password',
              label: 'Contraseña',
              controller: _password,
              validator: RegistrationValidation.password,
              obscure: !_showPassword,
              autofillHints: const [AutofillHints.newPassword],
              helper:
                  'Mínimo 8 caracteres. Evita contraseñas comunes '
                  'o solamente numéricas.',
              suffix: IconButton(
                tooltip: _showPassword
                    ? 'Ocultar contraseña'
                    : 'Mostrar contraseña',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            _field(
              id: 'password_confirm',
              label: 'Confirmar contraseña',
              controller: _confirmation,
              validator: (value) =>
                  RegistrationValidation.confirmation(value, _password.text),
              obscure: !_showConfirmation,
              autofillHints: const [AutofillHints.newPassword],
              action: TextInputAction.done,
              onSubmitted: (_) => _continueToRole(),
              suffix: IconButton(
                tooltip: _showConfirmation
                    ? 'Ocultar confirmación'
                    : 'Mostrar confirmación',
                onPressed: () =>
                    setState(() => _showConfirmation = !_showConfirmation),
                icon: Icon(
                  _showConfirmation ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('continue_registration'),
              onPressed: _continueToRole,
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String id,
    required String label,
    required TextEditingController controller,
    required FormFieldValidator<String> validator,
    List<String>? autofillHints,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    bool obscure = false,
    Widget? suffix,
    String? helper,
  }) {
    final passwordField = id == 'password' || id == 'password_confirm';
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: TextFormField(
        key: Key(id),
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        textCapitalization: capitalization,
        textInputAction: action,
        onFieldSubmitted: onSubmitted,
        autofillHints: autofillHints,
        obscureText: obscure,
        autocorrect: !passwordField && id != 'email',
        enableSuggestions: !passwordField,
        onChanged: (_) => _clearServerError(id),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          errorText: _serverErrors[id],
          suffixIcon: suffix,
          helperText: helper,
          helperMaxLines: 4,
        ),
      ),
    );
  }

  Widget _roles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          '¿Cómo usarás WorkNet?',
          'Elige el rol con el que quieres crear tu cuenta.',
          step: 'Paso 2 de 2 · Tu rol',
        ),
        _errorNotice(),
        _roleCard(
          role: PublicRole.candidate,
          icon: Icons.person_outline_rounded,
          description:
              'Busca oportunidades, crea tu perfil y postúlate con tu CV.',
        ),
        const SizedBox(height: 16),
        _roleCard(
          role: PublicRole.company,
          icon: Icons.business_outlined,
          description:
              'Registra tu organización y solicita la validación '
              'de tu cuenta antes de acceder como empresa.',
        ),
        const SizedBox(height: 28),
        FilledButton(
          key: const Key('submit_registration'),
          onPressed: _busy || _role == null ? null : _register,
          child: _busy
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Flexible(child: Text('Creando tu cuenta…')),
                  ],
                )
              : const Text('Crear cuenta'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          key: const Key('edit_registration'),
          onPressed: _busy
              ? null
              : () => setState(() {
                  _choosingRole = false;
                  _message = null;
                }),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Editar mis datos'),
        ),
      ],
    );
  }

  Widget _roleCard({
    required PublicRole role,
    required IconData icon,
    required String description,
  }) {
    final selected = _role == role;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: Key('role_${role.apiValue}'),
        color: selected ? WorkNetColors.mint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? WorkNetColors.green : WorkNetColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: _busy
              ? null
              : () => setState(() {
                  _role = role;
                  _message = null;
                }),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28, color: WorkNetColors.green),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: const TextStyle(color: WorkNetColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? WorkNetColors.green : WorkNetColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _success(RegisteredUser registered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            Icons.mark_email_unread_outlined,
            size: 60,
            color: WorkNetColors.green,
          ),
        ),
        const SizedBox(height: 24),
        _heading(
          'Revisa tu correo',
          'Tu cuenta fue creada. Enviamos un enlace de verificación a:',
          step: 'Registro completado',
        ),
        SelectableText(
          registered.email,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: WorkNetColors.mint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Abre el enlace del correo para verificar tu dirección. '
            'También puedes revisar tu carpeta de correo no deseado.',
          ),
        ),
        const SizedBox(height: 24),
        Text('Rol de la cuenta: ${registered.role.label}'),
        if (registered.role == PublicRole.company) ...[
          const SizedBox(height: 12),
          const Text(
            'Para acceder como empresa, también deberás registrar '
            'la información de tu organización y solicitar su validación.',
          ),
        ],
        const SizedBox(height: 32),
        OutlinedButton(
          key: const Key('new_registration'),
          onPressed: _startAgain,
          child: const Text('Registrar otra cuenta'),
        ),
      ],
    );
  }
}
