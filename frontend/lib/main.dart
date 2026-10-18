import 'package:flutter/material.dart';

import 'app.dart';
import 'core/navigation/platform_url.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  runApp(const WorkNetApp());
}
