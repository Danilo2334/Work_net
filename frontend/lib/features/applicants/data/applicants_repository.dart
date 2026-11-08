import 'dart:typed_data';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/applications/data/applications_repository.dart';
import 'package:worknet/features/offers/data/offer_parser.dart'
    show validatePage;
import 'package:worknet/features/profile/data/profile_model.dart';
import '../domain/applicant.dart';

class HttpApplicantsRepository implements ApplicantsRepository {
  HttpApplicantsRepository(this.api)
    : _applications = HttpApplicationsRepository(api);
  final WorkNetApi api;
  final HttpApplicationsRepository _applications;
  T _parse<T>(T Function() action) {
    try {
      return action();
    } on Object catch (e) {
      if (e is! FormatException && e is! TypeError && e is! RangeError) rethrow;
      throw const ApiFailure(
        'No pudimos leer los datos de los postulantes. Actualiza para volver a consultar.',
      );
    }
  }

  int _id(dynamic n) {
    if (n is! int || n <= 0) throw const FormatException();
    return n;
  }

  Applicant _applicant(dynamic raw, dynamic candidate) {
    final c = candidate as Map<String, dynamic>;
    return Applicant(
      application: _applications.decodeApplication(raw),
      candidateId: _id(c['id']),
      name: c['full_name'] as String,
    );
  }

  @override
  Future<ApplicantOffers> offers(String token, {int page = 1}) async {
    final r = await api.request(
      'company/applicant-offers/?page=$page&page_size=10',
      token: token,
    );
    return _parse(() {
      final rows = (r['offers'] as List).map((raw) {
        final v = raw as Map<String, dynamic>,
            count = v['applicants_count'] as int;
        if (![
              'published',
              'closed',
              'archived',
              'draft',
            ].contains(v['status']) ||
            count < 0) {
          throw const FormatException();
        }
        return ApplicantOffer(
          id: _id(v['id']),
          title: v['title'] as String,
          status: v['status'] as String,
          count: count,
        );
      }).toList();
      validatePage(r, page, rows.length);
      if (rows.map((x) => x.id).toSet().length != rows.length) {
        throw const FormatException();
      }
      return ApplicantOffers(
        offers: rows,
        count: r['count'] as int,
        page: page,
        pages: r['total_pages'] as int,
        next: r['next_page'] as int?,
        previous: r['previous_page'] as int?,
      );
    });
  }

  @override
  Future<ApplicantPage> applicants(
    String token,
    int offerId,
    ApplicantQuery query,
  ) async {
    final path = Uri(
      path: 'company/offers/$offerId/applications/',
      queryParameters: query.parameters,
    ).toString();
    final r = await api.request(path, token: token);
    return _parse(() {
      if (r['filter_scope'] != 'current_profile') throw const FormatException();
      final rows = (r['applications'] as List).map((raw) {
        final row = raw as Map<String, dynamic>;
        return _applicant(row, row['candidate']);
      }).toList();
      validatePage(r, query.page, rows.length);
      if (rows.any((x) => x.application.offer.id != offerId) ||
          rows.map((x) => x.application.id).toSet().length != rows.length) {
        throw const FormatException();
      }
      final offer = _applications.decodeOffer(r['offer']);
      if (offer.id != offerId) throw const FormatException();
      return ApplicantPage(
        offer: offer,
        applicants: rows,
        count: r['count'] as int,
        page: query.page,
        pages: r['total_pages'] as int,
        next: r['next_page'] as int?,
        previous: r['previous_page'] as int?,
      );
    });
  }

  @override
  Future<ApplicantDetail> detail(
    String token,
    int offerId,
    int applicationId,
  ) async {
    final responses = await Future.wait([
      api.request('company/applications/$applicationId/', token: token),
      api.request('company/applications/$applicationId/profile/', token: token),
    ]);
    return _parse(() {
      final r = responses[0], p = responses[1];
      final pa = p['application'] as Map<String, dynamic>,
          pc = p['candidate'] as Map<String, dynamic>;
      final item = _applicant(r['application'], r['candidate']);
      if (item.application.id != applicationId ||
          item.application.offer.id != offerId ||
          pa['id'] != applicationId ||
          pa['offer_id'] != offerId ||
          pc['id'] != item.candidateId) {
        throw const FormatException();
      }
      return ApplicantDetail(applicant: item, profile: ProfileModel.parse(p));
    });
  }

  @override
  Future<Uint8List> pdf(String token, int applicationId) => api.curriculumPdf(
    token: token,
    path: 'company/applications/$applicationId/cv/',
  );
}
