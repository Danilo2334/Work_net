import 'package:file_selector/file_selector.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/curriculum/domain/curriculum.dart';

class FileSelectorPdfPicker implements PdfPicker {
  const FileSelectorPdfPicker();
  @override
  Future<SelectedPdf?> pick(int maxBytes) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Documento PDF',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
        ),
      ],
    );
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      throw const ApiFailure('Selecciona un archivo PDF.');
    }
    if (await file.length() > maxBytes) {
      throw const ApiFailure(
        'El archivo supera el tamaño permitido. Selecciona un PDF más pequeño.',
      );
    }
    return SelectedPdf(file.name, await file.readAsBytes());
  }
}
