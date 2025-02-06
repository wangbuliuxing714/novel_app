import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:novel_app/models/novel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ExportService {
  static const Map<String, String> supportedFormats = {
    'txt': '纯文本文件 (.txt)',
    'md': 'Markdown文件 (.md)',
    'html': '网页文件 (.html)',
    'epub': '电子书文件 (.epub)',
  };

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt <= 29) {
        // Android 10 及以下版本需要存储权限
        final status = await Permission.storage.request();
        return status.isGranted;
      } else {
        // Android 11 及以上版本需要管理所有文件的权限
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  Future<Directory?> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // 使用公共下载目录
      final directory = Directory('/storage/emulated/0/Download/AINovel');
      // 确保目录存在
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
    // 如果不是 Android 平台，使用应用文档目录
    return await getApplicationDocumentsDirectory();
  }

  Future<String> exportChapters(List<Chapter> chapters, String format, {String? title}) async {
    // 首先请求权限
    if (!await _requestStoragePermission()) {
      return '无法获取存储权限，导出失败';
    }

    // 获取导出目录
    final directory = await _getExportDirectory();
    if (directory == null) {
      return '无法获取存储目录，导出失败';
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${title ?? '小说'}_$timestamp.$format';
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');

    try {
      String content = '';
      
      switch (format) {
        case 'txt':
          content = _generateTxtContent(chapters, title);
          break;
        case 'md':
          content = _generateMarkdownContent(chapters, title);
          break;
        case 'html':
          content = _generateHtmlContent(chapters, title);
          break;
        case 'epub':
          return await _generateEpub(chapters, title, directory.path, fileName);
        default:
          throw Exception('不支持的文件格式：$format');
      }

      await file.writeAsString(content, encoding: const SystemEncoding());
      
      // 返回文件的完整路径和更友好的提示
      return '文件已导出到：${file.path}\n\n你可以在手机的"下载"文件夹中的"AINovel"目录找到导出的小说文件。';
    } catch (e) {
      return '导出失败：$e';
    }
  }

  String _generateTxtContent(List<Chapter> chapters, String? title) {
    final buffer = StringBuffer();
    
    if (title != null) {
      buffer.writeln(title);
      buffer.writeln('=' * 30);
      buffer.writeln();
    }

    for (final chapter in chapters) {
      buffer.writeln('第${chapter.number}章：${chapter.title}');
      buffer.writeln();
      buffer.writeln(chapter.content);
      buffer.writeln();
      buffer.writeln('=' * 30);
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _generateMarkdownContent(List<Chapter> chapters, String? title) {
    final buffer = StringBuffer();
    
    if (title != null) {
      buffer.writeln('# $title');
      buffer.writeln();
    }

    for (final chapter in chapters) {
      buffer.writeln('## 第${chapter.number}章：${chapter.title}');
      buffer.writeln();
      buffer.writeln(chapter.content);
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _generateHtmlContent(List<Chapter> chapters, String? title) {
    final buffer = StringBuffer();
    
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html>');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="utf-8">');
    buffer.writeln('<title>${title ?? '小说'}</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { max-width: 800px; margin: 0 auto; padding: 20px; font-family: sans-serif; line-height: 1.6; }');
    buffer.writeln('h1 { text-align: center; }');
    buffer.writeln('h2 { margin-top: 2em; }');
    buffer.writeln('.chapter { margin-bottom: 2em; }');
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    if (title != null) {
      buffer.writeln('<h1>$title</h1>');
    }

    for (final chapter in chapters) {
      buffer.writeln('<div class="chapter">');
      buffer.writeln('<h2>第${chapter.number}章：${chapter.title}</h2>');
      buffer.writeln('<div class="content">');
      buffer.writeln(chapter.content.replaceAll('\n', '<br>'));
      buffer.writeln('</div>');
      buffer.writeln('</div>');
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  Future<String> _generateEpub(List<Chapter> chapters, String? title, String path, String fileName) async {
    // TODO: 实现EPUB格式导出
    // 这里需要添加EPUB生成的具体实现
    // 可以使用第三方库如epub_generator
    throw UnimplementedError('EPUB格式导出功能尚未实现');
  }
} 