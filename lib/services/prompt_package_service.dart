import 'dart:convert';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:novel_app/models/prompt_package.dart';
import 'package:novel_app/data/default_prompt_packages.dart';
import 'package:uuid/uuid.dart';

class PromptPackageService extends GetxService {
  static const String _boxName = 'prompt_packages';
  late final Box<dynamic> _box;
  final RxList<PromptPackage> promptPackages = <PromptPackage>[].obs;
  
  Future<PromptPackageService> init() async {
    _box = await Hive.openBox(_boxName);
    await _loadPromptPackages();
    
    // 如果没有提示词包，创建默认提示词包
    if (promptPackages.isEmpty) {
      await _createDefaultPromptPackages();
    }
    
    return this;
  }
  
  Future<void> _loadPromptPackages() async {
    try {
      final packages = _box.values.map((data) {
        if (data is Map) {
          return PromptPackage.fromJson(Map<String, dynamic>.from(data));
        } else if (data is String) {
          return PromptPackage.fromJson(jsonDecode(data));
        }
        throw Exception('无效的提示词包数据格式');
      }).toList();
      
      promptPackages.assignAll(packages.cast<PromptPackage>());
      promptPackages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('加载提示词包失败: $e');
      promptPackages.clear();
    }
  }
  
  Future<void> _createDefaultPromptPackages() async {
    // 使用预定义的默认提示词包
    for (final package in defaultPromptPackages) {
      await savePromptPackage(package);
    }
  }
  
  Future<void> savePromptPackage(PromptPackage package) async {
    try {
      // 将PromptPackage对象转换为JSON Map后存储
      await _box.put(package.id, package.toJson());
      
      final index = promptPackages.indexWhere((p) => p.id == package.id);
      if (index != -1) {
        promptPackages[index] = package;
      } else {
        promptPackages.add(package);
      }
      
      promptPackages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('保存提示词包失败: $e');
      rethrow;
    }
  }
  
  Future<void> deletePromptPackage(String id) async {
    try {
      await _box.delete(id);
      promptPackages.removeWhere((p) => p.id == id);
    } catch (e) {
      print('删除提示词包失败: $e');
      rethrow;
    }
  }
  
  PromptPackage? getPromptPackage(String id) {
    return promptPackages.firstWhereOrNull((p) => p.id == id);
  }
  
  List<PromptPackage> getPromptPackagesByType(String type) {
    return promptPackages.where((p) => p.type == type).toList();
  }
  
  PromptPackage? getDefaultPromptPackage(String type) {
    return promptPackages.firstWhereOrNull((p) => p.type == type && p.isDefault);
  }
  
  Future<void> setDefaultPromptPackage(String id) async {
    final package = getPromptPackage(id);
    if (package == null) return;
    
    // 取消其他同类型的默认设置
    for (final p in promptPackages.where((p) => p.type == package.type && p.isDefault)) {
      await savePromptPackage(p.copyWith(isDefault: false));
    }
    
    // 设置新的默认提示词包
    await savePromptPackage(package.copyWith(isDefault: true));
  }
} 