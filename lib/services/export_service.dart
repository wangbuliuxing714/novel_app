import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:novel_app/models/novel.dart';

class ExportService {
  static const Map<String, String> supportedFormats = {
    'txt': '纯文本文件 (.txt)',
    'md': 'Markdown文件 (.md)',
    'html': '网页文件 (.html)',
    'epub': '电子书文件 (.epub)',
  };

  Future<String> exportChapters(List<Chapter> chapters, String format, {String? title}) async {
    final directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
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
      return '文件已导出到：${file.path}';
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