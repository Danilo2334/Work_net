import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/statistics/statistics_repository.dart';
import 'package:worknet/features/notifications/notifications_repository.dart';
import 'package:worknet/features/status_changes/data/status_repository.dart';
import 'package:worknet/features/messages/data/messages_repository.dart';
import 'package:worknet/features/applications/data/applications_repository.dart';
import 'package:worknet/features/applicants/data/applicants_repository.dart';
import 'package:worknet/features/applicants/data/applicant_export_repository.dart';
import 'package:worknet/features/applicants/data/applicant_export_download.dart';
import 'package:worknet/features/offers/data/offer_repository.dart';
import 'package:worknet/features/offers/data/search_repository.dart';
import 'package:worknet/features/offers/data/favorites_repository.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/account/data/account_repository.dart';
import 'package:worknet/features/dashboard/data/dashboard_repository.dart';
import 'package:worknet/features/profile/data/profile_repository.dart';
import 'package:worknet/features/company/data/company_repository.dart';
import 'package:worknet/features/curriculum/data/curriculum_repository.dart';
import 'package:worknet/features/curriculum/data/pdf_picker.dart';
import 'package:worknet/features/curriculum/data/generated_curriculum_repository.dart';
import 'package:worknet/features/curriculum/data/curriculum_download.dart';

/// Composition root: concrete HTTP/storage adapters are selected only here.
class AppDependencies {
  AppDependencies(WorkNetApi api, SessionStore store) {
    access = HttpAccessRepository(api, store);
    session = SessionController(repository: access);
    account = HttpAccountRepository(api);
    dashboard = HttpCandidateDashboardRepository(api);
    profile = HttpProfileRepository(api);
    company = HttpCompanyRepository(api);
    offers = HttpOfferRepository(api);
    search = HttpOfferSearchRepository(api);
    favorites = HttpSavedOffersRepository(api);
    applications = HttpApplicationsRepository(api);
    applicants = HttpApplicantsRepository(api);
    applicantExports = HttpApplicantExportRepository(api);
    statuses = HttpStatusRepository(api);
    messages = HttpMessagesRepository(api);
    notifications = HttpNotificationsRepository(api);
    statistics = HttpStatisticsRepository(api);
    curriculum = HttpCurriculumRepository(api);
    generatedCurriculum = HttpGeneratedCurriculumRepository(api);
  }
  late final HttpAccessRepository access;
  late final SessionController session;
  late final HttpAccountRepository account;
  late final HttpCandidateDashboardRepository dashboard;
  late final HttpProfileRepository profile;
  late final HttpCompanyRepository company;
  late final HttpOfferRepository offers;
  late final HttpOfferSearchRepository search;
  late final HttpSavedOffersRepository favorites;
  late final HttpApplicationsRepository applications;
  late final HttpApplicantsRepository applicants;
  late final HttpApplicantExportRepository applicantExports;
  final applicantExportDownload = const FileApplicantExportDownload();
  late final HttpStatusRepository statuses;
  late final HttpMessagesRepository messages;
  late final HttpNotificationsRepository notifications;
  late final HttpStatisticsRepository statistics;
  late final HttpCurriculumRepository curriculum;
  late final HttpGeneratedCurriculumRepository generatedCurriculum;
  final curriculumDownload = const FileSelectorCurriculumDownload();
  final pdfPicker = const FileSelectorPdfPicker();
}
