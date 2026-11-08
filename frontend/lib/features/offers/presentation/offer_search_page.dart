import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';

import '../domain/search.dart';

class OfferSearchPage extends StatefulWidget {
  const OfferSearchPage({
    super.key,
    required this.session,
    required this.repository,
  });
  final SessionController session;
  final OfferSearchRepository repository;
  @override
  State<OfferSearchPage> createState() => _OfferSearchPageState();
}

class _OfferSearchPageState extends State<OfferSearchPage> {
  final _form = GlobalKey<FormState>();
  final _q = TextEditingController(),
      _location = TextEditingController(),
      _min = TextEditingController(),
      _max = TextEditingController();
  final _scroll = ScrollController();
  String _category = '', _contract = '', _sort = 'relevance';
  List<String> _categories = [], _contracts = [];
  OfferSearchQuery _query = const OfferSearchQuery();
  OfferSearchResult? _data;
  int _page = 1, _generation = 0;
  bool _loading = true, _dirty = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_q, _location, _min, _max]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _changed() => setState(() {
    _page = 1;
    _data = null;
    _dirty = true;
    _error = null;
  });
  String? _money(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!RegExp(r'^\d{1,10}([.,]\d{1,2})?$').hasMatch(value.trim())) {
      return 'Introduce un salario válido, desde 0 y con hasta dos decimales.';
    }
    return null;
  }

  Future<void> _apply() async {
    if (!_form.currentState!.validate()) return;
    _query = OfferSearchQuery(
      q: _q.text,
      location: _location.text,
      salaryMin: _min.text,
      salaryMax: _max.text,
      category: _category,
      contractType: _contract,
      sort: _sort,
    );
    _page = 1;
    _dirty = false;
    await _load();
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
      final result = await widget.repository.search(token, _query, page: _page);
      if (!mounted ||
          generation != _generation ||
          widget.session.session?.token != token) {
        return;
      }
      setState(() {
        _data = result;
        _categories = result.categories;
        _contracts = result.contractTypes;
      });
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
      setState(
        () =>
            _error = e.fields.isEmpty ? e.message : e.fields.values.join('\n'),
      );
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _go(int page) async {
    _page = page;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    await _load();
  }

  void _clear() {
    for (final c in [_q, _location, _min, _max]) {
      c.clear();
    }
    setState(() {
      _category = '';
      _contract = '';
      _sort = 'relevance';
    });
    _apply();
  }

  @override
  Widget build(BuildContext context) => Workspace(
    title: 'Buscar ofertas',
    loading: _loading,
    error: _error,
    onRetry: _loading ? null : _load,
    scrollController: _scroll,
    actions: [
      TextButton(
        onPressed: () => context.go('/dashboard'),
        child: const Text('Volver al dashboard'),
      ),
    ],
    children: [
      const Text('Encuentra ofertas por palabras clave y ajusta tus filtros.'),
      const SizedBox(height: 16),
      Form(
        key: _form,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 650
                ? constraints.maxWidth
                : (constraints.maxWidth - 32) / 3;
            Widget field(Widget child) => SizedBox(width: width, child: child);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                field(
                  TextFormField(
                    key: const Key('search_q'),
                    controller: _q,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: 'Palabras clave',
                    ),
                    maxLength: 120,
                    onChanged: (_) => _changed(),
                    onFieldSubmitted: (_) => _apply(),
                    validator: (v) =>
                        (v ?? '').trim().split(RegExp(r'\s+')).toSet().length >
                            8
                        ? 'Usa como máximo ocho palabras.'
                        : null,
                  ),
                ),
                field(
                  TextFormField(
                    key: const Key('search_location'),
                    controller: _location,
                    enabled: !_loading,
                    decoration: const InputDecoration(labelText: 'Ubicación'),
                    maxLength: 200,
                    onChanged: (_) => _changed(),
                  ),
                ),
                field(
                  DropdownButtonFormField<String>(
                    key: ValueKey('sort:$_sort'),
                    initialValue: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ordenar por'),
                    items: const [
                      DropdownMenuItem(
                        value: 'relevance',
                        child: Text('Relevancia'),
                      ),
                      DropdownMenuItem(
                        value: 'date',
                        child: Text('Fecha de publicación'),
                      ),
                    ],
                    onChanged: _loading
                        ? null
                        : (v) {
                            _sort = v!;
                            _changed();
                          },
                  ),
                ),
                field(
                  TextFormField(
                    key: const Key('search_salary_min'),
                    controller: _min,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: 'Salario mínimo',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _money,
                    onChanged: (_) => _changed(),
                  ),
                ),
                field(
                  TextFormField(
                    key: const Key('search_salary_max'),
                    controller: _max,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      labelText: 'Salario máximo',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final error = _money(v);
                      if (error != null) return error;
                      final min = double.tryParse(
                            _min.text.trim().replaceAll(',', '.'),
                          ),
                          max = double.tryParse(
                            (v ?? '').trim().replaceAll(',', '.'),
                          );
                      return min != null && max != null && min > max
                          ? 'El máximo debe ser mayor o igual al mínimo.'
                          : null;
                    },
                    onChanged: (_) => _changed(),
                  ),
                ),
                field(
                  DropdownButtonFormField<String>(
                    key: ValueKey('category:$_category'),
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todas las categorías'),
                      ),
                      for (final v in _categories)
                        DropdownMenuItem(value: v, child: Text(v)),
                    ],
                    onChanged: _loading
                        ? null
                        : (v) {
                            _category = v!;
                            _changed();
                          },
                  ),
                ),
                field(
                  DropdownButtonFormField<String>(
                    key: ValueKey('contract:$_contract'),
                    initialValue: _contract,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de contrato',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Todos los contratos'),
                      ),
                      for (final v in _contracts)
                        DropdownMenuItem(value: v, child: Text(v)),
                    ],
                    onChanged: _loading
                        ? null
                        : (v) {
                            _contract = v!;
                            _changed();
                          },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _apply,
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
          OutlinedButton(
            onPressed: _loading ? null : _clear,
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
      const SizedBox(height: 24),
      if (_loading) const Text('Buscando ofertas…'),
      if (_dirty) const Text('Pulsa Buscar para aplicar los filtros.'),
      if (_data case final data?) ...[
        Text(
          '${data.count} ofertas encontradas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        if (data.offers.isEmpty)
          const Text(
            'No encontramos ofertas con estos filtros. Prueba otras palabras o limpia los filtros.',
          ),
        for (final offer in data.offers)
          WorkspacePanel(
            title: offer.title,
            children: [
              Text(offer.companyName),
              const SizedBox(height: 8),
              Text('${offer.location} · ${offer.contractType}'),
              Text(
                'Categoría: ${offer.category.isEmpty ? 'Sin especificar' : offer.category}',
              ),
              Text(
                offer.salary == null
                    ? 'Salario no informado'
                    : 'Salario: ${offer.salary}',
              ),
              Text(
                'Publicada: ${offer.publishedAt.toLocal().toIso8601String().substring(0, 10)}',
              ),
            ],
          ),
        if (data.totalPages > 0)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: data.previousPage == null
                    ? null
                    : () => _go(data.previousPage!),
                child: const Text('Anterior'),
              ),
              Text('Página ${data.page} de ${data.totalPages}'),
              OutlinedButton(
                onPressed: data.nextPage == null
                    ? null
                    : () => _go(data.nextPage!),
                child: const Text('Siguiente'),
              ),
            ],
          ),
      ],
    ],
  );
}
