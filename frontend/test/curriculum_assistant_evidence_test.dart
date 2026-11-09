import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worknet/core/theme/worknet_theme.dart';
import 'package:worknet/features/curriculum/presentation/generated_curriculum_page.dart';

import 'curriculum_assistant_test.dart' as ai;
import 'generated_curriculum_test.dart' as cv;

const _boundaryKey = ValueKey('hu028-evidence-root');
const _record = bool.fromEnvironment('HU028_QA_SCREENSHOTS');

ThemeData _theme() {
  final theme = workNetTheme();
  if (!_record) return theme;
  const text = WidgetStatePropertyAll(
    TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w600),
  );
  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: theme.filledButtonTheme.style!.copyWith(textStyle: text),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: theme.outlinedButtonTheme.style!.copyWith(textStyle: text),
    ),
    textButtonTheme: const TextButtonThemeData(
      style: ButtonStyle(textStyle: text),
    ),
  );
}

Future<void> _font() async {
  const path = String.fromEnvironment('HU028_QA_FONT');
  if (!_record || path.isEmpty) return;
  final bytes = await File(path).readAsBytes();
  await (FontLoader(
    'Roboto',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  await (FontLoader(
    'Ahem',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  final icons = await File(
    '${File(path).parent.path}/MaterialIcons-Regular.otf',
  ).readAsBytes();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(Future.value(ByteData.sublistView(icons)))).load();
}

Future<void> _capture(WidgetTester tester, String filename) async {
  if (!_record) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_boundaryKey),
    );
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/evidencias/hu028-20261109/$filename.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _open(
  WidgetTester tester,
  ai.AssistantFake repository, {
  bool mobile = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = mobile
      ? const Size(390, 844)
      : const Size(1280, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.runAsync(_font);
  final session = await cv.makeSession();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        home: GeneratedCurriculumPage(
          session: session,
          repository: repository,
          download: cv.FakeDownload(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Completar mi CV con IA'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'desktop unconfigured assistant can be dismissed without changing CV',
    (tester) async {
      final repository = ai.AssistantFake()..available = false;
      await _open(tester, repository);
      expect(find.textContaining('pendiente de configuración'), findsOneWidget);
      await _capture(tester, 'HU028-V01-sin-configuracion-render-flutter');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Resumen del perfil'), findsOneWidget);
      expect(repository.saves, 0);
      await Scrollable.ensureVisible(
        tester.element(find.text('Resumen del perfil')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await _capture(
        tester,
        'HU028-V02-editor-manual-conservado-render-flutter',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'desktop review uses provided data and apply remains an unsaved draft',
    (tester) async {
      final repository = ai.AssistantFake();
      await _open(tester, repository);
      await tester.enterText(
        find.byKey(const ValueKey('cv_ai_text')),
        'Estudio Ingeniería en Universidad QA y manejo Django avanzado.',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('cv_ai_consent')));
      await tester.tap(find.byKey(const ValueKey('cv_ai_consent')));
      await tester.pumpAndSettle();
      await _capture(tester, 'HU028-V03-consentimiento-render-flutter');
      await tester.tap(find.text('Generar propuesta'));
      await tester.pumpAndSettle();
      expect(find.text('Resumen propuesto para revisar'), findsOneWidget);
      await _capture(
        tester,
        'HU028-V04-propuesta-doble-controlado-render-flutter',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('cv_ai_reviewed')));
      await tester.tap(find.byKey(const ValueKey('cv_ai_reviewed')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar al borrador'));
      await tester.pumpAndSettle();
      expect(repository.saves, 0);
      expect(find.text('Resumen propuesto para revisar'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Resumen propuesto para revisar')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await _capture(
        tester,
        'HU028-V05-borrador-sin-autoguardado-render-flutter',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'mobile proposal is readable and discard preserves the existing CV',
    (tester) async {
      final repository = ai.AssistantFake();
      await _open(tester, repository, mobile: true);
      await tester.enterText(
        find.byKey(const ValueKey('cv_ai_text')),
        'Estudio Ingeniería en Universidad QA y manejo Django avanzado.',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('cv_ai_consent')));
      await tester.tap(find.byKey(const ValueKey('cv_ai_consent')));
      await tester.pumpAndSettle();
      await _capture(tester, 'HU028-V06-consentimiento-movil-render-flutter');
      await tester.tap(find.text('Generar propuesta'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        'HU028-V07-propuesta-movil-doble-controlado-render-flutter',
      );
      await tester.tap(find.text('Descartar propuesta'));
      await tester.pumpAndSettle();
      expect(repository.saves, 0);
      expect(find.text('Resumen del perfil'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
