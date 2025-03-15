import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/theme_controller.dart';

class NovelContinueScreen extends StatefulWidget {
  final Novel novel;

  const NovelContinueScreen({super.key, required this.novel});

  @override
  State<NovelContinueScreen> createState() => _NovelContinueScreenState();
}

class _NovelContinueScreenState extends State<NovelContinueScreen> {
  final NovelController _novelController = Get.find();
  final ThemeController _themeController = Get.find();
  final TextEditingController _promptController = TextEditingController();
  final _selectedChapter = Rxn<Chapter>();
  final _chapterCount = 1.obs;
  final _isGenerating = false.obs;
  final _generatedOutline = ''.obs;
  final _generatedChapters = <Chapter>[].obs;
  final _currentStep = 0.obs; // 0: 未开始, 1: 生成大纲, 2: 生成章节
  String _generationStatus = '';

  @override
  void initState() {
    super.initState();
    _selectedChapter.value = widget.novel.outlineChapter;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final padding = isTablet ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('续写小说'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 800 : double.infinity,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 当前大纲
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '当前大纲',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: SingleChildScrollView(
                                  child: Text(widget.novel.outlineChapter.content),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: padding),
                      
                      // 续写提示输入
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '续写提示',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _promptController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: '请输入续写提示，例如：故事发展方向、情节要求等',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: padding),
                      
                      // 生成章节数量选择
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(padding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '生成章节数量',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Obx(() => Column(
                                children: [
                                  Slider(
                                    value: _chapterCount.value.toDouble(),
                                    min: 1,
                                    max: 20,
                                    divisions: 19,
                                    label: '${_chapterCount.value}章',
                                    onChanged: (value) {
                                      _chapterCount.value = value.toInt();
                                    },
                                  ),
                                  Text(
                                    '将生成 ${_chapterCount.value} 章续写内容',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: padding),
                      
                      // 生成按钮
                      ElevatedButton.icon(
                        onPressed: _startGeneration,
                        icon: const Icon(Icons.auto_stories),
                        label: const Text('开始续写'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      SizedBox(height: padding),
                      
                      // 生成结果显示
                      Obx(() {
                        if (_isGenerating.value) {
                          return const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('正在生成续写内容...'),
                              ],
                            ),
                          );
                        }
                        
                        if (_generatedOutline.value.isNotEmpty) {
                          return Column(
                            children: [
                              // 大纲显示
                              Card(
                                child: Padding(
                                  padding: EdgeInsets.all(padding),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '生成的大纲续写',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        constraints: const BoxConstraints(maxHeight: 200),
                                        child: SingleChildScrollView(
                                          child: Text(_generatedOutline.value),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: padding),
                              
                              // 章节内容显示
                              if (_generatedChapters.isNotEmpty)
                                Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(padding),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '生成的章节内容',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ..._generatedChapters.map((chapter) => Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '第${chapter.number}章：${chapter.title}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              constraints: const BoxConstraints(maxHeight: 300),
                                              child: SingleChildScrollView(
                                                child: Text(chapter.content),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Divider(),
                                          ],
                                        )).toList(),
                                      ],
                                    ),
                                  ),
                                ),
                              SizedBox(height: padding),
                              
                              // 操作按钮
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: _regenerate,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('重新生成'),
                                  ),
                                  SizedBox(width: padding),
                                  ElevatedButton.icon(
                                    onPressed: _saveContent,
                                    icon: const Icon(Icons.save),
                                    label: const Text('保存'),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                        
                        return const SizedBox();
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGeneration() async {
    if (_promptController.text.trim().isEmpty) {
      Get.snackbar('错误', '请输入续写提示');
      return;
    }

    _isGenerating.value = true;
    _currentStep.value = 1;
    try {
      // 先生成大纲续写
      final outlineResult = await _novelController.continueNovel(
        novel: widget.novel,
        chapter: widget.novel.outlineChapter,
        prompt: _promptController.text,
        chapterCount: _chapterCount.value,
      );
      _generatedOutline.value = outlineResult;

      // 将大纲也添加到生成章节列表中，作为第0章
      _generatedChapters.clear();
      _generatedChapters.add(Chapter(
        number: 0,
        title: '大纲',
        content: outlineResult,
      ));

      // 解析生成的大纲
      final outlinePattern = RegExp(r'第(\d+)章：(.*?)\n(.*?)(?=第\d+章|$)', dotAll: true);
      final matches = outlinePattern.allMatches(outlineResult);
      
      _currentStep.value = 2;
      
      // 根据大纲生成每个章节的内容
      for (final match in matches) {
        final number = int.parse(match.group(1)!);
        final title = match.group(2)!.trim();
        final outline = match.group(3)!.trim();
        
        // 生成章节内容
        final chapterContent = await _novelController.generateChapterFromOutline(
          chapterNumber: number,
          outlineString: _generatedOutline.value,
          onStatus: (status) {
            setState(() {
              _generationStatus = status;
            });
          },
        );
        
        _generatedChapters.add(Chapter(
          number: widget.novel.chapters.length + number,
          title: title,
          content: chapterContent.content,
        ));
      }
    } catch (e) {
      Get.snackbar('错误', '生成续写内容失败：$e');
    } finally {
      _isGenerating.value = false;
      _currentStep.value = 0;
    }
  }

  void _regenerate() {
    _generatedOutline.value = '';
    _generatedChapters.clear();
    _startGeneration();
  }

  void _saveContent() async {
    try {
      // 更新大纲
      final updatedOutline = widget.novel.outline + '\n\n' + _generatedOutline.value;
      
      // 创建包含更新后大纲的新章节
      final outlineChapter = Chapter(
        number: 0,
        title: '大纲',
        content: updatedOutline,
      );
      
      // 保存大纲章节
      await _novelController.saveChapter(widget.novel.title, outlineChapter);
      
      // 保存新生成的章节
      for (final chapter in _generatedChapters) {
        await _novelController.saveChapter(widget.novel.title, chapter);
      }
      
      Get.back(result: true);
      Get.snackbar('成功', '续写内容已保存');
    } catch (e) {
      Get.snackbar('错误', '保存续写内容失败：$e');
    }
  }
} 