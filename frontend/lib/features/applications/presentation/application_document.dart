import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/curriculum/presentation/private_pdf_view.dart';

import '../domain/application.dart';

class ApplicationDocument extends StatefulWidget {
  const ApplicationDocument({
    super.key,
    required this.session,
    required this.repository,
    required this.application,
  });
  final SessionController session;
  final ApplicationsRepository repository;
  final JobApplication application;
  @override
  State<ApplicationDocument> createState() => _ApplicationDocumentState();
}

class _ApplicationDocumentState extends State<ApplicationDocument> {
  Uint8List? _bytes;
  String? _error;
  bool _loading = true;
  late final String? _token = widget.session.session?.token;
  @override
  void initState() {
    super.initState();
    widget.session.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (widget.session.session?.token != _token) {
      _bytes = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _bytes = null;
    super.dispose();
  }

  Future<void> _load() async {
    if (_token == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _bytes = null;
    });
    try {
      final data = await widget.repository.pdf(_token, widget.application.id);
      if (mounted && widget.session.session?.token == _token) {
        setState(() => _bytes = data);
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
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 900,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('CV enviado: ${widget.application.cv?.filename ?? ''}'),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('Reintentar PDF'),
              ),
            ],
            if (_bytes != null && widget.session.session?.token == _token)
              PrivatePdfView(bytes: _bytes!),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar documento'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ApplicationDetails extends StatelessWidget {
  const ApplicationDetails({
    super.key,
    required this.application,
    required this.session,
    required this.repository,
  });
  final JobApplication application;
  final SessionController session;
  final ApplicationsRepository repository;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(application.offer.company),
      Text('${application.offer.location} · ${application.offer.contract}'),
      Text('Fecha: ${application.dateLabel} (hora local)'),
      const Text('Estado de postulación: Enviada'),
      if (!application.offer.active)
        const Text(
          'La oferta ya no está activa. Tu postulación y el CV enviado se conservan.',
        ),
      if (application.cv case final cv?) ...[
        Text('${cv.typeLabel}: ${cv.filename}'),
        OutlinedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => ApplicationDocument(
              session: session,
              repository: repository,
              application: application,
            ),
          ),
          child: const Text('Ver CV enviado'),
        ),
      ] else
        const Text('Esta postulación anterior no tiene un CV registrado.'),
    ],
  );
}
