import 'package:novel_app/models/novel.dart';

abstract class ExportPlatform {
  Future<String> exportContent(String content, String format, String fileName);
  Future<String> exportEpub(List<Chapter> chapters, String? title);
} 