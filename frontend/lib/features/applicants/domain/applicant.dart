import 'package:worknet/features/applications/domain/application.dart';
import 'package:worknet/features/profile/domain/profile.dart';

const applicantOrders = {
  'newest': 'Más recientes',
  'oldest': 'Más antiguas',
  'name': 'Nombre A–Z',
  'name_desc': 'Nombre Z–A',
};

class ApplicantQuery {
  const ApplicantQuery({
    this.page = 1,
    this.experience = '',
    this.education = '',
    this.skill = '',
    this.order = 'newest',
  });
  final int page;
  final String experience, education, skill, order;
  factory ApplicantQuery.fromUri(Uri uri) => ApplicantQuery(
    page: (int.tryParse(uri.queryParameters['page'] ?? '') ?? 1)
        .clamp(1, 2147483647)
        .toInt(),
    experience: uri.queryParameters['experience'] ?? '',
    education: uri.queryParameters['education'] ?? '',
    skill: uri.queryParameters['skill'] ?? '',
    order: applicantOrders.containsKey(uri.queryParameters['order'])
        ? uri.queryParameters['order']!
        : 'newest',
  );
  Map<String, String> get parameters => {
    'page': '$page',
    'page_size': '10',
    'order': order,
    if (experience.isNotEmpty) 'experience': experience,
    if (education.isNotEmpty) 'education': education,
    if (skill.isNotEmpty) 'skill': skill,
  };
  ApplicantQuery at(int page) => ApplicantQuery(
    page: page,
    experience: experience,
    education: education,
    skill: skill,
    order: order,
  );
  String location(int offerId) => Uri(
    path: '/company/offers/$offerId/applicants',
    queryParameters: parameters,
  ).toString();
}

class ApplicantOffer {
  const ApplicantOffer({
    required this.id,
    required this.title,
    required this.status,
    required this.count,
  });
  final int id, count;
  final String title, status;
  String get stateLabel => const {
    'published': 'Publicada',
    'closed': 'Cerrada',
    'archived': 'Archivada',
    'draft': 'Borrador',
  }[status]!;
}

class ApplicantOffers {
  const ApplicantOffers({
    required this.offers,
    required this.count,
    required this.page,
    required this.pages,
    this.next,
    this.previous,
  });
  final List<ApplicantOffer> offers;
  final int count, page, pages;
  final int? next, previous;
}

class Applicant {
  const Applicant({
    required this.application,
    required this.candidateId,
    required this.name,
  });
  final JobApplication application;
  final int candidateId;
  final String name;
  String get nameLabel => name.trim().isEmpty ? 'Nombre no disponible' : name;
}

class ApplicantPage {
  const ApplicantPage({
    required this.offer,
    required this.applicants,
    required this.count,
    required this.page,
    required this.pages,
    this.next,
    this.previous,
  });
  final ApplicationOffer offer;
  final List<Applicant> applicants;
  final int count, page, pages;
  final int? next, previous;
}

class ApplicantDetail {
  const ApplicantDetail({required this.applicant, required this.profile});
  final Applicant applicant;
  final CandidateProfile profile;
}

abstract interface class ApplicantsRepository
    implements ApplicationPdfRepository {
  Future<ApplicantOffers> offers(String token, {int page = 1});
  Future<ApplicantPage> applicants(
    String token,
    int offerId,
    ApplicantQuery query,
  );
  Future<ApplicantDetail> detail(String token, int offerId, int applicationId);
}
