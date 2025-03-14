import 'dart:io';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/export_platform.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;
import 'export_service_web.dart' if (dart.library.io) 'export_service_io.dart';
import 'package:intl/intl.dart';

class ExportService {
  static const Map<String, String> supportedFormats = {
    'txt': '文本文件 (*.txt)',
    'pdf': 'PDF文档 (*.pdf)',
    'html': '网页文件 (*.html)',
  };

  final ExportPlatform _platform;

  ExportService() : _platform = platform;

  Future<String> exportNovel(Novel novel, String format, {List<Chapter>? selectedChapters}) async {
    try {
      final chapters = selectedChapters ?? novel.chapters;
      if (chapters.isEmpty) {
        return '没有可导出的章节';
      }

      // 生成内容
      final content = _generateContent(novel, chapters, format);

      // 使用平台特定的导出方法
      if (format == 'pdf' && kIsWeb) {
        return '网页版暂不支持PDF导出';
      }

      return await _platform.exportContent(content, format, novel.title);
    } catch (e) {
      return '导出失败：$e';
    }
  }

  String _generateContent(Novel novel, List<Chapter> chapters, String format) {
    final buffer = StringBuffer();
    
    // 添加标题和元信息
    buffer.writeln('《${novel.title}》\n');
    buffer.writeln('作者：AI创作');
    buffer.writeln('创建时间：${DateFormat('yyyy-MM-dd HH:mm:ss').format(novel.createdAt)}\n');
    buffer.writeln('=' * 50 + '\n');
    
    // 添加目录
    buffer.writeln('目录\n');
    for (final chapter in chapters) {
      buffer.writeln('第${chapter.number}章：${chapter.title}');
    }
    buffer.writeln('\n' + '=' * 50 + '\n');
    
    // 添加章节内容
    for (final chapter in chapters) {
      buffer.writeln('\n第${chapter.number}章：${chapter.title}\n');
      buffer.writeln('-' * 30 + '\n');
      buffer.writeln(chapter.content);
      buffer.writeln('\n' + '=' * 50 + '\n');
    }
    
    return buffer.toString();
  }

  // 以下方法仅在非Web平台使用
  Future<Directory> _getExportDirectory() async {
    if (kIsWeb) throw UnsupportedError('Web平台不支持此操作');
    // 这里需要在实际使用时导入 path_provider
    throw UnimplementedError('需要在具体平台实现中定义');
  }

  Future<String> _exportToTxt(
    Directory directory,
    String fileName,
    Novel novel,
    List<Chapter> chapters,
  ) async {
    if (kIsWeb) throw UnsupportedError('Web平台不支持此操作');
    
    final file = File(path.join(directory.path, '$fileName.txt'));
    final content = _generateContent(novel, chapters, 'txt');
    await file.writeAsString(content);
    return '已导出到：${file.path}';
  }

  Future<String> _exportToPdf(
    Directory directory,
    String fileName,
    Novel novel,
    List<Chapter> chapters,
  ) async {
    if (kIsWeb) throw UnsupportedError('Web平台不支持此操作');
    
    final pdf = pw.Document();

    // 添加封面页
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                novel.title,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('创建时间：${novel.createTime}'),
            ],
          ),
        ),
      ),
    );

    // 添加目录页
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('目录', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            ...chapters.map((chapter) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text('第${chapter.number}章：${chapter.title}'),
            )),
          ],
        ),
      ),
    );

    // 添加章节内容
    for (final chapter in chapters) {
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '第${chapter.number}章：${chapter.title}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text(chapter.content),
            ],
          ),
        ),
      );
    }

    final file = File(path.join(directory.path, '$fileName.pdf'));
    await file.writeAsBytes(await pdf.save());
    return '已导出到：${file.path}';
  }

  Future<String> _exportToHtml(
    Directory directory,
    String fileName,
    Novel novel,
    List<Chapter> chapters,
  ) async {
    if (kIsWeb) throw UnsupportedError('Web平台不支持此操作');
    
    final content = _generateContent(novel, chapters, 'html');
    final file = File(path.join(directory.path, '$fileName.html'));
    await file.writeAsString(content);
    return '已导出到：${file.path}';
  }
} 