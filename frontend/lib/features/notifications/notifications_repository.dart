import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/offers/data/offer_parser.dart'
    show validatePage;

const noticeLabels = {
  'application_created': 'Nuevas postulaciones',
  'application_status_changed': 'Cambios de estado',
  'message_received': 'Nuevos mensajes',
  'company_reviewed': 'Decisiones sobre mi empresa',
};

class AccountNotice {
  const AccountNotice({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.readAt,
    this.applicationId,
    this.offerId,
    this.conversationId,
    this.companyReviewId,
  });
  final int id;
  final String title, kind;
  final DateTime createdAt;
  final DateTime? readAt;
  final int? applicationId, offerId, conversationId, companyReviewId;
}

class NoticePage {
  const NoticePage({
    required this.rows,
    required this.count,
    required this.page,
    required this.pages,
    required this.anchor,
    required this.unread,
  });
  final List<AccountNotice> rows;
  final int count, page, pages, anchor, unread;
}

abstract interface class NotificationsRepository {
  Future<NoticePage> list(
    String token, {
    int page = 1,
    String status = 'all',
    int? anchor,
  });
  Future<int> summary(String token);
  Future<void> read(String token, int id);
  Future<Map<String, bool>> preferences(String token);
  Future<Map<String, bool>> savePreferences(
    String token,
    Map<String, bool> values,
  );
}

class HttpNotificationsRepository implements NotificationsRepository {
  HttpNotificationsRepository(this.api);
  final WorkNetApi api;
  T _parse<T>(T Function() action) {
    try {
      return action();
    } on Object catch (e) {
      if (e is! FormatException &&
          e is! TypeError &&
          e is! RangeError &&
          e is! StateError) {
        rethrow;
      }
      throw const ApiFailure(
        'No pudimos leer las notificaciones. Reintenta la consulta.',
      );
    }
  }

  int _id(dynamic x, {bool zero = false}) {
    if (x is! int || x < (zero ? 0 : 1)) throw const FormatException();
    return x;
  }

  int? _optional(dynamic x) => x == null ? null : _id(x);
  @override
  Future<NoticePage> list(
    String token, {
    int page = 1,
    String status = 'all',
    int? anchor,
  }) async {
    final uri = Uri(
      path: 'notifications/',
      queryParameters: {
        'page': '$page',
        'page_size': '10',
        'status': status,
        if (anchor != null) 'through_id': '$anchor',
      },
    );
    final r = await api.request(uri.toString(), token: token);
    return _parse(() {
      final rows = (r['notifications'] as List).map((dynamic value) {
        final v = value as Map<String, dynamic>,
            kind = v['event_kind'] as String;
        if (kind != 'legacy' && !noticeLabels.containsKey(kind)) {
          throw const FormatException();
        }
        return AccountNotice(
          id: _id(v['id']),
          title: v['title'] as String,
          kind: kind,
          createdAt: DateTime.parse(v['created_at'] as String),
          readAt: v['read_at'] == null
              ? null
              : DateTime.parse(v['read_at'] as String),
          applicationId: _optional(v['application_id']),
          offerId: _optional(v['offer_id']),
          conversationId: _optional(v['conversation_id']),
          companyReviewId: _optional(v['company_review_id']),
        );
      }).toList();
      validatePage(r, page, rows.length);
      if (rows.map((x) => x.id).toSet().length != rows.length) {
        throw const FormatException();
      }
      return NoticePage(
        rows: rows,
        count: _id(r['count'], zero: true),
        page: page,
        pages: _id(r['total_pages'], zero: true),
        anchor: _id(r['through_id'], zero: true),
        unread: _id(r['unread_count'], zero: true),
      );
    });
  }

  @override
  Future<int> summary(String token) async {
    final r = await api.request('notifications/summary/', token: token);
    return _parse(() => _id(r['unread_count'], zero: true));
  }

  @override
  Future<void> read(String token, int id) async {
    await api.request(
      'notifications/read/',
      token: token,
      data: {
        'notification_ids': [id],
      },
    );
  }

  Map<String, bool> _preferences(Map<String, dynamic> r) => _parse(() {
    final p = r['preferences'] as Map<String, dynamic>;
    if (p.keys.toSet().difference(noticeLabels.keys.toSet()).isNotEmpty ||
        p.length != noticeLabels.length) {
      throw const FormatException();
    }
    return {for (final key in noticeLabels.keys) key: p[key] as bool};
  });
  @override
  Future<Map<String, bool>> preferences(String token) async => _preferences(
    await api.request('notifications/preferences/', token: token),
  );
  @override
  Future<Map<String, bool>> savePreferences(
    String token,
    Map<String, bool> values,
  ) async => _preferences(
    await api.request(
      'notifications/preferences/',
      token: token,
      method: 'PATCH',
      data: values,
    ),
  );
}
