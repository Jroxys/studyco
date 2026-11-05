import 'package:flutter/material.dart';
import '../core/data/academic_catalog.dart';
import '../core/widgets/academic_catalog_scope.dart';
import '../features/posts/domain/location_catalog.dart';
import '../features/posts/widgets/location_catalog_scope.dart';
import '../features/posts/data/campus_locations.dart';

import '../features/auth/screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'debug/home_preview.dart';
import '../features/auth/debug/password_reset_preview.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.locationCatalog, this.academicCatalog});
  final LocationCatalog? locationCatalog;
  final AcademicCatalog? academicCatalog;

  @override
  Widget build(BuildContext context) {
    final preview = PasswordResetPreview.screen() ?? HomePreview.screen();
    return MaterialApp(
      title: 'StudyCo',
      builder:
          (_, child) => LocationCatalogScope(
            catalog: locationCatalog ?? CampusLocations.catalog,
            child: AcademicCatalogScope(
              catalog: academicCatalog ?? AcademicCatalog.temporary,
              child: child!,
            ),
          ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: preview == null ? const LoginScreen() : null,
      onGenerateRoute:
          (_) => MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      onGenerateInitialRoutes:
          preview == null
              ? null
              : (_) {
                return [
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  MaterialPageRoute<void>(builder: (_) => preview),
                ];
              },
    );
  }
}
