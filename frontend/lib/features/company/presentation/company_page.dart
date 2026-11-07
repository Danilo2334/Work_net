import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/company/domain/company.dart';
import 'package:worknet/features/registration/domain/registration.dart';

class CompanyPage extends StatefulWidget {
  const CompanyPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final CompanyRepository repository;
  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _fields = {
    for (final key in [
      'name',
      'taxId',
      'sector',
      'location',
      'email',
      'description',
      'website',
      'social',
    ])
      key: TextEditingController(),
  };
  CompanyInfo? _company;
  Uint8List? _logo;
  bool _loading = true, _busy = false;
  String? _error, _success;
  String get _token => widget.session.session!.token;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply(CompanyInfo c) {
    _company = c;
    final d = c.draft;
    final values = {
      'name': d.name,
      'taxId': d.taxId,
      'sector': d.sector,
      'location': d.location,
      'email': d.email,
      'description': d.description,
      'website': c.website,
      'social': c.socialLinks.join('\n'),
    };
    for (final e in values.entries) {
      _fields[e.key]!.text = e.value;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await widget.repository.load(_token);
      Uint8List? logo;
      if (c.hasLogo) logo = await widget.repository.logo(_token);
      if (mounted) {
        setState(() {
          _apply(c);
          _logo = logo;
        });
      }
    } on ApiFailure catch (e) {
      if (e.status == 401) await widget.session.expire();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await action();
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
      if (mounted) {
        setState(() => _busy = false);
        if (_scroll.hasClients) {
          await _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  Future<void> _save({bool submit = false}) async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final d = CompanyDraft(
        name: _fields['name']!.text,
        taxId: _fields['taxId']!.text,
        sector: _fields['sector']!.text,
        location: _fields['location']!.text,
        email: _fields['email']!.text,
        description: _fields['description']!.text,
      );
      final c = submit
          ? await SubmitCompany(widget.repository)(_token, d)
          : await widget.repository.save(_token, d);
      if (mounted) {
        setState(() {
          _apply(c);
          _success = submit
              ? 'Solicitud enviada. Tu información está en revisión.'
              : 'Información guardada.';
        });
      }
    });
  }

  Future<void> _pickLogo() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Logo JPEG o PNG',
          extensions: ['jpg', 'jpeg', 'png'],
        ),
      ],
    );
    if (file == null || !mounted) return;
    await _run(() async {
      if (await file.length() > 2 * 1024 * 1024) {
        throw const ApiFailure('El logo no puede superar 2 MiB.');
      }
      await widget.repository.uploadLogo(
        _token,
        await file.readAsBytes(),
        file.name,
      );
      await _load();
      if (mounted) setState(() => _success = 'Logo guardado.');
    });
  }

  Widget _field(String key, String label, {int lines = 1, int max = 200}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: TextFormField(
          key: Key('company_$key'),
          controller: _fields[key],
          enabled: !_busy && (_company?.canEdit ?? false),
          maxLines: lines,
          maxLength: max,
          validator: (v) => key == 'email'
              ? RegistrationValidation.email(v)
              : (v == null || v.trim().isEmpty ? 'Completa este campo.' : null),
          decoration: InputDecoration(labelText: label),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final c = _company;
    return Workspace(
      scrollController: _scroll,
      title: 'Tu empresa',
      loading: _loading,
      error: _error,
      onRetry: _busy ? null : _load,
      actions: [
        OutlinedButton(
          onPressed: _busy ? null : () => _run(widget.session.logout),
          child: const Text('Cerrar sesión'),
        ),
        TextButton(
          onPressed: () => context.go('/account'),
          child: const Text('Configuración de cuenta'),
        ),
        if (c?.state == CompanyState.approved)
          FilledButton(
            onPressed: () => context.go('/company-dashboard'),
            child: const Text('Ir al dashboard'),
          ),
        TextButton(
          onPressed: _busy || _loading ? null : _load,
          child: const Text('Actualizar estado'),
        ),
      ],
      children: [
        if (_success != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              _success!,
              key: const Key('company_success'),
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        if (c != null && !_loading) ...[
          WorkspacePanel(
            title: 'Estado: ${c.stateLabel}',
            children: [
              Text(switch (c.state) {
                CompanyState.pending =>
                  c.submitted
                      ? 'Tu información está siendo revisada por un administrador.'
                      : 'Completa la información de tu organización para solicitar la validación.',
                CompanyState.rejected => 'Motivo del rechazo: ${c.reason}',
                CompanyState.approved =>
                  'Tu empresa está aprobada. Ya puedes acceder al dashboard.',
              }),
            ],
          ),
          WorkspacePanel(
            title: 'Información de la organización',
            children: [
              Form(
                key: _form,
                child: Column(
                  children: [
                    _field('name', 'Razón social'),
                    _field('taxId', 'NIT', max: 20),
                    _field('sector', 'Sector', max: 120),
                    _field('location', 'Ubicación'),
                    _field('email', 'Correo de contacto', max: 254),
                    _field(
                      'description',
                      'Descripción breve',
                      lines: 4,
                      max: 2000,
                    ),
                  ],
                ),
              ),
              if (c.canEdit)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      key: const Key('company_save'),
                      onPressed: _busy ? null : () => _save(),
                      child: const Text('Guardar información'),
                    ),
                    FilledButton(
                      key: const Key('company_submit'),
                      onPressed: _busy ? null : () => _save(submit: true),
                      child: Text(
                        c.state == CompanyState.rejected
                            ? 'Corregir y reenviar'
                            : 'Solicitar validación',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (c.state == CompanyState.approved)
            WorkspacePanel(
              title: 'Información complementaria',
              children: [
                if (_logo != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.memory(
                      _logo!,
                      height: 100,
                      width: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : _pickLogo,
                      child: const Text('Cargar logo'),
                    ),
                    if (c.hasLogo)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await widget.repository.removeLogo(_token);
                                await _load();
                              }),
                        child: const Text('Eliminar logo'),
                      ),
                  ],
                ),
                TextField(
                  controller: _fields['website'],
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Sitio web (opcional)',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _fields['social'],
                  enabled: !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Redes sociales (un enlace por línea)',
                    helperText:
                        'Usa enlaces completos, por ejemplo https://example.org',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final saved = await widget.repository.saveExtras(
                            _token,
                            _fields['website']!.text,
                            _fields['social']!.text
                                .split('\n')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList(),
                          );
                          if (mounted) {
                            setState(() {
                              _apply(saved);
                              _success = 'Información complementaria guardada.';
                            });
                          }
                        }),
                  child: const Text('Guardar complementos'),
                ),
              ],
            ),
        ],
      ],
    );
  }
}
