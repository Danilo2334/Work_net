import 'package:flutter/foundation.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/curriculum/domain/curriculum.dart';

/// Private documents live only while this screen and its session are active.
class CurriculumController extends ChangeNotifier {
  CurriculumController(this.repository, this.session, this.picker) {
    _token = session.session?.token;
    session.addListener(_sessionChanged);
  }
  final CurriculumRepository repository;
  final SessionController session;
  final PdfPicker picker;
  String? _token;
  int _generation = 0;
  bool _disposed = false;
  CurriculumInfo? info;
  Uint8List? document;
  String? error, notice;
  bool loading = false, uploading = false, reading = false;
  bool get busy => loading || uploading || reading;

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
    document = null;
    info = null;
    error = notice = null;
    loading = uploading = reading = false;
    _emit();
  }

  Future<void> _failure(Object failure) async {
    if (failure is ApiFailure && failure.status == 401) {
      await session.expire();
      return;
    }
    error = failure is ApiFailure
        ? (failure.fields['file'] ?? failure.message)
        : 'No pudimos completar la operación. Vuelve a intentarlo.';
  }

  Future<void> load() async {
    if (busy || _token == null) return;
    final generation = _generation, token = _token!;
    loading = true;
    error = notice = null;
    document = null;
    _emit();
    try {
      final result = await repository.load(token);
      if (_current(generation)) info = result;
    } catch (e) {
      if (_current(generation)) await _failure(e);
    } finally {
      if (_current(generation)) {
        loading = false;
        _emit();
      }
    }
  }

  Future<void> chooseAndUpload() async {
    if (busy || info == null || _token == null) return;
    final generation = _generation, token = _token!;
    uploading = true;
    error = notice = null;
    _emit();
    try {
      final selected = await picker.pick(info!.maxBytes);
      if (!_current(generation) || selected == null) return;
      final result = await repository.upload(token, selected);
      if (_current(generation)) {
        info = info!.withUploaded(result);
        document = null;
        notice = 'Tu currículum se guardó correctamente.';
      }
    } catch (e) {
      if (_current(generation)) await _failure(e);
    } finally {
      if (_current(generation)) {
        uploading = false;
        _emit();
      }
    }
  }

  Future<void> open() async {
    if (busy || info?.uploaded == null || _token == null) return;
    final generation = _generation, token = _token!;
    reading = true;
    error = notice = null;
    document = null;
    _emit();
    try {
      final result = await repository.read(token);
      if (_current(generation)) document = result;
    } catch (e) {
      if (_current(generation)) await _failure(e);
    } finally {
      if (_current(generation)) {
        reading = false;
        _emit();
      }
    }
  }

  void closeDocument() {
    document = null;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    session.removeListener(_sessionChanged);
    document = null;
    info = null;
    super.dispose();
  }
}
