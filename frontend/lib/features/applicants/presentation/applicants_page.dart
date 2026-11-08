import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import '../domain/applicant.dart';

class ApplicantsPage extends StatefulWidget {
  const ApplicantsPage({
    super.key,
    required this.session,
    required this.repository,
    required this.offerId,
    required this.query,
  });
  final SessionController session;
  final ApplicantsRepository repository;
  final int offerId;
  final ApplicantQuery query;
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
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _experience.dispose();
    _education.dispose();
    _skill.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = widget.session.session?.token;
    if (token == null) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
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
    context.replace(query.location(widget.offerId));
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
        onPressed: () => context.go('/company-dashboard'),
        child: const Text('Volver al dashboard'),
      ),
      TextButton(
        onPressed: _loading ? null : _load,
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
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _order = v!),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _loading ? null : _apply,
                      child: const Text('Aplicar filtros'),
                    ),
                    OutlinedButton(
                      onPressed: _loading ? null : _clear,
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
                onPressed: data.previous == null
                    ? null
                    : () => _navigate(widget.query.at(data.previous!)),
                child: const Text('Anterior'),
              ),
              Text('Página ${data.page} de ${data.pages}'),
              OutlinedButton(
                onPressed: data.next == null
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
