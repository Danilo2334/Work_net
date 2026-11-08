import 'package:worknet/core/api/worknet_api.dart';

import '../domain/search.dart';

class HttpOfferSearchRepository implements OfferSearchRepository {
  HttpOfferSearchRepository(this.api);
  final WorkNetApi api;
  @override
  Future<OfferSearchResult> search(
    String token,
    OfferSearchQuery query, {
    int page = 1,
  }) async {
    final body = await api.request(
      Uri(
        path: 'offers/search/',
        queryParameters: query.parameters(page),
      ).toString(),
      token: token,
    );
    try {
      final count = body['count'] as int,
          current = body['page'] as int,
          pages = body['total_pages'] as int,
          size = body['page_size'] as int;
      final next = body['next_page'] as int?,
          previous = body['previous_page'] as int?;
      if (count < 0 ||
          current != page ||
          size != 10 ||
          pages != (count / size).ceil() ||
          current < 1 ||
          current > (pages == 0 ? 1 : pages) ||
          next != (current < pages ? current + 1 : null) ||
          previous != (current > 1 ? current - 1 : null)) {
        throw const FormatException();
      }
      String field(Map<String, dynamic> row, String key) {
        final value = row[key] as String;
        return value;
      }

      final offers = (body['offers'] as List).map((raw) {
        final row = raw as Map<String, dynamic>;
        final salary = row['salary'] as String?;
        if ((row['id'] as int) <= 0 ||
            (salary != null &&
                !RegExp(r'^\d{1,10}\.\d{2}$').hasMatch(salary))) {
          throw const FormatException();
        }
        return SearchOffer(
          id: row['id'] as int,
          title: field(row, 'title'),
          companyName: field(row, 'company_name'),
          location: field(row, 'location'),
          contractType: field(row, 'contract_type'),
          category: field(row, 'category'),
          salary: salary,
          publishedAt: DateTime.parse(field(row, 'published_at')),
        );
      }).toList();
      final expected = count == 0
          ? 0
          : current < pages
          ? size
          : count - (current - 1) * size;
      if (offers.length != expected ||
          offers.map((o) => o.id).toSet().length != offers.length) {
        throw const FormatException();
      }
      return OfferSearchResult(
        offers: offers,
        count: count,
        page: current,
        totalPages: pages,
        nextPage: next,
        previousPage: previous,
        categories: List<String>.from(body['categories'] as List),
        contractTypes: List<String>.from(body['contract_types'] as List),
      );
    } on Object catch (e) {
      if (e is! FormatException && e is! TypeError) rethrow;
      throw const ApiFailure(
        'No pudimos interpretar las ofertas. Vuelve a intentarlo.',
      );
    }
  }
}
