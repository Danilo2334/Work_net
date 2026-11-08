import 'search.dart';

class SavedOfferEntry {
  const SavedOfferEntry({
    required this.offer,
    required this.status,
    required this.availability,
    required this.savedAt,
  });
  final SearchOffer offer;
  final String status, availability;
  final DateTime savedAt;
  String get statusLabel => switch (availability) {
    'active' => 'Activa',
    'closed' => 'Cerrada',
    'archived' => 'Archivada',
    'expired' => 'Vencida',
    'draft' => 'Borrador',
    _ => 'No disponible',
  };
}

class SavedOffers {
  const SavedOffers({
    required this.offers,
    required this.count,
    required this.page,
    required this.totalPages,
    required this.nextPage,
    required this.previousPage,
  });
  final List<SavedOfferEntry> offers;
  final int count, page, totalPages;
  final int? nextPage, previousPage;
}

abstract interface class SavedOffersRepository {
  Future<SavedOffers> load(String token, {int page = 1});
  Future<bool> setSaved(String token, int offerId, bool saved);
}
