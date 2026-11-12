import '../domain/location_catalog.dart';

/// Temporary catalog using the locations.csv names supplied by the team.
abstract final class CampusLocations {
  // The ONLY temporary source. API data replaces this catalog, never merges.
  // IDs remain null until actual PostgreSQL IDs are supplied by the backend.
  static final catalog = LocationCatalog(
    values.map((name) => CampusLocation(name: name)),
    isTemporary: isTemporary,
  );
  static const isTemporary = true;
  static const values = [
    'Espressolab',
    'Florida',
    'Colombia',
    'Starbucks',
    'Study',
    'Nevada',
    'Loba',
    'Albert',
    'Nexq',
    'Arabica',
  ];
}
