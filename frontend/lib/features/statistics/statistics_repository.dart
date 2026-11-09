import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/offers/data/offer_parser.dart'
    show validatePage;

const statisticLabels = {
  'submitted': 'Enviadas',
  'in_review': 'En revisión',
  'accepted': 'Aceptadas',
  'rejected': 'Rechazadas',
  'other': 'Otros estados históricos',
};

class OfferStatistics {
  const OfferStatistics(
    this.id,
    this.title,
    this.status,
    this.active,
    this.total,
    this.states,
  );
  final int id, total;
  final String title, status;
  final bool active;
  final Map<String, int> states;
}

class StatisticsSummary {
  const StatisticsSummary({
    required this.total,
    required this.states,
    required this.at,
    this.activeOffers,
    this.offers = const [],
    this.offerCount = 0,
    this.page = 1,
    this.pages = 0,
  });
  final int total, offerCount, page, pages;
  final int? activeOffers;
  final Map<String, int> states;
  final DateTime at;
  final List<OfferStatistics> offers;
}

abstract interface class StatisticsRepository {
  Future<StatisticsSummary> load(
    String token, {
    required bool company,
    int page = 1,
  });
}

class HttpStatisticsRepository implements StatisticsRepository {
  HttpStatisticsRepository(this.api);
  final WorkNetApi api;
  int _number(dynamic x) {
    if (x is! int || x < 0) throw const FormatException();
    return x;
  }

  Map<String, int> _states(dynamic data, int total) {
    final r = data as Map<String, dynamic>;
    if (r.length != statisticLabels.length ||
        !r.keys.every(statisticLabels.containsKey)) {
      throw const FormatException();
    }
    final counts = {for (final k in statisticLabels.keys) k: _number(r[k])};
    if (counts.values.fold<int>(0, (a, b) => a + b) != total) {
      throw const FormatException();
    }
    return counts;
  }

  @override
  Future<StatisticsSummary> load(
    String token, {
    required bool company,
    int page = 1,
  }) async {
    final r = await api.request(
      company
          ? 'statistics/company/?page=$page&page_size=10'
          : 'statistics/candidate/',
      token: token,
    );
    try {
      if (r['role'] != (company ? 'empresa' : 'candidato') ||
          r['scope'] != 'all_persisted_applications') {
        throw const FormatException();
      }
      final total = _number(r['applications_count']);
      final states = _states(r['states'], total);
      final at = DateTime.parse(r['as_of'] as String);
      if (!company) {
        return StatisticsSummary(total: total, states: states, at: at);
      }
      final p = r['offers'] as Map<String, dynamic>;
      final rows = (p['rows'] as List).map((dynamic raw) {
        final v = raw as Map<String, dynamic>, id = _number(v['id']);
        if (id == 0 ||
            ![
              'published',
              'closed',
              'archived',
              'draft',
            ].contains(v['status'])) {
          throw const FormatException();
        }
        final count = _number(v['applications_count']);
        return OfferStatistics(
          id,
          v['title'] as String,
          v['status'] as String,
          v['is_active'] as bool,
          count,
          _states(v['states'], count),
        );
      }).toList();
      validatePage(p, page, rows.length);
      if (rows.map((o) => o.id).toSet().length != rows.length) {
        throw const FormatException();
      }
      final count = _number(p['count']),
          active = _number(r['active_offers_count']);
      if (active > count || rows.any((o) => o.total > total)) {
        throw const FormatException();
      }
      return StatisticsSummary(
        total: total,
        states: states,
        at: at,
        activeOffers: active,
        offers: rows,
        offerCount: count,
        page: page,
        pages: _number(p['total_pages']),
      );
    } on Object catch (e) {
      if (e is! FormatException &&
          e is! TypeError &&
          e is! RangeError &&
          e is! StateError) {
        rethrow;
      }
      throw const ApiFailure(
        'No pudimos leer las estadísticas. Reintenta la consulta.',
      );
    }
  }
}
