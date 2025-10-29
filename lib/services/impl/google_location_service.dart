// ignore: library_prefixes
import 'package:e_repairkit/models/location.dart' as AppLocation; // Use 'as' to avoid name conflicts
import 'package:e_repairkit/services/location_service.dart';
import 'package:location/location.dart';

class GoogleLocationService implements LocationService {
  final Location _locationClient = Location();

  @override
  Future<bool> requestPermission() async {
    bool serviceEnabled = await _locationClient.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationClient.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }

    PermissionStatus permissionGranted = await _locationClient.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationClient.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<AppLocation.Location?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestPermission();
      if (!hasPermission) {
        print("Location permission denied.");
        return null;
      }

      final locationData = await _locationClient.getLocation();
      return AppLocation.Location(
        latitude: locationData.latitude ?? 0.0,
        longitude: locationData.longitude ?? 0.0,
      );
    } catch (e) {
      print("Error getting location: $e");
      return null;
    }
  }
}