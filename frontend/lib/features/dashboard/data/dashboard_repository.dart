import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/dashboard/domain/candidate_summary.dart';

abstract final class CandidateSummaryModel {
  static CandidateSummary parse(Map<String, dynamic> value) {
    int number(dynamic v) {
      if (v is! int || v < 0) throw const FormatException();
      return v;
    }

    final user = value['user'],
        p = value['profile_completion'],
        m = value['metrics'],
        rows = value['recent_jobs'];
    if (user is! Map ||
        user['full_name'] is! String ||
        user['role'] != 'candidato' ||
        p is! Map ||
        m is! Map ||
        rows is! List) {
      throw const FormatException();
    }
    final percent = number(p['percentage']);
    if (percent > 100) throw const FormatException();
    return CandidateSummary(
      name: user['full_name'],
      percentage: percent,
      applications: number(m['applications_count']),
      saved: number(m['saved_offers_count']),
      notifications: number(m['pending_notifications_count']),
      jobs: List.unmodifiable(
        rows.map((j) {
          if (j is! Map ||
              j['id'] is! int ||
              [
                'title',
                'company_name',
                'location',
                'contract_type',
                'published_at',
              ].any((k) => j[k] is! String)) {
            throw const FormatException();
          }
          return JobPreview(
            id: j['id'],
            title: j['title'],
            companyName: j['company_name'],
            location: j['location'],
            contractType: j['contract_type'],
          );
        }),
      ),
    );
  }
}

class HttpCandidateDashboardRepository implements CandidateDashboardRepository {
  HttpCandidateDashboardRepository(this.api);
  final WorkNetApi api;
  @override
  Future<CandidateSummary> load(String token) async =>
      CandidateSummaryModel.parse(
        await api.request('dashboard/candidate/', token: token),
      );
}
