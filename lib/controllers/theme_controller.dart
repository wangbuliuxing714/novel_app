import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyBackgroundColor = 'background_color';
  static const String _keyColorTemperature = 'color_temperature';
  
  final _prefs = Get.find<SharedPreferences>();
  final RxBool _isEyeProtectionMode = false.obs;
  final Rx<Color> _backgroundColor = const Color(0xFFF0F1E8).obs; // 默认护眼色
  final RxDouble _colorTemperature = 4500.0.obs; // 默认暖色调4500K
  
  bool get isEyeProtectionMode => _isEyeProtectionMode.value;
  Color get backgroundColor => _backgroundColor.value;
  double get colorTemperature => _colorTemperature.value;
  
  @override
  void onInit() {
    super.onInit();
    _loadThemeSettings();
  }
  
  void _loadThemeSettings() {
    _isEyeProtectionMode.value = _prefs.getBool(_keyThemeMode) ?? false;
    final savedColor = _prefs.getInt(_keyBackgroundColor);
    if (savedColor != null) {
      _backgroundColor.value = Color(savedColor);
    }
    final savedTemp = _prefs.getInt(_keyColorTemperature);
    _colorTemperature.value = savedTemp?.toDouble() ?? 4500.0;
  }
  
  void toggleTheme() {
    _isEyeProtectionMode.value = !_isEyeProtectionMode.value;
    _prefs.setBool(_keyThemeMode, _isEyeProtectionMode.value);
    if (_isEyeProtectionMode.value) {
      setBackgroundColor(const Color(0xFFF0F1E8)); // 切换到护眼模式时使用默认护眼色
      setColorTemperature(4500.0); // 使用暖色调
    } else {
      setBackgroundColor(Colors.white);
      setColorTemperature(6500.0); // 使用标准色温
    }
  }
  
  void setBackgroundColor(Color color) {
    _backgroundColor.value = color;
    _prefs.setInt(_keyBackgroundColor, color.value);
  }
  
  void setColorTemperature(double temperature) {
    _colorTemperature.value = temperature;
    _prefs.setInt(_keyColorTemperature, temperature.round());
  }
  
  static final ThemeData defaultTheme = ThemeData(
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    brightness: Brightness.light,
  );
  
  static final ThemeData eyeProtectionTheme = ThemeData(
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: const Color(0xFFF0F1E8),
    brightness: Brightness.light,
  );
  
  Color getAdjustedBackgroundColor() {
    final baseColor = _backgroundColor.value;
    final temperature = _colorTemperature.value;
    
    // 将色温转换为RGB调整值
    // 参考黑体辐射的色温-RGB对应关系
    double red, green, blue;
    
    if (temperature <= 6500) {
      // 2000K到6500K，红色分量逐渐减少，蓝色分量逐渐增加
      red = 1.0;
      green = 0.93 + 0.07 * (temperature - 2000) / 4500;
      blue = 0.7 + 0.3 * (temperature - 2000) / 4500;
    } else {
      // 6500K到10000K，红色分量继续减少，蓝色分量保持高值
      red = 1.0 - 0.2 * (temperature - 6500) / 3500;
      green = 1.0 - 0.1 * (temperature - 6500) / 3500;
      blue = 1.0;
    }
    
    // 将基础颜色与色温调整值混合
    final adjustedR = (baseColor.red * red).round().clamp(0, 255);
    final adjustedG = (baseColor.green * green).round().clamp(0, 255);
    final adjustedB = (baseColor.blue * blue).round().clamp(0, 255);
    
    return Color.fromARGB(
      baseColor.alpha,
      adjustedR,
      adjustedG,
      adjustedB,
    );
  }
  
  // 获取预设的背景颜色列表
  List<Color> get presetColors => [
    const Color(0xFFF0F1E8), // 护眼绿
    const Color(0xFFF5E6D3), // 暖色调
    const Color(0xFFE8F0F8), // 冷色调
    const Color(0xFFF2E6E6), // 粉色调
    Colors.white, // 纯白
  ];
} 