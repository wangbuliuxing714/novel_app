import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:novel_app/models/novel.dart';

class WebExportPlatform {
  Future<String> exportContent(String content, String format, String? title) async {
    if (!kIsWeb) {
      throw UnsupportedError('此方法仅支持Web平台');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeTitle = (title ?? '小说').replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final fileName = '${safeTitle}_$timestamp.$format';
      
      // 根据格式处理内容
      String processedContent = content;
      if (format == 'html') {
        processedContent = _generateHtml(title ?? '小说', content);
      } else if (format == 'md') {
        processedContent = _generateMarkdown(title ?? '小说', content);
      }

      // 返回下载链接
      return 'data:${_getMimeType(format)},${Uri.encodeComponent(processedContent)}';
    } catch (e) {
      print('导出失败: $e');
      return '导出失败：$e';
    }
  }

  String _generateHtml(String title, String content) {
    return '''
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
    <style>
        body {
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            font-family: "Microsoft YaHei", "PingFang SC", sans-serif;
            line-height: 1.8;
            background-color: #f5f5f5;
            color: #333;
        }
        h1 {
            text-align: center;
            color: #2c3e50;
            margin: 30px 0;
            font-size: 2em;
        }
        .chapter {
            background-color: white;
            padding: 30px;
            margin: 20px 0;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        p {
            text-indent: 2em;
            margin: 1em 0;
            font-size: 1.1em;
            line-height: 1.8;
        }
        @media (max-width: 600px) {
            body {
                padding: 15px;
            }
            .chapter {
                padding: 20px;
            }
        }
    </style>
</head>
<body>
    <h1>$title</h1>
    <div class="chapter">
    ${content.split('\n').map((p) => p.trim().isEmpty ? '' : '<p>${_escapeHtml(p)}</p>').join('\n')}
    </div>
</body>
</html>
''';
  }

  String _generateMarkdown(String title, String content) {
    return '''# $title

${content.split('\n').map((p) => p.trim().isEmpty ? '' : p).join('\n\n')}
''';
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  Future<String> exportEpub(List<Chapter> chapters, String? title) async {
    if (!kIsWeb) {
      throw UnsupportedError('此方法仅支持Web平台');
    }

    try {
      final buffer = StringBuffer();
      final safeTitle = (title ?? '小说').replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      // 添加标题页
      buffer.writeln('《$safeTitle》\n');
      buffer.writeln('创建时间：${DateTime.now().toString().split('.')[0]}\n');
      buffer.writeln('=' * 50 + '\n');
      
      // 添加章节内容
      for (var chapter in chapters) {
        buffer.writeln('\n第${chapter.number}章');
        buffer.writeln('-' * 30 + '\n');
        buffer.writeln(chapter.content);
        buffer.writeln('\n' + '=' * 50 + '\n');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${safeTitle}_$timestamp.txt';
      
      // 返回下载链接
      return 'data:text/plain;charset=utf-8,${Uri.encodeComponent(buffer.toString())}';
    } catch (e) {
      print('导出失败: $e');
      return '导出失败：$e';
    }
  }

  String _getMimeType(String format) {
    switch (format.toLowerCase()) {
      case 'txt':
        return 'text/plain;charset=utf-8';
      case 'md':
        return 'text/markdown;charset=utf-8';
      case 'html':
        return 'text/html;charset=utf-8';
      default:
        return 'text/plain;charset=utf-8';
    }
  }
} 