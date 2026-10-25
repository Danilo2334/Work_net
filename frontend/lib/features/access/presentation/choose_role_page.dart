import 'package:flutter/material.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/auth_shell.dart';
import 'package:worknet/core/widgets/error_notice.dart';
import 'package:worknet/features/access/domain/access.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

class ChooseRolePage extends StatefulWidget {
  const ChooseRolePage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final AccessRepository repository;
  @override
  State<ChooseRolePage> createState() => _ChooseRolePageState();
}

class _ChooseRolePageState extends State<ChooseRolePage> {
  bool _busy = false;
  String? _error;
  Future<void> _choose(String role) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.chooseRole(
        widget.session.session!.token,
        role,
      );
      await widget.session.update(role: saved);
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
    headline: 'Elige tu\ncamino.',
    description: 'Tu cuenta ya está creada y tu correo verificado.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Cómo usarás WorkNet?',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 24),
        ErrorNotice(_error),
        FilledButton(
          onPressed: _busy ? null : () => _choose('candidato'),
          child: const Text('Candidato'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _busy ? null : () => _choose('empresa'),
          child: const Text('Empresa'),
        ),
      ],
    ),
  );
}
