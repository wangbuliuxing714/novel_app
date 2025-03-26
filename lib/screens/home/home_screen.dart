import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/prompts/genre_prompts.dart';
import 'package:novel_app/models/character_card.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:novel_app/screens/novel_detail_screen.dart';
import 'package:novel_app/screens/settings_screen.dart';
import 'package:novel_app/screens/prompt_management_screen.dart';
import 'package:novel_app/screens/help_screen.dart';
import 'package:novel_app/controllers/theme_controller.dart';
import 'package:novel_app/screens/genre_manager_screen.dart';
import 'package:novel_app/controllers/genre_controller.dart';
import 'package:novel_app/screens/module_repository_screen.dart';
import 'package:novel_app/controllers/style_controller.dart';
import 'package:novel_app/services/character_type_service.dart';
import 'package:novel_app/services/character_card_service.dart';
import 'package:novel_app/screens/character_card_list_screen.dart';
import 'package:novel_app/screens/knowledge_base_screen.dart';
import 'package:novel_app/controllers/knowledge_base_controller.dart';
import 'package:novel_app/widgets/common/animated_button.dart';
import 'package:novel_app/widgets/common/animated_card.dart';
import 'package:novel_app/widgets/common/animated_list_tile.dart';
import 'package:novel_app/screens/donate_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NovelController controller = Get.find<NovelController>();
  final ScrollController _outputScrollController = ScrollController();

  @override
  void dispose() {
    _outputScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('岱宗文脉'),
        actions: [
          IconButton(
            icon: const Icon(Icons.build),
            tooltip: '工具广场',
            onPressed: () => Get.toNamed('/tools'),
          ),
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: '模块仓库',
            onPressed: () => Get.to(() => const ModuleRepositoryScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => Get.to(() => const HelpScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Get.to(() => const SettingsScreen()),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
              child: const Text(
                'AI小说生成器',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('我的书库'),
              onTap: () {
                Get.back();
                Get.toNamed('/library');
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('帮助'),
              onTap: () {
                Get.back();
                Get.to(() => const HelpScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('知识库'),
              onTap: () {
                Get.back();
                Get.to(() => KnowledgeBaseScreen());
              },
            ),
            ListTile(
              leading: const Icon(Icons.coffee),
              title: const Text('给我买杯咖啡'),
              onTap: () {
                Get.back();
                Get.to(() => const DonateScreen());
              },
            ),
            const Divider(),
            ListTile(
              leading: Obx(() => Icon(
                themeController.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              )),
              title: const Text('暗黑模式'),
              trailing: Obx(() => Switch(
                value: themeController.isDarkMode,
                onChanged: (_) => themeController.toggleTheme(),
              )),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGeneratorForm(),
              const SizedBox(height: 20),
              _buildGenerationStatus(),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: _buildNovelList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratorForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _TitleInput()),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('导入大纲'),
                  onPressed: () => _showImportOutlineDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGenreSelector(),
            const SizedBox(height: 16),
            _buildKnowledgeBaseToggle(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '创作要求',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCharacterSelector(),
                    const SizedBox(height: 12),
                    _buildTargetReaderSelector(),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '故事背景',
                        hintText: '例如：大学校园，现代都市',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: controller.updateBackground,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '其他要求',
                        hintText: '其他具体要求，如情节发展、特殊设定等',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      onChanged: controller.updateOtherRequirements,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GetX<NovelController>(
              builder: (controller) => DropdownButtonFormField<String>(
                value: controller.style.value,
                decoration: const InputDecoration(
                  labelText: '写作风格',
                ),
                items: Get.find<StyleController>().styles
                    .map((style) => DropdownMenuItem(
                          value: style.name,
                          child: Text(style.name),
                        ))
                    .toList(),
                onChanged: (value) => controller.updateStyle(value!),
              ),
            ),
            const SizedBox(height: 16),
            GetX<NovelController>(
              builder: (controller) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('短篇小说'),
                          subtitle: const Text('生成1万到2万字的短篇'),
                          value: controller.isShortNovel.value,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (value) => controller.toggleShortNovel(value ?? false),
                        ),
                      ),
                    ],
                  ),
                  if (controller.isShortNovel.value) ...[
                    Row(
                      children: [
                        const Text('字数：', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Slider(
                            value: controller.shortNovelWordCount.value.toDouble(),
                            min: 10000,
                            max: 20000,
                            divisions: 100,
                            label: '${(controller.shortNovelWordCount.value / 1000).toStringAsFixed(1)}万字',
                            onChanged: (value) =>
                                controller.updateShortNovelWordCount(value.toInt()),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              suffix: Text('字'),
                            ),
                            controller: TextEditingController(
                              text: controller.shortNovelWordCount.value.toString(),
                            ),
                            onSubmitted: (value) {
                              final wordCount = int.tryParse(value);
                              if (wordCount != null && wordCount >= 10000 && wordCount <= 20000) {
                                controller.updateShortNovelWordCount(wordCount);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Text('章节数量：', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Slider(
                            value: controller.totalChaptersRx.value.toDouble(),
                            min: 1,
                            max: 1000,
                            divisions: 999,
                            label: controller.totalChaptersRx.value.toString(),
                            onChanged: (value) =>
                                controller.updateTotalChapters(value.toInt()),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                              suffix: Text('章'),
                            ),
                            controller: TextEditingController(
                              text: controller.totalChaptersRx.value.toString(),
                            ),
                            onSubmitted: (value) {
                              final chapters = int.tryParse(value);
                              if (chapters != null && chapters > 0) {
                                controller.updateTotalChapters(chapters);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Builder(
                  builder: (context) => Obx(() {
                    if (controller.isGenerating.value) {
                      if (controller.isPaused.value) {
                        return AnimatedButton(
                          onPressed: controller.checkAndContinueGeneration,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.play_arrow),
                              const SizedBox(width: 8),
                              const Text('继续生成'),
                            ],
                          ),
                        );
                      } else {
                        return AnimatedButton(
                          onPressed: controller.stopGeneration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stop),
                              const SizedBox(width: 8),
                              const Text('停止生成'),
                            ],
                          ),
                        );
                      }
                    } else {
                      return AnimatedButton(
                        onPressed: controller.startGeneration,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow),
                            const SizedBox(width: 8),
                            const Text('开始生成'),
                          ],
                        ),
                      );
                    }
                  }),
                ),
                Builder(
                  builder: (context) => ElevatedButton.icon(
                    onPressed: () {
                      controller.startNewNovel();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('开始新小说'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showImportOutlineDialog(BuildContext context) {
    final textController = TextEditingController();
    final RxBool isAnalyzing = false.obs;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入大纲', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请输入您的小说大纲，支持多种格式：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 标准章节格式（第X章：标题）\n'
              '• 数字编号格式（1. 标题 或 1、标题）\n'
              '• 英文格式（Chapter 1: 标题）\n'
              '• 自由文本格式（会自动分章）',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              '系统将自动识别章节和标题，无需特定格式',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Obx(() => Stack(
                children: [
                  TextField(
                    controller: textController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: '在此粘贴或输入您的小说大纲...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    enabled: !isAnalyzing.value,
                  ),
                  if (isAnalyzing.value)
                    Container(
                      height: 240, // 设置合适的高度，与TextField的maxLines对应
                      alignment: Alignment.center,
                      color: Colors.black.withOpacity(0.05),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('正在解析大纲格式...',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('这可能需要几秒钟时间',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                ],
              )),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          Obx(() => ElevatedButton(
            onPressed: isAnalyzing.value
                ? null
                : () async {
                    if (textController.text.trim().isEmpty) {
                      Get.snackbar('提示', '请输入大纲内容');
                      return;
                    }
                    
                    isAnalyzing.value = true;
                    final result = await controller.importOutline(textController.text);
                    isAnalyzing.value = false;
                    
                    Navigator.pop(context);
                    if (result) {
                      Get.snackbar(
                        '成功', 
                        '大纲导入成功！共 ${controller.currentOutline.value?.chapters.length ?? 0} 章',
                        backgroundColor: Colors.green.shade100,
                        colorText: Colors.green.shade800,
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 3),
                      );
                    }
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                isAnalyzing.value
                    ? Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 8),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check, size: 16),
                const SizedBox(width: 4),
                const Text('智能导入'),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildGenreSelector() {
    final genreController = Get.find<GenreController>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择类型（最多5个）',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => Column(
          children: genreController.categories.map((category) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: category.genres.map((genre) => Obx(() => FilterChip(
                  label: Text(genre.name),
                  selected: controller.selectedGenres.contains(genre.name),
                  onSelected: (_) => controller.toggleGenre(genre.name),
                ))).toList(),
              ),
              const SizedBox(height: 8),
            ],
          )).toList(),
        )),
        Obx(() => controller.selectedGenres.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  '已选类型',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.selectedGenres.map((genre) => Chip(
                    label: Text(genre),
                    onDeleted: () => controller.toggleGenre(genre),
                  )).toList(),
                ),
              ],
            )
          : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildCharacterSelector() {
    final characterTypeService = Get.find<CharacterTypeService>();
    final characterCardService = Get.find<CharacterCardService>();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择角色',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => Column(
          children: characterTypeService.characterTypes.map((type) {
            final isSelected = controller.selectedCharacterTypes.contains(type);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(type.name),
                  leading: CircleAvatar(
                    backgroundColor: Color(int.parse(type.color, radix: 16)),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                  trailing: isSelected
                      ? TextButton(
                          onPressed: () => _showCharacterCardSelector(type),
                          child: Text(
                            controller.selectedCharacterCards[type.id]?.name ?? '选择角色卡片',
                            style: TextStyle(
                              color: controller.selectedCharacterCards[type.id] != null
                                  ? Theme.of(Get.context!).primaryColor
                                  : Colors.grey,
                            ),
                          ),
                        )
                      : null,
                  onTap: () => controller.toggleCharacterType(type),
                ),
                if (isSelected && controller.selectedCharacterCards[type.id] != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                    child: Text(
                      _buildCharacterSummary(controller.selectedCharacterCards[type.id]!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                const Divider(),
              ],
            );
          }).toList(),
        )),
      ],
    );
  }

  String _buildCharacterSummary(CharacterCard card) {
    final parts = <String>[];
    if (card.gender != null && card.gender!.isNotEmpty) {
      parts.add(card.gender!);
    }
    if (card.age != null && card.age!.isNotEmpty) {
      parts.add('${card.age}岁');
    }
    if (card.personalityTraits != null && card.personalityTraits!.isNotEmpty) {
      parts.add(card.personalityTraits!);
    }
    return parts.join(' · ');
  }

  Widget _buildTargetReaderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '目标读者',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('男性向'),
                value: '男性向',
                groupValue: controller.targetReader.value,
                onChanged: (value) => controller.updateTargetReader(value!),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('女性向'),
                value: '女性向',
                groupValue: controller.targetReader.value,
                onChanged: (value) => controller.updateTargetReader(value!),
              ),
            ),
          ],
        )),
      ],
    );
  }

  void _showCharacterCardSelector(CharacterType type) {
    final characterCardService = Get.find<CharacterCardService>();
    
    Get.dialog(
      AlertDialog(
        title: Text('选择${type.name}角色卡片'),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            final cards = characterCardService.getAllCards();
            if (cards.isEmpty) {
              return const Center(
                child: Text('还没有创建角色卡片'),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return ListTile(
                  title: Text(card.name),
                  subtitle: Text(_buildCharacterSummary(card)),
                  onTap: () {
                    controller.setCharacterCard(type.id, card);
                    Get.back();
                  },
                );
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.to(() => CharacterCardListScreen());
            },
            child: const Text('创建新角色'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationStatus() {
    return GetX<NovelController>(
      builder: (controller) {
        if (!controller.isGenerating.value) {
          return const SizedBox();
        }
        return Card(
          elevation: 4.0,
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '生成进度',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('正在生成', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: controller.generationProgress.value,
                  minHeight: 8,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.generationStatus.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '实时输出:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Obx(() {
                    // 当输出内容更新时，滚动到底部
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_outputScrollController.hasClients) {
                        _outputScrollController.jumpTo(
                          _outputScrollController.position.maxScrollExtent,
                        );
                      }
                    });
                    
                    return SingleChildScrollView(
                      controller: _outputScrollController,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        controller.realtimeOutput.value.isEmpty 
                            ? '等待生成内容...' 
                            : controller.realtimeOutput.value,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNovelList() {
    return GetX<NovelController>(
      builder: (controller) {
        if (controller.novels.isEmpty) {
          return const Center(
            child: Text('还没有生成任何小说'),
          );
        }
        return ListView.builder(
          itemCount: controller.novels.length,
          itemBuilder: (context, index) {
            final novel = controller.novels[index];
            return AnimatedCard(
              onTap: () => Get.to(() => NovelDetailScreen(novel: novel)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                novel.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                novel.genre,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开始新小说'),
        content: const Text('这将清除所有已生成的内容和设置，确定要开始新小说吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              controller.startNewNovel();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 添加知识库开关
  Widget _buildKnowledgeBaseToggle() {
    final knowledgeBaseController = Get.find<KnowledgeBaseController>();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '知识库辅助',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Obx(() => Switch(
                  value: knowledgeBaseController.useKnowledgeBase.value,
                  onChanged: (value) {
                    knowledgeBaseController.useKnowledgeBase.value = value;
                    knowledgeBaseController.saveSettings();
                    if (value && knowledgeBaseController.selectedDocIds.isEmpty) {
                      Get.to(() => KnowledgeBaseScreen());
                    }
                  },
                )),
              ],
            ),
            Obx(() {
              if (!knowledgeBaseController.useKnowledgeBase.value) {
                return const SizedBox.shrink();
              }
              
              final selectedCount = knowledgeBaseController.selectedDocIds.length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedCount > 0 
                          ? '已选择 $selectedCount 个知识文档' 
                          : '未选择知识文档',
                        style: TextStyle(
                          color: selectedCount > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('管理'),
                        onPressed: () => Get.to(() => KnowledgeBaseScreen()),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TitleInput extends StatefulWidget {
  @override
  _TitleInputState createState() => _TitleInputState();
}

class _TitleInputState extends State<_TitleInput> {
  late final TextEditingController _titleController;
  final NovelController _novelController = Get.find<NovelController>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _novelController.title.value);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_titleController.text != _novelController.title.value) {
        _titleController.text = _novelController.title.value;
      }
      return TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          labelText: '小说标题',
          hintText: '请输入小说标题',
        ),
        onChanged: _novelController.updateTitle,
      );
    });
  }
} 