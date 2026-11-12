import 'package:flutter/material.dart';

import '../data/campus_locations.dart';

/// A controlled menu selection accepting only the provided allowlist.
class PostLocationField extends StatelessWidget {
  const PostLocationField({
    super.key,
    required this.value,
    required this.onLocationChanged,
    this.enabled = true,
    this.locationOptions = CampusLocations.values,
    this.locationsAreTemporary = CampusLocations.isTemporary,
  });
  final String? value;
  final ValueChanged<String> onLocationChanged;
  final bool enabled;
  final List<String> locationOptions;
  final bool locationsAreTemporary;

  String? get _selected => locationOptions.contains(value) ? value : null;

  void _select(String value) {
    if (!enabled || !locationOptions.contains(value)) return;
    onLocationChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unavailable = locationOptions.isEmpty;
    return Column(
      children: [
        KeyedSubtree(
          key: const ValueKey('post-location-option'),
          child: DropdownButtonFormField<String>(
            key: ValueKey('selected-location-$_selected'),
            value: _selected,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              labelText: 'Konum seç *',
              prefixIcon: const Icon(Icons.location_on_outlined),
              helperMaxLines: 4,
              helperText:
                  unavailable
                      ? 'Konum listesi henüz hazır değil. Liste hazır olduğunda ilan oluşturabilirsiniz.'
                      : locationsAreTemporary
                      ? 'Geçici örnek konumlar; kampüs içi uygunlukları henüz doğrulanmadı.'
                      : null,
            ),
            hint: Text(
              unavailable
                  ? 'Konum listesi henüz hazır değil'
                  : 'Buluşma noktasını seçin',
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: colors.primary.withValues(alpha: 0.8),
              ),
            ),
            items: locationOptions
                .map(
                  (location) =>
                      DropdownMenuItem(value: location, child: Text(location)),
                )
                .toList(growable: false),
            validator: (value) {
              if (unavailable) return 'Konum listesi henüz hazır değil.';
              if (!locationOptions.contains(value)) {
                return 'Listeden bir buluşma noktası seçin.';
              }
              return null;
            },
            onChanged:
                !enabled || unavailable
                    ? null
                    : (value) {
                      if (value != null) _select(value);
                    },
          ),
        ),
      ],
    );
  }
}
