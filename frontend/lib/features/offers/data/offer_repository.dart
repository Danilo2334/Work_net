import 'package:worknet/core/api/worknet_api.dart';
import '../domain/offer.dart';

class HttpOfferRepository implements OfferRepository {
  HttpOfferRepository(this.api);
  final WorkNetApi api;
  @override
  Future<OfferCatalog> catalog(String token) async {
    final data = await api.request('company/offers/', token: token);
    return OfferCatalog(
      categories: List<String>.from(data['categories'] as List),
      contractTypes: List<String>.from(data['contract_types'] as List),
    );
  }

  @override
  Future<int> publish(String token, OfferDraft draft) async {
    final data = await api.request(
      'company/offers/',
      token: token,
      data: draft.toJson(),
    );
    return (data['offer'] as Map<String, dynamic>)['id'] as int;
  }
}
