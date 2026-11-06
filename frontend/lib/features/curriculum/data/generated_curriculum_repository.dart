import 'dart:typed_data';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/curriculum/domain/generated_curriculum.dart';

class HttpGeneratedCurriculumRepository
    implements GeneratedCurriculumRepository {
  HttpGeneratedCurriculumRepository(this.api);
  final WorkNetApi api;

  GeneratedCurriculum _decode(Map<String, dynamic> body) {
    final cv = body['curriculum'];
    if (body['exists'] is! bool ||
        cv is! Map ||
        !curriculumTemplates.containsKey(cv['template']) ||
        cv['data'] is! Map<String, dynamic>) {
      throw const FormatException('Currículum generado no válido');
    }
    final data = cv['data'] as Map<String, dynamic>;
    if (data['personal'] is! Map ||
        data['personal']['full_name'] is! String ||
        data['professional_summary'] is! String ||
        curriculumSections.keys.any(
          (section) =>
              data[section] is! List ||
              (data[section] as List).any(
                (row) => row is! Map<String, dynamic>,
              ),
        )) {
      throw const FormatException('Datos de currículum incompletos');
    }
    return GeneratedCurriculum(
      exists: body['exists'],
      template: cv['template'],
      data: data,
    );
  }

  @override
  Future<GeneratedCurriculum> load(String token) async =>
      _decode(await api.request('curriculum/generated/', token: token));
  @override
  Future<GeneratedCurriculum> save(
    String token,
    GeneratedCurriculum draft,
  ) async => _decode(
    await api.request(
      'curriculum/generated/',
      token: token,
      method: 'PUT',
      data: draft.payload,
    ),
  );
  @override
  Future<Uint8List> preview(String token, GeneratedCurriculum draft) =>
      api.curriculumPdf(
        token: token,
        path: 'curriculum/generated/preview/',
        data: draft.payload,
      );
  @override
  Future<Uint8List> pdf(String token) =>
      api.curriculumPdf(token: token, path: 'curriculum/generated/pdf/');
}
