import 'package:worknet/core/api/worknet_api.dart';
import '../domain/offer.dart';

class HttpOfferRepository implements OfferRepository {
  HttpOfferRepository(this.api);
  final WorkNetApi api;
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
