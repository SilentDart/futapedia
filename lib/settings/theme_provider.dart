import 'package:flutter/material.dart';
import 'package:futapedia/settings/theme.dart';

class ThemeProvider extends ChangeNotifier {
  // Initialize with the default theme color
  MaterialColor _themeColor = Colors.brown;
  
  MaterialColor get themeColor => _themeColor;
  
  // Update theme color and notify listeners
  void setThemeColor(MaterialColor color) {
    _themeColor = color;
    notifyListeners();
  }
  
  // Initialize provider with saved theme
  Future<void> loadSavedTheme() async {
    final savedColor = await ThemeColorManager.getSavedColor();
    _themeColor = savedColor;
    notifyListeners();
  }
}