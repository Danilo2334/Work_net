import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/company/domain/company.dart';

class CompanyReviewsPage extends StatefulWidget {
  const CompanyReviewsPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final CompanyRepository repository;
  @override
  State<CompanyReviewsPage> createState() => _CompanyReviewsPageState();
}

class _CompanyReviewsPageState extends State<CompanyReviewsPage> {
  CompanyListing? _data;
  bool _loading = true, _busy = false;
  String? _error, _success;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([int? page]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.pending(
        widget.session.session!.token,
        page ?? _data?.page ?? 1,
      );
      if (mounted) setState(() => _data = data);
    } on ApiFailure catch (e) {
      if (e.status == 401) await widget.session.expire();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(CompanyInfo company, bool approve) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReviewDialog(approve: approve, name: company.draft.name),
    );
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await ReviewCompany(widget.repository)(
        widget.session.session!.token,
        company,
        approve: approve,
        reason: reason,
      );
      if (mounted) {
        setState(
          () => _success = approve
              ? 'Empresa aprobada.'
              : 'Solicitud rechazada y motivo registrado.',
        );
      }
      await _load(1);
    } on ApiFailure catch (e) {
      if (e.status == 401) await widget.session.expire();
      if (mounted) {
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
  Widget build(BuildContext context) => Workspace(
    title: 'Solicitudes de empresas',
    loading: _loading,
    error: _error,
    onRetry: () => _load(),
    actions: [
      TextButton(
        onPressed: () => context.go('/admin-dashboard'),
        child: const Text('Volver a administración'),
      ),
      TextButton(
        onPressed: _loading || _busy ? null : () => _load(),
        child: const Text('Actualizar listado'),
      ),
    ],
    children: [
      if (_success != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(_success!),
        ),
      if (_data != null && !_loading) ...[
        Text('${_data!.count} solicitudes pendientes'),
        const SizedBox(height: 16),
        if (_data!.companies.isEmpty)
          const WorkspacePanel(
            title: 'Sin solicitudes',
            children: [Text('No hay solicitudes pendientes en esta página.')],
          ),
        for (final c in _data!.companies)
          WorkspacePanel(
            title: c.draft.name,
            children: [
              Text('NIT: ${c.draft.taxId}'),
              Text('Sector: ${c.draft.sector}'),
              Text('Ubicación: ${c.draft.location}'),
              SelectableText('Correo: ${c.draft.email}'),
              const SizedBox(height: 12),
              Text(c.draft.description),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    key: Key('approve_company_${c.id}'),
                    onPressed: _busy ? null : () => _review(c, true),
                    child: const Text('Aprobar'),
                  ),
                  OutlinedButton(
                    key: Key('reject_company_${c.id}'),
                    onPressed: _busy ? null : () => _review(c, false),
                    child: const Text('Rechazar con motivo'),
                  ),
                ],
              ),
            ],
          ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: _busy || _data!.page <= 1
                  ? null
                  : () => _load(_data!.page - 1),
              child: const Text('Anterior'),
            ),
            Text('Página ${_data!.page}'),
            OutlinedButton(
              onPressed: _busy || !_data!.hasNext
                  ? null
                  : () => _load(_data!.page + 1),
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ],
    ],
  );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.approve, required this.name});
  final bool approve;
  final String name;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.approve ? '¿Aprobar empresa?' : 'Motivo del rechazo'),
    scrollable: true,
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.name),
          if (!widget.approve) ...[
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('review_reason'),
              controller: _reason,
              maxLines: 4,
              maxLength: 2000,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Escribe el motivo del rechazo.'
                  : null,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('confirm_company_review'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _reason.text);
          }
        },
        child: Text(
          widget.approve ? 'Confirmar aprobación' : 'Confirmar rechazo',
        ),
      ),
    ],
  );
}
