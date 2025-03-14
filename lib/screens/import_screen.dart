import 'package:flutter/material.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/services/import_service.dart';
import 'package:get/get.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final ImportService _importService = ImportService();
  final NovelController _novelController = Get.find<NovelController>();
  
  bool _isLoading = false;
  String _statusMessage = '';
  Novel? _importedNovel;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入小说'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '导入小说功能说明：',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 支持导入TXT和JSON格式的小说文件\n'
              '2. TXT格式需要符合导出格式（标题、章节格式）\n'
              '3. JSON格式必须符合系统导出的JSON结构\n'
              '4. 导入成功后可在小说库中查看',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _importNovel,
              icon: const Icon(Icons.upload_file),
              label: const Text('选择文件导入'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 24),
            
            // 导入状态和结果
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在导入小说，请稍候...'),
                  ],
                ),
              ),
              
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _importedNovel != null ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _importedNovel != null ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_importedNovel != null) ...[
                      const SizedBox(height: 16),
                      Text('标题: ${_importedNovel!.title}'),
                      Text('章节数: ${_importedNovel!.chapters.length}'),
                      Text('总字数: ${_importedNovel!.wordCount}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // 可以跳转到小说详情页
                        },
                        child: const Text('查看小说'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _importNovel() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = '';
        _importedNovel = null;
      });
      
      final novel = await _importService.importNovel();
      
      if (novel == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = '导入取消或文件无效';
        });
        return;
      }
      
      // 保存到数据库
      await _novelController.saveNovel(novel);
      
      setState(() {
        _isLoading = false;
        _importedNovel = novel;
        _statusMessage = '小说导入成功！';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '导入失败: $e';
      });
    }
  }
} 