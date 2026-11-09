import 'dart:convert';

import 'generated_curriculum.dart';

class CurriculumSuggestion {
  CurriculumSuggestion({
    required Map<String, dynamic> data,
    required this.personalFields,
    required this.missingInformation,
    required this.notice,
  }) : _data = jsonEncode(data);

  final String _data;
  final List<String> personalFields;
  final List<String> missingInformation;
  final String notice;
  Map<String, dynamic> get data => jsonDecode(_data) as Map<String, dynamic>;

  /// Applying changes only the local draft; the owner still explicitly saves.
  Map<String, dynamic> applyTo(GeneratedCurriculum current) {
    final next = data;
    final personal = Map<String, dynamic>.from(current.data['personal'] as Map);
    for (final key in personalFields) {
      personal[key] = next['personal'][key];
    }
    next['personal'] = personal;
    return next;
  }
}

abstract interface class CurriculumAssistantRepository {
  Future<bool> assistantAvailable(String token);
  Future<CurriculumSuggestion> suggest(
    String token, {
    required String text,
    required bool includeProfile,
    required bool consent,
  });
}
