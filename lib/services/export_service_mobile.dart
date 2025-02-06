import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:novel_app/models/novel.dart';

abstract class ExportPlatform {
  Future<String> exportContent(String content, String format, String? title);
  Future<String> exportEpub(List<Chapter> chapters, String? title);
}

ExportPlatform createExportPlatform() => MobileExportPlatform();

class MobileExportPlatform implements ExportPlatform {
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      if (deviceInfo.version.sdkInt <= 29) {
        final status = await Permission.storage.request();
        return status.isGranted;
      } else {
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  Future<Directory?> _getExportDirectory() async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download/AINovel');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    }
    return await getApplicationDocumentsDirectory();
  }

  @override
  Future<String> exportContent(String content, String format, String? title) async {
    if (!await _requestStoragePermission()) {
      return '无法获取存储权限，导出失败';
    }

    final directory = await _getExportDirectory();
    if (directory == null) {
      return '无法获取存储目录，导出失败';
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${title ?? '小说'}_$timestamp.$format';
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');

      await file.writeAsString(content, encoding: const SystemEncoding());
      
      return '文件已导出到：${file.path}\n\n你可以在手机的"下载"文件夹中的"AINovel"目录找到导出的小说文件。';
    } catch (e) {
      return '导出失败：$e';
    }
  }

  @override
  Future<String> exportEpub(List<Chapter> chapters, String? title) async {
    // TODO: 实现EPUB格式导出
    throw UnimplementedError('EPUB格式导出功能尚未实现');
  }
} 