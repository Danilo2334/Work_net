import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:worknet/core/widgets/workspace.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/curriculum/domain/curriculum.dart';
import 'curriculum_controller.dart';
import 'private_pdf_view.dart';

class CurriculumPage extends StatefulWidget {
  const CurriculumPage({
    super.key,
    required this.session,
    required this.repository,
    required this.picker,
  });
  final SessionController session;
  final CurriculumRepository repository;
  final PdfPicker picker;
  @override
  State<CurriculumPage> createState() => _CurriculumPageState();
}

class _CurriculumPageState extends State<CurriculumPage> {
  late final _controller = CurriculumController(
    widget.repository,
    widget.session,
    widget.picker,
  );
  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _size(int bytes) => bytes >= 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MiB'
      : '${(bytes / 1024).toStringAsFixed(1)} KiB';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final c = _controller, info = c.info, uploaded = c.info?.uploaded;
      return Workspace(
        title: 'Mi currículum',
        loading: c.busy,
        error: c.error,
        onRetry: c.busy ? null : c.load,
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver al dashboard'),
          ),
          TextButton.icon(
            onPressed: c.busy ? null : c.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ],
        children: [
          if (c.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                c.notice!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          if (info != null)
            WorkspacePanel(
              title: uploaded == null
                  ? 'Todavía no has subido un currículum'
                  : 'Tu documento guardado',
              children: [
                Text(
                  uploaded == null
                      ? 'Sube tu currículum en PDF para guardarlo en tu cuenta.'
                      : uploaded.filename,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (uploaded != null) ...[
                  const SizedBox(height: 8),
                  Text('Tamaño: ${_size(uploaded.sizeBytes)}'),
                ],
                const SizedBox(height: 16),
                Text(
                  'PDF de hasta ${_size(info.maxBytes)} y ${info.maxPages} páginas. Usa un documento sin contraseña, formularios ni contenido interactivo.',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      key: const Key('choose_curriculum'),
                      onPressed: c.busy ? null : c.chooseAndUpload,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        c.uploading
                            ? 'Preparando y guardando…'
                            : uploaded == null
                            ? 'Seleccionar PDF'
                            : 'Reemplazar PDF',
                      ),
                    ),
                    if (uploaded != null)
                      OutlinedButton.icon(
                        key: const Key('view_curriculum'),
                        onPressed: c.busy ? null : c.open,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(c.reading ? 'Abriendo…' : 'Ver currículum'),
                      ),
                  ],
                ),
                if (uploaded != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Tu documento actual se conserva si cancelas o el nuevo archivo no es válido.',
                    ),
                  ),
              ],
            ),
          if (c.document != null)
            WorkspacePanel(
              title: 'Vista del documento',
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: c.closeDocument,
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar visor'),
                  ),
                ),
                PrivatePdfView(key: ObjectKey(c.document), bytes: c.document!),
              ],
            ),
        ],
      );
    },
  );
}
