import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class LicenseService extends GetxService {
  static const String _licenseKey = 'license_key';
  final RxBool isLicensed = false.obs;
  
  // 这里设置有效的许可证密钥列表
  final List<String> _validLicenses = [
    'NOVEL-APP-2024-PRO',  // 可以添加更多许可证
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString(_licenseKey);
    if (savedKey != null) {
      isLicensed.value = _validateLicense(savedKey);
    }
  }

  bool _validateLicense(String key) {
    // 创建许可证的哈希值进行验证
    final hash = sha256.convert(utf8.encode(key)).toString();
    return _validLicenses.any((license) => 
      sha256.convert(utf8.encode(license)).toString() == hash
    );
  }

  Future<bool> activateLicense(String key) async {
    if (_validateLicense(key)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKey, key);
      isLicensed.value = true;
      return true;
    }
    return false;
  }

  Future<void> deactivateLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKey);
    isLicensed.value = false;
  }
} 