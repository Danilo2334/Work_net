import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Renders authenticated bytes in memory, without URLs, disk or ImageCache.
class PrivatePdfView extends StatefulWidget {
  const PrivatePdfView({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<PrivatePdfView> createState() => _PrivatePdfViewState();
}

class _PrivatePdfViewState extends State<PrivatePdfView> {
  PdfDocument? _document;
  ui.Image? _image;
  int _page = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final document = await PdfDocument.openData(widget.bytes);
      if (!mounted) {
        await document.close();
        return;
      }
      _document = document;
      await _render(1);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'No pudimos abrir el documento. Cierra el visor y vuelve a intentarlo.';
        });
      }
    }
  }

  Future<void> _render(int number) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    PdfPage? page;
    try {
      page = await _document!.getPage(number);
      final rendered = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
      );
      if (rendered == null) throw const FormatException();
      final codec = await ui.instantiateImageCodec(rendered.bytes);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      if (!mounted) {
        image.dispose();
        return;
      }
      final previous = _image;
      setState(() {
        _image = image;
        _page = number;
      });
      previous?.dispose();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos mostrar esta página. Vuelve a intentarlo.',
        );
      }
    } finally {
      await page?.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    _document?.close();
    _document = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          IconButton(
            tooltip: 'Página anterior',
            onPressed: _loading || _page <= 1 ? null : () => _render(_page - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Página $_page de ${_document?.pagesCount ?? '…'}'),
          IconButton(
            tooltip: 'Página siguiente',
            onPressed: _loading || _page >= (_document?.pagesCount ?? 1)
                ? null
                : () => _render(_page + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      if (_error != null) ...[
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => _document == null ? _open() : _render(_page),
          child: const Text('Reintentar página'),
        ),
      ],
      SizedBox(
        height: (MediaQuery.sizeOf(context).height * .65).clamp(360.0, 820.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _image == null
            ? const SizedBox.shrink()
            : InteractiveViewer(
                key: ValueKey(_page),
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Semantics(
                    label: 'Contenido del currículum, página $_page',
                    image: true,
                    child: RawImage(image: _image, fit: BoxFit.contain),
                  ),
                ),
              ),
      ),
      const Text('Amplía el documento para leerlo con más detalle.'),
    ],
  );
}
