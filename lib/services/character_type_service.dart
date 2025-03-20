import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:flutter/material.dart';

class CharacterTypeService extends GetxService {
  final SharedPreferences _prefs;
  final RxList<CharacterType> characterTypes = <CharacterType>[].obs;
  static const String _storageKey = 'character_types';

  CharacterTypeService(this._prefs) {
    _initDefaultTypes();
    _loadFromStorage();
  }

  // 初始化默认的角色类型
  void _initDefaultTypes() {
    if (_prefs.getString(_storageKey) == null) {
      final defaultTypes = [
        CharacterType(
          id: '1',
          name: '主角',
          description: '故事的主要人物',
          color: const Color(0xFF2196F3).value.toRadixString(16),
        ),
        CharacterType(
          id: '2',
          name: '女主角',
          description: '故事的女主角',
          color: const Color(0xFFE91E63).value.toRadixString(16),
        ),
        CharacterType(
          id: '3',
          name: '闺蜜',
          description: '女主角的好朋友',
          color: const Color(0xFF9C27B0).value.toRadixString(16),
        ),
        CharacterType(
          id: '4',
          name: '兄弟',
          description: '主角的好兄弟',
          color: const Color(0xFF4CAF50).value.toRadixString(16),
        ),
      ];
      
      characterTypes.addAll(defaultTypes);
      _saveToStorage();
    }
  }

  // 从本地存储加载角色类型
  void _loadFromStorage() {
    try {
      final String? jsonStr = _prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        characterTypes.value = jsonList
            .map((json) => CharacterType.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('加载角色类型失败: $e');
      // 如果出现错误，使用默认类型
      characterTypes.clear();
      _initDefaultTypes();
    }
  }

  // 保存到本地存储
  Future<void> _saveToStorage() async {
    final String jsonStr = json.encode(
      characterTypes.map((type) => type.toJson()).toList(),
    );
    await _prefs.setString(_storageKey, jsonStr);
  }

  // 添加新的角色类型
  Future<void> addCharacterType(CharacterType type) async {
    characterTypes.add(type);
    await _saveToStorage();
  }

  // 更新角色类型
  Future<void> updateCharacterType(CharacterType type) async {
    final index = characterTypes.indexWhere((t) => t.id == type.id);
    if (index != -1) {
      characterTypes[index] = type;
      await _saveToStorage();
    }
  }

  // 删除角色类型
  Future<void> deleteCharacterType(String id) async {
    characterTypes.removeWhere((type) => type.id == id);
    await _saveToStorage();
  }
} 