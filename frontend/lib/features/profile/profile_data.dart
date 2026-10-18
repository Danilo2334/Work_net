class ProfileData {
  ProfileData(Map<String, dynamic> response) {
    final value = response['profile'],
        completion = response['profile_completion'];
    if (value is! Map ||
        value['exists'] is! bool ||
        value['professional_summary'] is! String ||
        value['has_photo'] is! bool ||
        completion is! Map ||
        completion['percentage'] is! int ||
        completion['percentage'] < 0 ||
        completion['percentage'] > 100) {
      throw const FormatException('Perfil no válido');
    }
    exists = value['exists'];
    summary = value['professional_summary'];
    hasPhoto = value['has_photo'];
    percentage = completion['percentage'];
    for (final section in profileSections.keys) {
      final rows = value[section];
      if (rows is! List) throw const FormatException('Sección no válida');
      entries[section] = rows.map((row) {
        if (row is! Map ||
            row['id'] is! String ||
            row[profileSections[section]!.$2] is! String) {
          throw const FormatException('Registro no válido');
        }
        return Map<String, dynamic>.from(row);
      }).toList();
    }
  }
  late final bool exists, hasPhoto;
  late final String summary;
  late final int percentage;
  final entries = <String, List<Map<String, dynamic>>>{};
}

const profileSections = {
  'education': ('Educación', 'qualification'),
  'experience': ('Experiencia laboral', 'position'),
  'skills': ('Habilidades', 'name'),
  'languages': ('Idiomas', 'name'),
};

const sectionSingular = {
  'education': 'educación',
  'experience': 'experiencia',
  'skills': 'habilidad',
  'languages': 'idioma',
};
