import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/app.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/core/theme/worknet_theme.dart';
import 'package:worknet/features/access/session.dart';
import 'package:worknet/features/profile/profile_data.dart';
import 'package:worknet/features/profile/profile_page.dart';

import 'support/access_fakes.dart';

Map<String, dynamic> profile({
  bool exists = false,
  String summary = '',
  bool photo = false,
  int percentage = 17,
  Map<String, List<Map<String, dynamic>>>? rows,
}) => {
  'profile': {
    'exists': exists,
    'professional_summary': summary,
    'has_photo': photo,
    for (final section in profileSections.keys) section: rows?[section] ?? [],
  },
  'profile_completion': {'percentage': percentage},
};

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> start(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  MemorySessionStore? store,
  String path = '/profile',
}) async {
  final api = WorkNetApi(client: MockClient(handler));
  addTearDown(api.close);
  await tester.pumpWidget(
    WorkNetApp(
      key: UniqueKey(),
      api: api,
      sessionStore:
          store ?? (MemorySessionStore()..value = jsonEncode(sessionData())),
      initialLocation: path,
    ),
  );
  await tester.pumpAndSettle();
}

final image = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGPgqC8AAAGKAPgcNHpfAAAAAElFTkSuQmCC',
);

Future<void> photoPage(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
  Future<XFile?> Function() picker,
) async {
  final api = WorkNetApi(client: MockClient(handler));
  addTearDown(api.close);
  final store = MemorySessionStore()..value = jsonEncode(sessionData());
  final controller = SessionController(api: api, store: store);
  addTearDown(controller.dispose);
  await controller.restore();
  await tester.pumpWidget(
    MaterialApp(
      theme: workNetTheme(),
      home: ProfilePage(controller: controller, pickPhoto: picker),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('perfil exige sesión y rol candidato', (tester) async {
    for (final value in [
      null,
      jsonEncode(sessionData(role: 'empresa')),
      jsonEncode(sessionData(role: 'admin')),
    ]) {
      var calls = 0;
      await start(tester, (_) async {
        calls++;
        return jsonResponse(profile());
      }, store: MemorySessionStore()..value = value);
      expect(calls, 0);
      expect(find.text('Perfil del candidato'), findsNothing);
    }
  });

  testWidgets('dashboard abre perfil vacío y foto es opcional', (tester) async {
    await start(
      tester,
      (r) async => jsonResponse(
        r.url.path.endsWith('candidate/') && !r.url.path.contains('profile/')
            ? dashboardData()
            : profile(),
      ),
      path: '/dashboard',
    );
    await tap(tester, 'open_candidate_profile');
    expect(find.textContaining('Tu perfil está vacío'), findsOneWidget);
    expect(
      find.textContaining('Puedes completar tu perfil sin fotografía.'),
      findsOneWidget,
    );
    expect(find.text('Completitud del perfil · 17%'), findsOneWidget);
  });

  testWidgets(
    'crear descripción persiste y dashboard muestra cálculo recibido de API',
    (tester) async {
      var summary = '';
      await start(tester, (r) async {
        if (r.url.path.contains('dashboard/')) {
          return jsonResponse({
            ...dashboardData(),
            'profile_completion': {
              ...dashboardData()['profile_completion'] as Map,
              'percentage': 33,
            },
          });
        }
        if (r.method == 'POST') {
          expect(jsonDecode(r.body), {
            'professional_summary': 'Descripción QA',
          });
          summary = 'Descripción QA';
        }
        return jsonResponse(
          profile(
            exists: summary.isNotEmpty,
            summary: summary,
            percentage: summary.isEmpty ? 17 : 33,
          ),
        );
      });
      await tester.enterText(
        find.byKey(const Key('profile_summary')),
        'Descripción QA',
      );
      await tap(tester, 'save_profile_summary');
      expect(find.text('Descripción guardada correctamente.'), findsOneWidget);
      await tap(tester, 'close_profile');
      expect(find.text('Completitud del perfil · 33%'), findsOneWidget);
      await tap(tester, 'open_candidate_profile');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('profile_summary')))
            .controller!
            .text,
        'Descripción QA',
      );
    },
  );

  testWidgets(
    'cada sección permite crear editar y eliminar registros con su id',
    (tester) async {
      final rows = <String, List<Map<String, dynamic>>>{
        for (final section in profileSections.keys) section: [],
      };
      await start(tester, (r) async {
        expect(r.headers['Authorization'], 'Token qa-token');
        final parts = r.url.path.split('/').where((s) => s.isNotEmpty).toList();
        if (parts.length >= 4) {
          final section = parts[3];
          if (r.method == 'POST') {
            rows[section]!.add({
              'id': 'qa-id',
              ...jsonDecode(r.body) as Map<String, dynamic>,
            });
          }
          if (r.method == 'PATCH') {
            expect(parts[4], 'qa-id');
            rows[section]![0].addAll(jsonDecode(r.body));
          }
          if (r.method == 'DELETE') {
            expect(parts[4], 'qa-id');
            rows[section]!.clear();
          }
        }
        return jsonResponse(profile(exists: true, rows: rows));
      });
      for (final section in profileSections.keys) {
        final field = profileSections[section]!.$2;
        await tap(tester, 'add_$section');
        await tester.enterText(find.byKey(Key('record_$field')), 'Registro QA');
        await tap(tester, 'save_profile_record');
        expect(find.text('Registro QA'), findsOneWidget);
        await tap(tester, 'edit_${section}_qa-id');
        await tester.enterText(
          find.byKey(Key('record_$field')),
          'Registro editado QA',
        );
        await tap(tester, 'save_profile_record');
        expect(find.text('Registro editado QA'), findsOneWidget);
        await tap(tester, 'delete_${section}_qa-id');
        await tap(tester, 'confirm_profile_delete');
        expect(find.text('Registro editado QA'), findsNothing);
      }
    },
  );

  testWidgets(
    'valida campos obligatorios fechas reales y orden antes de enviar',
    (tester) async {
      var writes = 0;
      await start(tester, (r) async {
        if (r.method != 'GET') writes++;
        return jsonResponse(profile());
      });
      await tap(tester, 'add_education');
      await tap(tester, 'save_profile_record');
      expect(find.text('Completa este campo.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('record_qualification')),
        'QA',
      );
      await tester.enterText(
        find.byKey(const Key('record_start_date')),
        '2026-02-31',
      );
      await tap(tester, 'save_profile_record');
      expect(find.text('Usa una fecha válida: AAAA-MM-DD.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('record_start_date')),
        '2026-03-01',
      );
      await tester.enterText(
        find.byKey(const Key('record_end_date')),
        '2025-01-01',
      );
      await tap(tester, 'save_profile_record');
      expect(
        find.text('La fecha final no puede ser anterior a la inicial.'),
        findsOneWidget,
      );
      expect(writes, 0);
    },
  );

  testWidgets(
    'rechazo de Django conserva el borrador y permite reintentar en el editor',
    (tester) async {
      var attempts = 0;
      await start(tester, (r) async {
        if (r.method == 'POST' && ++attempts == 1) {
          return jsonResponse({
            'errors': {
              'name': ['Error de QA del servicio.'],
            },
          }, 400);
        }
        return jsonResponse(
          profile(
            exists: true,
            rows: attempts == 0
                ? null
                : {
                    'skills': [
                      {'id': 'qa', 'name': 'Habilidad QA'},
                    ],
                  },
          ),
        );
      });
      await tap(tester, 'add_skills');
      await tester.enterText(
        find.byKey(const Key('record_name')),
        'Habilidad QA',
      );
      await tap(tester, 'save_profile_record');
      expect(find.text('Error de QA del servicio.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('record_name')))
            .controller!
            .text,
        'Habilidad QA',
      );
      await tap(tester, 'save_profile_record');
      expect(find.text('Registro guardado correctamente.'), findsOneWidget);
    },
  );

  testWidgets(
    'foto usa multipart y lectura autenticada sin token en URL y se puede eliminar',
    (tester) async {
      var hasPhoto = false, uploads = 0;
      await photoPage(
        tester,
        (r) async {
          expect(r.headers['Authorization'], 'Token qa-token');
          expect(r.url.query, isEmpty);
          if (r.url.path.endsWith('photo/')) {
            if (r.method == 'GET') {
              return http.Response.bytes(
                image,
                200,
                headers: {'content-type': 'image/png'},
              );
            }
            if (r.method == 'PUT') {
              uploads++;
              expect(
                r.headers['content-type'],
                startsWith('multipart/form-data'),
              );
              expect(latin1.decode(r.bodyBytes), contains('filename="qa.png"'));
              hasPhoto = true;
            }
            if (r.method == 'DELETE') hasPhoto = false;
          }
          return jsonResponse(profile(exists: true, photo: hasPhoto));
        },
        () async => XFile.fromData(
          image,
          path: 'qa.png',
          name: 'qa.png',
          mimeType: 'image/png',
        ),
      );
      await tap(tester, 'upload_profile_photo');
      expect(uploads, 1);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Completitud del perfil · 17%'), findsOneWidget);
      await tap(tester, 'delete_profile_photo');
      await tap(tester, 'confirm_profile_delete');
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'foto inválida del backend conserva foto previa y muestra error',
    (tester) async {
      await photoPage(
        tester,
        (r) async {
          if (r.url.path.endsWith('photo/')) {
            if (r.method == 'GET') {
              return http.Response.bytes(
                image,
                200,
                headers: {'content-type': 'image/png'},
              );
            }
            return jsonResponse({
              'errors': {
                'photo': ['La imagen está dañada.'],
              },
            }, 400);
          }
          return jsonResponse(profile(exists: true, photo: true));
        },
        () async => XFile.fromData(
          Uint8List.fromList([1, 2]),
          path: 'fake.png',
          name: 'fake.png',
        ),
      );
      await tap(tester, 'upload_profile_photo');
      expect(find.text('La imagen está dañada.'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('selector cancelado y foto demasiado grande no realizan carga', (
    tester,
  ) async {
    var writes = 0, choice = 0;
    await photoPage(
      tester,
      (r) async {
        if (r.method != 'GET') writes++;
        return jsonResponse(profile());
      },
      () async => choice++ == 0
          ? null
          : XFile.fromData(
              Uint8List(2 * 1024 * 1024 + 1),
              path: 'grande.png',
              name: 'grande.png',
            ),
    );
    await tap(tester, 'upload_profile_photo');
    expect(writes, 0);
    await tap(tester, 'upload_profile_photo');
    expect(find.text('La fotografía no puede superar 2 MiB.'), findsOneWidget);
    expect(writes, 0);
  });

  testWidgets(
    'vaciar perfil pide confirmación conserva cuenta y deja estado vacío',
    (tester) async {
      var exists = true;
      await start(tester, (r) async {
        if (r.method == 'DELETE') exists = false;
        return jsonResponse(
          profile(exists: exists, summary: exists ? 'QA' : ''),
        );
      });
      await tap(tester, 'clear_profile');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(exists, true);
      await tap(tester, 'clear_profile');
      await tap(tester, 'confirm_profile_delete');
      expect(find.textContaining('Tu perfil está vacío'), findsOneWidget);
    },
  );

  testWidgets('carga fallida permite reintentar y 401 elimina sesión', (
    tester,
  ) async {
    var attempts = 0;
    final store = MemorySessionStore()..value = jsonEncode(sessionData());
    await start(
      tester,
      (_) async => ++attempts == 1
          ? http.Response('offline', 500)
          : jsonResponse({'detail': 'Invalid token'}, 401),
      store: store,
    );
    expect(find.text('No pudimos cargar tu perfil'), findsOneWidget);
    await tap(tester, 'retry_profile');
    expect(find.byKey(const Key('submit_login')), findsOneWidget);
    expect(store.value, isNull);
  });

  testWidgets('datos malformados muestran error sin inventar perfil', (
    tester,
  ) async {
    await start(
      tester,
      (_) async => jsonResponse({'profile': {}, 'profile_completion': {}}),
    );
    expect(
      find.text('No pudimos interpretar tu perfil. Vuelve a intentarlo.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('save_profile_summary')), findsNothing);
  });

  testWidgets(
    'formulario y editor de educación funcionan en escritorio y móvil',
    (tester) async {
      for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await start(tester, (_) async => jsonResponse(profile()));
        await tap(tester, 'add_education');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
