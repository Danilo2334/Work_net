import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/data/access_repository.dart'
    show adminPermissionKeys;

class Administrator {
  const Administrator({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.verified,
    required this.enrolled,
    required this.permissions,
    required this.version,
    required this.protected,
  });
  final int id, version;
  final String name, email, role;
  final bool active, verified, enrolled, protected;
  final List<String> permissions;
  static Administrator parse(dynamic x) {
    if (x is! Map ||
        x['id'] is! int ||
        x['full_name'] is! String ||
        x['email'] is! String ||
        ![
          'principal',
          'gestor',
          'revisor',
        ].contains(x['administrative_role']) ||
        x['is_active'] is! bool ||
        x['email_verified'] is! bool ||
        x['mfa_enrolled'] is! bool ||
        x['version'] is! int ||
        x['protected'] is! bool ||
        x['permissions'] is! List ||
        (x['permissions'] as List).any(
          (p) => !adminPermissionKeys.contains(p),
        )) {
      throw const ApiFailure(
        'El servicio no confirmó una cuenta administrativa válida.',
      );
    }
    return Administrator(
      id: x['id'],
      name: x['full_name'],
      email: x['email'],
      role: x['administrative_role'],
      active: x['is_active'],
      verified: x['email_verified'],
      enrolled: x['mfa_enrolled'],
      permissions: List<String>.unmodifiable(x['permissions']),
      version: x['version'],
      protected: x['protected'],
    );
  }
}

class AdminListing {
  const AdminListing(
    this.rows,
    this.count,
    this.page,
    this.pageSize,
    this.canCreate,
    this.myPermissions,
    this.catalog,
    this.roles,
  );
  final List<Administrator> rows;
  final int count, page, pageSize;
  final bool canCreate;
  final Set<String> myPermissions;
  final Map<String, String> catalog;
  final Map<String, Set<String>> roles;
}

abstract interface class AdminRepository {
  Future<AdminListing> list(String token, int page);
  Future<void> create(String token, Map<String, dynamic> fields);
  Future<void> update(String token, int id, Map<String, dynamic> fields);
  Future<List<String>> events(String token);
}

class HttpAdminRepository implements AdminRepository {
  const HttpAdminRepository(this.api);
  final WorkNetApi api;
  @override
  Future<AdminListing> list(String token, int page) async {
    final x = await api.request('admin/accounts/?page=$page', token: token);
    if (x['results'] is! List ||
        x['count'] is! int ||
        x['page'] != page ||
        x['page_size'] != 20 ||
        x['can_create'] is! bool ||
        x['my_permissions'] is! List ||
        (x['my_permissions'] as List).any(
          (p) => !adminPermissionKeys.contains(p),
        ) ||
        x['permission_catalog'] is! List ||
        x['roles'] is! List) {
      throw const ApiFailure(
        'No pudimos interpretar el listado administrativo.',
      );
    }
    final catalog = <String, String>{};
    for (final c in x['permission_catalog']) {
      if (c is! Map ||
          !adminPermissionKeys.contains(c['key']) ||
          c['label'] is! String) {
        throw const ApiFailure('Catálogo de permisos no válido.');
      }
      catalog[c['key']] = c['label'];
    }
    final roles = <String, Set<String>>{};
    for (final r in x['roles']) {
      if (r is! Map ||
          !['gestor', 'revisor'].contains(r['key']) ||
          r['permissions'] is! List ||
          (r['permissions'] as List).any(
            (p) => !adminPermissionKeys.contains(p),
          )) {
        throw const ApiFailure('Catálogo de roles no válido.');
      }
      roles[r['key']] = Set<String>.from(r['permissions']);
    }
    if (roles.length != 2 || catalog.length != adminPermissionKeys.length) {
      throw const ApiFailure('El catálogo administrativo está incompleto.');
    }
    return AdminListing(
      (x['results'] as List).map(Administrator.parse).toList(growable: false),
      x['count'],
      page,
      20,
      x['can_create'],
      Set<String>.from(x['my_permissions']),
      catalog,
      roles,
    );
  }

  @override
  Future<void> create(String token, Map<String, dynamic> fields) async {
    Administrator.parse(
      (await api.request(
        'admin/accounts/',
        token: token,
        data: fields,
      ))['administrator'],
    );
  }

  @override
  Future<void> update(String token, int id, Map<String, dynamic> fields) async {
    Administrator.parse(
      (await api.request(
        'admin/accounts/$id/',
        token: token,
        method: 'PATCH',
        data: fields,
      ))['administrator'],
    );
  }

  @override
  Future<List<String>> events(String token) async {
    final x = await api.request('admin/events/', token: token);
    if (x['events'] is! List) {
      throw const ApiFailure(
        'No pudimos interpretar los eventos administrativos.',
      );
    }
    const labels = {
      'admin_created': 'Cuenta administrativa creada',
      'admin_updated': 'Nombre actualizado',
      'admin_authority_changed': 'Permisos o estado actualizados',
      'mfa_enrolled': 'Autenticador configurado',
      'mfa_login': 'Acceso con doble factor',
      'mfa_recovery': 'Recuperación de autenticador',
    };
    return (x['events'] as List)
        .map((e) {
          if (e is! Map ||
              e['action'] is! String ||
              e['created_at'] is! String ||
              DateTime.tryParse(e['created_at']) == null ||
              (e['actor__full_name'] != null &&
                  e['actor__full_name'] is! String) ||
              (e['target__full_name'] != null &&
                  e['target__full_name'] is! String)) {
            throw const ApiFailure('Evento administrativo no válido.');
          }
          return '${labels[e['action']] ?? 'Evento administrativo'} · Por: ${e['actor__full_name'] ?? 'Cuenta eliminada'} · Cuenta: ${e['target__full_name'] ?? 'Cuenta eliminada'} · ${e['created_at']}';
        })
        .toList(growable: false);
  }
}
