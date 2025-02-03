import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementService extends GetxService {
  static const String _lastAnnouncementIdKey = 'last_announcement_id';
  final announcement = Rxn<Announcement>();
  
  // 当前公告
  final currentAnnouncement = Announcement(
    id: '2025012101',
    title: '系统更新公告',
    content: '''
尊敬的用户：

我们很高兴地通知您，小说生成器已完成重要更新：

1. 新功能
强烈建议使用通义千问模型，章节内容重复会得到极大改善
想添加什么功能以及建议，请随时在店铺和小红书联系我。问题一般一天内都会解决。
解决不了，可以申请仅退款，后台极速同意。
目前是一天一更新哈哈


3. 注意事项
   - 目前Gemini模型仍然无法使用，请耐心等待
   - 请在设置页面配置正确的API密钥
   - 建议定期备份重要的创作内容
   - 如遇问题请及时反馈

感谢您的支持！
''',
    date: DateTime.now(),
    isImportant: true,
  );

  @override
  void onInit() {
    super.onInit();
    initAnnouncement();
  }

  Future<void> initAnnouncement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastAnnouncementId = prefs.getString(_lastAnnouncementIdKey);
      print('Last announcement ID: $lastAnnouncementId');
      print('Current announcement ID: ${currentAnnouncement.id}');
      
      // 如果没有显示过当前公告，或者公告ID不同，则显示公告
      if (lastAnnouncementId != currentAnnouncement.id) {
        print('Setting new announcement');
        announcement.value = currentAnnouncement;
      } else {
        print('No new announcement to show');
      }
    } catch (e) {
      print('Error initializing announcement: $e');
      // 如果出现错误，也显示公告
      announcement.value = currentAnnouncement;
    }
  }

  Future<void> init() async {
    await initAnnouncement();
  }

  Future<void> markAnnouncementAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastAnnouncementIdKey, currentAnnouncement.id);
      print('Marked announcement as read: ${currentAnnouncement.id}');
      announcement.value = null;
    } catch (e) {
      print('Error marking announcement as read: $e');
    }
  }
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final bool isImportant;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    this.isImportant = false,
  });
} 