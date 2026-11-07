import 'dart:convert';
import 'dart:typed_data';

const curriculumTemplates = {
  'clasica': 'Clásica',
  'moderna': 'Moderna',
  'minimalista': 'Minimalista',
};

const curriculumSections = {
  'education': 'Educación',
  'experience': 'Experiencia laboral',
  'skills': 'Habilidades',
  'languages': 'Idiomas',
  'certifications': 'Certificaciones',
  'extra_sections': 'Otras secciones',
};

/// A detached snapshot: editing a draft never mutates the saved response/profile.
class GeneratedCurriculum {
  GeneratedCurriculum({
    required this.exists,
    required this.template,
    required Map<String, dynamic> data,
  }) : _data = jsonEncode(data);
  final bool exists;
  final String template;
  final String _data;
  Map<String, dynamic> get data => jsonDecode(_data) as Map<String, dynamic>;
  Map<String, dynamic> get payload => {'template': template, 'data': data};
  GeneratedCurriculum edit({String? template, Map<String, dynamic>? data}) =>
      GeneratedCurriculum(
        exists: exists,
        template: template ?? this.template,
        data: data ?? this.data,
      );
}

abstract interface class GeneratedCurriculumRepository {
  Future<GeneratedCurriculum> load(String token);
  Future<GeneratedCurriculum> save(String token, GeneratedCurriculum draft);
  Future<Uint8List> preview(String token, GeneratedCurriculum draft);
  Future<Uint8List> pdf(String token);
}

abstract interface class CurriculumDownload {
  /// False means the user cancelled the destination picker.
  Future<bool> save(Uint8List bytes);
}
