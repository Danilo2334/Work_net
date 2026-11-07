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
