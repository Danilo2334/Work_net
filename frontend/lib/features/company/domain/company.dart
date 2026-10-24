import 'dart:typed_data';
import 'package:worknet/core/domain/failure.dart';

enum CompanyState { pending, approved, rejected }

class CompanyDraft {
  const CompanyDraft({
    required this.name,
    required this.taxId,
    required this.sector,
    required this.location,
    required this.email,
    required this.description,
  });
  final String name, taxId, sector, location, email, description;
  void validate() {
    if ([
      name,
      taxId,
      sector,
      location,
      email,
      description,
    ].any((s) => s.trim().isEmpty)) {
      throw const ApiFailure('Completa todos los datos obligatorios.');
    }
    if (!RegExp(r'^\d{6,15}(?:-\d)?$').hasMatch(taxId.trim())) {
      throw const ApiFailure('Escribe un NIT válido.');
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim())) {
      throw const ApiFailure('Escribe un correo de contacto válido.');
    }
  }
}

class CompanyInfo {
  const CompanyInfo({
    required this.id,
    required this.draft,
    required this.state,
    required this.submitted,
    required this.reason,
    required this.version,
    required this.website,
    required this.socialLinks,
    required this.hasLogo,
  });
  final int? id;
  final CompanyDraft draft;
  final CompanyState state;
  final bool submitted, hasLogo;
  final String reason, website;
  final List<String> socialLinks;
  final int version;
  bool get canEdit =>
      state == CompanyState.rejected ||
      (state == CompanyState.pending && !submitted);
  String get stateLabel => switch (state) {
    CompanyState.pending => 'Pendiente',
    CompanyState.approved => 'Aprobada',
    CompanyState.rejected => 'Rechazada',
  };
}

class WorkspaceSummary {
  const WorkspaceSummary(
    this.metrics,
    this.notices,
    this.events,
    this.applications,
  );
  final Map<String, int> metrics;
  final List<String> notices, events, applications;
}

class CompanyListing {
  const CompanyListing(this.companies, this.page, this.hasNext, this.count);
  final List<CompanyInfo> companies;
  final int page, count;
  final bool hasNext;
}

abstract interface class CompanyRepository {
  Future<CompanyInfo> load(String token);
  Future<CompanyInfo> save(String token, CompanyDraft data);
  Future<CompanyInfo> submit(String token);
  Future<CompanyInfo> saveExtras(
    String token,
    String website,
    List<String> socialLinks,
  );
  Future<WorkspaceSummary> companySummary(String token);
  Future<WorkspaceSummary> adminSummary(String token);
  Future<CompanyListing> pending(String token, int page);
  Future<void> review(
    String token,
    CompanyInfo company, {
    required bool approve,
    String reason = '',
  });
  Future<void> uploadLogo(String token, Uint8List data, String filename);
  Future<Uint8List> logo(String token);
  Future<void> removeLogo(String token);
}

class SubmitCompany {
  const SubmitCompany(this.repository);
  final CompanyRepository repository;
  Future<CompanyInfo> call(String token, CompanyDraft draft) async {
    draft.validate();
    await repository.save(token, draft);
    return repository.submit(token);
  }
}

class ReviewCompany {
  const ReviewCompany(this.repository);
  final CompanyRepository repository;
  Future<void> call(
    String token,
    CompanyInfo company, {
    required bool approve,
    String reason = '',
  }) async {
    if (!approve && reason.trim().isEmpty) {
      throw const ApiFailure('Escribe el motivo del rechazo.');
    }
    return repository.review(
      token,
      company,
      approve: approve,
      reason: reason.trim(),
    );
  }
}
