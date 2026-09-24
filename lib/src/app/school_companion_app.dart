import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'app_theme.dart';

class SchoolCompanionApp extends StatelessWidget {
  const SchoolCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'School Companion',
      debugShowCheckedModeBanner: false,
      theme: buildMivaTheme(),
      routerConfig: appRouterConfig,
    );
  }
}
