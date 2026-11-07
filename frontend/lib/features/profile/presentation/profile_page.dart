import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/profile/domain/profile.dart';
import 'package:worknet/features/profile/domain/profile_validation.dart';
import 'package:worknet/core/theme/worknet_theme.dart';
import 'package:worknet/core/widgets/error_notice.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'profile_record_editor.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.repository,
    this.pickPhoto,
  });
  final SessionController controller;
  final ProfileRepository repository;
  final Future<XFile?> Function()? pickPhoto;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _summary = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  CandidateProfile? _data;
  Uint8List? _photo;
  bool _loading = true, _busy = false, _picking = false, _photoLoading = false;
  String? _loadError, _error, _success, _photoError;
  bool get _working => _busy || _picking;
  String get _token => widget.controller.session?.token ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _summary.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _apply(CandidateProfile data) {
    if (mounted) {
      setState(() {
        _data = data;
        _summary.text = data.summary;
        if (!data.hasPhoto) _photo = null;
      });
    }
  }

  Future<void> _loadPhoto() async {
    if (mounted) {
      setState(() {
        _photoLoading = true;
        _photoError = null;
        _photo = null;
      });
    }
    try {
      final photo = await widget.repository.photo(_token);
      if (mounted) setState(() => _photo = photo);
    } on ApiFailure catch (e) {
      if (e.status == 401) await widget.controller.expire();
      if (mounted) setState(() => _photoError = e.message);
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      _apply(await widget.repository.load(_token));
      if (_data?.hasPhoto == true) await _loadPhoto();
    } on ApiFailure catch (e) {
      if (e.status == 401) await widget.controller.expire();
      if (mounted) setState(() => _loadError = e.message);
    } on FormatException {
      if (mounted) {
        setState(
          () => _loadError =
              'No pudimos interpretar tu perfil. Vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _feedback(String message) {
    if (!mounted) return;
    setState(() {
      _success = message;
      _error = null;
    });
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _run(
    Future<CandidateProfile> Function() action,
    String success, {
    bool reloadPhoto = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = _success = null;
    });
    try {
      _apply(await action());
      if (reloadPhoto && _data?.hasPhoto == true) await _loadPhoto();
      _feedback(success);
    } on ApiFailure catch (e) {
      if (e.status == 401) await widget.controller.expire();
      if (mounted) {
        setState(
          () => _error = e.fields.isEmpty
              ? e.message
              : e.fields.values.join('\n'),
        );
      }
    } on FormatException {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos interpretar el perfil actualizado. Vuelve a consultar tus datos.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_scroll.hasClients && _error != null) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  Future<void> _upload() async {
    setState(() {
      _picking = true;
      _error = _success = null;
    });
    try {
      final file =
          await (widget.pickPhoto?.call() ??
              openFile(
                acceptedTypeGroups: [
                  const XTypeGroup(
                    label: 'Fotografía JPEG o PNG',
                    extensions: ['jpg', 'jpeg', 'png'],
                    mimeTypes: ['image/jpeg', 'image/png'],
                    uniformTypeIdentifiers: ['public.jpeg', 'public.png'],
                  ),
                ],
              ));
      if (!mounted || file == null) return;
      validateProfilePhoto(file.name, await file.length());
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await _run(
        () => widget.repository.upload(_token, bytes, file.name),
        'Fotografía guardada correctamente.',
        reloadPhoto: true,
      );
    } on ApiFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos abrir el archivo. Selecciona otra fotografía.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<bool> _confirm(String title, String description) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm_profile_delete'),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _edit(String section, [Map<String, dynamic>? record]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileRecordEditor(
        section: section,
        record: record,
        onSave: (values) async {
          try {
            _apply(
              await widget.repository.saveRecord(
                _token,
                section,
                values,
                id: record?['id'] as String?,
              ),
            );
          } on ApiFailure catch (e) {
            if (e.status == 401) await widget.controller.expire();
            rethrow;
          }
        },
      ),
    );
    if (saved == true) _feedback('Registro guardado correctamente.');
  }

  Widget _panel(String title, List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: WorkNetColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Widget _photograph() => _panel('Fotografía opcional', [
    Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 112,
        height: 112,
        child: _photoLoading
            ? const Center(child: CircularProgressIndicator())
            : _photo == null
            ? const CircleAvatar(
                backgroundColor: WorkNetColors.mint,
                child: Icon(Icons.person_outline, size: 52),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(56),
                child: Image.memory(
                  _photo!,
                  fit: BoxFit.cover,
                  semanticLabel: 'Fotografía privada del perfil',
                  errorBuilder: (_, _, _) => const Center(
                    child: Text('No pudimos mostrar la fotografía.'),
                  ),
                ),
              ),
      ),
    ),
    const SizedBox(height: 16),
    const Text(
      'JPEG o PNG, hasta 2 MiB. Máximo 4096 px por lado y 16 MP. Puedes completar tu perfil sin fotografía.',
    ),
    ErrorNotice(_photoError),
    Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const Key('upload_profile_photo'),
          onPressed: _working ? null : _upload,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _picking
                ? 'Abriendo archivo…'
                : _data!.hasPhoto
                ? 'Cambiar fotografía'
                : 'Agregar fotografía',
          ),
        ),
        if (_data!.hasPhoto)
          TextButton(
            key: const Key('delete_profile_photo'),
            onPressed: _working
                ? null
                : () async {
                    if (await _confirm(
                          '¿Eliminar fotografía?',
                          'Podrás agregar otra fotografía cuando quieras.',
                        ) &&
                        mounted) {
                      await _run(
                        () => widget.repository.removePhoto(_token),
                        'Fotografía eliminada.',
                      );
                    }
                  },
            child: const Text('Eliminar fotografía'),
          ),
        if (_photoError != null)
          TextButton(
            onPressed: _working ? null : _loadPhoto,
            child: const Text('Reintentar fotografía'),
          ),
      ],
    ),
  ]);

  Widget _section(String section) => _panel(profileSections[section]!.$1, [
    if (_data!.entries[section]!.isEmpty)
      const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text('Todavía no has agregado registros.'),
      ),
    for (final row in _data!.entries[section]!)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WorkNetColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                row[profileSections[section]!.$2],
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final field in [
                'institution',
                'company',
                'level',
                'start_date',
                'end_date',
                'description',
              ])
                if (row[field] != null && row[field].toString().isNotEmpty)
                  Text(
                    '${switch (field) {
                      'start_date' => 'Desde: ',
                      'end_date' => 'Hasta: ',
                      'level' => 'Nivel: ',
                      _ => '',
                    }}${row[field]}',
                  ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    key: Key('edit_${section}_${row['id']}'),
                    onPressed: _working ? null : () => _edit(section, row),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Editar'),
                  ),
                  TextButton.icon(
                    key: Key('delete_${section}_${row['id']}'),
                    onPressed: _working
                        ? null
                        : () async {
                            if (await _confirm(
                                  '¿Eliminar registro?',
                                  'Se eliminará este registro de tu perfil.',
                                ) &&
                                mounted) {
                              await _run(
                                () => widget.repository.deleteRecord(
                                  _token,
                                  section,
                                  row['id'] as String,
                                ),
                                'Registro eliminado correctamente.',
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        key: Key('add_$section'),
        onPressed: _working ? null : () => _edit(section),
        icon: const Icon(Icons.add),
        label: Text('Agregar ${sectionSingular[section]}'),
      ),
    ),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        key: const Key('close_profile'),
        tooltip: 'Volver al dashboard',
        onPressed: _working ? null : () => context.go('/dashboard'),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Perfil del candidato'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_loadError != null)
                      _panel('No pudimos cargar tu perfil', [
                        ErrorNotice(_loadError),
                        FilledButton(
                          key: const Key('retry_profile'),
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ]),
                    if (_loadError == null && _data != null) ...[
                      Text(
                        'Completitud del perfil · ${_data!.percentage}%',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _data!.percentage / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      const SizedBox(height: 16),
                      if (!_data!.exists)
                        const Text(
                          'Tu perfil está vacío. Agrega una descripción o tu primer registro para comenzar.',
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _working ? null : _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Volver a consultar'),
                        ),
                      ),
                      if (_busy) const LinearProgressIndicator(),
                      ErrorNotice(_error),
                      if (_success != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _success!,
                              style: const TextStyle(
                                color: WorkNetColors.green,
                              ),
                            ),
                          ),
                        ),
                      _photograph(),
                      const SizedBox(height: 24),
                      _panel('Descripción profesional', [
                        Form(
                          key: _form,
                          child: TextFormField(
                            key: const Key('profile_summary'),
                            controller: _summary,
                            enabled: !_working,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 5000,
                            decoration: const InputDecoration(
                              labelText: 'Describe tu perfil profesional',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('save_profile_summary'),
                          onPressed: _working
                              ? null
                              : () {
                                  if (_form.currentState!.validate()) {
                                    _run(
                                      () => widget.repository.summary(
                                        _token,
                                        _summary.text,
                                        create: !_data!.exists,
                                      ),
                                      'Descripción guardada correctamente.',
                                    );
                                  }
                                },
                          child: const Text('Guardar descripción'),
                        ),
                      ]),
                      for (final section in profileSections.keys) ...[
                        const SizedBox(height: 24),
                        _section(section),
                      ],
                      if (_data!.exists) ...[
                        const SizedBox(height: 24),
                        _panel('Vaciar perfil profesional', [
                          const Text(
                            'Puedes eliminar la descripción, los registros y la fotografía de tu perfil. Esta acción requiere confirmación.',
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            key: const Key('clear_profile'),
                            onPressed: _working
                                ? null
                                : () async {
                                    if (await _confirm(
                                          '¿Vaciar tu perfil?',
                                          'Se borrarán la descripción, los registros y la fotografía. Tu cuenta seguirá disponible.',
                                        ) &&
                                        mounted) {
                                      await _run(
                                        () => widget.repository.clear(_token),
                                        'Perfil eliminado correctamente.',
                                      );
                                    }
                                  },
                            child: const Text('Vaciar perfil'),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ),
  );
}
