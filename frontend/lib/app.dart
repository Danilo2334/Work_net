import 'package:flutter/material.dart';

import 'core/theme/worknet_theme.dart';
import 'features/registration/data/registration_api.dart';
import 'features/registration/presentation/registration_page.dart';

class WorkNetApp extends StatelessWidget {
  const WorkNetApp({super.key, this.registrationApi});

  final RegistrationApi? registrationApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorkNet',
      debugShowCheckedModeBanner: false,
      theme: workNetTheme(),
      home: RegistrationPage(api: registrationApi),
    );
  }
}
