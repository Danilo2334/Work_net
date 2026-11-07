class OfferCatalog {
  const OfferCatalog({required this.categories, required this.contractTypes});
  final List<String> categories, contractTypes;
}

class OfferDraft {
  const OfferDraft({
    required this.title,
    required this.description,
    required this.requirements,
    required this.salary,
    required this.location,
    required this.category,
    required this.contractType,
  });
  final String title,
      description,
      requirements,
      salary,
      location,
      category,
      contractType;
  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'requirements': requirements,
    'salary': salary,
    'location': location,
    'category': category,
    'contract_type': contractType,
  };
}

abstract interface class OfferRepository {
  Future<OfferCatalog> catalog(String token);
  Future<int> publish(String token, OfferDraft draft);
}

class EditableOffer {
  const EditableOffer(this.id, this.draft, {this.status = 'published'});
  final int id;
  final OfferDraft draft;
  final String status;
}

class ActiveOffers {
  const ActiveOffers(this.offers, this.count, this.nextPage, this.previousPage);
  final List<EditableOffer> offers;
  final int count;
  final int? nextPage, previousPage;
}

abstract interface class OfferEditingRepository {
  Future<ActiveOffers> active(String token, {int page = 1});
  Future<EditableOffer> read(String token, int id);
  Future<EditableOffer> update(String token, int id, OfferDraft draft);
}

abstract interface class OfferLifecycleRepository {
  Future<ActiveOffers> preserved(String token, {int page = 1});
  Future<EditableOffer> transition(
    String token,
    int id, {
    required bool archive,
  });
}
