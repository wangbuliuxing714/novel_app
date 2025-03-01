import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/models/export_platform.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class IOExportPlatform implements ExportPlatform {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  Future<bool> _requestNativePermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        if (sdkInt >= 33) { // Android 13 及以上
          // 请求媒体权限
          final photos = await Permission.photos.request();
          final videos = await Permission.videos.request();
          final audio = await Permission.audio.request();
          
          if (!photos.isGranted || !videos.isGranted || !audio.isGranted) {
            print('媒体权限被拒绝');
            return false;
          }
        } else if (sdkInt >= 30) { // Android 11-12
          // 请求管理所有文件权限
          if (!await Permission.manageExternalStorage.request().isGranted) {
            print('管理所有文件权限被拒绝');
            return false;
          }
        } else { // Android 10 及以下
          // 请求基本存储权限
          final storage = await Permission.storage.request();
          if (!storage.isGranted) {
            print('存储权限被拒绝');
            return false;
          }
        }
        return true;
      }
      return true;
    } catch (e) {
      print('请求权限失败: $e');
      return false;
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final sdkInt = androidInfo.version.sdkInt;
        
        if (sdkInt >= 33) {
          if (!await Permission.photos.isGranted ||
              !await Permission.videos.isGranted ||
              !await Permission.audio.isGranted) {
            return await _requestNativePermissions();
          }
        } else if (sdkInt >= 30) {
          if (!await Permission.manageExternalStorage.isGranted) {
            return await _requestNativePermissions();
          }
        } else {
          if (!await Permission.storage.isGranted) {
            return await _requestNativePermissions();
          }
        }
        return true;
      }
      return true;
    } catch (e) {
      print('检查权限失败: $e');
      return false;
    }
  }

  Future<bool> _requestBatteryOptimization() async {
    try {
      if (Platform.isAndroid) {
        if (await Permission.ignoreBatteryOptimizations.request().isGranted) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('请求电池优化失败: $e');
      return false;
    }
  }

  @override
  Future<String> exportContent(String content, String format, String fileName) async {
    try {
      // 检查并请求权限
      if (!await _checkAndRequestPermissions()) {
        return '导出失败：未获得存储权限。请在系统设置中授予应用存储权限。';
      }

      // 请求忽略电池优化
      await _requestBatteryOptimization();

      // 直接使用默认导出目录
      final directory = await _getDefaultExportDirectory();
      
      try {
        // 确保目录存在
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final file = File(path.join(directory.path, '$fileName.$format'));
        await file.writeAsString(content, flush: true);
        
        print('文件已保存到: ${file.path}');
        return '已导出到：${file.path}';
      } catch (e) {
        print('写入文件失败: $e');
        return '导出失败：无法写入文件，请检查存储权限和可用空间';
      }
    } catch (e) {
      print('导出错误: $e');
      return '导出失败：$e';
    }
  }

  Future<Directory> _getDefaultExportDirectory() async {
    if (Platform.isAndroid) {
      try {
        final directory = Directory('/storage/emulated/0/Download/岱宗文脉');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      } catch (e) {
        print('无法访问外部存储，使用应用专属目录: $e');
        final appDir = await getApplicationDocumentsDirectory();
        final directory = Directory('${appDir.path}/exports');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      }
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      final directory = Directory('${appDir.path}/exports');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
  }

  @override
  Future<String> exportEpub(List<Chapter> chapters, String? title) async {
    try {
      // 请求权限
      if (!await _requestNativePermissions()) {
        return '导出失败：未获得存储权限';
      }

      // 请求忽略电池优化
      await _requestBatteryOptimization();

      final directory = await _getDefaultExportDirectory();
      
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

      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(buffer.toString(), flush: true);
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