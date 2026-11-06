// Apoyo HTTP con el adaptador real; no sustituye navegador ni Postman Desktop.
import 'dart:convert';
import 'dart:io';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/offers/data/offer_repository.dart';
import 'package:worknet/features/offers/domain/offer.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1)
    throw ArgumentError('Indica el entorno privado de una corrida QA nueva.');
  final data = jsonDecode(await File(args.single).readAsString()) as Map;
  final env = {for (final v in data['values'] as List) v['key']: v['value']};
  final base = Uri.parse('${env['base_url']}/');
  if (base.scheme != 'http' ||
      base.host != '127.0.0.1' ||
      base.port != 8021 ||
      !(env['qa_run_id'] as String).startsWith('run-')) {
    throw StateError('Usar exclusivamente la corrida HU013 aislada en 8021.');
  }
  final api = WorkNetApi(baseUri: base);
  var checks = 0;
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

  final token = await login('company_email');
  final repository = HttpOfferRepository(api);
  final catalog = await repository.catalog(token);
  check(
    catalog.categories.isNotEmpty && catalog.contractTypes.isNotEmpty,
    'Catálogo',
  );
  final before = await api.request('dashboard/company/', token: token);
  final draft = OfferDraft(
    title: 'Oferta ficticia HU013 HTTP',
    description: 'Comprobación aislada',
    requirements: 'Pruebas de integración',
    salary: '2500000.50',
    location: 'Pasto',
    category: catalog.categories.first,
    contractType: catalog.contractTypes.first,
  );
  final id = await repository.publish(token, draft);
  check(id > 0, 'Publicación');
  final after = await api.request('dashboard/company/', token: token);
  check(
    after['metrics']['active_offers'] == before['metrics']['active_offers'] + 1,
    'Dashboard persistido',
  );
  for (final field in ['candidate_email', 'draft_email']) {
    final other = await login(field);
    try {
      await repository.publish(other, draft);
      throw StateError('Permiso inesperado');
    } on ApiFailure catch (e) {
      check(e.status == 403, 'Permiso $field');
    }
  }
  try {
    await repository.publish(
      token,
      OfferDraft(
        title: '',
        description: draft.description,
        requirements: draft.requirements,
        salary: '-1',
        location: draft.location,
        category: draft.category,
        contractType: draft.contractType,
      ),
    );
    throw StateError('Validación inesperada');
  } on ApiFailure catch (e) {
    check(e.status == 400, 'Validación');
  }
  final last = await api.request('dashboard/company/', token: token);
  check(
    last['metrics']['active_offers'] == after['metrics']['active_offers'],
    'Rechazos sin escritura',
  );
  stdout.writeln(
    '$checks comprobaciones HTTP HU013 aprobadas; no navegador ni Desktop.',
  );
  exit(0);
}
