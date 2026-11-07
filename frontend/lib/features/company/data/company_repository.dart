import 'dart:typed_data';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/company/domain/company.dart';

class HttpCompanyRepository implements CompanyRepository {
  HttpCompanyRepository(this.api);
  final WorkNetApi api;
  CompanyInfo _parse(dynamic c) {
    if (c is! Map ||
        (c['id'] != null && c['id'] is! int) ||
        c['submitted'] is! bool ||
        c['version'] is! int ||
        !['pending', 'approved', 'rejected'].contains(c['state']) ||
        [
          'legal_name',
          'tax_id',
          'sector',
          'location',
          'contact_email',
          'description',
          'rejection_reason',
          'website',
        ].any((k) => c[k] is! String) ||
        c['has_logo'] is! bool ||
        c['social_links'] is! List ||
        (c['social_links'] as List).any((v) => v is! String)) {
      throw const ApiFailure(
        'No pudimos interpretar la información empresarial.',
      );
    }
    return CompanyInfo(
      id: c['id'] as int?,
      draft: CompanyDraft(
        name: c['legal_name'],
        taxId: c['tax_id'],
        sector: c['sector'],
        location: c['location'],
        email: c['contact_email'],
        description: c['description'],
      ),
      state: CompanyState.values.byName(c['state']),
      submitted: c['submitted'],
      reason: c['rejection_reason'],
      version: c['version'],
      website: c['website'],
      socialLinks: List<String>.unmodifiable(c['social_links']),
      hasLogo: c['has_logo'],
    );
  }

  Future<CompanyInfo> _call(
    String token, {
    Map<String, dynamic>? data,
    String? path,
    String? method,
  }) async => _parse(
    (await api.request(
      path ?? 'company/',
      token: token,
      data: data,
      method: method,
    ))['company'],
  );
  @override
  Future<CompanyInfo> load(String token) => _call(token);
  @override
  Future<CompanyInfo> save(String token, CompanyDraft d) async {
    d.validate();
    return _call(
      token,
      method: 'PATCH',
      data: {
        'legal_name': d.name.trim(),
        'tax_id': d.taxId.trim(),
        'sector': d.sector.trim(),
        'location': d.location.trim(),
        'contact_email': d.email.trim(),
        'description': d.description.trim(),
      },
    );
  }

  @override
  Future<CompanyInfo> submit(String token) =>
      _call(token, path: 'company/submit/', data: {});
  @override
  Future<CompanyInfo> saveExtras(
    String token,
    String website,
    List<String> socialLinks,
  ) => _call(
    token,
    method: 'PATCH',
    data: {'website': website.trim(), 'social_links': socialLinks},
  );
  WorkspaceSummary _summary(Map<String, dynamic> response, List<String> keys) {
    final metrics = response['metrics'];
    if (metrics is! Map ||
        keys.any((k) => metrics[k] is! int || metrics[k] < 0) ||
        response['notifications'] is! List ||
        (keys.contains('candidates') && response['recent_events'] is! List) ||
        (keys.contains('active_offers') &&
            response['recent_applications'] is! List)) {
      throw const ApiFailure('No pudimos interpretar el resumen.');
    }
    final notices = (response['notifications'] as List).map((v) {
      if (v is! Map || v['title'] is! String) {
        throw const ApiFailure('Aviso no válido.');
      }
      return v['title'] as String;
    }).toList();
    final events = <String>[];
    for (final e in (response['recent_events'] as List? ?? [])) {
      if (e is! Map ||
          e['profile__legal_name'] is! String ||
          e['action'] is! String) {
        throw const ApiFailure('Evento no válido.');
      }
      final action = switch (e['action']) {
        'submitted' => 'Solicitud enviada',
        'approved' => 'Empresa aprobada',
        'rejected' => 'Solicitud rechazada',
        _ => 'Actualización',
      };
      events.add('$action · ${e['profile__legal_name']}');
    }
    final applications = <String>[];
    for (final a in (response['recent_applications'] as List? ?? [])) {
      if (a is! Map ||
          a['candidate__full_name'] is! String ||
          a['offer__title'] is! String) {
        throw const ApiFailure('Postulación no válida.');
      }
      applications.add('${a['candidate__full_name']} · ${a['offer__title']}');
    }
    return WorkspaceSummary(
      {for (final k in keys) k: metrics[k] as int},
      notices,
      events,
      applications,
    );
  }

  @override
  Future<WorkspaceSummary> companySummary(String token) async => _summary(
    await api.request('dashboard/company/', token: token),
    ['active_offers', 'closed_offers', 'applications'],
  );
  @override
  Future<WorkspaceSummary> adminSummary(String token) async => _summary(
    await api.request('dashboard/admin/', token: token),
    ['candidates', 'companies', 'pending_companies'],
  );
  @override
  Future<CompanyListing> pending(String token, int page) async {
    final r = await api.request('admin/companies/?page=$page', token: token);
    if (r['companies'] is! List ||
        r['page'] is! int ||
        r['count'] is! int ||
        r['has_next'] is! bool) {
      throw const ApiFailure('Listado no válido.');
    }
    return CompanyListing(
      (r['companies'] as List).map(_parse).toList(),
      r['page'],
      r['has_next'],
      r['count'],
    );
  }

  @override
  Future<void> review(
    String token,
    CompanyInfo company, {
    required bool approve,
    String reason = '',
  }) async {
    if (!approve && reason.trim().isEmpty) {
      throw const ApiFailure('Escribe el motivo del rechazo.');
    }
    await api.request(
      'admin/companies/${company.id}/review/',
      token: token,
      data: {
        'decision': approve ? 'approved' : 'rejected',
        'version': company.version,
        'reason': reason.trim(),
      },
    );
  }

  @override
  Future<void> uploadLogo(String token, Uint8List data, String filename) async {
    await api.uploadProfilePhoto(
      data,
      filename,
      token: token,
      path: 'company/logo/',
    );
  }

  @override
  Future<Uint8List> logo(String token) =>
      api.profilePhoto(token: token, path: 'company/logo/');
  @override
  Future<void> removeLogo(String token) async {
    await api.request('company/logo/', token: token, method: 'DELETE');
  }
}
