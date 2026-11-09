import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_saver/src/messages.g.dart';
import 'package:worknet/features/curriculum/data/curriculum_download.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.file_saver.FileSaverHostApi.saveAs',
    FileSaverHostApi.pigeonChannelCodec,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockDecodedMessageHandler<Object?>(channel, null),
  );
  final bytes = Uint8List.fromList('%PDF-1.7\nCV privado QA\n%%EOF'.codeUnits);
  test(
    'guardado nativo envía exactamente bytes, PDF y nombre sin URL ni Token',
    () async {
      messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
        final request = (message as List).single as SaveRequest;
        expect(request.bytes, bytes);
        expect(request.name, 'curriculum-worknet');
        expect(request.fileExtension, '.pdf');
        expect(request.mimeType, 'application/pdf');
        expect(request.sourcePath, isNull);
        return ['content://document/qa-cv'];
      });
      expect(await const FileSelectorCurriculumDownload().save(bytes), true);
    },
  );
  test('cancelar el selector no anuncia una descarga', () async {
    messenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => [null],
    );
    expect(await const FileSelectorCurriculumDownload().save(bytes), false);
  });
  test('fallo del guardado nativo se propaga para mostrar el error', () async {
    messenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (_) async => ['save_failed', 'Error QA', null],
    );
    await expectLater(
      const FileSelectorCurriculumDownload().save(bytes),
      throwsA(isA<PlatformException>()),
    );
  });
}
