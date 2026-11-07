// Adaptador Dart contra Django real. No acredita navegador ni Postman Desktop.
import 'dart:convert';
import 'dart:io';

import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/curriculum/data/generated_curriculum_repository.dart';
import 'package:worknet/features/curriculum/domain/generated_curriculum.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Indica el entorno privado de una corrida QA nueva.');
  }
  final environment = File(args.single).absolute;
  final body = jsonDecode(await environment.readAsString()) as Map;
  final env = {
    for (final row in body['values'] as List) row['key']: row['value'],
  };
  final state =
      jsonDecode(
            await File.fromUri(
              environment.parent.uri.resolve('state.json'),
            ).readAsString(),
          )
          as Map;
  final base = Uri.parse('${env['base_url']}/');
  String normalized(String value) => value.replaceAll('\\', '/').toLowerCase();
  if (base.scheme != 'http' ||
      base.host != '127.0.0.1' ||
      base.port != state['port'] ||
      state['qa_marker'] != 'WORKNET_POSTMAN_AISLADO' ||
      env['qa_confirmation'] != 'SOLO_BASE_AISLADA' ||
      !(env['qa_run_id'] as String).startsWith('run-') ||
      !environment.parent.path.endsWith(env['qa_run_id'] as String) ||
      normalized(state['database'] as String) !=
          normalized(
            File.fromUri(environment.parent.uri.resolve('qa.sqlite3')).path,
          )) {
    throw StateError('El entorno no corresponde a una base QA aislada.');
  }
  final api = WorkNetApi(baseUri: base);
  final repository = HttpGeneratedCurriculumRepository(api);
  var checks = 0;
  Object? ordered(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      // Django normalizes omitted optional dates to null when saving a CV.
      return {
        for (final key in keys)
          if (!(['start_date', 'end_date'].contains(key) && value[key] == null))
            key: ordered(value[key]),
      };
    }
    if (value is List) {
      return value.map(ordered).toList();
    }
    return value;
  }

  void check(bool value, String label) {
    if (!value) throw StateError(label);
    checks++;
  }

  Future<String> login(String field) async {
    final result = await api.request(
      'login/',
      data: {'email': env[field], 'password': env['qa_password']},
    );
    return result['token'] as String;
  }

  final token = await login('candidate_email');
  final profile = await api.request('profile/candidate/', token: token);
  final account = await api.request('account/', token: token);
  final initial = await repository.load(token);
  check(
    !initial.exists,
    'Usa otra corrida: esta cuenta ya tiene un CV generado.',
  );
  final source = profile['profile'] as Map;
  check(
    initial.data['professional_summary'] == source['professional_summary'],
    'Precarga del resumen',
  );
  for (final section in ['education', 'experience', 'skills', 'languages']) {
    final copied = initial.data[section] as List;
    final original = source[section] as List;
    check(
      copied.length == original.length &&
          copied.asMap().entries.every((entry) {
            final row = entry.value as Map;
            return !row.containsKey('id') &&
                row.entries.every(
                  (field) => original[entry.key][field.key] == field.value,
                );
          }),
      'Precarga de $section sin identificadores privados',
    );
  }
  final folder = Directory.fromUri(
    environment.parent.uri.resolve('pdf-hu012/'),
  );
  await folder.create();
  for (final template in curriculumTemplates.keys) {
    final draft = initial.edit(template: template);
    final saved = await repository.save(token, draft);
    check(saved.exists && saved.template == template, 'Guardar $template');
    check(
      jsonEncode(ordered(saved.data)) == jsonEncode(ordered(initial.data)),
      'Conservar datos al cambiar plantilla',
    );
    final pdf = await repository.pdf(token);
    check(
      pdf.length > 500 && ascii.decode(pdf.take(5).toList()) == '%PDF-',
      'PDF guardado de $template',
    );
    await File.fromUri(folder.uri.resolve('$template.pdf')).writeAsBytes(pdf);
  }
  check(
    jsonEncode(await api.request('profile/candidate/', token: token)) ==
        jsonEncode(profile),
    'El perfil original se conserva',
  );
  check(
    jsonEncode(await api.request('account/', token: token)) ==
        jsonEncode(account),
    'La cuenta original se conserva',
  );
  final other = await repository.load(await login('other_email'));
  check(!other.exists, 'Otro candidato no recibe el CV del titular');
  stdout.writeln(
    '$checks comprobaciones HTTP HU008/HU012 aprobadas; no navegador ni Desktop.',
  );
  exit(0);
}
