import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/models/draft.dart';
import 'package:novel_app/services/ai_service.dart';

class DraftController extends GetxController {
  static const String _storageKey = 'drafts';
  final _drafts = <Draft>[].obs;
  final _selectedDraft = Rxn<Draft>();
  final AIService _aiService = Get.find<AIService>();
  
  List<Draft> get drafts => _drafts;
  Draft? get selectedDraft => _selectedDraft.value;

  @override
  void onInit() {
    super.onInit();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final draftsJson = prefs.getStringList(_storageKey) ?? [];
    _drafts.value = draftsJson
        .map((json) => Draft.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> _saveDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final draftsJson = _drafts
        .map((draft) => jsonEncode(draft.toJson()))
        .toList();
    await prefs.setStringList(_storageKey, draftsJson);
  }

  Future<void> createDraft(String title) async {
    final draft = Draft.create(title: title);
    _drafts.add(draft);
    await _saveDrafts();
    selectDraft(draft);
  }

  void selectDraft(Draft? draft) {
    _selectedDraft.value = draft;
  }

  Future<void> updateDraft(String title, String content) async {
    if (_selectedDraft.value == null) return;
    
    final index = _drafts.indexWhere((d) => d.id == _selectedDraft.value!.id);
    if (index == -1) return;

    final updatedDraft = _selectedDraft.value!.copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );

    _drafts[index] = updatedDraft;
    _selectedDraft.value = updatedDraft;
    await _saveDrafts();
  }

  Future<void> deleteDraft(String id) async {
    _drafts.removeWhere((draft) => draft.id == id);
    if (_selectedDraft.value?.id == id) {
      _selectedDraft.value = null;
    }
    await _saveDrafts();
  }

  Future<String> aiModifyText(String text, String prompt) async {
    try {
      final response = await _aiService.generateText(
        '请根据以下要求修改文本：\n'
        '要求：$prompt\n'
        '原文：$text'
      );
      return response;
    } catch (e) {
      return '修改失败：$e';
    }
  }
} 