import 'package:e_repairkit/models/location.dart';
import 'package:e_repairkit/models/shop.dart';
import 'package:e_repairkit/services/findshop_service.dart';

class MockShopFinderService implements ShopFinderService {
  @override
  Future<List<Shop>> findNearby(Location location) async {
    await Future.delayed(const Duration(milliseconds: 700));
    return [
      Shop(id: 'shop1', name: 'Nearby Repair Center', distance: 1.4),
      Shop(id: 'shop2', name: 'Official Brand Store', distance: 3.1),
    ];
  }
}