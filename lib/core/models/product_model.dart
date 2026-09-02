import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final int frequency;
  final double? price;
  final String? imageUrl;
  final DateTime lastAdded;

  const Product({
    required this.id,
    required this.name,
    this.frequency = 1,
    this.price,
    this.imageUrl,
    required this.lastAdded,
  });

  Product copyWith({
    String? id,
    String? name,
    int? frequency,
    double? price,
    String? imageUrl,
    DateTime? lastAdded,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      lastAdded: lastAdded ?? this.lastAdded,
    );
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final lastAddedValue = map['lastAdded'];

    return Product(
      id: id,
      name: (map['name'] ?? '').toString(),
      frequency: (map['frequency'] ?? 1) as int,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      imageUrl: map['imageUrl']?.toString(),
      lastAdded: lastAddedValue is Timestamp
          ? lastAddedValue.toDate()
          : (lastAddedValue is DateTime
              ? lastAddedValue
              : DateTime.parse(
                  map['lastAdded'] ?? DateTime.now().toIso8601String())),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'frequency': frequency,
      'price': price,
      'imageUrl': imageUrl,
      'lastAdded': Timestamp.fromDate(lastAdded),
    };
  }

  Map<String, dynamic> toMapHive() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'price': price,
      'imageUrl': imageUrl,
      'lastAdded': lastAdded.toIso8601String(),
    };
  }

  factory Product.fromMapHive(Map<String, dynamic> map) {
    return Product(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      frequency: (map['frequency'] ?? 1) as int,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      imageUrl: map['imageUrl']?.toString(),
      lastAdded: map['lastAdded'] is DateTime
          ? map['lastAdded'] as DateTime
          : DateTime.parse(map['lastAdded'] ?? DateTime.now().toIso8601String()),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() =>
      'Product(id: $id, name: $name, frequency: $frequency, price: $price)';
}
