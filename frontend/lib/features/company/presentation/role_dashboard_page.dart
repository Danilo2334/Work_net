import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/company/domain/company.dart';

class RoleDashboardPage extends StatefulWidget {
  const RoleDashboardPage({
    super.key,
    required this.session,
    required this.repository,
    required this.admin,
  });
  final SessionController session;
  final CompanyRepository repository;
  final bool admin;
  @override
  State<RoleDashboardPage> createState() => _RoleDashboardPageState();
}

class _RoleDashboardPageState extends State<RoleDashboardPage> {
  WorkspaceSummary? _data;
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = widget.session.session!.token;
      final data = await (widget.admin
          ? widget.repository.adminSummary(token)
          : widget.repository.companySummary(token));
      if (mounted) setState(() => _data = data);
    } on ApiFailure catch (e) {
      if (e.status == 401) await widget.session.expire();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await widget.session.logout();
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _list(String title, List<String> rows, String empty) => WorkspacePanel(
    title: title,
    children: rows.isEmpty
        ? [Text(empty)]
        : rows
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(s),
                ),
              )
              .toList(),
  );
  @override
  Widget build(BuildContext context) {
    final d = _data;
    final labels = widget.admin
        ? {
            'candidates': 'Candidatos registrados',
            'companies': 'Empresas registradas',
            'pending_companies': 'Solicitudes pendientes',
          }
        : {
            'active_offers': 'Ofertas activas',
            'closed_offers': 'Ofertas cerradas',
            'applications': 'Postulaciones recibidas',
          };
    return Workspace(
      title: widget.admin ? 'Administración' : 'Dashboard de empresa',
      loading: _loading,
      error: _error,
      onRetry: _load,
      actions: [
        OutlinedButton(
          onPressed: _busy ? null : _logout,
          child: const Text('Cerrar sesión'),
        ),
        TextButton(
          onPressed: () => context.go('/account'),
          child: const Text('Configuración de cuenta'),
        ),
        if (widget.admin)
          FilledButton(
            key: const Key('open_company_reviews'),
            onPressed: () => context.go('/company-reviews'),
            child: const Text('Revisar empresas'),
          )
        else
          TextButton(
            onPressed: () => context.go('/company'),
            child: const Text('Información de empresa'),
          ),
        TextButton(
          onPressed: _loading ? null : _load,
          child: const Text('Actualizar datos'),
        ),
      ],
      children: [
        if (d != null && !_loading) ...[
          WorkspacePanel(
            title: 'Resumen de actividad',
            children: [
              for (final e in labels.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '${e.value}: ${d.metrics[e.key]}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
          if (!widget.admin)
            _list(
              'Postulaciones recientes',
              d.applications,
              'Todavía no has recibido postulaciones.',
            ),
          _list('Avisos', d.notices, 'No tienes avisos nuevos.'),
          if (widget.admin)
            _list(
              'Eventos de validación empresarial',
              d.events,
              'Todavía no hay eventos de validación.',
            ),
          WorkspacePanel(
            title: 'Próximas funciones',
            children: [
              Text(
                widget.admin
                    ? 'La gestión de administradores y permisos todavía no está disponible. La revisión de empresas está habilitada arriba.'
                    : 'La creación y gestión de ofertas, la gestión de postulantes, los mensajes y las estadísticas todavía no están disponibles.',
              ),
            ],
          ),
        ],
      ],
    );
  }
}
