import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:novel_app/models/novel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as path;

class ExportService {
  static const Map<String, String> supportedFormats = {
    'txt': '文本文件 (*.txt)',
    'pdf': 'PDF文档 (*.pdf)',
    'html': '网页文件 (*.html)',
  };

  Future<String> exportNovel(Novel novel, String format, {List<Chapter>? selectedChapters}) async {
    try {
      final chapters = selectedChapters ?? novel.chapters;
      if (chapters.isEmpty) {
        return '没有可导出的章节';
      }

      final directory = await _getExportDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${novel.title}_$timestamp';

      switch (format) {
        case 'txt':
          return await _exportToTxt(directory, fileName, novel, chapters);
        case 'pdf':
          return await _exportToPdf(directory, fileName, novel, chapters);
        case 'html':
          return await _exportToHtml(directory, fileName, novel, chapters);
        default:
          return '不支持的导出格式';
      }
    } catch (e) {
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

  Future<String> _exportToTxt(
    Directory directory,
    String fileName,
    Novel novel,
    List<Chapter> chapters,
  ) async {
    final file = File(path.join(directory.path, '$fileName.txt'));
    final buffer = StringBuffer();

    // 写入小说标题
    buffer.writeln('《${novel.title}》');
    buffer.writeln('\n');

    // 写入章节内容
    for (final chapter in chapters) {
      buffer.writeln('第${chapter.number}章：${chapter.title}');
      buffer.writeln('\n');
      buffer.writeln(chapter.content);
      buffer.writeln('\n\n');
    }

    await file.writeAsString(buffer.toString());
    return '已导出到：${file.path}';
  }

  Future<String> _exportToPdf(
    Directory directory,
    String fileName,
    Novel novel,
    List<Chapter> chapters,
  ) async {
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
    final buffer = StringBuffer();

    // 写入HTML头部
    buffer.write('''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>${novel.title}</title>
        <style>
          body { max-width: 800px; margin: 0 auto; padding: 20px; line-height: 1.6; }
          h1 { text-align: center; margin: 2em 0; }
          .chapter { margin: 2em 0; }
          .chapter-title { font-size: 1.5em; font-weight: bold; margin: 1em 0; }
          .chapter-content { text-indent: 2em; }
        </style>
      </head>
      <body>
        <h1>${novel.title}</h1>
    ''');

    // 写入目录
    buffer.write('''
      <div class="toc">
        <h2>目录</h2>
        <ul>
    ''');

    for (final chapter in chapters) {
      buffer.write(
        '<li><a href="#chapter-${chapter.number}">第${chapter.number}章：${chapter.title}</a></li>'
      );
    }

    buffer.write('</ul></div>');

    // 写入章节内容
    for (final chapter in chapters) {
      buffer.write('''
        <div class="chapter" id="chapter-${chapter.number}">
          <div class="chapter-title">第${chapter.number}章：${chapter.title}</div>
          <div class="chapter-content">
            ${chapter.content.split('\n').map((p) => '<p>$p</p>').join('\n')}
          </div>
        </div>
      ''');
    }

    // 写入HTML尾部
    buffer.write('</body></html>');

    final file = File(path.join(directory.path, '$fileName.html'));
    await file.writeAsString(buffer.toString());
    return '已导出到：${file.path}';
  }
} 