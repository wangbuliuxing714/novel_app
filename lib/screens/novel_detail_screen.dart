import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/novel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:novel_app/services/content_review_service.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:novel_app/controllers/novel_controller.dart';

class NovelDetailScreen extends StatefulWidget {
  final Novel novel;

  const NovelDetailScreen({Key? key, required this.novel}) : super(key: key);

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  final NovelController _controller = Get.find<NovelController>();
  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _chapterControllers = [];
  final List<String> _undoHistory = [];
  final List<String> _redoHistory = [];
  bool _isEditing = false;
  int _currentChapterIndex = 0;
  late Novel _currentNovel;

  @override
  void initState() {
    super.initState();
    _currentNovel = widget.novel.copyWith();
    _titleController.text = _currentNovel.title;
    _initChapterControllers();
  }

  void _initChapterControllers() {
    _chapterControllers.clear();
    for (var chapter in _currentNovel.chapters) {
      final controller = TextEditingController(text: chapter.content);
      controller.addListener(() {
        // 当文本发生变化时保存到历史记录
        if (_isEditing) {
          _saveCurrentToHistory();
        }
      });
      _chapterControllers.add(controller);
    }
  }

  void _saveCurrentToHistory() {
    if (_currentChapterIndex < _currentNovel.chapters.length) {
      // 只有当内容真正发生变化时才保存历史
      final currentText = _chapterControllers[_currentChapterIndex].text;
      final currentChapter = _currentNovel.chapters[_currentChapterIndex];
      if (_undoHistory.isEmpty || _undoHistory.last != currentChapter.content) {
        _undoHistory.add(currentChapter.content);
        // 添加新的历史记录时清空重做历史
        _redoHistory.clear();
        setState(() {}); // 更新UI状态，使撤销按钮可用
      }
    }
  }

  void _undo() {
    if (_undoHistory.isNotEmpty) {
      // 保存当前状态到重做历史
      _redoHistory.add(_chapterControllers[_currentChapterIndex].text);
      // 恢复上一个状态
      final lastState = _undoHistory.removeLast();
      _chapterControllers[_currentChapterIndex].text = lastState;
      
      // 更新小说对象
      final updatedChapters = List<Chapter>.from(_currentNovel.chapters);
      updatedChapters[_currentChapterIndex] = updatedChapters[_currentChapterIndex].copyWith(
        content: lastState,
      );
      _updateNovel(_currentNovel.copyWith(chapters: updatedChapters));
    }
  }

  void _redo() {
    if (_redoHistory.isNotEmpty) {
      // 保存当前状态到撤销历史
      _undoHistory.add(_chapterControllers[_currentChapterIndex].text);
      // 恢复下一个状态
      final nextState = _redoHistory.removeLast();
      _chapterControllers[_currentChapterIndex].text = nextState;
      
      // 更新小说对象
      final updatedChapters = List<Chapter>.from(_currentNovel.chapters);
      updatedChapters[_currentChapterIndex] = updatedChapters[_currentChapterIndex].copyWith(
        content: nextState,
      );
      _updateNovel(_currentNovel.copyWith(chapters: updatedChapters));
    }
  }

  void _saveChanges() async {
    try {
      // 创建更新后的小说对象
      final updatedNovel = _currentNovel.copyWith(
        title: _titleController.text,
      );

      // 更新所有章节内容
      final updatedChapters = List<Chapter>.from(_currentNovel.chapters);
      for (var i = 0; i < _currentNovel.chapters.length; i++) {
        updatedChapters[i] = updatedChapters[i].copyWith(
          content: _chapterControllers[i].text,
        );
      }

      // 更新小说内容
      final finalNovel = updatedNovel.copyWith(
        chapters: updatedChapters,
        content: updatedChapters.map((c) => c.content).join('\n\n'),
      );

      // 保存到数据库
      await _controller.saveNovel(finalNovel);
      
      // 更新本地状态
      _updateNovel(finalNovel);

      setState(() {
        _isEditing = false;
        // 清空历史记录
        _undoHistory.clear();
        _redoHistory.clear();
      });

      Get.snackbar(
        '保存成功',
        '所有修改已保存',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        '保存失败',
        '发生错误：$e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isEditing
            ? TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '输入小说标题',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
              )
            : Text(_currentNovel.title),
        actions: [
          if (_isEditing) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoHistory.isEmpty ? null : _undo,
              tooltip: '撤销',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: _redoHistory.isEmpty ? null : _redo,
              tooltip: '重做',
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: '保存',
            ),
          ],
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                // 取消编辑，恢复原始内容
                _titleController.text = _currentNovel.title;
                _initChapterControllers();
                _undoHistory.clear();
                _redoHistory.clear();
              }
              setState(() {
                _isEditing = !_isEditing;
              });
            },
            tooltip: _isEditing ? '取消' : '编辑',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildChapterList(),
          Expanded(
            child: _buildChapterContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _currentNovel.chapters.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('第${_currentNovel.chapters[index].number}章'),
              selected: _currentChapterIndex == index,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _currentChapterIndex = index;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildChapterContent() {
    if (_currentChapterIndex >= _currentNovel.chapters.length) {
      return const Center(child: Text('暂无内容'));
    }

    final chapter = _currentNovel.chapters[_currentChapterIndex];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chapter.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _isEditing
              ? TextField(
                  controller: _chapterControllers[_currentChapterIndex],
                  maxLines: null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '输入章节内容',
                  ),
                )
              : Text(
                  chapter.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.8,
                  ),
                ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _chapterControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateNovel(Novel newNovel) {
    setState(() {
      _currentNovel = newNovel;
    });
  }
}

class NovelDetailController extends GetxController {
  final Novel novel;
  final RxList<int> selectedChapters = <int>[].obs;
  final RxBool isReviewing = false.obs;
  final RxBool isGenerating = false.obs;
  final RxBool isPaused = false.obs;
  final RxInt currentProcessingChapter = 0.obs;
  final reviewRequirementsController = TextEditingController();
  final _contentReviewService = Get.find<ContentReviewService>();
  final _aiService = Get.find<AIService>();

  NovelDetailController(this.novel);

  @override
  void onInit() {
    super.onInit();
    checkForUnfinishedTask();
  }

  @override
  void onClose() {
    reviewRequirementsController.dispose();
    super.onClose();
  }

  void updateGeneratingStatus(bool value) {
    isGenerating.value = value;
  }

  void updatePausedStatus(bool value) {
    isPaused.value = value;
  }

  Future<void> checkForUnfinishedTask() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTask = prefs.getString('unfinished_task_${novel.id}');
    
    if (savedTask != null) {
      final taskData = json.decode(savedTask);
      selectedChapters.value = List<int>.from(taskData['selected_chapters']);
      currentProcessingChapter.value = taskData['current_chapter'];
      
      if (selectedChapters.isNotEmpty) {
        Get.dialog(
          AlertDialog(
            title: const Text('发现未完成的任务'),
            content: const Text('是否继续上次未完成的润色任务？'),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back();
                  clearUnfinishedTask();
                },
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  resumeUnfinishedTask(taskData['requirements']);
                },
                child: const Text('继续'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> clearUnfinishedTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('unfinished_task_${novel.id}');
    selectedChapters.clear();
    currentProcessingChapter.value = 0;
    isPaused.value = false;
    isGenerating.value = false;
  }

  Future<void> saveCurrentProgress() async {
    if (!isGenerating.value) return;
    
    final prefs = await SharedPreferences.getInstance();
    final taskData = {
      'selected_chapters': selectedChapters.toList(),
      'current_chapter': currentProcessingChapter.value,
      'requirements': reviewRequirementsController.text,
    };
    await prefs.setString('unfinished_task_${novel.id}', json.encode(taskData));
  }

  void pauseGeneration() {
    isPaused.value = true;
    saveCurrentProgress();
  }

  void resumeGeneration() {
    isPaused.value = false;
    continueGeneration();
  }

  Future<void> resumeUnfinishedTask(String requirements) async {
    reviewRequirementsController.text = requirements;
    isGenerating.value = true;
    await continueGeneration();
  }

  Future<void> continueGeneration() async {
    if (!isGenerating.value) return;

    try {
      for (int i = currentProcessingChapter.value; i < selectedChapters.length; i++) {
        if (isPaused.value) {
          await saveCurrentProgress();
          return;
        }

        currentProcessingChapter.value = i;
        final chapterIndex = selectedChapters[i];
        final chapter = novel.chapters[chapterIndex];
        
        final reviewedContent = await _contentReviewService.reviewContent(
          content: chapter.content,
          style: '与原文风格一致',
          model: AIModel.values.firstWhere(
            (m) => m.toString().split('.').last == Get.find<ApiConfigController>().selectedModelId.value,
            orElse: () => AIModel.deepseek,
          ),
        );

        novel.chapters[chapterIndex] = chapter.copyWith(content: reviewedContent);
        await saveCurrentProgress();
      }

      Get.snackbar('成功', '章节润色完成');
      await clearUnfinishedTask();
    } catch (e) {
      Get.snackbar('错误', '章节润色失败：$e');
      isPaused.value = true;
      await saveCurrentProgress();
    }
  }

  Future<void> reviewSelectedChapters() async {
    try {
      isGenerating.value = true;
      isPaused.value = false;
      currentProcessingChapter.value = 0;
      Get.back(); // 关闭对话框

      await continueGeneration();
    } catch (e) {
      Get.snackbar('错误', '章节润色失败：$e');
    }
  }

  void showReviewDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('章节润色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => Text('已选择 ${selectedChapters.length} 个章节')),
            const SizedBox(height: 16),
            TextField(
              controller: reviewRequirementsController,
              decoration: const InputDecoration(
                labelText: '润色要求（可选）',
                hintText: '请输入具体的润色要求...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: reviewSelectedChapters,
            child: const Text('开始润色'),
          ),
        ],
      ),
    );
  }

  bool _areChaptersConsecutive() {
    if (selectedChapters.isEmpty) return false;
    selectedChapters.sort();
    for (int i = 1; i < selectedChapters.length; i++) {
      if (selectedChapters[i] != selectedChapters[i - 1] + 1) {
        return false;
      }
    }
    return true;
  }

  String _generateChapterSummary(String content) {
    final sentences = content.split('。');
    if (sentences.length <= 3) return content;
    return sentences.take(3).join('。') + '。';
  }

  Future<void> generateContent() async {
    if (isGenerating.value) return;
    
    try {
      updateGeneratingStatus(true);
      String response = '';
      
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: '''作为一个专业的小说创作助手，请遵循以下创作原则：

1. 故事逻辑：
   - 确保因果关系清晰合理，事件发展有其必然性
   - 人物行为要符合其性格特征和处境
   - 情节转折要有铺垫，避免突兀
   - 矛盾冲突的解决要符合逻辑
   - 故事背景要前后一致，细节要互相呼应

2. 叙事结构：
   - 采用灵活多变的叙事手法，避免单一直线式发展
   - 合理安排伏笔和悬念，让故事更有层次感
   - 注意时间线的合理性，避免前后矛盾
   - 场景转换要流畅自然，不生硬突兀
   - 故事节奏要有张弛，紧凑处突出戏剧性

3. 人物塑造：
   - 赋予角色丰富的心理活动和独特性格
   - 人物成长要符合其经历和环境
   - 人物关系要复杂立体，互动要自然
   - 对话要体现人物性格和身份特点
   - 避免脸谱化和类型化的人物描写

4. 环境描写：
   - 场景描写要与情节和人物情感相呼应
   - 细节要生动传神，突出关键特征
   - 环境氛围要配合故事发展
   - 感官描写要丰富多样
   - 避免无关的环境描写，保持紧凑

5. 语言表达：
   - 用词准确生动，避免重复和陈词滥调
   - 句式灵活多样，富有韵律感
   - 善用修辞手法，但不过分堆砌
   - 对话要自然流畅，符合说话人特点
   - 描写要细腻传神，避免空洞''',
        userPrompt: reviewRequirementsController.text,
        maxTokens: 7000,
        temperature: 0.7,
      )) {
        response += chunk;
      }

      // 处理生成的内容
      // TODO: 根据实际需求处理生成的内容

    } catch (e) {
      Get.snackbar('错误', '生成失败：$e');
    } finally {
      updateGeneratingStatus(false);
    }
  }
}

class ChapterDetailScreen extends StatelessWidget {
  final Chapter chapter;

  const ChapterDetailScreen({
    Key? key,
    required this.chapter,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('第${chapter.number}章：${chapter.title}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          chapter.content,
          style: const TextStyle(fontSize: 16.0, height: 1.6),
        ),
      ),
    );
  }
} 