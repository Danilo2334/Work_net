import 'package:flutter/material.dart';

import '../../core/api/worknet_api.dart';
import '../../core/widgets/error_notice.dart';
import 'profile_data.dart';

class ProfileRecordEditor extends StatefulWidget {
  const ProfileRecordEditor({
    super.key,
    required this.section,
    required this.onSave,
    this.record,
  });
  final String section;
  final Map<String, dynamic>? record;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<ProfileRecordEditor> createState() => _ProfileRecordEditorState();
}

class _ProfileRecordEditorState extends State<ProfileRecordEditor> {
  final _form = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  bool _busy = false;
  String _level = '';
  String? _error;
  bool get _dated => ['education', 'experience'].contains(widget.section);
  Map<String, String> get _labels => switch (widget.section) {
    'education' => {
      'qualification': 'Título o formación',
      'institution': 'Institución',
    },
    'experience' => {'position': 'Puesto', 'company': 'Empresa'},
    'skills' => {'name': 'Habilidad'},
    _ => {'name': 'Idioma'},
  };
  Map<String, String> get _levels => widget.section == 'skills'
      ? {
          '': 'Sin especificar',
          'basico': 'Básico',
          'intermedio': 'Intermedio',
          'avanzado': 'Avanzado',
        }
      : {
          '': 'Sin especificar',
          for (final level in ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'])
            level: level,
          'nativo': 'Nativo',
        };

  @override
  void initState() {
    super.initState();
    for (final field in [
      ..._labels.keys,
      if (_dated) ...['start_date', 'end_date', 'description'],
    ]) {
      _controllers[field] = TextEditingController(
        text: widget.record?[field]?.toString() ?? '',
      );
    }
    final level = widget.record?['level'];
    if (level is String && _levels.containsKey(level)) _level = level;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _date(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final date = DateTime.tryParse(value);
    return !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
            date == null ||
            date.toIso8601String().substring(0, 10) != value
        ? 'Usa una fecha válida: AAAA-MM-DD.'
        : null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final values = <String, dynamic>{
      for (final field in _controllers.keys)
        field: _controllers[field]!.text.trim(),
    };
    if (_dated) {
      for (final field in ['start_date', 'end_date']) {
        if (values[field] == '') values[field] = null;
      }
    } else {
      values['level'] = _level;
    }
    try {
      await widget.onSave(values);
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (e) {
      if (!mounted) return;
      if (e.status == 401) {
        Navigator.pop(context, false);
        return;
      }
      setState(
        () =>
            _error = e.fields.isEmpty ? e.message : e.fields.values.join('\n'),
      );
    } on FormatException {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos interpretar el perfil actualizado. Vuelve a consultar tus datos.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        '${widget.record == null ? 'Agregar' : 'Editar'} ${sectionSingular[widget.section]}',
      ),
      scrollable: true,
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorNotice(_error),
              for (final entry in _labels.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    key: Key('record_${entry.key}'),
                    controller: _controllers[entry.key],
                    enabled: !_busy,
                    decoration: InputDecoration(labelText: entry.value),
                    maxLength: entry.key == 'name' ? 100 : 200,
                    validator: (value) =>
                        entry.key == profileSections[widget.section]!.$2 &&
                            (value == null || value.trim().isEmpty)
                        ? 'Completa este campo.'
                        : null,
                  ),
                ),
              if (_dated) ...[
                for (final field in ['start_date', 'end_date'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      key: Key('record_$field'),
                      controller: _controllers[field],
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: field == 'start_date'
                            ? 'Fecha de inicio'
                            : 'Fecha de finalización',
                        hintText: 'AAAA-MM-DD (opcional)',
                      ),
                      validator: (value) {
                        final invalid = _date(value);
                        if (invalid != null) return invalid;
                        final start = _controllers['start_date']!.text,
                            end = _controllers['end_date']!.text;
                        if (field == 'end_date' &&
                            start.isNotEmpty &&
                            end != '' &&
                            _date(start) == null &&
                            end.compareTo(start) < 0) {
                          return 'La fecha final no puede ser anterior a la inicial.';
                        }
                        return null;
                      },
                    ),
                  ),
                TextFormField(
                  key: const Key('record_description'),
                  controller: _controllers['description'],
                  enabled: !_busy,
                  maxLength: 3000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),
              ] else
                DropdownButtonFormField<String>(
                  key: const Key('record_level'),
                  initialValue: _level,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nivel (opcional)',
                  ),
                  items: [
                    for (final entry in _levels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _level = value ?? ''),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('save_profile_record'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Guardando…' : 'Guardar registro'),
        ),
      ],
    ),
  );
}
