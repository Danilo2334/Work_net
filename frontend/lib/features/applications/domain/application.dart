import 'dart:typed_data';

class ApplicationOffer {
  const ApplicationOffer({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.contract,
    required this.status,
    required this.active,
  });
  final int id;
  final String title, company, location, contract, status;
  final bool active;
}

class CvChoice {
  const CvChoice({
    required this.source,
    required this.id,
    required this.revision,
    required this.label,
  });
  final String source, revision, label;
  final int id;
  String get typeLabel => source == 'uploaded' ? 'CV subido' : 'CV generado';
}

class SentCv {
  const SentCv({
    required this.source,
    required this.filename,
    required this.sha256,
    required this.sourceId,
    required this.size,
  });
  final String source, filename, sha256;
  final int sourceId, size;
  String get typeLabel => source == 'uploaded' ? 'CV subido' : 'CV generado';
}

class JobApplication {
  const JobApplication({
    required this.id,
    required this.offer,
    required this.createdAt,
    this.cv,
  });
  final int id;
  final ApplicationOffer offer;
  final DateTime createdAt;
  final SentCv? cv;
  String get dateLabel => createdAt
      .toLocal()
      .toIso8601String()
      .substring(0, 19)
      .replaceFirst('T', ' ');
}

class ApplicationContext {
  const ApplicationContext({
    required this.offer,
    required this.candidateName,
    required this.choices,
    this.existing,
  });
  final ApplicationOffer offer;
  final String candidateName;
  final List<CvChoice> choices;
  final JobApplication? existing;
}

class ApplicationHistory {
  const ApplicationHistory({
    required this.applications,
    required this.count,
    required this.page,
    required this.pages,
    this.next,
    this.previous,
  });
  final List<JobApplication> applications;
  final int count, page, pages;
  final int? next, previous;
}

abstract interface class ApplicationsRepository {
  Future<ApplicationContext> context(String token, int offerId);
  Future<JobApplication> submit(String token, int offerId, CvChoice cv);
  Future<ApplicationHistory> history(String token, {int page = 1});
  Future<Uint8List> pdf(String token, int applicationId);
}
