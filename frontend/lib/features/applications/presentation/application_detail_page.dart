import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import '../domain/application.dart';
import 'application_document.dart';
import 'package:worknet/features/messages/domain/message.dart';
import 'package:worknet/features/messages/presentation/message_access.dart';

class ApplicationDetailPage extends StatefulWidget {
  const ApplicationDetailPage({
    super.key,
    required this.session,
    required this.repository,
    required this.id,
    this.messages,
  });
  final SessionController session;
  final ApplicationsRepository repository;
  final int id;
  final MessagesRepository? messages;
  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  JobApplication? _data;
  String? _error;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.session.session?.token;
    if (token == null) return;
    final generation = ++_generation;
    setState(() {
      _data = null;
      _error = null;
      _loading = true;
    });
    try {
      final item = await widget.repository.detail(token, widget.id);
      if (mounted &&
          generation == _generation &&
          widget.session.session?.token == token) {
        setState(() => _data = item);
      }
    } on ApiFailure catch (e) {
      if (!mounted ||
          generation != _generation ||
          widget.session.session?.token != token) {
        return;
      }
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/applications');
    }
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Detalle de postulación',
    loading: _loading,
    error: _error,
    onRetry: _loading ? null : _load,
    actions: [
      TextButton(onPressed: _back, child: const Text('Volver al historial')),
      TextButton(
        onPressed: _loading ? null : _load,
        child: const Text('Actualizar detalle'),
      ),
    ],
    children: [
      if (_loading) const Text('Cargando detalle…'),
      if (_data case final item?)
        WorkspacePanel(
          title: item.offer.title,
          children: [
            Text('Postulación #${item.id}'),
            ApplicationDetails(
              application: item,
              session: widget.session,
              repository: widget.repository,
            ),
            if (widget.messages case final repository?)
              StartConversationButton(
                session: widget.session,
                repository: repository,
                applicationId: item.id,
                label: 'Conversar con la empresa',
              ),
          ],
        ),
    ],
  );
}
