import '../models/location.dart';

abstract class LocationService {
  Future<Location?> getCurrentLocation();
  Future<bool> requestPermission();
}
