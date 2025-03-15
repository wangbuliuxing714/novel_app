import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:novel_app/models/novel.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:gbk_codec/gbk_codec.dart';

class ImportService {
  // 支持的导入格式
  static const List<String> supportedFormats = [
    'txt', 'json'
  ];
  
  // 请求必要的权限
  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true;
    
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    
    return true;
  }
  
  // 选择要导入的文件
  Future<(Uint8List, String)?> pickFileBytes() async {
    try {
      if (!kIsWeb && !await _requestPermissions()) {
        throw Exception('未获得存储权限');
      }
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedFormats,
        dialogTitle: '选择要导入的小说文件',
        withData: true, // 确保获取文件内容
      );
      
      if (result == null || result.files.isEmpty) return null;
      
      final file = result.files.single;
      
      // 获取文件扩展名
      String extension = '';
      if (file.extension != null) {
        extension = file.extension!.toLowerCase();
      } else if (file.name.contains('.')) {
        extension = file.name.split('.').last.toLowerCase();
      } else {
        throw Exception('无法确定文件类型');
      }
      
      // 确保文件内容可用
      if (file.bytes == null) {
        throw Exception('无法获取文件内容');
      }
      
      return (file.bytes!, extension);
    } catch (e) {
      print('选择文件失败: $e');
      rethrow;
    }
  }
  
  // 解析TXT数据为小说对象
  Future<Novel?> _parseTxtBytes(Uint8List bytes) async {
    try {
      // 尝试以UTF-8解码
      String content;
      try {
        content = utf8.decode(bytes);
      } catch (e) {
        // 如果UTF-8解码失败，尝试以GB18030解码（中文环境常用）
        try {
          content = gbk.decode(bytes);
        } catch (e) {
          // 如果还是失败，返回一个默认值
          content = '无法解析文件内容，可能是编码问题';
          print('文件解码失败: $e');
        }
      }
      
      final lines = content.split('\n');
      
      String title = '导入的小说';
      String genre = '其他';
      String outline = '导入的小说大纲';
      String novelContent = content;
      final List<Chapter> chapters = [];
      
      // 提取标题
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].startsWith('《') && lines[i].endsWith('》')) {
          title = lines[i].substring(1, lines[i].length - 1);
          break;
        }
      }
      
      // 提取章节
      final chapterRegex = RegExp(r'第(\d+)章：(.+)');
      String currentChapterTitle = '';
      int currentChapterNumber = 0;
      List<String> currentChapterContent = [];
      
      for (int i = 0; i < lines.length; i++) {
        final match = chapterRegex.firstMatch(lines[i]);
        
        if (match != null) {
          // 如果已经有章节在处理，则保存
          if (currentChapterNumber > 0) {
            chapters.add(Chapter(
              number: currentChapterNumber,
              title: currentChapterTitle,
              content: currentChapterContent.join('\n'),
            ));
            currentChapterContent = [];
          }
          
          currentChapterNumber = int.parse(match.group(1)!);
          currentChapterTitle = match.group(2)!;
        } else if (currentChapterNumber > 0) {
          // 跳过章节标题后的分隔线
          if (lines[i].startsWith('-' * 10)) continue;
          // 跳过章节末尾的分隔线
          if (lines[i].startsWith('=' * 10)) continue;
          
          currentChapterContent.add(lines[i]);
        }
      }
      
      // 保存最后一个章节
      if (currentChapterNumber > 0) {
        chapters.add(Chapter(
          number: currentChapterNumber,
          title: currentChapterTitle,
          content: currentChapterContent.join('\n'),
        ));
      }
      
      // 如果没有章节，创建一个默认章节
      if (chapters.isEmpty) {
        chapters.add(Chapter(
          number: 1,
          title: '第1章',
          content: content,
        ));
      }
      
      return Novel(
        title: title,
        genre: genre,
        outline: outline,
        content: novelContent,
        chapters: chapters,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('解析TXT文件失败: $e');
      return null;
    }
  }
  
  // 解析JSON数据为小说对象
  Future<Novel?> _parseJsonBytes(Uint8List bytes) async {
    try {
      final content = utf8.decode(bytes);
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      return Novel.fromJson(json);
    } catch (e) {
      print('解析JSON文件失败: $e');
      return null;
    }
  }
  
  // 导入小说
  Future<Novel?> importNovel() async {
    try {
      final fileData = await pickFileBytes();
      if (fileData == null) return null;
      
      final (bytes, extension) = fileData;
      
      switch (extension) {
        case 'txt':
          return await _parseTxtBytes(bytes);
        case 'json':
          return await _parseJsonBytes(bytes);
        default:
          throw Exception('不支持的文件格式：$extension');
      }
    } catch (e) {
      print('导入小说失败: $e');
      rethrow;
    }
  }
} 