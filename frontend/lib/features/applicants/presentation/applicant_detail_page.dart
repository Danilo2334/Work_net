import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/applications/presentation/application_document.dart';
import 'package:worknet/features/profile/domain/profile.dart';
import '../domain/applicant.dart';
import 'package:worknet/features/status_changes/domain/status_change.dart';
import 'package:worknet/features/status_changes/presentation/status_change_panel.dart';
import 'package:worknet/features/messages/domain/message.dart';
import 'package:worknet/features/messages/presentation/message_access.dart';

class ApplicantDetailPage extends StatefulWidget {
  const ApplicantDetailPage({
    super.key,
    required this.session,
    required this.repository,
    required this.statuses,
    required this.offerId,
    required this.id,
    this.messages,
  });
  final SessionController session;
  final ApplicantsRepository repository;
  final StatusRepository statuses;
  final MessagesRepository? messages;
  final int offerId, id;
  @override
  State<ApplicantDetailPage> createState() => _ApplicantDetailPageState();
}

class _ApplicantDetailPageState extends State<ApplicantDetailPage> {
  ApplicantDetail? _data;
  bool _loading = true;
  String? _error;
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
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.detail(
        token,
        widget.offerId,
        widget.id,
      );
      if (mounted &&
          generation == _generation &&
          widget.session.session?.token == token) {
        setState(() => _data = data);
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
      context.go('/company/offers/${widget.offerId}/applicants');
    }
  }

  String _record(Map<String, dynamic> row) => [
    for (final key in [
      'position',
      'company',
      'qualification',
      'institution',
      'name',
      'level',
      'start_date',
      'end_date',
      'description',
    ])
      if (row[key] is String && (row[key] as String).trim().isNotEmpty)
        row[key] as String,
  ].join(' · ');
  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Detalle del postulante',
    loading: _loading,
    error: _error,
    onRetry: _loading ? null : _load,
    actions: [
      TextButton(onPressed: _back, child: const Text('Volver a postulantes')),
      TextButton(
        onPressed: _loading ? null : _load,
        child: const Text('Actualizar detalle'),
      ),
    ],
    children: [
      if (_loading) const Text('Cargando perfil y postulación…'),
      if (_data case final data?) ...[
        WorkspacePanel(
          title: data.applicant.nameLabel,
          children: [
            Text(data.applicant.application.offer.title),
            ApplicationDetails(
              application: data.applicant.application,
              session: widget.session,
              repository: widget.repository,
            ),
            if (widget.messages case final repository?)
              StartConversationButton(
                session: widget.session,
                repository: repository,
                applicationId: widget.id,
                label: 'Conversar con el candidato',
              ),
          ],
        ),
        StatusChangePanel(
          session: widget.session,
          repository: widget.statuses,
          id: widget.id,
          onChanged: _load,
        ),
        WorkspacePanel(
          title: 'Perfil actual del candidato',
          children: [
            const Text(
              'Datos actuales del perfil. El CV anterior se consulta con Ver CV enviado y mantiene el documento original de esta postulación.',
            ),
            if (!data.profile.exists)
              const Text(
                'El candidato todavía no tiene un perfil profesional guardado.',
              ),
            if (data.profile.summary.isNotEmpty) Text(data.profile.summary),
            for (final section in profileSections.entries) ...[
              const SizedBox(height: 16),
              Text(
                section.value.$1,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (data.profile.entries[section.key]!.isEmpty)
                const Text('Sin información registrada.'),
              for (final row in data.profile.entries[section.key]!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(_record(row)),
                ),
            ],
          ],
        ),
      ],
    ],
  );
}
