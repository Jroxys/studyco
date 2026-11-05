import 'package:flutter/widgets.dart';
import '../data/campus_locations.dart';
import '../domain/location_catalog.dart';

/// Place above the Navigator so every route uses the same source snapshot.
class LocationCatalogScope extends InheritedWidget {
  const LocationCatalogScope({
    super.key,
    required this.catalog,
    required super.child,
  });
  final LocationCatalog catalog;

  static LocationCatalog of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LocationCatalogScope>()
          ?.catalog ??
      CampusLocations.catalog;

  @override
  bool updateShouldNotify(LocationCatalogScope oldWidget) =>
      catalog != oldWidget.catalog;
}
