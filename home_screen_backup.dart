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
import 'package:novel_app/screens/license_screen.dart';
import 'package:novel_app/screens/tts_screen.dart';
import 'package:novel_app/screens/prompt_package_list_screen.dart';
import 'package:novel_app/screens/tools_screen.dart';
import 'package:novel_app/screens/character_generator_screen.dart';
import 'package:novel_app/screens/background_generator_screen.dart';

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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Get.to(() => const SettingsScreen());
                  break;
                case 'reset':
                  controller.startNewNovel();
                  break;
                case 'adjust_detail_level':
                  _showDetailLevelDialog(context);
                  break;
                case 'licenses':
                  Get.to(() => LicenseScreen());
                  break;
                case 'tts':
                  Get.to(() => TTSScreen());
                  break;
                case 'prompt_packages':
                  Get.to(() => PromptPackageListScreen());
                  break;
                case 'tools':
                  Get.to(() => ToolsScreen());
                  break;
                case 'character_generator':
                  Get.to(() => CharacterGeneratorScreen());
                  break;
                case 'background_generator':
                  Get.to(() => BackgroundGeneratorScreen());
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('设置'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('重置表单'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'adjust_detail_level',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('调整细节程度'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'licenses',
                child: ListTile(
                  leading: Icon(Icons.verified_user),
                  title: Text('许可证'),
                ),
              ),
            ],
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
              SizedBox(
                child: Row(
                  children: [
                    Expanded(child: _TitleInput()),
                  ],
                ),
              ),
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

  void _showDetailLevelDialog(BuildContext context) {
    // Detail level dialog implementation
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