import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/account/data/account_repository.dart';
import 'package:worknet/features/dashboard/data/dashboard_repository.dart';
import 'package:worknet/features/profile/data/profile_repository.dart';
import 'package:worknet/features/company/data/company_repository.dart';
import 'package:worknet/features/curriculum/data/curriculum_repository.dart';
import 'package:worknet/features/curriculum/data/pdf_picker.dart';

/// Composition root: concrete HTTP/storage adapters are selected only here.
class AppDependencies {
  AppDependencies(WorkNetApi api, SessionStore store) {
    access = HttpAccessRepository(api, store);
    session = SessionController(repository: access);
    account = HttpAccountRepository(api);
    dashboard = HttpCandidateDashboardRepository(api);
    profile = HttpProfileRepository(api);
    company = HttpCompanyRepository(api);
    curriculum = HttpCurriculumRepository(api);
  }
  late final HttpAccessRepository access;
  late final SessionController session;
  late final HttpAccountRepository account;
  late final HttpCandidateDashboardRepository dashboard;
  late final HttpProfileRepository profile;
  late final HttpCompanyRepository company;
  late final HttpCurriculumRepository curriculum;
  final pdfPicker = const FileSelectorPdfPicker();
}
