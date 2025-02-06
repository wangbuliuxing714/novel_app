import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/screens/home/home_screen.dart';
import 'package:novel_app/screens/storage/storage_screen.dart';
import 'package:novel_app/screens/chapter_detail/chapter_detail_screen.dart';
import 'package:novel_app/screens/chapter_edit/chapter_edit_screen.dart';
import 'package:novel_app/screens/draft/draft_screen.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/services/novel_generator_service.dart';
import 'package:novel_app/models/prompt_template.dart';
import 'package:novel_app/services/content_review_service.dart';
import 'package:novel_app/services/announcement_service.dart';
import 'package:novel_app/screens/announcement_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/cache_service.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/theme_controller.dart';
import 'package:novel_app/controllers/draft_controller.dart';
import 'package:novel_app/services/license_service.dart';
import 'package:novel_app/screens/license_screen.dart';
import 'package:novel_app/controllers/genre_controller.dart';
import 'package:novel_app/screens/genre_manager_screen.dart';
import 'package:novel_app/controllers/style_controller.dart';
import 'package:novel_app/controllers/outline_prompt_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();

  // 初始化SharedPreferences（确保最先初始化）
  final prefs = await SharedPreferences.getInstance();
  Get.put(prefs);
  
  // 初始化主题控制器
  Get.put(ThemeController());
  
  // 初始化服务
  final apiConfig = Get.put(ApiConfigController());
  final aiService = Get.put(AIService(apiConfig));
  final cacheService = Get.put(CacheService(prefs));
  
  // 先初始化OutlinePromptController
  final outlinePromptController = OutlinePromptController();
  await outlinePromptController.init();
  Get.put(outlinePromptController);
  
  // 然后初始化其他依赖服务
  Get.put(NovelGeneratorService(aiService, apiConfig, cacheService));
  Get.put(ContentReviewService(aiService, apiConfig, cacheService));
  Get.put(NovelController());
  Get.put(DraftController());
  Get.put(GenreController());
  Get.put(StyleController());
  
  // 初始化公告服务
  final announcementService = Get.put(AnnouncementService());
  await announcementService.init();
  
  // 直接检查是否有公告需要显示
  if (announcementService.announcement.value != null) {
    print('有新公告需要显示');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        AnnouncementScreen(announcement: announcementService.announcement.value!),
        barrierDismissible: false,
      );
    });
  } else {
    print('没有新公告需要显示');
  }

  // 只在Web平台初始化许可证服务
  if (kIsWeb) {
    final licenseService = LicenseService();
    await licenseService.init();
    Get.put(licenseService);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'AI小说生成器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: kIsWeb  // 只在Web平台检查许可证
          ? Obx(() {
              final licenseService = Get.find<LicenseService>();
              return licenseService.isLicensed.value
                  ? const HomeScreen()  // 已激活许可证，显示主页
                  : LicenseScreen();    // 未激活许可证，显示激活页面
            })
          : const HomeScreen(),  // 非Web平台直接显示主页
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const HomeScreen()),
        GetPage(name: '/storage', page: () => StorageScreen()),
        GetPage(name: '/chapter_detail', page: () => ChapterDetailScreen()),
        GetPage(name: '/chapter_edit', page: () => ChapterEditScreen()),
        GetPage(name: '/draft', page: () => DraftScreen()),
      ],
    );
  }
}