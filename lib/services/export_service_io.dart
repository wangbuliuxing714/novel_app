import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/export_platform.dart';
import 'package:file_picker/file_picker.dart';

class IOExportPlatform implements ExportPlatform {
  @override
  Future<String> exportContent(String content, String format, String fileName) async {
    try {
      // 让用户选择保存位置
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存位置',
      );

      if (selectedDirectory == null) {
        return '导出已取消';
      }

      final file = File(path.join(selectedDirectory, '$fileName.$format'));
      await file.writeAsString(content);
      return '已导出到：${file.path}';
    } catch (e) {
      return '导出失败：$e';
    }
  }

  @override
  Future<String> exportEpub(List<Chapter> chapters, String? title) async {
    try {
      // 让用户选择保存位置
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存位置',
      );

      if (selectedDirectory == null) {
        return '导出已取消';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeTitle = (title ?? '小说').replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = '${safeTitle}_$timestamp.txt';
      
      final buffer = StringBuffer();
      buffer.writeln('《$safeTitle》\n');
      buffer.writeln('创建时间：${DateTime.now().toString().split('.')[0]}\n');
      buffer.writeln('=' * 50 + '\n');
      
      for (var chapter in chapters) {
        buffer.writeln('\n第${chapter.number}章：${chapter.title}');
        buffer.writeln('-' * 30 + '\n');
        buffer.writeln(chapter.content);
        buffer.writeln('\n' + '=' * 50 + '\n');
      }

      final file = File(path.join(selectedDirectory, fileName));
      await file.writeAsString(buffer.toString());
      return '已导出到：${file.path}';
    } catch (e) {
      print('导出失败: $e');
      return '导出失败：$e';
    }
  }
}

ExportPlatform createExportPlatform() {
  if (kIsWeb) throw UnsupportedError('此实现仅支持原生平台');
  return IOExportPlatform();
}

// 导出平台实现
ExportPlatform get platform => createExportPlatform(); 