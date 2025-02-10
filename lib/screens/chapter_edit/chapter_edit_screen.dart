import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/controllers/theme_controller.dart';

class ChapterEditScreen extends StatefulWidget {
  const ChapterEditScreen({super.key});

  @override
  State<ChapterEditScreen> createState() => _ChapterEditScreenState();
}

class _ChapterEditScreenState extends State<ChapterEditScreen> {
  final Chapter chapter = Get.arguments;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _novelController = Get.find<NovelController>();
  final _aiService = Get.find<AIService>();
  final _apiConfig = Get.find<ApiConfigController>();
  final _themeController = Get.find<ThemeController>();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasChanges = false;
  TextSelection? _lastSelection;
  bool _isGenerating = false;
  final _prompt = '';

  @override
  void initState() {
    super.initState();
    _titleController.text = chapter.title;
    _contentController.text = chapter.content;
    
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃更改？'),
        content: const Text('你有未保存的更改，确定要放弃吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _saveChanges() {
    final updatedChapter = Chapter(
      number: chapter.number,
      title: _titleController.text,
      content: _contentController.text,
    );
    
    _novelController.updateChapter(updatedChapter);
    setState(() {
      _hasChanges = false;
    });
    
    Get.offNamed('/chapter_detail', arguments: updatedChapter);
    Get.snackbar('成功', '章节已保存');
  }

  void _showCustomMenu(BuildContext context, Offset position, String selectedText) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(48, 48),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const Text('AI修改'),
          onTap: () {
            _showAIEditDialog(selectedText);
          },
        ),
        PopupMenuItem(
          child: const Text('复制'),
          onTap: () {
            Clipboard.setData(ClipboardData(text: selectedText));
          },
        ),
        PopupMenuItem(
          child: const Text('剪切'),
          onTap: () {
            Clipboard.setData(ClipboardData(text: selectedText));
            _updateContent(_lastSelection!, '');
          },
        ),
        PopupMenuItem(
          child: const Text('粘贴'),
          onTap: () async {
            final data = await Clipboard.getData('text/plain');
            if (data?.text != null) {
              _updateContent(_lastSelection!, data!.text!);
            }
          },
        ),
      ],
    );
  }

  void _updateContent(TextSelection selection, String newText) {
    final currentText = _contentController.text;
    final newContent = currentText.replaceRange(
      selection.start,
      selection.end,
      newText,
    );
    _contentController.value = TextEditingValue(
      text: newContent,
      selection: TextSelection.collapsed(
        offset: selection.start + newText.length,
      ),
    );
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _showAIEditDialog(String selectedText) async {
    final promptController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI修改文本'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('已选中文本：', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    child: Text(
                      selectedText,
                      style: TextStyle(color: Colors.grey.shade800),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: promptController,
                  decoration: const InputDecoration(
                    labelText: '修改指令',
                    hintText: '例如：改写成更生动的描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(promptController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _modifyTextWithAI(selectedText, result);
    }
  }

  Future<void> _modifyTextWithAI(String originalText, String prompt) async {
    try {
      final modifiedTextController = TextEditingController();
      
      Get.dialog(
        AlertDialog(
          title: const Text('AI正在修改文本'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: modifiedTextController,
                    maxLines: null,
                    readOnly: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('取消'),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      final systemPrompt = '''请根据用户的要求修改以下文本。要求：
1. 保持修改后的文本与上下文的连贯性
2. 保持人物、场景等设定的一致性
3. 确保修改后的文本符合整体风格
4. 避免出现与原意相违背的内容

原文：
$originalText

用户要求：
$prompt''';

      final userPrompt = '请按照上述要求修改文本，直接输出修改后的内容，不需要其他解释。';

      String modifiedText = '';
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        maxTokens: 2000,
        temperature: 0.7,
      )) {
        modifiedText += chunk;
        modifiedTextController.text = modifiedText;
      }

      Get.back(); // 关闭生成对话框

      if (_lastSelection != null) {
        _updateContent(_lastSelection!, modifiedText.trim());
        Get.snackbar(
          '修改完成',
          '文本已更新',
          backgroundColor: Colors.green.withOpacity(0.1),
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.back(); // 关闭生成对话框
      Get.snackbar(
        '修改失败',
        e.toString(),
        backgroundColor: Colors.red.withOpacity(0.1),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _generateContent() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      String response = '';
      await for (final chunk in _aiService.generateTextStream(
        systemPrompt: '''你是一位经验丰富的网络小说作家，擅长创作各类爽文网文。作为专业的爽文写手，你需要遵循以下要求：

1. 专业性增强（最重要）：
   - 根据不同场景准确使用专业术语和行话
   - 战斗场景：具体的招式名称、力道参数（如："一记迅猛的直拳，力道达到2.3吨"）
   - 修炼场景：详细的境界划分、具体的能量数值（如："灵力浓度达到367ppm"）
   - 商战场景：准确的金融术语、具体的数据指标（如："季度ROI达到37.8%"）
   - 科技场景：精确的技术参数、具体的型号规格（如："量子计算机的相干时间达到97微秒"）

2. 感官沉浸（重要）：
   - 视觉：不仅写"看到"，还要有光影、色彩、动态的细节
   - 听觉：环境音、对话音、心跳声等声音的层次感
   - 触觉：温度、质地、压力等触感的具体描述
   - 嗅觉：空气中的气味变化、情绪带来的微妙气息
   - 味觉：当场景涉及饮食，详细描写味道层次
   - 多感官联动：在关键场景同时调动3种以上感官

3. 叙事纵深：
   - 时间线交织：现在、回忆、预示三条线并行
   - 空间层次：近景、中景、远景的场景切换
   - 视角转换：适时切换第一人称、第三人称、全知视角
   - 因果链条：每个情节都要埋下后续发展的伏笔
   - 情感递进：通过细节暗示情感变化，避免直白表达

4. 写作技巧：
   - 场景细节要生动形象
   - 打斗场面要有张力
   - 对话要简洁有力
   - 保持节奏紧凑
   - 增加诙谐元素

5. 注意事项：
   - 保持人物性格一致性
   - 注意前后文的连贯性
   - 避免重复性内容
   - 直接返回小说内容，不需要解释说明''',
        userPrompt: _prompt,
      )) {
        setState(() {
          response += chunk;
          _contentController.text = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('编辑第${chapter.number}章'),
          actions: [
            if (_hasChanges)
              TextButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text('保存'),
              ),
          ],
        ),
        body: Obx(() => Container(
          color: _themeController.getAdjustedBackgroundColor(),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '章节标题',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _contentController,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 20,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.8,
                    ),
                    contextMenuBuilder: (context, editableTextState) {
                      final List<ContextMenuButtonItem> buttonItems = 
                        editableTextState.contextMenuButtonItems;
                      
                      if (editableTextState.textEditingValue.selection.isValid &&
                          !editableTextState.textEditingValue.selection.isCollapsed) {
                        _lastSelection = editableTextState.textEditingValue.selection;
                        final selectedText = _lastSelection!.textInside(_contentController.text);
                        
                        return AdaptiveTextSelectionToolbar(
                          anchors: editableTextState.contextMenuAnchors,
                          children: [
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(12.0),
                              onPressed: () {
                                editableTextState.hideToolbar();
                                _showAIEditDialog(selectedText);
                              },
                              child: const Text(
                                'AI修改',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              indent: 8,
                              endIndent: 8,
                            ),
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(12.0),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: selectedText));
                                editableTextState.hideToolbar();
                              },
                              child: const Text(
                                '复制',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              indent: 8,
                              endIndent: 8,
                            ),
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(12.0),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: selectedText));
                                _updateContent(_lastSelection!, '');
                                editableTextState.hideToolbar();
                              },
                              child: const Text(
                                '剪切',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            const VerticalDivider(
                              width: 1,
                              indent: 8,
                              endIndent: 8,
                            ),
                            TextSelectionToolbarTextButton(
                              padding: const EdgeInsets.all(12.0),
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  _updateContent(_lastSelection!, data!.text!);
                                }
                                editableTextState.hideToolbar();
                              },
                              child: const Text(
                                '粘贴',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        );
                      }
                      
                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: buttonItems,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }
} 