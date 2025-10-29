import '../models/location.dart';
import '../models/shop.dart';

abstract class ShopFinderService {
  Future<List<Shop>> findNearby(Location location);
}