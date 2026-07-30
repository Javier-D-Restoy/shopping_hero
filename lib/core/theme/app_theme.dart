import 'package:flutter/material.dart';

// Todo Theme tendrá una clase que será la que vayamos a exportar como tema.

// const Color _customColor = Color(0xFF31045C);  // Los colores hexadecimal empiezan con "0xFF"

const List<Color> _colorThemes = [
  Colors.blue,
  Colors.teal,
  Colors.green,
  Colors.yellow,
  Colors.orange,
  Colors.pink,
];

class AppTheme {
  final int selectedColor;

  AppTheme({
    this.selectedColor = 0  // Añadimos los assert para controlar el rango de inputs.
  }): assert(selectedColor >= 0 && selectedColor <= _colorThemes.length - 1, 'Colors must be between 0 and ${_colorThemes.length}');

  // Crearemos un método que retorne algo que de tipo ThemeData, porque eso es lo que espera
  // el parámetro "theme: " del objeto "MaterialApp"
  ThemeData theme() {
    return ThemeData(
      useMaterial3: true, // Ahora viene por defecto en true.
      colorSchemeSeed: _colorThemes[selectedColor],
      // brightness: Brightness.dark // modo oscuro o luminoso
    );
  } // Con esto ya puedo llamar a este tema para usarlo en nuestra aplicación incluso en tiempo de ejecución.
}