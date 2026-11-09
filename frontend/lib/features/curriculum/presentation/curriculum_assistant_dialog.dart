import 'package:flutter/material.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/curriculum/domain/curriculum_assistant.dart';
import 'package:worknet/features/curriculum/domain/generated_curriculum.dart';

class CurriculumAssistantDialog extends StatefulWidget {
  const CurriculumAssistantDialog({
    super.key,
    required this.repository,
    required this.session,
  });
  final CurriculumAssistantRepository repository;
  final SessionController session;

  @override
  State<CurriculumAssistantDialog> createState() =>
      _CurriculumAssistantDialogState();
}

class _CurriculumAssistantDialogState extends State<CurriculumAssistantDialog> {
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _token;
  bool _loading = true, _busy = false, _available = false;
  bool _includeProfile = false, _consent = false, _reviewed = false;
  String? _error;
  CurriculumSuggestion? _suggestion;

  @override
  void initState() {
    super.initState();
    _token = widget.session.session?.token;
    widget.session.addListener(_sessionChanged);
    _check();
  }

  bool get _current =>
      mounted && _token != null && widget.session.session?.token == _token;

  void _sessionChanged() {
    if (mounted && widget.session.session?.token != _token) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _failure(Object error) async {
    if (!_current) return;
    if (error is ApiFailure && error.status == 401) {
      await widget.session.expire();
    } else if (_current) {
      setState(
        () => _error = error is ApiFailure
            ? error.message
            : 'No pudimos interpretar la respuesta. Tu edición se conserva.',
      );
    }
  }

  Future<void> _check() async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final available = await widget.repository.assistantAvailable(_token!);
      if (_current) setState(() => _available = available);
    } catch (error) {
      await _failure(error);
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    if (_busy || !_current || !_consent || !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.repository.suggest(
        _token!,
        text: _text.text.trim(),
        includeProfile: _includeProfile,
        consent: _consent,
      );
      if (_current) {
        setState(() {
          _suggestion = result;
          _reviewed = false;
        });
      }
    } catch (error) {
      await _failure(error);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    _text.dispose();
    super.dispose();
  }

  Widget _proposal(CurriculumSuggestion suggestion) {
    final data = suggestion.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(suggestion.notice),
        const SizedBox(height: 12),
        for (final field in suggestion.personalFields)
          Text(
            '${const {'full_name': 'Nombre', 'email': 'Correo', 'phone': 'Teléfono', 'location': 'Ubicación', 'website': 'Sitio web'}[field]}: ${data['personal'][field]}',
          ),
        if ((data['professional_summary'] as String).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Resumen profesional',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(data['professional_summary']),
        ],
        for (final section in curriculumSections.entries)
          if ((data[section.key] as List).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(section.value, style: Theme.of(context).textTheme.titleSmall),
            for (final row in data[section.key] as List)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  (row as Map).values
                      .where((v) => v != null && v.toString().isNotEmpty)
                      .join(' · '),
                ),
              ),
          ],
        if (suggestion.missingInformation.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Información por completar',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final item in suggestion.missingInformation) Text('• $item'),
        ],
        const SizedBox(height: 16),
        const Text(
          'Aplicar reemplaza el resumen y las secciones del borrador. Conservaremos la plantilla y los datos de contacto que no hayas proporcionado. Podrás corregir todo antes de guardar.',
        ),
        CheckboxListTile(
          key: const ValueKey('cv_ai_reviewed'),
          contentPadding: EdgeInsets.zero,
          value: _reviewed,
          onChanged: (value) => setState(() => _reviewed = value ?? false),
          title: const Text(
            'He revisado la propuesta y quiero llevarla al editor.',
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Completar mi CV con IA'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _suggestion != null
            ? _proposal(_suggestion!)
            : Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _check,
                        child: const Text('Volver a comprobar'),
                      ),
                    ],
                    if (!_available && _error == null)
                      const Text(
                        'El asistente está pendiente de configuración. Puedes seguir creando tu CV manualmente.',
                      ),
                    if (_available) ...[
                      const Text(
                        'Cuéntanos tus estudios, experiencia, habilidades y logros. Gemini organizará los datos en una propuesta que podrás revisar antes de guardar.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('cv_ai_text'),
                        controller: _text,
                        enabled: !_busy,
                        minLines: 5,
                        maxLines: 10,
                        maxLength: 12000,
                        decoration: const InputDecoration(
                          labelText: 'Mi información profesional',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            (value?.trim().isEmpty ?? true) && !_includeProfile
                            ? 'Escribe tu información o incluye tu perfil.'
                            : null,
                      ),
                      CheckboxListTile(
                        key: const ValueKey('cv_ai_profile'),
                        contentPadding: EdgeInsets.zero,
                        value: _includeProfile,
                        onChanged: _busy
                            ? null
                            : (value) => setState(
                                () => _includeProfile = value ?? false,
                              ),
                        title: const Text(
                          'Incluir los datos de mi perfil de WorkNet y mi nombre y correo de cuenta.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const Text(
                        'El texto y el perfil seleccionado se enviarán a Gemini. El tratamiento de la información depende de las condiciones y el plan del proveedor. Envía solo datos que quieras compartir.',
                      ),
                      CheckboxListTile(
                        key: const ValueKey('cv_ai_consent'),
                        contentPadding: EdgeInsets.zero,
                        value: _consent,
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _consent = value ?? false),
                        title: const Text(
                          'Autorizo este envío para preparar mi CV.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (_busy) const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_suggestion == null ? 'Cancelar' : 'Descartar propuesta'),
      ),
      if (_suggestion != null)
        FilledButton(
          onPressed: _reviewed && _current
              ? () => Navigator.pop(context, _suggestion)
              : null,
          child: const Text('Aplicar al borrador'),
        )
      else if (!_loading && _available)
        FilledButton(
          onPressed: _busy || !_consent ? null : _generate,
          child: Text(_busy ? 'Preparando propuesta…' : 'Generar propuesta'),
        ),
    ],
  );
}
