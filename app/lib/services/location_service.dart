import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class AppLocation {
  final double latitude;
  final double longitude;
  final String label;
  final String? city;
  final String? state;

  const AppLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.city,
    this.state,
  });
}

class LocationService {
  Future<bool> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location services are turned off. Enable GPS and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Enable it in Settings.');
    }
    return true;
  }

  Future<AppLocation> getCurrentLocation() async {
    await ensurePermission();
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    String label = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
    String? city;
    String? state;

    try {
      final places = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (places.isNotEmpty) {
        final p = places.first;
        city = p.locality?.isNotEmpty == true
            ? p.locality
            : (p.subAdministrativeArea?.isNotEmpty == true ? p.subAdministrativeArea : p.subLocality);
        state = p.administrativeArea;
        final parts = <String>[
          if (city != null && city.isNotEmpty) city,
          if (state != null && state.isNotEmpty) state,
        ];
        if (parts.isNotEmpty) label = parts.join(', ');
      }
    } catch (_) {
      // Keep coordinates label if reverse geocode fails.
    }

    return AppLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      label: label,
      city: city,
      state: state,
    );
  }
}
