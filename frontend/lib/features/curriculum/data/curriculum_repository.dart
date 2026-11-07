import 'dart:typed_data';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/curriculum/domain/curriculum.dart';

class HttpCurriculumRepository implements CurriculumRepository {
  HttpCurriculumRepository(this.api);
  final WorkNetApi api;

  static UploadedCurriculum _uploaded(dynamic value) {
    if (value is! Map ||
        value['filename'] is! String ||
        value['size_bytes'] is! int ||
        (value['size_bytes'] as int) <= 0) {
      throw const FormatException('Metadata de PDF no válida');
    }
    return UploadedCurriculum(
      filename: value['filename'],
      sizeBytes: value['size_bytes'],
    );
  }

  @override
  Future<CurriculumInfo> load(String token) async {
    final data = await api.request('curriculum/', token: token);
    final limits = data['limits'];
    if (limits is! Map ||
        limits['max_upload_bytes'] is! int ||
        limits['max_upload_pages'] is! int ||
        (limits['max_upload_bytes'] as int) <= 0 ||
        (limits['max_upload_pages'] as int) <= 0) {
      throw const FormatException('Límites de PDF no válidos');
    }
    return CurriculumInfo(
      uploaded: data['uploaded'] == null ? null : _uploaded(data['uploaded']),
      maxBytes: limits['max_upload_bytes'],
      maxPages: limits['max_upload_pages'],
    );
  }

  @override
  Future<UploadedCurriculum> upload(String token, SelectedPdf file) async =>
      _uploaded(
        (await api.uploadPdf(
          file.bytes,
          file.filename,
          token: token,
        ))['uploaded'],
      );

  @override
  Future<Uint8List> read(String token) => api.curriculumPdf(token: token);
}
