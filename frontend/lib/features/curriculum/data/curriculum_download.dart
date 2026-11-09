import 'package:flutter/foundation.dart';
import 'package:file_saver/file_saver.dart';
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
    final destination = await FileSaver.instance.saveAs(
      name: 'curriculum-worknet',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
    return destination != null;
  }
}
