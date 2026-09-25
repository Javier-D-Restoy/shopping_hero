import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final int frequency;
  final int amount;
  final double? price;
  final double? pricePerKilo;
  final String? imageUrl;
  final DateTime lastAdded;

  /// Categoría asignada al producto en listas personales. Valor por defecto 'Genérico'.
  final String category;

  /// Categoría asignada al producto en listas compartidas. Valor por defecto 'Genérico'.
  final String categoryShared;

  /// Identificador o nombre del icono/símbolo/imagen del producto.
  final String? icon;

  const Product({
    required this.id,
    required this.name,
    this.frequency = 1,
    this.amount = 1,
    this.price = 0,
    this.pricePerKilo = 0,
    this.imageUrl,
    required this.lastAdded,
    this.category = 'Genérico',
    this.categoryShared = 'Genérico',
    this.icon,
  });

  /// Devuelve la categoría correspondiente según el contexto de la lista.
  String getCategory({required bool isShared}) => isShared ? categoryShared : category;

  Product copyWith({
    String? id,
    String? name,
    int? frequency,
    int? amount,
    double? price,
    double? pricePerKilo,
    String? imageUrl,
    DateTime? lastAdded,
    String? category,
    String? categoryShared,
    String? icon,
    bool clearIcon = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      amount: amount ?? this.amount,
      price: price ?? this.price,
      pricePerKilo: pricePerKilo ?? this.pricePerKilo,
      imageUrl: imageUrl ?? this.imageUrl,
      lastAdded: lastAdded ?? this.lastAdded,
      category: category ?? this.category,
      categoryShared: categoryShared ?? this.categoryShared,
      icon: clearIcon ? null : (icon ?? this.icon),
    );
  }

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    final lastAddedValue = map['lastAdded'];
    final storedId = (map['id'] ?? id).toString();

    // Parseo defensivo para la categoría personal
    final rawCategory = map['category'];
    String parsedCategory = 'Genérico';
    if (rawCategory is String && rawCategory.isNotEmpty) {
      parsedCategory = rawCategory;
    } else if (rawCategory is Iterable && rawCategory.isNotEmpty) {
      final first = rawCategory.firstWhere(
        (e) => e != null,
        orElse: () => 'Genérico',
      );
      parsedCategory = first.toString();
    }

    // Parseo para la categoría compartida: Si no existe en Firestore, 
    // cae estrictamente a 'Genérico' para asegurar consistencia multi-dispositivo.
    final rawCategoryShared = map['categoryShared'];
    String parsedCategoryShared = 'Genérico';
    if (rawCategoryShared is String && rawCategoryShared.isNotEmpty) {
      parsedCategoryShared = rawCategoryShared;
    }

    return Product(
      id: storedId,
      name: (map['name'] ?? '').toString(),
      frequency: (map['frequency'] ?? 1) as int,
      amount: (map['amount'] ?? 1) as int,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      pricePerKilo: map['pricePerKilo'] != null
          ? (map['pricePerKilo'] as num).toDouble()
          : null,
      imageUrl: map['imageUrl']?.toString(),
      lastAdded: lastAddedValue is Timestamp
          ? lastAddedValue.toDate()
          : (lastAddedValue is DateTime
                ? lastAddedValue
                : DateTime.parse(
                    map['lastAdded'] ?? DateTime.now().toIso8601String(),
                  )),
      category: parsedCategory,
      categoryShared: parsedCategoryShared,
      icon: map['icon']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'amount': amount,
      'price': price,
      'pricePerKilo': pricePerKilo,
      'imageUrl': imageUrl,
      'lastAdded': Timestamp.fromDate(lastAdded),
      'category': category.isEmpty ? 'Genérico' : category,
      'categoryShared': categoryShared.isEmpty ? 'Genérico' : categoryShared,
      'icon': icon,
    };
  }

  Map<String, dynamic> toMapHive() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'amount': amount,
      'price': price,
      'pricePerKilo': pricePerKilo,
      'imageUrl': imageUrl,
      'lastAdded': lastAdded.toIso8601String(),
      'category': category.isEmpty ? 'Genérico' : category,
      'categoryShared': categoryShared.isEmpty ? 'Genérico' : categoryShared,
      'icon': icon,
    };
  }

  factory Product.fromMapHive(Map<String, dynamic> map) {
    final rawCategory = map['category'];
    String parsedCategory = 'Genérico';
    if (rawCategory is String && rawCategory.isNotEmpty) {
      parsedCategory = rawCategory;
    } else if (rawCategory is Iterable && rawCategory.isNotEmpty) {
      final first = rawCategory.firstWhere(
        (e) => e != null,
        orElse: () => 'Genérico',
      );
      parsedCategory = first.toString();
    }

    final rawCategoryShared = map['categoryShared'];
    String parsedCategoryShared = 'Genérico';
    if (rawCategoryShared is String && rawCategoryShared.isNotEmpty) {
      parsedCategoryShared = rawCategoryShared;
    }

    return Product(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      frequency: (map['frequency'] ?? 1) as int,
      amount: (map['amount'] ?? 1) as int,
      price: map['price'] != null ? (map['price'] as num).toDouble() : null,
      pricePerKilo: map['pricePerKilo'] != null
          ? (map['pricePerKilo'] as num).toDouble()
          : null,
      imageUrl: map['imageUrl']?.toString(),
      lastAdded: map['lastAdded'] is DateTime
          ? map['lastAdded'] as DateTime
          : DateTime.parse(
              map['lastAdded'] ?? DateTime.now().toIso8601String(),
            ),
      category: parsedCategory,
      categoryShared: parsedCategoryShared,
      icon: map['icon']?.toString(),
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
      'Product(id: $id, name: $name, category: $category, categoryShared: $categoryShared)';
}