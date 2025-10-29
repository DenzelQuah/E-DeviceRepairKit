class Shop {
  final String id;
  final String name;
  final double distance;
  final double? lat;
  final double? long;

  // Ensure constructors and fromMap/toMap handle these as nullable fields.
  // You can add more fields later (e.g., address, rating)

  Shop({
    required this.id,
    required this.name,
    required this.distance,
    this.lat,
    this.long,
  });

    factory Shop.fromMap(Map<String, dynamic> m) {
    return Shop(
      id: m['id'] as String? ?? 'unknown_id',
      name: m['name'] as String? ?? 'Unknown',
      distance: (m['distance'] as num?)?.toDouble() ?? 0.0,
      lat: (m['lat'] as num?)?.toDouble(),
      long: (m['long'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'distance': distance,
        'lat': lat,
        'long': long,
      };
}
