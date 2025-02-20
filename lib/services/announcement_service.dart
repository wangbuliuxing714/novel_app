import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementService extends GetxService {
  static const String _lastAnnouncementIdKey = 'last_announcement_id';
  final announcement = Rxn<Announcement>();
  
  // 当前公告
  final currentAnnouncement = Announcement(
    id: '20250220',
    title: '系统功能更新公告',
    content: '''
尊敬的用户：

我们很高兴地通知您，岱宗文脉已完成重要功能更新：

1. 新增功能
   - 小说内容编辑功能

2. 功能优化
   - 大幅优化了AI生成的内容质量，同学说是番茄风格[狗头]
   - 修复了大纲导入会生成不相关内容的问题
   - 降低了大纲导入门槛


3. 使用建议
   - 推荐使用通义千问模型，便宜，记忆好
   - API配置说明请在网盘中查看
   - 建议定期导出备份重要内容
   - 如遇问题请及时在店铺或小红书联系我们

4. 注意事项
   - 如果出现生成质量问题，请切换几个模型试试，或者调整提示词，确认不是这两个问题，请在售后群及时反馈
   - 之前购买的，没加售后群的店铺私信
   - 请确保正确配置API密钥
   - 音频转换功能需要配置硅基流动API
   - 由于考研备考，更新进度缓慢，请见谅


如有任何问题或建议，欢迎随时反馈！
我们会持续优化功能，提供更好的创作体验。

感谢您的支持与信任！
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