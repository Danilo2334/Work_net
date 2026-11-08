import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/applications/data/applications_repository.dart';
import 'package:worknet/features/applications/domain/application.dart';
import '../domain/status_change.dart';

class HttpStatusRepository implements StatusRepository {
  HttpStatusRepository(this.api)
    : _applications = HttpApplicationsRepository(api);
  final WorkNetApi api;
  final HttpApplicationsRepository _applications;
  StatusContext _parse(
    Map<String, dynamic> r,
    int id, [
    StatusCommand? command,
  ]) {
    try {
      final app = _applications.decodeApplication(r['application']);
      final allowed = (r['allowed_transitions'] as List)
          .map((s) => ApplicationStatus.values.firstWhere((v) => v.code == s))
          .toList();
      if (app.id != id ||
          allowed.contains(ApplicationStatus.submitted) ||
          allowed.toSet().length != allowed.length) {
        throw const FormatException();
      }
      ApplicationStatus? recorded;
      if (command != null) {
        final e = r['event'] as Map<String, dynamic>;
        if (e['request_id'] != command.id ||
            e['version'] != command.version + 1 ||
            e['to_status'] != command.target.code ||
            e['comment'] != command.comment) {
          throw const FormatException();
        }
        DateTime.parse(e['changed_at'] as String);
        recorded = command.target;
      }
      return StatusContext(
        application: app,
        allowed: allowed,
        recordedTarget: recorded,
      );
    } on Object catch (e) {
      if (e is! FormatException &&
          e is! StateError &&
          e is! TypeError &&
          e is! RangeError) {
        rethrow;
      }
      throw const ApiFailure(
        'No pudimos confirmar el resultado del cambio. Comprueba su resultado antes de reintentar.',
      );
    }
  }

  String _path(int id) => 'company/applications/$id/status/';
  @override
  Future<StatusContext> load(String token, int id) async =>
      _parse(await api.request(_path(id), token: token), id);
  @override
  Future<StatusContext> change(
    String token,
    int id,
    StatusCommand command,
  ) async => _parse(
    await api.request(
      _path(id),
      token: token,
      data: {
        'target_status': command.target.code,
        'expected_version': command.version,
        'request_id': command.id,
        'comment': command.comment,
        'confirm': true,
      },
    ),
    id,
    command,
  );
  @override
  Future<StatusContext> lookup(
    String token,
    int id,
    StatusCommand command,
  ) async => _parse(
    await api.request('${_path(id)}operations/${command.id}/', token: token),
    id,
    command,
  );
}
