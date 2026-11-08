import 'package:worknet/core/api/worknet_api.dart';
import '../domain/favorites.dart';
import 'offer_parser.dart';

class HttpSavedOffersRepository implements SavedOffersRepository {
  HttpSavedOffersRepository(this.api);
  final WorkNetApi api;
  @override
  Future<bool> setSaved(String token, int offerId, bool saved) async {
    final body = await api.request(
      'offers/$offerId/saved/',
      token: token,
      method: saved ? 'PUT' : 'DELETE',
    );
    if (body['offer_id'] != offerId || body['is_saved'] != saved) {
      throw const ApiFailure(
        'No pudimos confirmar el cambio. Reintenta para consultar el estado actual de Guardados.',
      );
    }
    return saved;
  }

  @override
  Future<SavedOffers> load(String token, {int page = 1}) async {
    final body = await api.request(
      'offers/saved/?page=$page&page_size=10',
      token: token,
    );
    try {
      final offers = (body['offers'] as List).map((raw) {
        final row = raw as Map<String, dynamic>,
            offer = parseOffer(raw, allowUnpublished: true);
        final status = row['status'] as String,
            availability = row['availability'] as String;
        if (!offer.isSaved ||
            !['published', 'closed', 'archived', 'draft'].contains(status) ||
            ![
              'active',
              'closed',
              'archived',
              'draft',
              'expired',
              'unavailable',
            ].contains(availability) ||
            row['is_active'] != (availability == 'active')) {
          throw const FormatException();
        }
        if (!(status == 'published'
                ? ['active', 'expired', 'unavailable']
                : [status])
            .contains(availability)) {
          throw const FormatException();
        }
        return SavedOfferEntry(
          offer: offer,
          status: status,
          availability: availability,
          savedAt: DateTime.parse(row['saved_at'] as String),
        );
      }).toList();
      validatePage(body, page, offers.length);
      if (offers.map((e) => e.offer.id).toSet().length != offers.length) {
        throw const FormatException();
      }
      return SavedOffers(
        offers: offers,
        count: body['count'] as int,
        page: page,
        totalPages: body['total_pages'] as int,
        nextPage: body['next_page'] as int?,
        previousPage: body['previous_page'] as int?,
      );
    } on Object catch (e) {
      if (e is! FormatException && e is! TypeError) rethrow;
      throw const ApiFailure(
        'No pudimos interpretar Guardados. Vuelve a intentarlo.',
      );
    }
  }
}
