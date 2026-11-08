import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/applications/domain/application.dart';
import 'package:worknet/features/status_changes/domain/status_change.dart';

class StatusFake implements StatusRepository {
  StatusFake(this.application);
  JobApplication application;
  int writes = 0, lookups = 0;
  bool loseResponse = false;
  ApiFailure? failure;
  StatusCommand? accepted;
  StatusContext context([ApplicationStatus? recorded]) => StatusContext(
    application: application,
    allowed: switch (application.status) {
      ApplicationStatus.submitted => [
        ApplicationStatus.inReview,
        ApplicationStatus.accepted,
        ApplicationStatus.rejected,
      ],
      ApplicationStatus.inReview => [
        ApplicationStatus.accepted,
        ApplicationStatus.rejected,
      ],
      _ => [],
    },
    recordedTarget: recorded,
  );
  @override
  Future<StatusContext> load(String token, int id) async => context();
  @override
  Future<StatusContext> change(
    String token,
    int id,
    StatusCommand command,
  ) async {
    writes++;
    if (failure != null) throw failure!;
    if (accepted?.id != command.id) {
      accepted = command;
      application = JobApplication(
        id: application.id,
        offer: application.offer,
        createdAt: application.createdAt,
        cv: application.cv,
        status: command.target,
        statusVersion: command.version + 1,
        statusModifiedAt: DateTime.utc(2026, 11, 8, 20),
        statusComment: command.comment,
      );
    }
    if (loseResponse) throw const ApiFailure('Respuesta perdida');
    return context(command.target);
  }

  @override
  Future<StatusContext> lookup(
    String token,
    int id,
    StatusCommand command,
  ) async {
    lookups++;
    if (accepted?.id != command.id) {
      throw const ApiFailure('Sin registro', status: 404);
    }
    return context(command.target);
  }
}
