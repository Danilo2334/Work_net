import 'package:worknet/core/api/worknet_api.dart';

import '../domain/offer.dart';

class HttpOfferRepository implements OfferRepository, OfferEditingRepository {
  HttpOfferRepository(this.api);
  final WorkNetApi api;
  EditableOffer _offer(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! int ||
        (value['id'] as int) <= 0 ||
        value['status'] != 'published' ||
        [
          'title',
          'description',
          'requirements',
          'location',
          'category',
          'contract_type',
        ].any((k) => value[k] is! String) ||
        (value['salary'] != null && value['salary'] is! String)) {
      throw const ApiFailure(
        'Recibimos una oferta no válida. Vuelve a consultarla.',
      );
    }
    return EditableOffer(
      value['id'] as int,
      OfferDraft(
        title: value['title'] as String,
        description: value['description'] as String,
        requirements: value['requirements'] as String,
        salary: value['salary'] as String? ?? '',
        location: value['location'] as String,
        category: value['category'] as String,
        contractType: value['contract_type'] as String,
      ),
    );
  }

  @override
  Future<ActiveOffers> active(String token, {int page = 1}) async {
    final data = await api.request(
      'company/offers/active/?page=$page',
      token: token,
    );
    if (data['offers'] is! List ||
        data['count'] is! int ||
        (data['count'] as int) < 0 ||
        ['next_page', 'previous_page'].any(
          (k) => data[k] != null && (data[k] is! int || (data[k] as int) <= 0),
        )) {
      throw const ApiFailure(
        'Recibimos una lista de ofertas no válida. Vuelve a intentarlo.',
      );
    }
    return ActiveOffers(
      (data['offers'] as List).map(_offer).toList(),
      data['count'] as int,
      data['next_page'] as int?,
      data['previous_page'] as int?,
    );
  }

  @override
  Future<EditableOffer> read(String token, int id) async {
    final offer = _offer(
      (await api.request('company/offers/$id/', token: token))['offer'],
    );
    if (offer.id != id) {
      throw const ApiFailure('La respuesta no corresponde a esta oferta.');
    }
    return offer;
  }

  @override
  Future<EditableOffer> update(String token, int id, OfferDraft draft) async {
    final offer = _offer(
      (await api.request(
        'company/offers/$id/',
        token: token,
        method: 'PATCH',
        data: draft.toJson(),
      ))['offer'],
    );
    if (offer.id != id) {
      throw const ApiFailure(
        'No pudimos confirmar los cambios de esta oferta. Vuelve a consultarla.',
      );
    }
    return offer;
  }

  @override
  Future<OfferCatalog> catalog(String token) async {
    final data = await api.request('company/offers/', token: token);
    List<String> choices(String key) {
      final value = data[key];
      if (value is! List ||
          value.isEmpty ||
          value.any((item) => item is! String || item.trim().isEmpty)) {
        throw const ApiFailure(
          'Recibimos un catálogo de ofertas no válido. Vuelve a intentarlo.',
        );
      }
      return List<String>.from(value).toSet().toList();
    }

    return OfferCatalog(
      categories: choices('categories'),
      contractTypes: choices('contract_types'),
    );
  }

  @override
  Future<int> publish(String token, OfferDraft draft) async {
    final data = await api.request(
      'company/offers/',
      token: token,
      data: draft.toJson(),
    );
    final offer = data['offer'];
    final id = offer is Map<String, dynamic> ? offer['id'] : null;
    if (id is! int || id <= 0) {
      throw const ApiFailure(
        'No pudimos confirmar la publicación. Consulta el dashboard antes de volver a intentarlo.',
      );
    }
    return id;
  }
}
