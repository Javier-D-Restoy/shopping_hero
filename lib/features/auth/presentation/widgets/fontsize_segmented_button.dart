import 'package:flutter/material.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart'; // <--- Añade tu import aquí

class FontSizeSegmentedButton extends StatelessWidget {
  final FontSizeOption value;
  final ValueChanged<FontSizeOption> onChanged;

  const FontSizeSegmentedButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<FontSizeOption>(
      segments: const [
        ButtonSegment<FontSizeOption>(
          value: FontSizeOption.small,
          label: Text('aA', style: TextStyle(fontSize: 12)),
          tooltip: 'Pequeño',
        ),
        ButtonSegment<FontSizeOption>(
          value: FontSizeOption.medium,
          label: Text('aA', style: TextStyle(fontSize: 15)),
          tooltip: 'Mediano',
        ),
        ButtonSegment<FontSizeOption>(
          value: FontSizeOption.large,
          label: Text('aA', style: TextStyle(fontSize: 20)),
          tooltip: 'Grande',
        ),
      ],
      selected: {value},
      onSelectionChanged: (Set<FontSizeOption> newSelection) {
        onChanged(newSelection.first);
      },
      showSelectedIcon: false,
    );
  }
}