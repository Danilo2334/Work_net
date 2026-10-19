import 'package:worknet/features/access/data/access_repository.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MemorySessionStore implements SessionStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('storage');
    this.value = value;
  }

  @override
  Future<void> clear() async {
    if (fail) throw StateError('storage');
    value = null;
  }
}

Map<String, dynamic> sessionData({
  String role = 'candidato',
  String token = 'qa-token',
}) => {
  'token': token,
  'user': {
    'id': 1,
    'full_name': 'Candidata QA',
    'email': 'qa@example.com',
    'role': role,
    'email_verified': true,
  },
};

Map<String, dynamic> dashboardData({bool empty = false}) => {
  'user': {'id': 1, 'full_name': 'Candidata QA', 'role': 'candidato'},
  'profile_completion': {
    'percentage': 67,
    'status': 'incomplete',
    'completed_sections': 4,
    'total_sections': 6,
    'missing_sections': ['skills', 'languages'],
  },
  'metrics': {
    'applications_count': 2,
    'saved_offers_count': 3,
    'pending_notifications_count': 1,
  },
  'recent_jobs': empty
      ? []
      : [
          {
            'id': 7,
            'title': 'Oferta QA desde API',
            'company_name': 'Empresa QA',
            'location': 'Pasto',
            'contract_type': 'Indefinido',
            'published_at': '2026-10-17T12:00:00Z',
          },
        ],
};

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
