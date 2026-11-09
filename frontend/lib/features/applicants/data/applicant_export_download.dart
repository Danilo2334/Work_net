import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import '../domain/applicant_export.dart';

class FileApplicantExportDownload implements ApplicantExportDownload {
  const FileApplicantExportDownload();
  @override
  Future<bool> save(ApplicantExportFile file) async {
    final csv = file.type == ApplicantExportType.csv;
    // El navegador descarga bytes ya autorizados; no persiste tokens en una URL.
    if (kIsWeb) {
      await XFile.fromData(
        file.bytes,
        name: file.name,
        mimeType: csv ? 'text/csv;charset=utf-8' : 'application/pdf',
      ).saveTo(file.name);
      return true;
    }
    // Android utiliza su selector de documentos; no requiere acceso general al almacenamiento.
    final path = await FileSaver.instance.saveAs(
      name: file.name.substring(0, file.name.lastIndexOf('.')),
      bytes: file.bytes,
      fileExtension: file.type.name,
      mimeType: csv ? MimeType.csv : MimeType.pdf,
    );
    return path != null;
  }
}
