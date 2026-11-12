import 'package:flutter/widgets.dart';
import '../data/academic_catalog.dart';

/// Above the Navigator: Create, Search and Registration share one snapshot.
class AcademicCatalogScope extends InheritedWidget {
  const AcademicCatalogScope({
    super.key,
    required this.catalog,
    required super.child,
  });
  final AcademicCatalog catalog;

  static AcademicCatalog of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AcademicCatalogScope>()
          ?.catalog ??
      AcademicCatalog.temporary;

  @override
  bool updateShouldNotify(AcademicCatalogScope oldWidget) =>
      catalog != oldWidget.catalog;
}
