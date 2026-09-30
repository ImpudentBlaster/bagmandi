/// Public manufacturer address for other users: city + state only.
String publicCityState({
  String? city,
  String? state,
  String? fallbackLocation,
}) {
  final c = city?.trim() ?? '';
  final s = state?.trim() ?? '';
  if (c.isNotEmpty && s.isNotEmpty) return '$c, $s';
  if (c.isNotEmpty) return c;
  if (s.isNotEmpty) return s;

  final loc = fallbackLocation?.trim() ?? '';
  if (loc.isEmpty) return '';
  final bits = loc
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  // Legacy full addresses: keep last two segments as city, state.
  if (bits.length >= 2) {
    return '${bits[bits.length - 2]}, ${bits[bits.length - 1]}';
  }
  return bits.first;
}
