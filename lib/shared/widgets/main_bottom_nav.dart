import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showSharedTab = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showSharedTab;

  @override
  Widget build(BuildContext context) {

    final themeProvider = context.watch<ThemeProvider>();

    final backgroundColor = themeProvider.navSurface;
    final borderColor = themeProvider.navBorderColor;
    final iconColor = themeProvider.navPrimaryColor;
    final labelColor = themeProvider.navPrimaryColor;

    final double topInset = currentIndex == 0 ? 2 : 10;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: themeProvider.isDarkMode ? Colors.black : Colors.white,
          boxShadow: [
            if (currentIndex != 0) BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(12, topInset, 12, 12),
        child: Row(
          children: [
            _buildNavigationButton(Icons.list, 'Lista', 0, backgroundColor, borderColor, iconColor, labelColor),
            _buildNavigationButton(Icons.person, 'Perfil', 1, backgroundColor, borderColor, iconColor, labelColor),
            if (showSharedTab)
              _buildNavigationButton(Icons.supervised_user_circle, 'Compartido', 2, backgroundColor, borderColor, iconColor, labelColor),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    IconData icon,
    String label,
    int index,
    Color backgroundColor,
    Color borderColor,
    Color iconColor,
    Color labelColor,
  ) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? backgroundColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? borderColor : Colors.transparent, width: 2)
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? iconColor : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? labelColor : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
