import '../domain/search.dart';

SearchOffer parseOffer(
  Map<String, dynamic> row, {
  bool allowUnpublished = false,
}) {
  final id = row['id'] as int, saved = row['is_saved'] as bool;
  final salary = row['salary'] as String?;
  final published = row['published_at'];
  if (id <= 0 ||
      (salary != null && !RegExp(r'^\d{1,10}\.\d{2}$').hasMatch(salary)) ||
      (published is! String && !(allowUnpublished && published == null))) {
    throw const FormatException();
  }
  return SearchOffer(
    id: id,
    title: row['title'] as String,
    companyName: row['company_name'] as String,
    location: row['location'] as String,
    contractType: row['contract_type'] as String,
    category: row['category'] as String,
    salary: salary,
    publishedAt: published == null ? null : DateTime.parse(published as String),
    isSaved: saved,
  );
}

void validatePage(Map<String, dynamic> body, int page, int length) {
  final count = body['count'] as int,
      current = body['page'] as int,
      pages = body['total_pages'] as int,
      size = body['page_size'] as int;
  if (count < 0 ||
      current != page ||
      size != 10 ||
      pages != (count / size).ceil() ||
      current < 1 ||
      current > (pages == 0 ? 1 : pages) ||
      body['next_page'] != (current < pages ? current + 1 : null) ||
      body['previous_page'] != (current > 1 ? current - 1 : null) ||
      length !=
          (count == 0
              ? 0
              : current < pages
              ? size
              : count - (current - 1) * size)) {
    throw const FormatException();
  }
}
