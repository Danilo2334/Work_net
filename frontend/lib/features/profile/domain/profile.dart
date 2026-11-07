import 'dart:typed_data';

class CandidateProfile {
  const CandidateProfile({
    required this.exists,
    required this.summary,
    required this.hasPhoto,
    required this.percentage,
    required this.entries,
  });
  final bool exists, hasPhoto;
  final String summary;
  final int percentage;
  // Structured business records, preserved for editing and future CV generation.
  final Map<String, List<Map<String, dynamic>>> entries;
}

abstract interface class ProfileRepository {
  Future<CandidateProfile> load(String token);
  Future<CandidateProfile> summary(
    String token,
    String text, {
    required bool create,
  });
  Future<CandidateProfile> saveRecord(
    String token,
    String section,
    Map<String, dynamic> fields, {
    String? id,
  });
  Future<CandidateProfile> deleteRecord(
    String token,
    String section,
    String id,
  );
  Future<CandidateProfile> clear(String token);
  Future<CandidateProfile> upload(
    String token,
    Uint8List bytes,
    String filename,
  );
  Future<CandidateProfile> removePhoto(String token);
  Future<Uint8List> photo(String token);
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
