import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/app.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/core/theme/worknet_theme.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/curriculum/data/curriculum_repository.dart';
import 'package:worknet/features/curriculum/domain/curriculum.dart';
import 'package:worknet/features/curriculum/presentation/curriculum_controller.dart';
import 'package:worknet/features/curriculum/presentation/curriculum_page.dart';
import 'support/access_fakes.dart';

const oldPdf = UploadedCurriculum(filename: 'anterior.pdf', sizeBytes: 1234);
const newPdf = UploadedCurriculum(filename: 'nuevo.pdf', sizeBytes: 2345);
const initial = CurriculumInfo(maxBytes: 5242880, maxPages: 50);
final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7\nQA'));

class FakeCurriculum implements CurriculumRepository {
  CurriculumInfo value = initial;
  Object? failure;
  Completer<UploadedCurriculum>? pendingUpload;
  Completer<Uint8List>? pendingRead;
  int uploads = 0;
  @override
  Future<CurriculumInfo> load(String token) async {
    if (failure != null) throw failure!;
    return value;
  }

  @override
  Future<UploadedCurriculum> upload(String token, SelectedPdf file) async {
    uploads++;
    if (failure != null) throw failure!;
    if (pendingUpload != null) return pendingUpload!.future;
    value = initial.withUploaded(newPdf);
    return newPdf;
  }

  @override
  Future<Uint8List> read(String token) async {
    if (failure != null) throw failure!;
    return pendingRead?.future ?? pdf;
  }
}

class FakePicker implements PdfPicker {
  SelectedPdf? selected;
  Completer<SelectedPdf?>? pending;
  int calls = 0;
  @override
  Future<SelectedPdf?> pick(int maxBytes) async {
    calls++;
    expect(maxBytes, initial.maxBytes);
    return pending?.future ?? selected;
  }
}

Future<SessionController> session() async {
  final api = WorkNetApi(client: MockClient((_) async => jsonResponse({})));
  addTearDown(api.close);
  final value = SessionController(
    repository: HttpAccessRepository(
      api,
      MemorySessionStore()..value = jsonEncode(sessionData()),
    ),
  );
  await value.restore();
  addTearDown(value.dispose);
  return value;
}

void main() {
  test('metadata y limites se obtienen del contrato real', () async {
    final api = WorkNetApi(
      client: MockClient((r) async {
        expect(r.url.path, '/api/curriculum/');
        expect(r.headers['authorization'], 'Token secreto-local');
        return jsonResponse({
          'uploaded': {'filename': 'cv.pdf', 'size_bytes': 1234},
          'limits': {'max_upload_bytes': 9999, 'max_upload_pages': 12},
        });
      }),
    );
    addTearDown(api.close);
    final value = await HttpCurriculumRepository(api).load('secreto-local');
    expect(value.uploaded!.filename, 'cv.pdf');
    expect(value.maxBytes, 9999);
    expect(value.maxPages, 12);
  });

  for (final status in [201, 200]) {
    test('multipart PDF usa solo file y acepta HTTP $status', () async {
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.method, 'PUT');
          expect(r.url.path, '/api/curriculum/uploaded/');
          expect(r.url.query, isEmpty);
          expect(r.headers['authorization'], 'Token secreto-local');
          expect(r.headers['content-type'], startsWith('multipart/form-data'));
          expect(r.body, contains('name="file"; filename="nuevo.pdf"'));
          expect(r.body, contains('application/pdf'));
          expect(r.body, isNot(contains('name="photo"')));
          return jsonResponse({
            'uploaded': {'filename': 'nuevo.pdf', 'size_bytes': pdf.length},
          }, status);
        }),
      );
      addTearDown(api.close);
      expect(
        (await HttpCurriculumRepository(
          api,
        ).upload('secreto-local', SelectedPdf('nuevo.pdf', pdf))).filename,
        'nuevo.pdf',
      );
    });
  }

  test('lectura binaria autenticada, sin token en URL', () async {
    final api = WorkNetApi(
      client: MockClient((r) async {
        expect(r.url.query, isEmpty);
        expect(r.headers['authorization'], 'Token secreto-local');
        // Django's private/no-store response controls caching. Adding a custom
        // request header here would require an unnecessary CORS allowance.
        expect(r.headers['cache-control'], isNull);
        return http.Response.bytes(
          pdf,
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }),
    );
    addTearDown(api.close);
    expect(await HttpCurriculumRepository(api).read('secreto-local'), pdf);
  });

  test('no muestra JSON ni HTML como PDF', () async {
    final api = WorkNetApi(client: MockClient((_) async => jsonResponse({})));
    addTearDown(api.close);
    await expectLater(
      api.curriculumPdf(token: 'local'),
      throwsA(isA<ApiFailure>()),
    );
  });

  test('cancelacion conserva metadata y documento sin enviar', () async {
    final repo = FakeCurriculum()..value = initial.withUploaded(oldPdf);
    final c = CurriculumController(repo, await session(), FakePicker());
    addTearDown(c.dispose);
    await c.load();
    await c.open();
    await c.chooseAndUpload();
    expect(c.info!.uploaded, oldPdf);
    expect(c.document, pdf);
    expect(repo.uploads, 0);
    expect(c.notice, isNull);
    expect(c.busy, false);
  });

  test('rechazo preserva PDF anterior y expone error del servidor', () async {
    final repo = FakeCurriculum()..value = initial.withUploaded(oldPdf);
    final c = CurriculumController(
      repo,
      await session(),
      FakePicker()..selected = SelectedPdf('nuevo.pdf', pdf),
    );
    addTearDown(c.dispose);
    await c.load();
    await c.open();
    repo.failure = const ApiFailure(
      'Revisa los datos',
      status: 400,
      fields: {'file': 'PDF corrupto'},
    );
    await c.chooseAndUpload();
    expect(c.info!.uploaded, oldPdf);
    expect(c.document, pdf);
    expect(c.error, 'PDF corrupto');
    expect(c.notice, isNull);
  });

  test('espera confirmacion y evita selector y envios duplicados', () async {
    final repo = FakeCurriculum()
      ..value = initial.withUploaded(oldPdf)
      ..pendingUpload = Completer();
    final picker = FakePicker()..selected = SelectedPdf('nuevo.pdf', pdf);
    final c = CurriculumController(repo, await session(), picker);
    addTearDown(c.dispose);
    await c.load();
    final operation = c.chooseAndUpload();
    await Future<void>.delayed(Duration.zero);
    await c.chooseAndUpload();
    expect(picker.calls, 1);
    expect(repo.uploads, 1);
    expect(c.info!.uploaded, oldPdf);
    expect(c.notice, isNull);
    repo.pendingUpload!.complete(newPdf);
    await operation;
    expect(c.info!.uploaded, newPdf);
    expect(c.notice, isNotNull);
  });

  test('error de conexion permite reintentar la consulta', () async {
    final repo = FakeCurriculum()..failure = const ApiFailure('Sin conexión');
    final c = CurriculumController(repo, await session(), FakePicker());
    addTearDown(c.dispose);
    await c.load();
    expect(c.error, 'Sin conexión');
    repo.failure = null;
    await c.load();
    expect(c.error, isNull);
    expect(c.info, initial);
  });

  test('401 limpia sesion, metadata y bytes privados', () async {
    final s = await session(),
        repo = FakeCurriculum()..value = initial.withUploaded(oldPdf);
    final c = CurriculumController(repo, s, FakePicker());
    addTearDown(c.dispose);
    await c.load();
    await c.open();
    repo.failure = const ApiFailure('Sesión caducada', status: 401);
    await c.load();
    expect(s.session, isNull);
    expect(c.info, isNull);
    expect(c.document, isNull);
  });

  test('cambio de sesion descarta lectura privada tardia', () async {
    final s = await session(),
        repo = FakeCurriculum()
          ..value = initial.withUploaded(oldPdf)
          ..pendingRead = Completer();
    final c = CurriculumController(repo, s, FakePicker());
    addTearDown(c.dispose);
    await c.load();
    final operation = c.open();
    await s.update(token: 'otra-sesion');
    repo.pendingRead!.complete(pdf);
    await operation;
    expect(c.document, isNull);
    expect(c.info, isNull);
    expect(c.busy, false);
  });

  test('logout durante selector no envia el archivo', () async {
    final s = await session(),
        repo = FakeCurriculum(),
        picker = FakePicker()..pending = Completer();
    final c = CurriculumController(repo, s, picker);
    addTearDown(c.dispose);
    await c.load();
    final operation = c.chooseAndUpload();
    await s.logout();
    picker.pending!.complete(SelectedPdf('nuevo.pdf', pdf));
    await operation;
    expect(repo.uploads, 0);
    expect(c.info, isNull);
  });

  testWidgets('pantalla vacia y error de reemplazo conservan datos', (
    tester,
  ) async {
    final repo = FakeCurriculum(),
        picker = FakePicker()..selected = SelectedPdf('nuevo.pdf', pdf);
    await tester.pumpWidget(
      MaterialApp(
        theme: workNetTheme(),
        home: CurriculumPage(
          session: await session(),
          repository: repo,
          picker: picker,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Todavía no has subido un currículum'), findsOneWidget);
    await tester.tap(find.byKey(const Key('choose_curriculum')));
    await tester.pumpAndSettle();
    expect(find.text('nuevo.pdf'), findsOneWidget);
    repo.failure = const ApiFailure('Archivo corrupto', status: 400);
    await tester.tap(find.byKey(const Key('choose_curriculum')));
    await tester.pumpAndSettle();
    expect(find.text('nuevo.pdf'), findsOneWidget);
    expect(find.text('Archivo corrupto'), findsOneWidget);
  });

  testWidgets('ruta exige sesion y rol candidato', (tester) async {
    for (final stored in [
      null,
      jsonEncode(sessionData(role: 'empresa')),
      jsonEncode(sessionData(role: 'admin')),
    ]) {
      var curriculumCalls = 0;
      final api = WorkNetApi(
        client: MockClient((r) async {
          if (r.url.path.contains('/curriculum/')) curriculumCalls++;
          return jsonResponse({});
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        WorkNetApp(
          key: UniqueKey(),
          api: api,
          sessionStore: MemorySessionStore()..value = stored,
          initialLocation: '/curriculum',
        ),
      );
      await tester.pumpAndSettle();
      expect(curriculumCalls, 0);
      expect(find.text('Mi currículum'), findsNothing);
    }
  });
}
