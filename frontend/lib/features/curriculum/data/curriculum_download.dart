import 'package:flutter/foundation.dart';
import 'package:file_selector/file_selector.dart';
import 'package:worknet/features/curriculum/domain/generated_curriculum.dart';

class FileSelectorCurriculumDownload implements CurriculumDownload {
  const FileSelectorCurriculumDownload();
  @override
  Future<bool> save(Uint8List bytes) async {
    const name = 'curriculum-worknet.pdf';
    final file = XFile.fromData(bytes, mimeType: 'application/pdf', name: name);
    if (kIsWeb) {
      await file.saveTo(name);
      return true;
    }
    final destination = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Documento PDF', extensions: ['pdf']),
      ],
    );
    if (destination == null) return false;
    await file.saveTo(destination.path);
    return true;
  }
}
