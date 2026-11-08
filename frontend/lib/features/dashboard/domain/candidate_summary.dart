class JobPreview {
  const JobPreview({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.contractType,
    this.isSaved = false,
  });
  final int id;
  final String title, companyName, location, contractType;
  final bool isSaved;
}

class CandidateSummary {
  const CandidateSummary({
    required this.name,
    required this.percentage,
    required this.applications,
    required this.saved,
    required this.notifications,
    required this.jobs,
    this.notices = const [],
  });
  final String name;
  final int percentage, applications, saved, notifications;
  final List<JobPreview> jobs;
  final List<CandidateNotice> notices;
}

class CandidateNotice {
  const CandidateNotice({
    required this.title,
    required this.createdAt,
    required this.pending,
    this.applicationId,
  });
  final String title;
  final DateTime createdAt;
  final bool pending;
  final int? applicationId;
}

abstract interface class CandidateDashboardRepository {
  Future<CandidateSummary> load(String token);
}
