import 'package:e_repairkit/models/location.dart';
import 'package:e_repairkit/services/location_service.dart';

class MockLocationService implements LocationService {
  @override
  Future<Location?> getCurrentLocation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Fake location (Googleplex)
    return Location(latitude: 37.4220, longitude: -122.0840);
  }

  @override
  Future<bool> requestPermission() async {
    return true; // Always say yes for mocks
  }
}