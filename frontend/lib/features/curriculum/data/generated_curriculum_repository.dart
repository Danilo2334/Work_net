import 'dart:typed_data';

import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/curriculum/domain/generated_curriculum.dart';
import 'package:worknet/features/curriculum/domain/curriculum_assistant.dart';

class HttpGeneratedCurriculumRepository
    implements GeneratedCurriculumRepository, CurriculumAssistantRepository {
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

  @override
  Future<bool> assistantAvailable(String token) async {
    final body = await api.request(
      'curriculum/generated/assistant/',
      token: token,
    );
    if (body['available'] is! bool) {
      throw const FormatException('Estado del asistente no válido');
    }
    return body['available'] as bool;
  }

  @override
  Future<CurriculumSuggestion> suggest(
    String token, {
    required String text,
    required bool includeProfile,
    required bool consent,
  }) async {
    final body = await api.request(
      'curriculum/generated/assistant/',
      token: token,
      data: {
        'text': text,
        'include_profile': includeProfile,
        'consent': consent,
      },
    );
    final value = body['suggestion'];
    if (body['saved'] != false || value is! Map<String, dynamic>) {
      throw const FormatException('Propuesta del asistente no válida');
    }
    final data = value['data'];
    final fields = value['personal_fields'];
    final missing = value['missing_information'];
    const personalKeys = {'full_name', 'email', 'phone', 'location', 'website'};
    if (data is! Map<String, dynamic> ||
        data['personal'] is! Map<String, dynamic> ||
        personalKeys.any((key) => data['personal'][key] is! String) ||
        data['professional_summary'] is! String ||
        curriculumSections.keys.any(
          (key) =>
              data[key] is! List ||
              (data[key] as List).any((row) => row is! Map<String, dynamic>),
        ) ||
        fields is! List ||
        fields.any(
          (field) => field is! String || !personalKeys.contains(field),
        ) ||
        missing is! List ||
        missing.any((item) => item is! String) ||
        value['notice'] is! String) {
      throw const FormatException('Datos de propuesta incompletos');
    }
    return CurriculumSuggestion(
      data: data,
      personalFields: List<String>.unmodifiable(fields),
      missingInformation: List<String>.unmodifiable(missing),
      notice: value['notice'],
    );
  }
}
