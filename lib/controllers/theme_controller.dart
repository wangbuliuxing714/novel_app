import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const String _keyThemeMode = 'theme_mode';
  
  final _prefs = Get.find<SharedPreferences>();
  final RxBool _isDarkMode = false.obs;
  
  bool get isDarkMode => _isDarkMode.value;
  
  @override
  void onInit() {
    super.onInit();
    _loadThemeSettings();
  }
  
  void _loadThemeSettings() {
    _isDarkMode.value = _prefs.getBool(_keyThemeMode) ?? false;
  }
  
  void toggleTheme() {
    _isDarkMode.value = !_isDarkMode.value;
    _prefs.setBool(_keyThemeMode, _isDarkMode.value);
    Get.changeTheme(_isDarkMode.value ? ThemeData.dark() : ThemeData.light());
  }
  
  static final ThemeData defaultTheme = ThemeData(
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    brightness: Brightness.light,
  );
  
  static final ThemeData darkTheme = ThemeData(
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.grey[900],
    brightness: Brightness.dark,
  );

  // 获取调整后的背景色
  Color getAdjustedBackgroundColor() {
    return Get.theme.scaffoldBackgroundColor;
  }
} 