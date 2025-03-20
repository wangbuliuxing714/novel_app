import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/character_card.dart';

class CharacterCardService extends GetxService {
  static const String CARDS_KEY = 'character_cards';
  final SharedPreferences _prefs;
  final RxList<CharacterCard> cards = <CharacterCard>[].obs;

  CharacterCardService(this._prefs) {
    _loadCards();
  }

  // 加载所有角色卡片
  void _loadCards() {
    try {
      final String? cardsJson = _prefs.getString(CARDS_KEY);
      if (cardsJson != null) {
        final List<dynamic> decodedList = jsonDecode(cardsJson);
        cards.value = decodedList.map((json) => CharacterCard.fromJson(json)).toList();
      }
    } catch (e) {
      print('加载角色卡片失败: $e');
      // 出错时清空角色卡片并保存，重置数据
      cards.clear();
      _saveCards();
    }
  }

  // 保存所有角色卡片
  Future<void> _saveCards() async {
    final String cardsJson = jsonEncode(cards.map((card) => card.toJson()).toList());
    await _prefs.setString(CARDS_KEY, cardsJson);
  }

  // 添加新角色卡片
  Future<void> addCard(CharacterCard card) async {
    cards.add(card);
    await _saveCards();
  }

  // 更新角色卡片
  Future<void> updateCard(CharacterCard updatedCard) async {
    final index = cards.indexWhere((card) => card.id == updatedCard.id);
    if (index != -1) {
      cards[index] = updatedCard;
      await _saveCards();
    }
  }

  // 删除角色卡片
  Future<void> deleteCard(String id) async {
    cards.removeWhere((card) => card.id == id);
    await _saveCards();
  }

  // 获取所有角色卡片
  List<CharacterCard> getAllCards() {
    return cards;
  }

  // 根据ID获取角色卡片
  CharacterCard? getCardById(String id) {
    return cards.firstWhereOrNull((card) => card.id == id);
  }
} 