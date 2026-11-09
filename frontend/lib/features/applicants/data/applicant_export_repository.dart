import 'package:worknet/core/api/worknet_api.dart';
import '../domain/applicant.dart';
import '../domain/applicant_export.dart';

class HttpApplicantExportRepository implements ApplicantExportRepository {
  const HttpApplicantExportRepository(this.api);
  final WorkNetApi api;
  @override
  Future<ApplicantExportFile> export(
    String token,
    int offerId,
    ApplicantQuery query,
    ApplicantExportType type,
  ) => api.applicantExport(
    token: token,
    offerId: offerId,
    parameters: {
      'file_type': type.name,
      'order': query.order,
      if (query.experience.isNotEmpty) 'experience': query.experience,
      if (query.education.isNotEmpty) 'education': query.education,
      if (query.skill.isNotEmpty) 'skill': query.skill,
    },
    type: type,
  );
}
