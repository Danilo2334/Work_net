import 'package:worknet/features/applications/domain/application.dart';

class StatusCommand {
  const StatusCommand({
    required this.id,
    required this.version,
    required this.target,
    required this.comment,
  });
  final String id, comment;
  final int version;
  final ApplicationStatus target;
}

class StatusContext {
  const StatusContext({
    required this.application,
    required this.allowed,
    this.recordedTarget,
  });
  final JobApplication application;
  final List<ApplicationStatus> allowed;
  final ApplicationStatus? recordedTarget;
}

abstract interface class StatusRepository {
  Future<StatusContext> load(String token, int id);
  Future<StatusContext> change(String token, int id, StatusCommand command);
  Future<StatusContext> lookup(String token, int id, StatusCommand command);
}
