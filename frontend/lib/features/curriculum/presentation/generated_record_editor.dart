import 'package:flutter/material.dart';
import 'package:worknet/features/profile/domain/profile_validation.dart';

/// Extra sections of a CV do not write into the candidate's source profile.
class GeneratedRecordEditor extends StatefulWidget {
  const GeneratedRecordEditor({super.key, required this.section, this.record});
  final String section;
  final Map<String, dynamic>? record;
  @override
  State<GeneratedRecordEditor> createState() => _GeneratedRecordEditorState();
}

class _GeneratedRecordEditorState extends State<GeneratedRecordEditor> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  bool get certification => widget.section == 'certifications';
  Map<String, String> get labels => certification
      ? {
          'title': 'Certificación',
          'issuer': 'Entidad emisora',
          'issue_date': 'Fecha de expedición',
          'description': 'Descripción',
        }
      : {'title': 'Título de la sección', 'content': 'Contenido'};
  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) {
      _fields[key] = TextEditingController(
        text: widget.record?[key]?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(certification ? 'Certificación' : 'Otra sección'),
    scrollable: true,
    content: SizedBox(
      width: 460,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in labels.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  key: Key('cv_record_${field.key}'),
                  controller: _fields[field.key],
                  decoration: InputDecoration(
                    labelText: field.value,
                    hintText: field.key == 'issue_date'
                        ? 'AAAA-MM-DD (opcional)'
                        : null,
                  ),
                  maxLength: ['description', 'content'].contains(field.key)
                      ? 3000
                      : field.key == 'issue_date'
                      ? 10
                      : certification
                      ? 200
                      : 120,
                  maxLines: ['description', 'content'].contains(field.key)
                      ? 4
                      : 1,
                  validator: (value) => field.key == 'issue_date'
                      ? validateProfileDate(value)
                      : ['title', 'content'].contains(field.key) &&
                            (value?.trim().isEmpty ?? true)
                      ? 'Completa este campo.'
                      : null,
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, <String, dynamic>{
            for (final field in _fields.entries)
              field.key:
                  field.key == 'issue_date' && field.value.text.trim().isEmpty
                  ? null
                  : field.value.text.trim(),
          });
        },
        child: const Text('Guardar registro'),
      ),
    ],
  );
}
