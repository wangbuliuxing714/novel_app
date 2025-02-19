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

class HomeScreen extends GetView<NovelController> {
  const HomeScreen({super.key});

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
              leading: const Icon(Icons.edit_note),
              title: const Text('草稿本'),
              onTap: () {
                Get.back();
                Get.toNamed('/draft');
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
                  onPressed: () => _showImportOutlineDialog(Get.context!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGenreSelector(),
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
              builder: (controller) => Row(
                children: [
                  const Text('章节数量：', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Slider(
                      value: controller.totalChapters.value.toDouble(),
                      min: 1,
                      max: 1000,
                      divisions: 999,
                      label: controller.totalChapters.value.toString(),
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
                        text: controller.totalChapters.value.toString(),
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
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Builder(
                  builder: (context) => Obx(() {
                    if (controller.isGenerating.value) {
                      if (controller.isPaused.value) {
                        return ElevatedButton.icon(
                          onPressed: controller.checkAndContinueGeneration,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('继续生成'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        );
                      } else {
                        return ElevatedButton.icon(
                          onPressed: controller.stopGeneration,
                          icon: const Icon(Icons.pause),
                          label: const Text('暂停生成'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        );
                      }
                    } else {
                      return ElevatedButton.icon(
                        onPressed: controller.startGeneration,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('开始生成'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      );
                    }
                  }),
                ),
                Builder(
                  builder: (context) => ElevatedButton.icon(
                    onPressed: () {
                      _showDialog(context);
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
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入大纲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: '''请输入JSON格式的大纲，例如：
{
  "novel_title": "小说标题",
  "chapters": [
    {
      "chapter_number": 1,
      "chapter_title": "第一章",
      "content_outline": "章节大纲内容"
    }
  ]
}''',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final result = await controller.importOutline(textController.text);
              Navigator.pop(context);
              if (result) {
                Get.snackbar('成功', '大纲导入成功');
              }
            },
            child: const Text('导入'),
          ),
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '生成进度',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: controller.generationProgress.value,
                ),
                const SizedBox(height: 8),
                Text(controller.generationStatus.value),
                const SizedBox(height: 16),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Obx(() => SingleChildScrollView(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      controller.realtimeOutput.value,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  )),
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
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(novel.title),
                subtitle: Text('${novel.genre} · ${novel.createTime}'),
                trailing: Text('${novel.wordCount}字'),
                onTap: () => Get.to(() => NovelDetailScreen(novel: novel)),
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