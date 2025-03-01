import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/services/background_generator_service.dart';
import 'package:novel_app/controllers/genre_controller.dart';
import 'package:novel_app/widgets/common/loading_overlay.dart';

class BackgroundGeneratorScreen extends StatefulWidget {
  const BackgroundGeneratorScreen({Key? key}) : super(key: key);

  @override
  _BackgroundGeneratorScreenState createState() => _BackgroundGeneratorScreenState();
}

class _BackgroundGeneratorScreenState extends State<BackgroundGeneratorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _initialIdeaController = TextEditingController();
  
  final RxString _selectedGenre = ''.obs;
  final RxBool _isDetailed = false.obs;
  final RxBool _isGenerating = false.obs;
  final RxString _generatedBackground = ''.obs;
  
  final BackgroundGeneratorService _backgroundGeneratorService = Get.find<BackgroundGeneratorService>();
  final GenreController _genreController = Get.find<GenreController>();
  
  @override
  void initState() {
    super.initState();
    if (_genreController.genres.isNotEmpty) {
      _selectedGenre.value = _genreController.genres.first.name;
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _initialIdeaController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('故事背景生成器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _generatedBackground.value.isEmpty
                ? null
                : () {
                    // 保存生成的背景到剪贴板
                    Get.snackbar('成功', '背景已复制到剪贴板');
                  },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isGenerating.value,
        loadingText: '正在生成背景...',
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGenerationForm(),
              const SizedBox(height: 16),
              _buildGeneratedContent(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGenerationForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '背景生成设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '小说标题',
                border: OutlineInputBorder(),
                hintText: '请输入小说标题',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '小说类型',
                border: OutlineInputBorder(),
              ),
              value: _selectedGenre.value.isEmpty && _genreController.genres.isNotEmpty
                  ? _genreController.genres.first.name
                  : _selectedGenre.value,
              items: _genreController.genres.map((genre) {
                return DropdownMenuItem<String>(
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
              controller: _initialIdeaController,
              decoration: const InputDecoration(
                labelText: '初始构想（可选）',
                border: OutlineInputBorder(),
                hintText: '请输入你的初始构想或关键元素',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Obx(() => SwitchListTile(
              title: const Text('生成详细背景'),
              subtitle: const Text('开启后将生成更详细的世界观设定'),
              value: _isDetailed.value,
              onChanged: (value) {
                _isDetailed.value = value;
              },
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _generateBackground,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('生成背景'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGeneratedContent() {
    return Expanded(
      child: Obx(() {
        if (_generatedBackground.value.isEmpty) {
          return const Center(
            child: Text(
              '生成的背景将显示在这里',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          );
        }
        
        return Card(
          elevation: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '生成的背景',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  _generatedBackground.value,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
  
  Future<void> _generateBackground() async {
    // 验证输入
    if (_titleController.text.isEmpty) {
      Get.snackbar('错误', '请输入小说标题');
      return;
    }
    
    if (_selectedGenre.value.isEmpty) {
      Get.snackbar('错误', '请选择小说类型');
      return;
    }
    
    // 开始生成
    _isGenerating.value = true;
    
    try {
      final background = await _backgroundGeneratorService.generateBackground(
        title: _titleController.text,
        genre: _selectedGenre.value,
        initialIdea: _initialIdeaController.text,
        isDetailed: _isDetailed.value,
      );
      
      _generatedBackground.value = background;
    } catch (e) {
      Get.snackbar('错误', '生成背景失败: $e');
    } finally {
      _isGenerating.value = false;
    }
  }
} 