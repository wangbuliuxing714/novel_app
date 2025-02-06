import 'dart:html' as html;
import 'package:novel_app/models/novel.dart';

abstract class ExportPlatform {
  Future<String> exportContent(String content, String format, String? title);
  Future<String> exportEpub(List<Chapter> chapters, String? title);
}

ExportPlatform createExportPlatform() => WebExportPlatform();

class WebExportPlatform implements ExportPlatform {
  @override
  Future<String> exportContent(String content, String format, String? title) async {
    try {
      String mimeType = _getMimeType(format);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${title ?? '小说'}_$timestamp.$format';
      
      // 创建Blob对象
      final blob = html.Blob([content], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // 创建下载链接并触发下载
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      
      // 清理URL
      html.Url.revokeObjectUrl(url);
      
      return '文件已开始下载';
    } catch (e) {
      return '导出失败：$e';
    }
  }

  @override
  Future<String> exportEpub(List<Chapter> chapters, String? title) async {
    throw Exception('Web版暂不支持EPUB格式导出');
  }

  String _getMimeType(String format) {
    switch (format) {
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'html':
        return 'text/html';
      default:
        return 'application/octet-stream';
    }
  }
} 