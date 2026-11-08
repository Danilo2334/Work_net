import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/curriculum/domain/generated_curriculum.dart';
import 'package:worknet/features/profile/domain/profile.dart';
import 'package:worknet/features/profile/presentation/profile_record_editor.dart';
import 'package:worknet/features/registration/domain/registration.dart';
import 'generated_curriculum_controller.dart';
import 'generated_record_editor.dart';
import 'private_pdf_view.dart';

class GeneratedCurriculumPage extends StatefulWidget {
  const GeneratedCurriculumPage({
    super.key,
    required this.session,
    required this.repository,
    required this.download,
    this.returnToOfferId,
  });
  final SessionController session;
  final GeneratedCurriculumRepository repository;
  final CurriculumDownload download;
  final int? returnToOfferId;
  @override
  State<GeneratedCurriculumPage> createState() =>
      GeneratedCurriculumPageState();
}

class GeneratedCurriculumPageState extends State<GeneratedCurriculumPage> {
  late final _controller = GeneratedCurriculumController(
    widget.repository,
    widget.session,
    widget.download,
  );
  final _form = GlobalKey<FormState>();
  int _formVersion = 0;
  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> confirmLeave() async {
    if (widget.session.session == null) return true;
    if (_controller.busy) return false;
    if (!_controller.dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content: const Text(
              'Si sales, perderás la edición que todavía no has guardado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Seguir editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salir sin guardar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _reload() async {
    if (!await confirmLeave() || !mounted) return;
    await _controller.load();
    if (mounted) setState(() => ++_formVersion);
  }

  void _text(String key, String value, {bool personal = false}) {
    final data = _controller.draft!.data;
    if (personal) {
      data['personal'][key] = value;
    } else {
      data[key] = value;
    }
    _controller.edit(data: data);
  }

  Future<void> _record(String section, [int? index]) async {
    final cv = _controller.draft;
    if (cv == null || _controller.busy) return;
    final token = widget.session.session?.token;
    final rows = cv.data[section] as List;
    Map<String, dynamic>? result;
    if (profileSections.containsKey(section)) {
      await showDialog<bool>(
        context: context,
        builder: (_) => ProfileRecordEditor(
          section: section,
          record: index == null ? null : Map<String, dynamic>.from(rows[index]),
          onSave: (value) async {
            result = value;
          },
        ),
      );
    } else {
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => GeneratedRecordEditor(
          section: section,
          record: index == null ? null : Map<String, dynamic>.from(rows[index]),
        ),
      );
    }
    if (!mounted ||
        result == null ||
        widget.session.session?.token != token ||
        _controller.draft == null) {
      return;
    }
    final data = _controller.draft!.data;
    final current = data[section] as List;
    if (index == null) {
      current.add(result);
    } else {
      current[index] = result;
    }
    _controller.edit(data: data);
  }

  Widget _personalField(String key, String label, {int maxLength = 200}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          key: ValueKey('cv_${key}_$_formVersion'),
          initialValue:
              _controller.draft!.data['personal'][key]?.toString() ?? '',
          enabled: !_controller.busy,
          decoration: InputDecoration(labelText: label),
          maxLength: maxLength,
          onChanged: (value) => _text(key, value, personal: true),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (key == 'full_name' && text.isEmpty) return 'Escribe tu nombre.';
            if (key == 'email' && text.isNotEmpty) {
              return RegistrationValidation.email(text);
            }
            if (key == 'website' && text.isNotEmpty) {
              final uri = Uri.tryParse(text);
              if (uri == null ||
                  !['http', 'https'].contains(uri.scheme) ||
                  uri.host.isEmpty) {
                return 'Escribe una URL HTTP o HTTPS válida.';
              }
            }
            return null;
          },
        ),
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _controller.save();
    if (mounted && _controller.error == null) setState(() => ++_formVersion);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller, cv = c.draft;
      return Workspace(
        title: 'Crear mi CV',
        loading: c.busy,
        error: c.error,
        onRetry: cv == null && !c.busy ? c.load : null,
        actions: [
          TextButton.icon(
            onPressed: c.busy
                ? null
                : () => context.go(
                    widget.returnToOfferId == null
                        ? '/curriculum'
                        : '/curriculum?apply_offer=${widget.returnToOfferId}',
                  ),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver a mi currículum'),
          ),
          if (widget.returnToOfferId != null)
            TextButton(
              onPressed: c.busy || cv?.exists != true || c.dirty
                  ? null
                  : () => context.go('/offers/${widget.returnToOfferId}/apply'),
              child: const Text('Continuar postulación'),
            ),
          TextButton.icon(
            onPressed: c.busy ? null : _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a consultar'),
          ),
        ],
        children: [
          if (cv != null)
            Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.notice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(c.notice!),
                    ),
                  WorkspacePanel(
                    title: 'Tu currículum, a tu manera',
                    children: [
                      Text(
                        cv.exists
                            ? 'Edita tu currículum guardado.'
                            : 'Precargamos la información disponible de tu perfil. Revisa los datos antes de guardar.',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'La edición del CV es independiente: no modifica tu perfil ni tu cuenta.',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey('cv_template_${cv.template}'),
                        initialValue: cv.template,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Plantilla',
                        ),
                        items: [
                          for (final entry in curriculumTemplates.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: c.busy
                            ? null
                            : (value) {
                                if (value != null) c.edit(template: value);
                              },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Puedes cambiar de plantilla sin perder los datos. La vista previa muestra el PDF de tu edición actual.',
                      ),
                    ],
                  ),
                  WorkspacePanel(
                    title: 'Información personal',
                    children: [
                      _personalField(
                        'full_name',
                        'Nombre completo',
                        maxLength: 150,
                      ),
                      _personalField(
                        'email',
                        'Correo electrónico',
                        maxLength: 254,
                      ),
                      _personalField(
                        'phone',
                        'Teléfono (opcional)',
                        maxLength: 40,
                      ),
                      _personalField('location', 'Ubicación (opcional)'),
                      _personalField('website', 'Sitio web (opcional)'),
                      TextFormField(
                        key: ValueKey('cv_summary_$_formVersion'),
                        initialValue: cv.data['professional_summary'],
                        enabled: !c.busy,
                        minLines: 3,
                        maxLines: 8,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                          labelText: 'Perfil profesional',
                        ),
                        onChanged: (value) =>
                            _text('professional_summary', value),
                      ),
                    ],
                  ),
                  for (final section in curriculumSections.entries)
                    WorkspacePanel(
                      title: section.value,
                      children: [
                        if ((cv.data[section.key] as List).isEmpty)
                          const Text(
                            'Todavía no hay registros en esta sección.',
                          ),
                        for (
                          var index = 0;
                          index < (cv.data[section.key] as List).length;
                          index++
                        )
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              (cv.data[section
                                          .key][index][profileSections[section
                                                  .key]
                                              ?.$2 ??
                                          'title'] ??
                                      '')
                                  .toString(),
                            ),
                            subtitle: Text(
                              (cv.data[section.key][index]['institution'] ??
                                      cv.data[section.key][index]['company'] ??
                                      cv.data[section.key][index]['level'] ??
                                      cv.data[section.key][index]['issuer'] ??
                                      cv.data[section.key][index]['content'] ??
                                      '')
                                  .toString(),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Editar ${section.value}',
                                  onPressed: c.busy
                                      ? null
                                      : () => _record(section.key, index),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Quitar del CV',
                                  onPressed: c.busy
                                      ? null
                                      : () {
                                          final data = c.draft!.data;
                                          (data[section.key] as List).removeAt(
                                            index,
                                          );
                                          c.edit(data: data);
                                        },
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                              ],
                            ),
                          ),
                        TextButton.icon(
                          key: Key('cv_add_${section.key}'),
                          onPressed:
                              c.busy ||
                                  (cv.data[section.key] as List).length >=
                                      (section.key == 'extra_sections'
                                          ? 10
                                          : 100)
                              ? null
                              : () => _record(section.key),
                          icon: const Icon(Icons.add),
                          label: Text('Agregar ${section.value.toLowerCase()}'),
                        ),
                      ],
                    ),
                  WorkspacePanel(
                    title: 'Guardar y revisar',
                    children: [
                      Text(
                        c.dirty
                            ? 'Tienes cambios sin guardar.'
                            : cv.exists
                            ? 'Estás viendo tu versión guardada.'
                            : 'Este borrador todavía no está guardado.',
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            key: const Key('cv_save'),
                            onPressed: c.busy ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Guardar CV'),
                          ),
                          OutlinedButton.icon(
                            key: const Key('cv_preview'),
                            onPressed: c.busy
                                ? null
                                : () {
                                    if (_form.currentState!.validate()) {
                                      c.preview();
                                    }
                                  },
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Vista previa'),
                          ),
                          OutlinedButton.icon(
                            key: const Key('cv_download'),
                            onPressed: c.busy || !cv.exists || c.dirty
                                ? null
                                : c.downloadSaved,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Descargar PDF guardado'),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Guarda los cambios antes de descargar el PDF.',
                        ),
                      ),
                    ],
                  ),
                  if (c.document != null)
                    WorkspacePanel(
                      title: 'Vista previa de tu edición',
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: c.closeDocument,
                            child: const Text('Cerrar vista previa'),
                          ),
                        ),
                        PrivatePdfView(
                          key: ObjectKey(c.document),
                          bytes: c.document!,
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
