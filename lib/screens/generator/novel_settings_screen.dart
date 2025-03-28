import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/style_controller.dart';
import 'package:novel_app/controllers/genre_controller.dart';
import 'package:novel_app/services/character_type_service.dart';
import 'package:novel_app/services/character_card_service.dart';
import 'package:novel_app/models/character_card.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:novel_app/controllers/knowledge_base_controller.dart';
import 'package:novel_app/screens/knowledge_base_screen.dart';

class NovelSettingsScreen extends StatefulWidget {
  const NovelSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NovelSettingsScreen> createState() => _NovelSettingsScreenState();
}

class _NovelSettingsScreenState extends State<NovelSettingsScreen> {
  final NovelController _novelController = Get.find<NovelController>();
  final StyleController _styleController = Get.find<StyleController>();
  final GenreController _genreController = Get.find<GenreController>();
  final CharacterTypeService _characterTypeService = Get.find<CharacterTypeService>();
  final CharacterCardService _characterCardService = Get.find<CharacterCardService>();
  final KnowledgeBaseController _knowledgeBaseController = Get.find<KnowledgeBaseController>();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _backgroundController = TextEditingController();
  final TextEditingController _specialRequirementsController = TextEditingController();
  
  final RxList<String> _selectedGenres = <String>[].obs;
  final RxList<CharacterType> _selectedCharacterTypes = <CharacterType>[].obs;
  final RxList<CharacterCard> _selectedCharacterCards = <CharacterCard>[].obs;
  final RxString _selectedStyle = ''.obs;
  final RxInt _totalChapters = 5.obs;
  final RxBool _useOutline = true.obs;
  
  // 添加短篇小说相关变量
  final RxBool _isShortNovel = false.obs;
  final RxInt _shortNovelWordCount = 15000.obs;
  
  @override
  void initState() {
    super.initState();
    _titleController.text = _novelController.currentNovelTitle;
    _backgroundController.text = _novelController.currentNovelBackground;
    _specialRequirementsController.text = _novelController.specialRequirements.join('\n');
    
    _selectedGenres.value = _novelController.selectedGenres.toList();
    _selectedCharacterTypes.value = _novelController.selectedCharacterTypes.toList();
    _selectedCharacterCards.value = _novelController.selectedCharacterCards.toList();
    _selectedStyle.value = _novelController.selectedStyle;
    _totalChapters.value = _novelController.totalChapters;
    _useOutline.value = _novelController.isUsingOutline.value;
    
    // 初始化短篇小说设置
    _isShortNovel.value = _novelController.isShortNovel.value;
    _shortNovelWordCount.value = _novelController.shortNovelWordCount.value;
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _backgroundController.dispose();
    _specialRequirementsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBasicSettingsSection(),
            const SizedBox(height: 16),
            _buildChaptersSection(),
            const SizedBox(height: 16),
            _buildGenreSection(),
            const SizedBox(height: 16),
            _buildStyleSection(),
            const SizedBox(height: 16),
            _buildCharacterSection(),
            const SizedBox(height: 16),
            _buildKnowledgeBaseSection(),
            const SizedBox(height: 16),
            _buildAdvancedSettingsSection(),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _saveSettings,
              child: const Text('保存设置'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBasicSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('基本设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '小说标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _backgroundController,
              decoration: const InputDecoration(
                labelText: '故事背景',
                border: OutlineInputBorder(),
                hintText: '描述故事的世界观、时代背景等',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // 添加短篇小说选项
            Row(
              children: [
                Obx(() => Switch(
                  value: _isShortNovel.value,
                  onChanged: (value) => _isShortNovel.value = value,
                )),
                const Text('生成短篇小说'),
                const Tooltip(
                  message: '启用后，将生成一篇1万到2万字的短篇小说，而不是分章节的长篇小说',
                  child: Icon(Icons.info_outline, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 根据短篇小说选项显示不同的设置
            Obx(() => _isShortNovel.value 
              ? Column(
                  children: [
                    Row(
                      children: [
                        const Text('短篇字数: '),
                        Expanded(
                          child: Slider(
                            value: _shortNovelWordCount.value.toDouble(),
                            min: 10000,
                            max: 20000,
                            divisions: 10,
                            label: '${(_shortNovelWordCount.value / 10000).toStringAsFixed(1)}万字',
                            onChanged: (value) => _shortNovelWordCount.value = value.toInt(),
                          ),
                        ),
                        Text('${(_shortNovelWordCount.value / 10000).toStringAsFixed(1)}万字'),
                      ],
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        const Text('章节数量: '),
                        Expanded(
                          child: Slider(
                            value: _totalChapters.value.toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: _totalChapters.value.toString(),
                            onChanged: (value) => _totalChapters.value = value.toInt(),
                          ),
                        ),
                        Text(_totalChapters.value.toString()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _useOutline.value,
                          onChanged: (value) => _useOutline.value = value ?? true,
                        ),
                        const Text('使用大纲生成'),
                        const Tooltip(
                          message: '启用后，系统会先生成大纲再生成章节内容；禁用后，系统会直接生成章节内容',
                          child: Icon(Icons.info_outline, size: 16),
                        ),
                      ],
                    ),
                  ],
                )
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChaptersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('章节设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Obx(() => _isShortNovel.value 
              ? Column(
                  children: [
                    Row(
                      children: [
                        const Text('短篇字数: '),
                        Expanded(
                          child: Slider(
                            value: _shortNovelWordCount.value.toDouble(),
                            min: 10000,
                            max: 20000,
                            divisions: 10,
                            label: '${(_shortNovelWordCount.value / 10000).toStringAsFixed(1)}万字',
                            onChanged: (value) => _shortNovelWordCount.value = value.toInt(),
                          ),
                        ),
                        Text('${(_shortNovelWordCount.value / 10000).toStringAsFixed(1)}万字'),
                      ],
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        const Text('章节数量: '),
                        Expanded(
                          child: Slider(
                            value: _totalChapters.value.toDouble(),
                            min: 1,
                            max: 20,
                            divisions: 19,
                            label: _totalChapters.value.toString(),
                            onChanged: (value) => _totalChapters.value = value.toInt(),
                          ),
                        ),
                        Text(_totalChapters.value.toString()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _useOutline.value,
                          onChanged: (value) => _useOutline.value = value ?? true,
                        ),
                        const Text('使用大纲生成'),
                        const Tooltip(
                          message: '启用后，系统会先生成大纲再生成章节内容；禁用后，系统会直接生成章节内容',
                          child: Icon(Icons.info_outline, size: 16),
                        ),
                      ],
                    ),
                  ],
                )
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGenreSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('小说类型', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _genreController.genres.map((genre) {
                return Obx(() => FilterChip(
                  label: Text(genre.name),
                  selected: _selectedGenres.contains(genre.name),
                  onSelected: (selected) {
                    if (selected) {
                      _selectedGenres.add(genre.name);
                    } else {
                      _selectedGenres.remove(genre.name);
                    }
                  },
                ));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStyleSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('写作风格', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Obx(() => DropdownButtonFormField<String>(
              value: _selectedStyle.value.isEmpty ? _styleController.styles[0].name : _selectedStyle.value,
              decoration: const InputDecoration(
                labelText: '选择写作风格',
                border: OutlineInputBorder(),
              ),
              items: _styleController.styles.map((style) {
                return DropdownMenuItem(
                  value: style.name,
                  child: Text(style.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _selectedStyle.value = value;
                }
              },
            )),
            const SizedBox(height: 8),
            Obx(() {
              final style = _styleController.styles.firstWhere(
                (s) => s.name == (_selectedStyle.value.isEmpty ? _styleController.styles[0].name : _selectedStyle.value),
                orElse: () => _styleController.styles[0],
              );
              return Text('描述: ${style.description}');
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCharacterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('角色设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('选择角色类型:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _characterTypeService.characterTypes.map((type) {
                return Obx(() => FilterChip(
                  label: Text(type.name),
                  selected: _selectedCharacterTypes.any((t) => t.id == type.id),
                  onSelected: (selected) {
                    if (selected) {
                      _selectedCharacterTypes.add(type);
                    } else {
                      _selectedCharacterTypes.removeWhere((t) => t.id == type.id);
                    }
                  },
                ));
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('选择角色卡片:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _characterCardService.getAllCards().map((card) {
                return Obx(() => FilterChip(
                  label: Text(card.name),
                  selected: _selectedCharacterCards.any((c) => c.id == card.id),
                  onSelected: (selected) {
                    if (selected) {
                      _selectedCharacterCards.add(card);
                    } else {
                      _selectedCharacterCards.removeWhere((c) => c.id == card.id);
                    }
                  },
                ));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildKnowledgeBaseSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('知识库设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.library_books),
                  label: const Text('管理知识库'),
                  onPressed: () => Get.to(() => KnowledgeBaseScreen()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Obx(() => SwitchListTile(
              title: const Text('使用知识库'),
              subtitle: const Text('使用已有知识库内容辅助生成'),
              value: _knowledgeBaseController.useKnowledgeBase.value,
              onChanged: (value) {
                _knowledgeBaseController.useKnowledgeBase.value = value;
                _knowledgeBaseController.saveSettings();
              },
            )),
            
            // 仅当启用知识库时显示选择区域
            Obx(() {
              if (!_knowledgeBaseController.useKnowledgeBase.value) {
                return const SizedBox.shrink();
              }
              
              if (_knowledgeBaseController.documents.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('暂无知识文档，请先添加知识文档'),
                );
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text('选择参考的知识库文档:'),
                  ),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _knowledgeBaseController.documents.map((doc) {
                      return Obx(() => FilterChip(
                        label: Text(doc.title.length > 15 
                            ? '${doc.title.substring(0, 15)}...' 
                            : doc.title),
                        selected: _knowledgeBaseController.selectedDocIds.contains(doc.id),
                        onSelected: (selected) {
                          _knowledgeBaseController.toggleDocumentSelection(doc.id);
                        },
                      ));
                    }).toList(),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: const Text('清除选择'),
                          onPressed: () {
                            _knowledgeBaseController.clearSelection();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAdvancedSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('高级设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _specialRequirementsController,
              decoration: const InputDecoration(
                labelText: '特殊要求',
                border: OutlineInputBorder(),
                hintText: '每行一个特殊要求，例如：\n主角必须是女性\n故事必须有反转\n结局必须是悲剧',
              ),
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
  }
  
  void _saveSettings() {
    // 保存设置到控制器
    _novelController.setNovelTitle(_titleController.text);
    _novelController.setNovelBackground(_backgroundController.text);
    _novelController.setSpecialRequirements(
      _specialRequirementsController.text.split('\n').where((line) => line.trim().isNotEmpty).toList()
    );
    
    _novelController.setSelectedGenres(_selectedGenres);
    _novelController.setSelectedCharacterTypes(_selectedCharacterTypes);
    _novelController.setSelectedCharacterCards(_selectedCharacterCards);
    _novelController.setSelectedStyle(_selectedStyle.value);
    _novelController.setTotalChapters(_totalChapters.value);
    _novelController.setUsingOutline(_useOutline.value);
    
    // 保存短篇小说设置
    _novelController.toggleShortNovel(_isShortNovel.value);
    _novelController.updateShortNovelWordCount(_shortNovelWordCount.value);
    
    Get.back();
    Get.snackbar('成功', '设置已保存');
  }
} 