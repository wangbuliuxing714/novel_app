import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService extends GetxService {
  final RxBool isLicensed = true.obs; // 始终返回已授权状态
  
  Future<void> init() async {
    // 不做任何验证，直接设置为已授权
    isLicensed.value = true;
  }

  // 仅保留方法但返回固定结果
  Future<bool> activateLicense(String key) async {
    return true; // 始终激活成功
  }

  Future<void> deactivateLicense() async {
    // 不做任何操作，保持已授权状态
  }
} 