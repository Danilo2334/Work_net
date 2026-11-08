import 'dart:typed_data';

import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/offers/data/offer_parser.dart'
    show validatePage;

import '../domain/application.dart';

class HttpApplicationsRepository implements ApplicationsRepository {
  HttpApplicationsRepository(this.api);
  final WorkNetApi api;
  static const invalid = ApiFailure(
    'No pudimos confirmar los datos de la postulación. Consulta su estado antes de volver a enviarla.',
  );

  T _parse<T>(T Function() action) {
    try {
      return action();
    } on Object catch (e) {
      if (e is! FormatException && e is! TypeError && e is! RangeError) rethrow;
      throw invalid;
    }
  }

  int _id(dynamic n) {
    if (n is! int || n <= 0) throw const FormatException();
    return n;
  }

  String _text(dynamic s) {
    if (s is! String || s.trim().isEmpty) throw const FormatException();
    return s;
  }

  String _source(dynamic s) {
    if (s != 'uploaded' && s != 'generated') throw const FormatException();
    return s as String;
  }

  ApplicationOffer _offer(dynamic raw) {
    final r = raw as Map<String, dynamic>,
        status = r['status'] as String,
        active = r['is_active'] as bool;
    if (!['published', 'closed', 'archived', 'draft'].contains(status) ||
        (active && status != 'published')) {
      throw const FormatException();
    }
    return ApplicationOffer(
      id: _id(r['id']),
      title: _text(r['title']),
      company: _text(r['company_name']),
      location: r['location'] as String,
      contract: r['contract_type'] as String,
      status: status,
      active: active,
    );
  }

  JobApplication _application(dynamic raw) {
    final r = raw as Map<String, dynamic>;
    final status = ApplicationStatus.values.firstWhere(
      (value) => value.code == r['status'],
      orElse: () => throw const FormatException(),
    );
    SentCv? cv;
    if (r['cv'] != null) {
      final c = r['cv'] as Map<String, dynamic>, source = _source(c['source']);
      final digest = c['sha256'] as String;
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
          (source == 'generated' &&
              !['clasica', 'moderna', 'minimalista'].contains(c['template'])) ||
          (source == 'uploaded' && c['template'] != '')) {
        throw const FormatException();
      }
      DateTime.parse(c['source_updated_at'] as String);
      cv = SentCv(
        source: source,
        filename: _text(c['filename']),
        sha256: digest,
        sourceId: _id(c['source_id']),
        size: _id(c['size_bytes']),
      );
    }
    return JobApplication(
      id: _id(r['id']),
      offer: _offer(r['offer']),
      createdAt: DateTime.parse(r['created_at'] as String),
      status: status,
      statusVersion: r['status_change'] == null
          ? 0
          : _version(r['status_change']['version']),
      statusModifiedAt: r['status_change']?['modified_at'] == null
          ? null
          : DateTime.parse(r['status_change']['modified_at'] as String),
      statusComment: r['status_change'] == null
          ? ''
          : r['status_change']['comment'] as String,
      cv: cv,
    );
  }

  int _version(dynamic value) {
    if (value is! int || value < 0) throw const FormatException();
    return value;
  }

  JobApplication decodeApplication(dynamic raw) =>
      _parse(() => _application(raw));

  ApplicationOffer decodeOffer(dynamic raw) => _parse(() => _offer(raw));

  @override
  Future<JobApplication> detail(String token, int applicationId) async {
    final r = await api.request('applications/$applicationId/', token: token);
    return _parse(() {
      final item = _application(r['application']);
      if (item.id != applicationId) throw const FormatException();
      return item;
    });
  }

  @override
  Future<ApplicationContext> context(String token, int offerId) async {
    final r = await api.request('offers/$offerId/application/', token: token);
    return _parse(() {
      final offer = _offer(r['offer']);
      if (offer.id != offerId) throw const FormatException();
      final choices = (r['cv_options'] as List).map((raw) {
        final c = raw as Map<String, dynamic>,
            revision = c['revision'] as String;
        DateTime.parse(revision);
        return CvChoice(
          source: _source(c['source']),
          id: _id(c['id']),
          revision: revision,
          label: _text(c['label']),
        );
      }).toList();
      if (choices.map((c) => c.source).toSet().length != choices.length) {
        throw const FormatException();
      }
      final existing = r['application'] == null
          ? null
          : _application(r['application']);
      if (existing != null && existing.offer.id != offerId) {
        throw const FormatException();
      }
      return ApplicationContext(
        offer: offer,
        candidateName: (r['candidate'] as Map)['full_name'] as String,
        choices: choices,
        existing: existing,
      );
    });
  }

  @override
  Future<JobApplication> submit(String token, int offerId, CvChoice cv) async {
    final r = await api.request(
      'offers/$offerId/application/',
      token: token,
      data: {
        'cv_source': cv.source,
        'cv_id': cv.id,
        'cv_revision': cv.revision,
        'confirm': true,
      },
    );
    return _parse(() {
      if (r['created'] is! bool) throw const FormatException();
      final item = _application(r['application']);
      if (item.offer.id != offerId ||
          (r['created'] == true &&
              (item.cv?.source != cv.source ||
                  item.cv?.sourceId != cv.id ||
                  item.status != ApplicationStatus.submitted))) {
        throw const FormatException();
      }
      return item;
    });
  }

  @override
  Future<ApplicationHistory> history(String token, {int page = 1}) async {
    final r = await api.request(
      'applications/?page=$page&page_size=10',
      token: token,
    );
    return _parse(() {
      final items = (r['applications'] as List).map(_application).toList();
      validatePage(r, page, items.length);
      if (items.map((a) => a.id).toSet().length != items.length) {
        throw const FormatException();
      }
      return ApplicationHistory(
        applications: items,
        count: r['count'] as int,
        page: page,
        pages: r['total_pages'] as int,
        next: r['next_page'] as int?,
        previous: r['previous_page'] as int?,
      );
    });
  }

  @override
  Future<Uint8List> pdf(String token, int applicationId) =>
      api.curriculumPdf(token: token, path: 'applications/$applicationId/cv/');
}
