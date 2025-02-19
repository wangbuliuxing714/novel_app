import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/export_platform.dart';

class IOExportPlatform implements ExportPlatform {
  @override
  Future<String> exportContent(String content, String format, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File(path.join(directory.path, '$fileName.$format'));
      await file.writeAsString(content);
      return '已导出到：${file.path}';
    } catch (e) {
      return '导出失败：$e';
    }
  }

  @override
  Future<String> exportEpub(List<Chapter> chapters, String? title) async {
    try {
      final directory = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeTitle = (title ?? '小说').replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = '${safeTitle}_$timestamp.txt';
      
      final buffer = StringBuffer();
      buffer.writeln('《$safeTitle》\n');
      buffer.writeln('创建时间：${DateTime.now().toString().split('.')[0]}\n');
      buffer.writeln('=' * 50 + '\n');
      
      for (var chapter in chapters) {
        buffer.writeln('\n第${chapter.number}章');
        buffer.writeln('-' * 30 + '\n');
        buffer.writeln(chapter.content);
        buffer.writeln('\n' + '=' * 50 + '\n');
      }

      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(buffer.toString());
      return '已导出到：${file.path}';
    } catch (e) {
      print('导出失败: $e');
      return '导出失败：$e';
    }
  }

  Future<Directory> _getExportDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(path.join(appDir.path, 'exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }
}

ExportPlatform createExportPlatform() {
  if (kIsWeb) throw UnsupportedError('此实现仅支持原生平台');
  return IOExportPlatform();
}

// 导出平台实现
ExportPlatform get platform => createExportPlatform(); 