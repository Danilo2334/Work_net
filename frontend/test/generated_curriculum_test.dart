import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/app.dart';
import 'package:worknet/core/theme/worknet_theme.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/curriculum/data/generated_curriculum_repository.dart';
import 'package:worknet/features/curriculum/domain/generated_curriculum.dart';
import 'package:worknet/features/curriculum/presentation/generated_curriculum_controller.dart';
import 'package:worknet/features/curriculum/presentation/generated_curriculum_page.dart';
import 'support/access_fakes.dart';

Map<String, dynamic> cvData() => {
  'personal': {
    'full_name': 'Candidata QA',
    'email': 'qa@example.com',
    'phone': '',
    'location': '',
    'website': '',
  },
  'professional_summary': 'Resumen del perfil',
  'education': [
    {'qualification': 'Ingeniería', 'institution': 'Universidad QA'},
  ],
  'experience': [],
  'skills': [
    {'name': 'Django', 'level': 'avanzado'},
  ],
  'languages': [],
  'certifications': [],
  'extra_sections': [],
};
GeneratedCurriculum initial() =>
    GeneratedCurriculum(exists: false, template: 'clasica', data: cvData());
final pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.7\nCV QA'));

class FakeGenerated implements GeneratedCurriculumRepository {
  GeneratedCurriculum value = initial();
  Object? failure;
  Completer<GeneratedCurriculum>? pendingSave;
  Completer<Uint8List>? pendingPreview;
  int saves = 0, previews = 0, reads = 0;
  void fail() {
    if (failure != null) throw failure!;
  }

  @override
  Future<GeneratedCurriculum> load(String token) async {
    fail();
    return value;
  }

  @override
  Future<GeneratedCurriculum> save(
    String token,
    GeneratedCurriculum draft,
  ) async {
    saves++;
    fail();
    if (pendingSave != null) return pendingSave!.future;
    value = GeneratedCurriculum(
      exists: true,
      template: draft.template,
      data: draft.data,
    );
    return value;
  }

  @override
  Future<Uint8List> preview(String token, GeneratedCurriculum draft) async {
    previews++;
    fail();
    return pendingPreview?.future ?? pdfBytes;
  }

  @override
  Future<Uint8List> pdf(String token) async {
    reads++;
    fail();
    return pdfBytes;
  }
}

class FakeDownload implements CurriculumDownload {
  int calls = 0;
  bool accepted = true;
  @override
  Future<bool> save(Uint8List bytes) async {
    expect(bytes, pdfBytes);
    calls++;
    return accepted;
  }
}

Future<SessionController> makeSession() async {
  final api = WorkNetApi(client: MockClient((_) async => jsonResponse({})));
  addTearDown(api.close);
  final session = SessionController(
    repository: HttpAccessRepository(
      api,
      MemorySessionStore()..value = jsonEncode(sessionData()),
    ),
  );
  await session.restore();
  addTearDown(session.dispose);
  return session;
}

Future<GeneratedCurriculumController> makeController(
  FakeGenerated repository,
  FakeDownload download,
) async {
  final c = GeneratedCurriculumController(
    repository,
    await makeSession(),
    download,
  );
  addTearDown(c.dispose);
  await c.load();
  return c;
}

void main() {
  testWidgets('reentrada rapida no recupera un borrador descartado', (
    tester,
  ) async {
    var loads = 0;
    final api = WorkNetApi(
      client: MockClient((r) async {
        if (r.url.path == '/api/curriculum/generated/') {
          loads++;
          return jsonResponse({
            'exists': false,
            'curriculum': initial().payload,
          });
        }
        return jsonResponse({
          'uploaded': null,
          'limits': {'max_upload_bytes': 5242880, 'max_upload_pages': 50},
        });
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      WorkNetApp(
        api: api,
        sessionStore: MemorySessionStore()..value = jsonEncode(sessionData()),
        initialLocation: '/curriculum/create',
      ),
    );
    await tester.pumpAndSettle();
    final editor = find.byType(GeneratedCurriculumPage);
    final router = GoRouter.of(tester.element(editor));
    final name = find.byKey(const ValueKey('cv_full_name_0'));
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Borrador descartado QA');
    router.go('/curriculum');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir sin guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // Volver mientras la página saliente aún anima su transición.
    router.go('/curriculum/create');
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.text('Borrador descartado QA'), findsNothing);
    expect(find.text('Candidata QA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'doble guardado se bloquea y respuesta tardia no cambia de propietario',
    () async {
      final repo = FakeGenerated(), download = FakeDownload();
      final c = await makeController(repo, download);
      repo.pendingSave = Completer<GeneratedCurriculum>();
      final pending = c.save();
      await c.save();
      expect(repo.saves, 1);
      await c.session.expire();
      repo.pendingSave!.complete(
        GeneratedCurriculum(exists: true, template: 'clasica', data: cvData()),
      );
      await pending;
      expect(c.draft, isNull);
      expect(c.notice, isNull);
    },
  );
  testWidgets('ruta del editor exige candidato autenticado', (tester) async {
    for (final role in [null, 'empresa', 'admin']) {
      var calls = 0;
      final api = WorkNetApi(
        client: MockClient((r) async {
          if (r.url.path.contains('/curriculum/')) calls++;
          return jsonResponse({});
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        WorkNetApp(
          key: UniqueKey(),
          api: api,
          sessionStore: MemorySessionStore()
            ..value = role == null ? null : jsonEncode(sessionData(role: role)),
          initialLocation: '/curriculum/create',
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Crear mi CV'), findsNothing);
    }
  });
  for (final size in [const Size(390, 844), const Size(1440, 960)]) {
    testWidgets('editor y cambios sin guardar funcionan en $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeGenerated(), download = FakeDownload();
      final session = await makeSession();
      final key = GlobalKey<GeneratedCurriculumPageState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: workNetTheme(),
          home: GeneratedCurriculumPage(
            key: key,
            session: session,
            repository: repo,
            download: download,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('cv_full_name_0'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Nombre del CV');
      final leave = key.currentState!.confirmLeave();
      await tester.pumpAndSettle();
      expect(find.text('Cambios sin guardar'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(await leave, isFalse);
      expect(repo.saves, 0);
      expect(tester.takeException(), isNull);
    });
  }
  test('precarga y PUT preservan listas, opcionales y token privado', () async {
    final draft = initial();
    var calls = 0;
    final api = WorkNetApi(
      client: MockClient((r) async {
        expect(r.url.path, '/api/curriculum/generated/');
        expect(r.url.query, isEmpty);
        expect(r.headers['authorization'], 'Token privado');
        if (calls++ == 0) {
          expect(r.method, 'GET');
        } else {
          expect(r.method, 'PUT');
          expect(jsonDecode(r.body), draft.payload);
        }
        return jsonResponse({
          'exists': calls > 1,
          'curriculum': draft.payload,
        }, calls > 1 ? 201 : 200);
      }),
    );
    addTearDown(api.close);
    final repo = HttpGeneratedCurriculumRepository(api);
    expect((await repo.load('privado')).data, cvData());
    expect((await repo.save('privado', draft)).exists, isTrue);
  });
  test(
    'vista previa envia edicion completa como POST y devuelve PDF real',
    () async {
      final draft = initial().edit(template: 'moderna');
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/api/curriculum/generated/preview/');
          expect(r.headers['authorization'], 'Token privado');
          expect(jsonDecode(r.body), draft.payload);
          return http.Response.bytes(
            pdfBytes,
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
      );
      addTearDown(api.close);
      expect(
        await HttpGeneratedCurriculumRepository(api).preview('privado', draft),
        pdfBytes,
      );
    },
  );
  test(
    'descarga exige respuesta PDF; HTML o JSON 200 no son documentos',
    () async {
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.url.path, '/api/curriculum/generated/pdf/');
          return jsonResponse({'message': 'no es PDF'});
        }),
      );
      addTearDown(api.close);
      await expectLater(
        HttpGeneratedCurriculumRepository(api).pdf('privado'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test('respuesta incompleta no se reemplaza con datos inventados', () async {
    final api = WorkNetApi(
      client: MockClient(
        (_) async => jsonResponse({
          'exists': false,
          'curriculum': {
            'template': 'clasica',
            'data': {
              'personal': {'full_name': 'QA'},
            },
          },
        }),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      HttpGeneratedCurriculumRepository(api).load('privado'),
      throwsFormatException,
    );
  });
  test(
    'las tres plantillas conservan datos y no mutan el perfil precargado',
    () async {
      final repo = FakeGenerated(), download = FakeDownload();
      final c = await makeController(repo, download);
      final original = c.draft!;
      for (final template in curriculumTemplates.keys) {
        c.edit(template: template);
        expect(c.draft!.data, original.data);
      }
      final copy = c.draft!.data;
      copy['personal']['full_name'] = 'Editado';
      c.edit(data: copy);
      expect(original.data['personal']['full_name'], 'Candidata QA');
      expect(repo.value.data['personal']['full_name'], 'Candidata QA');
      expect(c.dirty, isTrue);
    },
  );
  test(
    'preview no guarda; error de guardado conserva edicion y permite reintento',
    () async {
      final repo = FakeGenerated(), download = FakeDownload();
      final c = await makeController(repo, download);
      c.edit(template: 'minimalista');
      await c.preview();
      expect(repo.saves, 0);
      expect(c.document, pdfBytes);
      expect(c.dirty, isTrue);
      repo.failure = const ApiFailure('Sin conexión');
      await c.save();
      expect(c.draft!.template, 'minimalista');
      expect(c.dirty, isTrue);
      expect(c.error, 'Sin conexión');
      repo.failure = null;
      await c.save();
      expect(c.draft!.exists, isTrue);
      expect(c.dirty, isFalse);
      await c.load();
      expect(c.draft!.template, 'minimalista');
    },
  );
  test('descarga solo version guardada; cancelacion no altera el CV', () async {
    final repo = FakeGenerated(), download = FakeDownload();
    final c = await makeController(repo, download);
    await c.downloadSaved();
    expect(download.calls, 0);
    await c.save();
    download.accepted = false;
    await c.downloadSaved();
    expect(download.calls, 1);
    expect(c.notice, 'Descarga cancelada.');
    expect(c.draft!.exists, isTrue);
    c.edit(template: 'moderna');
    await c.downloadSaved();
    expect(download.calls, 1);
  });
  test(
    'sesion expirada descarta datos, PDF y respuesta asincrona tardia',
    () async {
      final repo = FakeGenerated(), download = FakeDownload();
      final c = await makeController(repo, download);
      repo.pendingPreview = Completer<Uint8List>();
      final pending = c.preview();
      await c.session.expire();
      repo.pendingPreview!.complete(pdfBytes);
      await pending;
      expect(c.draft, isNull);
      expect(c.document, isNull);
      expect(c.busy, isFalse);
    },
  );
  test('401 al guardar expira la sesion sin retener el CV', () async {
    final repo = FakeGenerated(), download = FakeDownload();
    final c = await makeController(repo, download);
    repo.failure = const ApiFailure('Sesión inválida', status: 401);
    await c.save();
    expect(c.session.session, isNull);
    expect(c.draft, isNull);
  });
  testWidgets(
    'editor muestra precarga, agrega certificacion y guarda sin modificar perfil',
    (tester) async {
      final repo = FakeGenerated(), download = FakeDownload();
      final session = await makeSession();
      await tester.pumpWidget(
        MaterialApp(
          theme: workNetTheme(),
          home: GeneratedCurriculumPage(
            session: session,
            repository: repo,
            download: download,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Candidata QA'), findsOneWidget);
      final add = find.byKey(const Key('cv_add_certifications'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('cv_record_title')),
        'Certificación QA',
      );
      await tester.tap(find.text('Guardar registro'));
      await tester.pumpAndSettle();
      expect(find.text('Certificación QA'), findsOneWidget);
      final save = find.byKey(const Key('cv_save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.value.data['certifications'][0]['title'], 'Certificación QA');
      expect(repo.value.exists, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
