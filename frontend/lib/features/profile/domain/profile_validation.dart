import 'package:worknet/core/domain/failure.dart';

String? validateProfileDate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final date = DateTime.tryParse(value);
  return !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
          date == null ||
          date.toIso8601String().substring(0, 10) != value
      ? 'Usa una fecha válida: AAAA-MM-DD.'
      : null;
}

void validateProfilePhoto(String name, int length) {
  if (length > 2 * 1024 * 1024) {
    throw const ApiFailure('La fotografía no puede superar 2 MiB.');
  }
  if (!RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false).hasMatch(name)) {
    throw const ApiFailure('Selecciona una fotografía JPEG o PNG.');
  }
}

String? validateProfileEndDate(String? end, String start) {
  final invalid = validateProfileDate(end);
  if (invalid != null) return invalid;
  if (start.isNotEmpty &&
      end != null &&
      end.isNotEmpty &&
      validateProfileDate(start) == null &&
      end.compareTo(start) < 0) {
    return 'La fecha final no puede ser anterior a la inicial.';
  }
  return null;
}
