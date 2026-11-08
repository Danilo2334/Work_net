class OfferSearchQuery {
  const OfferSearchQuery({
    this.q = '',
    this.location = '',
    this.salaryMin = '',
    this.salaryMax = '',
    this.category = '',
    this.contractType = '',
    this.sort = 'relevance',
  });
  final String q, location, salaryMin, salaryMax, category, contractType, sort;
  Map<String, String> parameters(int page) => {
    if (q.trim().isNotEmpty) 'q': q.trim(),
    if (location.trim().isNotEmpty) 'location': location.trim(),
    if (salaryMin.trim().isNotEmpty)
      'salary_min': salaryMin.trim().replaceAll(',', '.'),
    if (salaryMax.trim().isNotEmpty)
      'salary_max': salaryMax.trim().replaceAll(',', '.'),
    if (category.isNotEmpty) 'category': category,
    if (contractType.isNotEmpty) 'contract_type': contractType,
    'sort': sort,
    'page': '$page',
    'page_size': '10',
  };
}

class SearchOffer {
  const SearchOffer({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.contractType,
    required this.category,
    required this.salary,
    required this.publishedAt,
  });
  final int id;
  final String title, companyName, location, contractType, category;
  final String? salary;
  final DateTime publishedAt;
}

class OfferSearchResult {
  const OfferSearchResult({
    required this.offers,
    required this.count,
    required this.page,
    required this.totalPages,
    required this.nextPage,
    required this.previousPage,
    required this.categories,
    required this.contractTypes,
  });
  final List<SearchOffer> offers;
  final List<String> categories, contractTypes;
  final int count, page, totalPages;
  final int? nextPage, previousPage;
}

abstract interface class OfferSearchRepository {
  Future<OfferSearchResult> search(
    String token,
    OfferSearchQuery query, {
    int page = 1,
  });
}
