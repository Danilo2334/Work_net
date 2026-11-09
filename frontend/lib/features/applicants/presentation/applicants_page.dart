import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import '../domain/applicant.dart';
import '../domain/applicant_export.dart';

class ApplicantsPage extends StatefulWidget {
  const ApplicantsPage({
    super.key,
    required this.session,
    required this.repository,
    required this.offerId,
    required this.query,
    this.returnToStatistics = false,
    this.exports,
    this.download,
  });
  final SessionController session;
  final ApplicantsRepository repository;
  final int offerId;
  final ApplicantQuery query;
  final bool returnToStatistics;
  final ApplicantExportRepository? exports;
  final ApplicantExportDownload? download;
  @override
  State<ApplicantsPage> createState() => _ApplicantsPageState();
}

class _ApplicantsPageState extends State<ApplicantsPage> {
  late final _experience = TextEditingController(text: widget.query.experience);
  late final _education = TextEditingController(text: widget.query.education);
  late final _skill = TextEditingController(text: widget.query.skill);
  late String _order = widget.query.order;
  final _form = GlobalKey<FormState>();
  ApplicantPage? _data;
  bool _loading = true;
  String? _error;
  int _generation = 0;
  bool _exporting = false;
  String? _exportMessage;
  late String? _activeToken;
  bool get _busy => _loading || _exporting;
  @override
  void initState() {
    super.initState();
    _activeToken = widget.session.session?.token;
    widget.session.addListener(_sessionChanged);
    _load();
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _experience.dispose();
    _education.dispose();
    _skill.dispose();
    super.dispose();
  }

  bool _authorized(String? token) =>
      token != null &&
      widget.session.session?.token == token &&
      widget.session.session?.role == 'empresa';

  void _sessionChanged() {
    if (_activeToken == widget.session.session?.token &&
        _authorized(_activeToken)) {
      return;
    }
    _activeToken = widget.session.session?.token;
    ++_generation;
    if (mounted) {
      setState(() {
        _data = null;
        _exportMessage = null;
        _loading = false;
      });
    }
  }

  Future<void> _export(ApplicantExportType type) async {
    final token = widget.session.session?.token;
    if (_busy ||
        !_authorized(token) ||
        (_data?.count ?? 0) == 0 ||
        widget.exports == null ||
        widget.download == null) {
      return;
    }
    final generation = _generation;
    setState(() {
      _exporting = true;
      _exportMessage = null;
    });
    try {
      final file = await widget.exports!.export(
        token!,
        widget.offerId,
        widget.query,
        type,
      );
      if (!mounted || generation != _generation || !_authorized(token)) return;
      final saved = await widget.download!.save(file);
      if (!mounted || generation != _generation || !_authorized(token)) return;
      setState(
        () => _exportMessage = saved
            ? 'Descarga solicitada: ${file.count} coincidencias en ${type.name.toUpperCase()}.'
            : 'Descarga cancelada. Puedes intentarlo de nuevo.',
      );
    } on ApiFailure catch (e) {
      if (!mounted || generation != _generation || !_authorized(token)) return;
      if (e.status == 401) {
        await widget.session.expire();
        return;
      }
      setState(
        () => _exportMessage = [e.message, ...e.fields.values].join('\n'),
      );
    } catch (_) {
      if (mounted && generation == _generation && _authorized(token)) {
        setState(
          () => _exportMessage =
              'No pudimos guardar el archivo. Inténtalo de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _load() async {
    final token = widget.session.session?.token;
    if (token == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _exportMessage = null;
      _data = null;
    });
    try {
      final data = await widget.repository.applicants(
        token,
        widget.offerId,
        widget.query,
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
      if (e.status == 400 &&
          e.fields.containsKey('page') &&
          widget.query.page > 1) {
        _navigate(widget.query.at(1));
        return;
      }
      setState(() => _error = [e.message, ...e.fields.values].join('\n'));
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _navigate(ApplicantQuery query) {
    if (query.location(widget.offerId) ==
        widget.query.location(widget.offerId)) {
      _load();
      return;
    }
    context.replace(
      query.location(widget.offerId),
      extra: widget.returnToStatistics ? 'statistics' : null,
    );
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    _navigate(
      ApplicantQuery(
        experience: _experience.text.trim(),
        education: _education.text.trim(),
        skill: _skill.text.trim(),
        order: _order,
      ),
    );
  }

  void _clear() {
    _experience.clear();
    _education.clear();
    _skill.clear();
    setState(() => _order = 'newest');
    _navigate(const ApplicantQuery());
  }

  Future<void> _open(Applicant item) async {
    await context.push(
      '/company/offers/${widget.offerId}/applicants/${item.application.id}',
    );
    if (mounted) await _load();
  }

  Widget _field(TextEditingController c, String label, String helper) =>
      TextFormField(
        controller: c,
        maxLength: 100,
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: (value) {
          if ((value ?? '').length > 100) return 'Máximo 100 caracteres.';
          if ((value ?? '').runes.any((c) => c < 32 || c == 127)) {
            return 'Escribe texto sin caracteres de control.';
          }
          return null;
        },
      );
  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Postulantes de la oferta',
    loading: _loading,
    error: _error,
    onRetry: _loading ? null : _load,
    actions: [
      TextButton(
        onPressed: () => context.go('/company/applicants'),
        child: const Text('Seleccionar otra oferta'),
      ),
      TextButton(
        onPressed: () {
          if (widget.returnToStatistics && context.canPop()) {
            context.pop();
          } else {
            context.go(
              widget.returnToStatistics ? '/statistics' : '/company-dashboard',
            );
          }
        },
        child: Text(
          widget.returnToStatistics
              ? 'Volver a estadísticas'
              : 'Volver al dashboard',
        ),
      ),
      TextButton(
        onPressed: _busy ? null : _load,
        child: const Text('Actualizar postulantes'),
      ),
    ],
    children: [
      WorkspacePanel(
        title: 'Filtrar por perfil actual',
        children: [
          const Text(
            'Coincidencia por fragmento, sin distinguir mayúsculas o tildes. Los filtros se combinan. El CV enviado se conserva aunque cambie el perfil actual.',
          ),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (_, constraints) {
                    final width = constraints.maxWidth >= 800
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: _field(
                            _experience,
                            'Experiencia',
                            'Puesto, empresa o descripción',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _field(
                            _education,
                            'Educación',
                            'Título o institución',
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _field(
                            _skill,
                            'Habilidad',
                            'Nombre de la habilidad',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _order,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Orden'),
                  items: [
                    for (final e in applicantOrders.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _order = v!),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _busy ? null : _apply,
                      child: const Text('Aplicar filtros'),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _clear,
                      child: const Text('Limpiar filtros'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      if (_loading) const Text('Cargando postulantes…'),
      if (_data case final data?) ...[
        WorkspacePanel(
          title: data.offer.title,
          children: [
            Text('${data.count} postulantes encontrados'),
            if (widget.exports != null && widget.download != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Exportar todas las coincidencias de los filtros aplicados, en el mismo orden, hasta 5.000 registros. Incluye todas las páginas. Aplica primero los cambios de filtros u orden.',
              ),
              const Text(
                'El archivo contiene nombre, fecha, estado y nombre del CV enviado; no incluye documentos ni datos de contacto. Fecha en UTC. El CSV protege las celdas que podrían interpretarse como fórmulas.',
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final type in ApplicantExportType.values)
                    OutlinedButton(
                      onPressed: _busy || data.count == 0
                          ? null
                          : () => _export(type),
                      child: Text('Exportar ${type.name.toUpperCase()}'),
                    ),
                ],
              ),
              if (_exporting) const Text('Preparando descarga…'),
              if (_exportMessage != null)
                Text(_exportMessage!, key: const Key('export_result')),
            ],
            if (!data.offer.active)
              const Text(
                'Oferta no activa. Las postulaciones y sus documentos enviados se conservan.',
              ),
          ],
        ),
        if (data.applicants.isEmpty)
          const Text('No hay postulantes que coincidan con esta consulta.'),
        for (final item in data.applicants)
          WorkspacePanel(
            title: item.nameLabel,
            children: [
              Text('Fecha: ${item.application.dateLabel} (hora local)'),
              Text('Estado de postulación: ${item.application.status.label}'),
              Text(
                item.application.cv == null
                    ? 'Esta postulación anterior no tiene un CV registrado.'
                    : 'CV enviado: ${item.application.cv!.filename}',
              ),
              OutlinedButton(
                key: Key('applicant_detail_${item.application.id}'),
                onPressed: () => _open(item),
                child: const Text('Ver perfil y CV'),
              ),
            ],
          ),
        if (data.pages > 0)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _busy || data.previous == null
                    ? null
                    : () => _navigate(widget.query.at(data.previous!)),
                child: const Text('Anterior'),
              ),
              Text('Página ${data.page} de ${data.pages}'),
              OutlinedButton(
                onPressed: _busy || data.next == null
                    ? null
                    : () => _navigate(widget.query.at(data.next!)),
                child: const Text('Siguiente'),
              ),
            ],
          ),
      ],
    ],
  );
}
