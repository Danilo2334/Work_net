import 'dart:typed_data';

class UploadedCurriculum {
  const UploadedCurriculum({required this.filename, required this.sizeBytes});
  final String filename;
  final int sizeBytes;
}

class CurriculumInfo {
  const CurriculumInfo({
    this.uploaded,
    required this.maxBytes,
    required this.maxPages,
  });
  final UploadedCurriculum? uploaded;
  final int maxBytes, maxPages;

  CurriculumInfo withUploaded(UploadedCurriculum value) =>
      CurriculumInfo(uploaded: value, maxBytes: maxBytes, maxPages: maxPages);
}

class SelectedPdf {
  const SelectedPdf(this.filename, this.bytes);
  final String filename;
  final Uint8List bytes;
}

abstract interface class CurriculumRepository {
  Future<CurriculumInfo> load(String token);
  Future<UploadedCurriculum> upload(String token, SelectedPdf file);
  Future<Uint8List> read(String token);
}

abstract interface class PdfPicker {
  Future<SelectedPdf?> pick(int maxBytes);
}
