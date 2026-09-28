import 'package:flutter/material.dart';

/// Criterios de ordenación disponibles para los productos activos de una lista.
/// Es una preferencia puramente local del dispositivo: no se sincroniza con
/// Firestore para no generar conflictos entre usuarios que comparten la lista.
enum ProductSortOption { dateDesc, alphabetical, category, categoryAlphabetical}

extension ProductSortOptionLabel on ProductSortOption {
  String get label {
    switch (this) {
      case ProductSortOption.dateDesc:
        return 'Más recientes primero';
      case ProductSortOption.alphabetical:
        return 'Alfabético';
      case ProductSortOption.category:
        return 'Por categoría (reciente)';
      case ProductSortOption.categoryAlphabetical:
        return 'Por categoría (alfabético)';
    }
  }
}

enum FrequentSortOption {
  frequency, // Ordenar por frecuencia de uso (más frecuentes primero)
  date,      // Ordenar por fecha (más recientes primero)
}

extension FrequentSortOptionExtension on FrequentSortOption {
  String get displayName {
    switch (this) {
      case FrequentSortOption.frequency:
        return 'Frecuencia';
      case FrequentSortOption.date:
        return 'Reciente';
    }
  }

  IconData get icon {
    switch (this) {
      case FrequentSortOption.frequency:
        return Icons.repeat;
      case FrequentSortOption.date:
        return Icons.access_time;
    }
  }
}