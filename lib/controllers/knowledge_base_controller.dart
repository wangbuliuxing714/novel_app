import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:novel_app/models/knowledge_document.dart';
import 'package:flutter/material.dart';

class KnowledgeBaseController extends GetxController {
  static const _boxName = 'knowledge_base';
  late final Box<dynamic> _box;
  
  final documents = <KnowledgeDocument>[].obs;
  final categories = <String>['未分类'].obs;
  final selectedDocIds = <String>{}.obs;
  
  // 是否使用知识库
  final RxBool useKnowledgeBase = false.obs;
  
  // 是否处于多选模式
  final RxBool isMultiSelectMode = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    _initializeBox();
  }
  
  Future<void> _initializeBox() async {
    _box = await Hive.openBox(_boxName);
    _loadData();
    _loadSettings();
  }
  
  // 加载数据
  Future<void> _loadData() async {
    final savedDocs = _box.get('documents');
    if (savedDocs != null) {
      final docs = (savedDocs as List)
        .map((e) => KnowledgeDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList();
      documents.assignAll(docs);
    }
    
    final savedCategories = _box.get('categories');
    if (savedCategories != null) {
      categories.assignAll(List<String>.from(savedCategories));
    }
  }
  
  void _loadSettings() {
    useKnowledgeBase.value = _box.get('use_knowledge_base', defaultValue: false);
    final saved = _box.get('selected_doc_ids');
    if (saved != null) {
      selectedDocIds.addAll(List<String>.from(saved));
    }
  }
  
  Future<void> saveSettings() async {
    await _box.put('use_knowledge_base', useKnowledgeBase.value);
    await _box.put('selected_doc_ids', selectedDocIds.toList());
  }
  
  // 添加分类
  Future<void> addCategory(String category) async {
    if (!categories.contains(category)) {
      categories.add(category);
      await _box.put('categories', categories.toList());
    }
  }
  
  // 添加文档
  Future<void> addDocument(KnowledgeDocument doc) async {
    documents.add(doc);
    await _box.put('documents', documents.map((d) => d.toJson()).toList());
  }
  
  // 更新文档
  Future<void> updateDocument(KnowledgeDocument doc) async {
    final index = documents.indexWhere((d) => d.id == doc.id);
    if (index != -1) {
      documents[index] = doc;
      await _box.put('documents', documents.map((d) => d.toJson()).toList());
    }
  }
  
  // 删除文档
  Future<void> deleteDocument(String id) async {
    documents.removeWhere((doc) => doc.id == id);
    selectedDocIds.remove(id); // 同时移除选中状态
    await _box.put('documents', documents.map((d) => d.toJson()).toList());
    await saveSettings();
  }
  
  // 切换多选模式
  void toggleMultiSelectMode() {
    isMultiSelectMode.value = !isMultiSelectMode.value;
    if (!isMultiSelectMode.value) {
      clearSelection();
    }
  }
  
  // 切换文档选择状态
  void toggleDocumentSelection(String id) {
    if (selectedDocIds.contains(id)) {
      selectedDocIds.remove(id);
    } else {
      selectedDocIds.add(id);
    }
    saveSettings();
  }
  
  // 选择所有文档
  void selectAllDocuments() {
    selectedDocIds.addAll(documents.map((doc) => doc.id));
    saveSettings();
  }
  
  // 取消选择所有文档
  void deselectAllDocuments() {
    selectedDocIds.clear();
    saveSettings();
  }
  
  // 获取选中的文档
  List<KnowledgeDocument> getSelectedDocuments() {
    return documents.where((doc) => selectedDocIds.contains(doc.id)).toList();
  }
  
  // 清除所有选中状态
  void clearSelection() {
    selectedDocIds.clear();
    isMultiSelectMode.value = false;
    saveSettings();
  }
  
  // 构建包含知识库的提示词
  String buildPromptWithKnowledge(String userPrompt) {
    if (!useKnowledgeBase.value || selectedDocIds.isEmpty) return userPrompt;
    
    final selectedDocs = documents
      .where((doc) => selectedDocIds.contains(doc.id))
      .toList();
    
    if (selectedDocs.isEmpty) return userPrompt;
    
    String knowledgeContext = "请根据以下知识库内容生成符合设定的小说：\n\n";
    
    // 按分类组织知识内容
    Map<String, List<KnowledgeDocument>> docsByCategory = {};
    for (var doc in selectedDocs) {
      if (!docsByCategory.containsKey(doc.category)) {
        docsByCategory[doc.category] = [];
      }
      docsByCategory[doc.category]!.add(doc);
    }
    
    // 按分类添加知识内容
    docsByCategory.forEach((category, docs) {
      knowledgeContext += "【$category】\n";
      for (var doc in docs) {
        knowledgeContext += "${doc.title}：${doc.content}\n\n";
      }
    });
    
    knowledgeContext += "用户要求：\n$userPrompt";
    
    return knowledgeContext;
  }
  
  // 选择文件
  Future<File?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md', 'pdf', 'docx'],
      );
      
      if (result != null) {
        return File(result.files.single.path!);
      }
    } catch (e) {
      print('选择文件时出错: $e');
    }
    return null;
  }
  
  // 处理文件内容
  Future<String> processFileContent(File file) async {
    try {
      final extension = path.extension(file.path).toLowerCase();
      switch (extension) {
        case '.txt':
        case '.md':
          return await file.readAsString();
        case '.pdf':
          // TODO: 实现PDF文件处理
          return 'PDF文件内容待处理';
        case '.docx':
          // TODO: 实现DOCX文件处理
          return 'DOCX文件内容待处理';
        default:
          return '不支持的文件格式';
      }
    } catch (e) {
      print('处理文件内容时出错: $e');
      return '文件处理失败';
    }
  }
  
  // 上传文件
  Future<KnowledgeDocument?> uploadFile({
    required String title,
    required String category,
    String? initialContent,
  }) async {
    try {
      final file = await pickFile();
      if (file == null) return null;
      
      final content = await processFileContent(file);
      final doc = KnowledgeDocument(
        title: title,
        content: initialContent != null ? '$initialContent\n\n$content' : content,
        category: category,
        filePath: file.path,
        fileType: path.extension(file.path).substring(1),
      );
      
      await addDocument(doc);
      return doc;
    } catch (e) {
      print('上传文件时出错: $e');
      return null;
    }
  }
} 