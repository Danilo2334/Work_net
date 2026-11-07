import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import '../domain/offer.dart';

class PublishOfferPage extends StatefulWidget {
  const PublishOfferPage({
    super.key,
    required this.session,
    required this.repository,
    this.offerId,
    this.editingRepository,
  }) : assert(offerId == null || editingRepository != null);
  final SessionController session;
  final OfferRepository repository;
  final int? offerId;
  final OfferEditingRepository? editingRepository;
  @override
  State<PublishOfferPage> createState() => _PublishOfferPageState();
}

class _PublishOfferPageState extends State<PublishOfferPage> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final key in [
      'title',
      'description',
      'requirements',
      'salary',
      'location',
    ])
      key: TextEditingController(),
  };
  OfferCatalog? _catalog;
  String? _category, _contract, _error;
  int? _published;
  bool _loading = true, _busy = false;
  bool _loaded = false;
  bool get _editing => widget.offerId != null;
  String? get _token => widget.session.session?.token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await widget.repository.catalog(token);
      final existing = _editing && !_loaded
          ? await widget.editingRepository!.read(token, widget.offerId!)
          : null;
      if (mounted && _token == token) {
        setState(() {
          _catalog = catalog;
          if (existing != null) {
            for (final entry in existing.draft.toJson().entries) {
              _fields[entry.key]?.text = entry.value as String;
            }
            _category = catalog.categories.contains(existing.draft.category)
                ? existing.draft.category
                : null;
            _contract =
                catalog.contractTypes.contains(existing.draft.contractType)
                ? existing.draft.contractType
                : null;
          }
          _loaded = true;
        });
      }
    } on ApiFailure catch (e) {
      if (mounted && _token == token) {
        if (e.status == 401) await widget.session.expire();
        if (mounted) setState(() => _error = e.message);
      }
    } finally {
      if (mounted && _token == token) setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    if (_busy || _published != null || !_form.currentState!.validate()) return;
    final token = _token;
    if (token == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final draft = OfferDraft(
      title: _fields['title']!.text.trim(),
      description: _fields['description']!.text.trim(),
      requirements: _fields['requirements']!.text.trim(),
      salary: _fields['salary']!.text.trim().replaceAll(',', '.'),
      location: _fields['location']!.text.trim(),
      category: _category!,
      contractType: _contract!,
    );
    try {
      final id = _editing
          ? (await widget.editingRepository!.update(
              token,
              widget.offerId!,
              draft,
            )).id
          : await widget.repository.publish(token, draft);
      if (mounted && _token == token) setState(() => _published = id);
    } on ApiFailure catch (e) {
      if (mounted && _token == token) {
        if (e.status == 401) await widget.session.expire();
        if (mounted) {
          setState(
            () => _error = e.fields.isEmpty
                ? e.message
                : e.fields.values.join('\n'),
          );
        }
      }
    } finally {
      if (mounted && _token == token) setState(() => _busy = false);
    }
  }

  Widget _field(String name, String label, {int lines = 1, int limit = 200}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          key: Key('offer_$name'),
          controller: _fields[name],
          enabled: !_busy,
          maxLines: lines,
          maxLength: limit,
          keyboardType: name == 'salary'
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          decoration: InputDecoration(labelText: label),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return 'Completa este campo.';
            if (name == 'salary' &&
                !RegExp(r'^\d{1,10}([.,]\d{1,2})?$').hasMatch(text)) {
              return 'Escribe un salario no negativo, con hasta dos decimales.';
            }
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Workspace(
    title: _editing ? 'Editar oferta' : 'Publicar oferta',
    loading: _loading,
    error: _error,
    onRetry: _busy ? null : _load,
    actions: [
      TextButton(
        onPressed: _busy
            ? null
            : () => context.go(
                _editing ? '/company/offers' : '/company-dashboard',
              ),
        child: Text(_editing ? 'Volver a mis ofertas' : 'Volver al dashboard'),
      ),
    ],
    children: [
      if (!_loading && _catalog != null)
        WorkspacePanel(
          title: _published == null
              ? 'Datos de la oferta'
              : (_editing ? 'Edición confirmada' : 'Publicación confirmada'),
          children: [
            if (_published != null)
              Text(
                _editing
                    ? 'Cambios guardados correctamente.'
                    : 'Oferta publicada correctamente. Número $_published.',
                key: const Key('offer_success'),
              )
            else
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field('title', 'Título'),
                    _field(
                      'description',
                      'Descripción',
                      lines: 4,
                      limit: 10000,
                    ),
                    _field(
                      'requirements',
                      'Requisitos',
                      lines: 4,
                      limit: 10000,
                    ),
                    _field('salary', 'Salario'),
                    _field('location', 'Ubicación'),
                    DropdownButtonFormField<String>(
                      key: const Key('offer_category'),
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        for (final c in _catalog!.categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      validator: (v) =>
                          v == null ? 'Selecciona una categoría.' : null,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _category = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: const Key('offer_contract'),
                      initialValue: _contract,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de contrato',
                      ),
                      items: [
                        for (final c in _catalog!.contractTypes)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      validator: (v) =>
                          v == null ? 'Selecciona un contrato.' : null,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _contract = v),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('offer_publish'),
                      onPressed: _busy ? null : _publish,
                      child: Text(
                        _editing
                            ? (_busy ? 'Guardando…' : 'Guardar cambios')
                            : (_busy ? 'Publicando…' : 'Publicar oferta'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
    ],
  );
}
