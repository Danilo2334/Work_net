import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/curriculum/domain/generated_curriculum.dart';

class GeneratedCurriculumController extends ChangeNotifier {
  GeneratedCurriculumController(this.repository, this.session, this.download) {
    _token = session.session?.token;
    session.addListener(_sessionChanged);
  }
  final GeneratedCurriculumRepository repository;
  final SessionController session;
  final CurriculumDownload download;
  String? _token, _baseline;
  int _generation = 0;
  bool _disposed = false;
  GeneratedCurriculum? draft;
  Uint8List? document;
  bool busy = false;
  String? error, notice;
  bool get dirty => draft != null && jsonEncode(draft!.payload) != _baseline;
  bool _current(int generation) =>
      !_disposed &&
      generation == _generation &&
      _token != null &&
      session.session?.token == _token;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_token == session.session?.token) return;
    _token = session.session?.token;
    ++_generation;
    draft = null;
    document = null;
    _baseline = null;
    error = notice = null;
    busy = false;
    _emit();
  }

  Future<void> _run(Future<void> Function(String, int) action) async {
    if (busy || _token == null) return;
    final generation = _generation, token = _token!;
    busy = true;
    error = notice = null;
    _emit();
    try {
      await action(token, generation);
    } catch (e) {
      if (_current(generation)) {
        if (e is ApiFailure && e.status == 401) {
          await session.expire();
        } else {
          error = e is ApiFailure
              ? e.message
              : 'No pudimos completar la operación. Tu edición se conserva; vuelve a intentarlo.';
        }
      }
    } finally {
      if (_current(generation)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<void> load() => _run((token, generation) async {
    final value = await repository.load(token);
    if (_current(generation)) {
      draft = value;
      _baseline = jsonEncode(value.payload);
      document = null;
    }
  });
  void edit({String? template, Map<String, dynamic>? data}) {
    if (busy || draft == null) return;
    draft = draft!.edit(template: template, data: data);
    document = null;
    notice = error = null;
    _emit();
  }

  Future<void> save() => _run((token, generation) async {
    if (draft == null) return;
    final value = await repository.save(token, draft!);
    if (_current(generation)) {
      draft = value;
      _baseline = jsonEncode(value.payload);
      document = null;
      notice = 'Tu currículum se guardó correctamente.';
    }
  });
  Future<void> preview() => _run((token, generation) async {
    if (draft == null) return;
    final bytes = await repository.preview(token, draft!);
    if (_current(generation)) document = bytes;
  });
  Future<void> downloadSaved() => _run((token, generation) async {
    if (draft?.exists != true || dirty) return;
    final bytes = await repository.pdf(token);
    if (!_current(generation)) return;
    final accepted = await download.save(bytes);
    if (_current(generation)) {
      notice = accepted
          ? 'Se solicitó la descarga de tu PDF guardado.'
          : 'Descarga cancelada.';
    }
  });
  void closeDocument() {
    document = null;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    session.removeListener(_sessionChanged);
    draft = null;
    document = null;
    super.dispose();
  }
}
