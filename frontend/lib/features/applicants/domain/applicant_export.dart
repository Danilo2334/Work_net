import 'dart:typed_data';
import 'applicant.dart';

enum ApplicantExportType { csv, pdf }

class ApplicantExportFile {
  const ApplicantExportFile({
    required this.bytes,
    required this.name,
    required this.type,
    required this.count,
  });
  final Uint8List bytes;
  final String name;
  final ApplicantExportType type;
  final int count;
}

abstract interface class ApplicantExportRepository {
  Future<ApplicantExportFile> export(
    String token,
    int offerId,
    ApplicantQuery query,
    ApplicantExportType type,
  );
}

abstract interface class ApplicantExportDownload {
  Future<bool> save(ApplicantExportFile file);
}
