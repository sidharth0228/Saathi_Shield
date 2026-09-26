import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Ref _ref;

  ThemeNotifier(this._ref) : super(ThemeMode.light) {
    _loadTheme();
  }

  void _loadTheme() {
    final localStorage = _ref.read(localStorageProvider);
    final isDark = localStorage.isDarkMode();
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final localStorage = _ref.read(localStorageProvider);
    if (state == ThemeMode.light) {
      state = ThemeMode.dark;
      await localStorage.setDarkMode(true);
    } else {
      state = ThemeMode.light;
      await localStorage.setDarkMode(false);
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});
