// Entrada QA explícita: reutiliza WorkNetApp y su restauración/guards reales.
// Las credenciales ficticias se inyectan desde un archivo privado de defines.
// Nunca se utiliza como lib/main.dart ni se publica un APK con esos valores.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:worknet/app.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/data/access_repository.dart';

class _EphemeralStore implements SessionStore {
  String? _value;
  @override
  Future<String?> read() async => _value;
  @override
  Future<void> write(String value) async {
    _value = value;
  }

  @override
  Future<void> clear() async {
    _value = null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const base = String.fromEnvironment('QA_ANDROID_API');
    const email = String.fromEnvironment('QA_ANDROID_EMAIL');
    const password = String.fromEnvironment('QA_ANDROID_PASSWORD');
    const confirmation = String.fromEnvironment('QA_ANDROID_CONFIRM');
    const run = String.fromEnvironment('QA_ANDROID_RUN');
    final uri = Uri.parse(base);
    if (uri.scheme != 'http' ||
        uri.host != '10.0.2.2' ||
        uri.path != '/api/' ||
        uri.port < 1024 ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        confirmation != 'SOLO_BASE_AISLADA' ||
        !RegExp(r'^run-\d{8}T\d{6}-[a-f0-9]{8}$').hasMatch(run) ||
        email != 'candidate.postman@worknet.test' ||
        password.length < 12) {
      throw StateError('Solo una QA Android ficticia aislada.');
    }
    final store = _EphemeralStore();
    final check = await http
        .get(uri.resolve('company/offers/'))
        .timeout(const Duration(seconds: 10));
    if (check.headers['x-worknet-qa-run'] != run || check.statusCode != 401) {
      throw StateError('El servidor no acredita esta QA aislada.');
    }
    final api = WorkNetApi(baseUri: uri);
    final auth = HttpAccessRepository(api, store);
    final user = await auth.login(email, password);
    if (user.role != 'candidato') {
      throw StateError('Rol QA no confirmado.');
    }
    await auth.remember(user);
    runApp(
      WorkNetApp(
        api: api,
        sessionStore: store,
        initialLocation: '/curriculum/create',
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('No se pudo iniciar la QA Android aislada.'),
          ),
        ),
      ),
    );
  }
}
