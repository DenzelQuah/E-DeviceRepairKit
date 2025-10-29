import 'package:flutter/material.dart';
import '../../models/shop.dart';

class ShopCard extends StatelessWidget {
  final Shop shop;
  const ShopCard({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2.0,
      child: ListTile(
        leading: Icon(Icons.store, color: Theme.of(context).primaryColor),
        title: Text(shop.name),
        subtitle: Text('Approx. ${shop.distance} km away'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // You can add navigation to a map view here later
        },
      ),
    );
  }
}