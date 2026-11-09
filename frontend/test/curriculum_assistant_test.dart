import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/curriculum/data/generated_curriculum_repository.dart';
import 'package:worknet/features/curriculum/domain/curriculum_assistant.dart';
import 'package:worknet/features/curriculum/presentation/curriculum_assistant_dialog.dart';
import 'package:worknet/features/curriculum/presentation/generated_curriculum_controller.dart';
import 'package:worknet/features/curriculum/presentation/generated_curriculum_page.dart';

import 'generated_curriculum_test.dart' as cv;

CurriculumSuggestion suggestion() => CurriculumSuggestion(
  data: cv.cvData()
    ..['professional_summary'] = 'Resumen propuesto para revisar',
  personalFields: const [],
  missingInformation: const ['Completa las fechas de estudio.'],
  notice: 'Propuesta de prueba controlada; no se ha guardado.',
);

class AssistantFake extends cv.FakeGenerated
    implements CurriculumAssistantRepository {
  bool available = true;
  int generations = 0;
  Object? assistantFailure;
  Completer<CurriculumSuggestion>? pending;
  @override
  Future<bool> assistantAvailable(String token) async => available;
  @override
  Future<CurriculumSuggestion> suggest(
    String token, {
    required String text,
    required bool includeProfile,
    required bool consent,
  }) async {
    generations++;
    if (assistantFailure != null) throw assistantFailure!;
    return pending?.future ?? suggestion();
  }
}

Future<void> generate(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('cv_ai_text')),
    'Mis estudios y experiencia profesional en desarrollo.',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('cv_ai_consent')));
  await tester.tap(find.byKey(const ValueKey('cv_ai_consent')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Generar propuesta'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'applying a proposal preserves contact fields and changes only local draft',
    () async {
      final session = await cv.makeSession();
      final repository = AssistantFake();
      final controller = GeneratedCurriculumController(
        repository,
        session,
        cv.FakeDownload(),
      );
      await controller.load();
      controller.edit(template: 'moderna');
      final original = controller.draft!.data;
      controller.edit(data: suggestion().applyTo(controller.draft!));
      expect(controller.draft!.template, 'moderna');
      expect(controller.draft!.data['personal'], original['personal']);
      expect(
        controller.draft!.data['professional_summary'],
        contains('propuesto'),
      );
      expect(controller.dirty, isTrue);
      expect(repository.saves, 0);
      controller.dispose();
    },
  );

  test(
    'HTTP assistant sends consent and reads a private detached suggestion',
    () async {
      final api = WorkNetApi(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Token fixture-session');
          expect(request.url.path, '/api/curriculum/generated/assistant/');
          if (request.method == 'GET') {
            return http.Response(
              '{"available":true}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          expect(jsonDecode(request.body), {
            'text': 'Texto QA',
            'include_profile': false,
            'consent': true,
          });
          return http.Response(
            jsonEncode({
              'saved': false,
              'suggestion': {
                'data': suggestion().data,
                'personal_fields': [],
                'missing_information': ['Completa las fechas.'],
                'notice': 'Revisa antes de guardar.',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUri: Uri.parse('http://localhost:8000/api/'),
      );
      addTearDown(api.close);
      final repository = HttpGeneratedCurriculumRepository(api);
      expect(await repository.assistantAvailable('fixture-session'), isTrue);
      final result = await repository.suggest(
        'fixture-session',
        text: 'Texto QA',
        includeProfile: false,
        consent: true,
      );
      expect(result.missingInformation, ['Completa las fechas.']);
      final changed = result.data..['professional_summary'] = 'Editado';
      expect(result.data, isNot(changed));
    },
  );

  test('malformed HTTP suggestion cannot be applied', () async {
    for (final payload in [
      {'saved': true, 'suggestion': {}},
      {
        'saved': false,
        'suggestion': {
          'data': cv.cvData(),
          'personal_fields': ['owner'],
          'missing_information': [],
          'notice': 'QA',
        },
      },
      {
        'saved': false,
        'suggestion': {
          'data': {},
          'personal_fields': [],
          'missing_information': [],
          'notice': 'QA',
        },
      },
    ]) {
      final api = WorkNetApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(payload),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final repository = HttpGeneratedCurriculumRepository(api);
      await expectLater(
        repository.suggest(
          'fixture-session',
          text: 'QA',
          includeProfile: false,
          consent: true,
        ),
        throwsFormatException,
      );
      api.close();
    }
  });

  testWidgets('unconfigured assistant leaves manual editor available', (
    tester,
  ) async {
    final session = await cv.makeSession();
    final repository = AssistantFake()..available = false;
    await tester.pumpWidget(
      MaterialApp(
        home: GeneratedCurriculumPage(
          session: session,
          repository: repository,
          download: cv.FakeDownload(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completar mi CV con IA'));
    await tester.pumpAndSettle();
    expect(find.textContaining('pendiente de configuración'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Crear mi CV'), findsOneWidget);
    expect(repository.generations, 0);
    expect(repository.saves, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'consent and review are required; apply does not save automatically',
    (tester) async {
      final session = await cv.makeSession();
      final repository = AssistantFake();
      await tester.pumpWidget(
        MaterialApp(
          home: GeneratedCurriculumPage(
            session: session,
            repository: repository,
            download: cv.FakeDownload(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completar mi CV con IA'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Generar propuesta'),
            )
            .onPressed,
        isNull,
      );
      await generate(tester);
      expect(find.text('Resumen propuesto para revisar'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Aplicar al borrador'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('cv_ai_reviewed')));
      await tester.tap(find.byKey(const ValueKey('cv_ai_reviewed')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar al borrador'));
      await tester.pumpAndSettle();
      expect(repository.generations, 1);
      expect(repository.saves, 0);
      expect(find.byType(CurriculumAssistantDialog), findsNothing);
      expect(find.text('Resumen propuesto para revisar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'discard preserves original draft and provider error is recoverable',
    (tester) async {
      final session = await cv.makeSession();
      final repository = AssistantFake();
      await tester.pumpWidget(
        MaterialApp(
          home: GeneratedCurriculumPage(
            session: session,
            repository: repository,
            download: cv.FakeDownload(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completar mi CV con IA'));
      await tester.pumpAndSettle();
      await generate(tester);
      await tester.tap(find.text('Descartar propuesta'));
      await tester.pumpAndSettle();
      expect(find.text('Resumen del perfil'), findsOneWidget);
      repository.assistantFailure = const ApiFailure(
        'Cuota agotada; edición conservada.',
        status: 429,
      );
      await tester.tap(find.text('Completar mi CV con IA'));
      await tester.pumpAndSettle();
      await generate(tester);
      expect(find.text('Cuota agotada; edición conservada.'), findsOneWidget);
      expect(repository.saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('late suggestion after cancelling is ignored', (tester) async {
    final session = await cv.makeSession();
    final repository = AssistantFake()
      ..pending = Completer<CurriculumSuggestion>();
    await tester.pumpWidget(
      MaterialApp(
        home: GeneratedCurriculumPage(
          session: session,
          repository: repository,
          download: cv.FakeDownload(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completar mi CV con IA'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cv_ai_text')),
      'Experiencia profesional QA.',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('cv_ai_consent')));
    await tester.tap(find.byKey(const ValueKey('cv_ai_consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generar propuesta'));
    await tester.pump();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    repository.pending!.complete(suggestion());
    await tester.pumpAndSettle();
    expect(find.text('Resumen del perfil'), findsOneWidget);
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
