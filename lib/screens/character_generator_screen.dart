import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/models/character_card.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:novel_app/services/character_generator_service.dart';
import 'package:novel_app/services/character_type_service.dart';
import 'package:novel_app/controllers/genre_controller.dart';
import 'package:novel_app/screens/character_card_edit_screen.dart';

class CharacterGeneratorScreen extends StatefulWidget {
  const CharacterGeneratorScreen({Key? key}) : super(key: key);

  @override
  State<CharacterGeneratorScreen> createState() => _CharacterGeneratorScreenState();
}

class _CharacterGeneratorScreenState extends State<CharacterGeneratorScreen> {
  final CharacterGeneratorService _generatorService = Get.find<CharacterGeneratorService>();
  final CharacterTypeService _typeService = Get.find<CharacterTypeService>();
  final GenreController _genreController = Get.find<GenreController>();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _backgroundController = TextEditingController();
  
  final RxList<CharacterType> _selectedTypes = <CharacterType>[].obs;
  final RxString _selectedGenre = ''.obs;
  final RxInt _characterCount = 3.obs;
  final RxBool _isGenerating = false.obs;
  final RxList<CharacterCard> _generatedCharacters = <CharacterCard>[].obs;
  
  @override
  void dispose() {
    _titleController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色生成器'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGenerationForm(),
            const SizedBox(height: 24),
            Obx(() => _isGenerating.value
                ? const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在生成角色，请稍候...'),
                      ],
                    ),
                  )
                : _generatedCharacters.isEmpty
                    ? const Center(
                        child: Text('点击"生成角色"按钮开始生成'),
                      )
                    : _buildGeneratedCharactersList()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGenerationForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '角色生成设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '小说标题',
                hintText: '请输入小说标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '小说类型',
                border: OutlineInputBorder(),
              ),
              value: _selectedGenre.value.isEmpty && _genreController.genres.isNotEmpty
                  ? _genreController.genres[0].name
                  : _selectedGenre.value,
              items: _genreController.genres.map((genre) {
                return DropdownMenuItem(
                  value: genre.name,
                  child: Text(genre.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _selectedGenre.value = value;
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _backgroundController,
              decoration: const InputDecoration(
                labelText: '故事背景',
                hintText: '描述故事的世界观、时代背景等',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            const Text('选择角色类型:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _typeService.characterTypes.map((type) {
                return Obx(() => FilterChip(
                  label: Text(type.name),
                  selected: _selectedTypes.any((t) => t.id == type.id),
                  onSelected: (selected) {
                    if (selected) {
                      _selectedTypes.add(type);
                    } else {
                      _selectedTypes.removeWhere((t) => t.id == type.id);
                    }
                  },
                ));
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('生成角色数量: '),
                Expanded(
                  child: Obx(() => Slider(
                    value: _characterCount.value.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: _characterCount.value.toString(),
                    onChanged: (value) => _characterCount.value = value.toInt(),
                  )),
                ),
                Obx(() => Text(_characterCount.value.toString())),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generateCharacters,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('生成角色'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGeneratedCharactersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '已生成 ${_generatedCharacters.length} 个角色',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => _generatedCharacters.clear(),
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._generatedCharacters.map((character) => _buildCharacterCard(character)),
      ],
    );
  }
  
  Widget _buildCharacterCard(CharacterCard character) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  character.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: '编辑',
                      onPressed: () => Get.to(() => CharacterCardEditScreen(card: character)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: '删除',
                      onPressed: () => _removeCharacter(character),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            _buildCharacterInfoSection('基本信息', [
              if (character.gender != null && character.gender!.isNotEmpty) '性别: ${character.gender}',
              if (character.age != null && character.age!.isNotEmpty) '年龄: ${character.age}',
              if (character.race != null && character.race!.isNotEmpty) '种族: ${character.race}',
            ]),
            _buildCharacterInfoSection('性格特点', [
              if (character.personalityTraits != null && character.personalityTraits!.isNotEmpty)
                character.personalityTraits!,
            ]),
            _buildCharacterInfoSection('背景故事', [
              if (character.background != null && character.background!.isNotEmpty)
                character.background!,
            ]),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Get.to(() => CharacterCardEditScreen(card: character)),
                child: const Text('查看详情'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCharacterInfoSection(String title, List<String> items) {
    if (items.isEmpty || items.every((item) => item.isEmpty)) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...items.map((item) => Text(item)),
        const SizedBox(height: 8),
      ],
    );
  }
  
  void _generateCharacters() async {
    if (_titleController.text.isEmpty) {
      Get.snackbar('错误', '请输入小说标题');
      return;
    }
    
    if (_selectedGenre.value.isEmpty) {
      Get.snackbar('错误', '请选择小说类型');
      return;
    }
    
    _isGenerating.value = true;
    
    try {
      final characters = await _generatorService.generateCharacters(
        title: _titleController.text,
        genre: _selectedGenre.value,
        background: _backgroundController.text,
        characterCount: _characterCount.value,
        preferredTypes: _selectedTypes.isEmpty ? null : _selectedTypes,
      );
      
      _generatedCharacters.assignAll(characters);
      
      if (characters.isEmpty) {
        Get.snackbar('提示', '生成角色失败，请重试');
      }
    } catch (e) {
      Get.snackbar('错误', '生成角色时发生错误: $e');
    } finally {
      _isGenerating.value = false;
    }
  }
  
  void _removeCharacter(CharacterCard character) {
    _generatedCharacters.removeWhere((c) => c.id == character.id);
  }
} 