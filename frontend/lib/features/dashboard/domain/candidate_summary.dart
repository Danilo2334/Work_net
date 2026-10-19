class JobPreview {
  const JobPreview({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.contractType,
  });
  final int id;
  final String title, companyName, location, contractType;
}

class CandidateSummary {
  const CandidateSummary({
    required this.name,
    required this.percentage,
    required this.applications,
    required this.saved,
    required this.notifications,
    required this.jobs,
  });
  final String name;
  final int percentage, applications, saved, notifications;
  final List<JobPreview> jobs;
}

abstract interface class CandidateDashboardRepository {
  Future<CandidateSummary> load(String token);
}
