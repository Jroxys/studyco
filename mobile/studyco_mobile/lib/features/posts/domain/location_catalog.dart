/// A real backend ID is optional until GET /api/v1/locations is connected.
/// Temporary entries have no ID; no UUID is fabricated.
class CampusLocation {
  const CampusLocation({required this.name, this.id});
  final String name;
  final String? id;
}

String locationKey(String name) {
  var key = name.trim().replaceAll('İ', 'i').toLowerCase();
  const letters = {
    'ı': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
    '\u0307': '',
  };
  for (final entry in letters.entries) {
    key = key.replaceAll(entry.key, entry.value);
  }
  return key.replaceAll(RegExp(r'\s+'), ' ');
}

/// One authoritative snapshot: replace the whole catalog when changing source.
/// An empty remote snapshot remains empty, without temporary fallback/merging.
class LocationCatalog {
  factory LocationCatalog(
    Iterable<CampusLocation> locations, {
    bool isTemporary = false,
  }) {
    final names = <String>{};
    final ids = <String>{};
    final entries = <CampusLocation>[];
    for (final location in locations) {
      final key = locationKey(location.name);
      if (key.isEmpty ||
          names.contains(key) ||
          (location.id != null && ids.contains(location.id))) {
        continue;
      }
      names.add(key);
      if (location.id != null) ids.add(location.id!);
      entries.add(CampusLocation(name: location.name.trim(), id: location.id));
    }
    return LocationCatalog._(List.unmodifiable(entries), isTemporary);
  }
  const LocationCatalog._(this.entries, this.isTemporary);
  final List<CampusLocation> entries;
  final bool isTemporary;
  List<String> get names =>
      List.unmodifiable(entries.map((entry) => entry.name));

  CampusLocation? findByName(String? name) {
    if (name == null) return null;
    final key = locationKey(name);
    for (final entry in entries) {
      if (locationKey(entry.name) == key) return entry;
    }
    return null;
  }
}
