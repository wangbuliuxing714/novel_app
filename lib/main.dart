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
import 'package:novel_app/screens/character_type/character_type_screen.dart';
import 'package:novel_app/screens/library/library_screen.dart';
import 'package:novel_app/screens/tts/tts_screen.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:novel_app/services/novel_generator_service.dart';
import 'package:novel_app/services/content_review_service.dart';
import 'package:novel_app/services/announcement_service.dart';
import 'package:novel_app/screens/announcement_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_app/services/cache_service.dart';
import 'package:novel_app/controllers/theme_controller.dart';
import 'package:novel_app/controllers/genre_controller.dart';
import 'package:novel_app/controllers/style_controller.dart';
import 'package:novel_app/services/character_card_service.dart';
import 'package:novel_app/services/character_type_service.dart';
import 'package:novel_app/adapters/novel_adapter.dart';
import 'package:novel_app/adapters/chapter_adapter.dart';
import 'package:novel_app/controllers/tts_controller.dart';
import 'package:novel_app/screens/tools/tools_screen.dart';
import 'package:novel_app/screens/novel_continue/novel_continue_screen.dart';
import 'package:novel_app/services/prompt_package_service.dart';
import 'package:novel_app/controllers/prompt_package_controller.dart';
import 'package:novel_app/services/character_generator_service.dart';
import 'package:novel_app/services/background_generator_service.dart';
import 'package:novel_app/controllers/knowledge_base_controller.dart';
import 'package:novel_app/screens/import_screen.dart';
import 'package:novel_app/services/license_service.dart';
import 'package:novel_app/screens/license_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();
  
  // 注册 Novel 和 Chapter 适配器
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(NovelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ChapterAdapter());
  }

  // 打开 Hive 盒子
  await Hive.openBox('novels');
  await Hive.openBox('generated_chapters');

  // 初始化SharedPreferences（确保最先初始化）
  final prefs = await SharedPreferences.getInstance();
  Get.put(prefs);
  
  // 初始化主题控制器
  Get.put(ThemeController());
  
  // 初始化服务
  final apiConfig = Get.put(ApiConfigController());
  final aiService = Get.put(AIService(apiConfig));
  final cacheService = Get.put(CacheService(prefs));
  
  // 初始化角色相关服务
  Get.put(CharacterTypeService(prefs));
  Get.put(CharacterCardService(prefs));
  
  // 初始化文本转语音控制器
  Get.put(TTSController());
  
  // 初始化提示词包服务（移到前面）
  await Get.putAsync(() => PromptPackageService().init());
  final promptPackageController = Get.put(PromptPackageController());
  
  // 先初始化基础服务
  Get.put(NovelGeneratorService(aiService, cacheService, apiConfig));
  Get.put(ContentReviewService(aiService, apiConfig, cacheService));
  
  // 然后初始化控制器
  Get.put(NovelController());
  Get.put(GenreController());
  Get.put(StyleController());
  
  // 初始化角色生成服务和背景生成服务
  Get.put(CharacterGeneratorService(
    aiService, 
    Get.find<CharacterCardService>(), 
    Get.find<CharacterTypeService>(),
    promptPackageController
  ));
  
  // 初始化背景生成服务
  Get.put(BackgroundGeneratorService(aiService, promptPackageController));
  
  // 初始化知识库控制器
  Get.put(KnowledgeBaseController());
  
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
    final licenseService = Get.put(LicenseService());
    await licenseService.init();
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
        GetPage(name: '/', page: () => HomeScreen()),
        GetPage(name: '/storage', page: () => StorageScreen()),
        GetPage(name: '/chapter_detail', page: () => ChapterDetailScreen()),
        GetPage(name: '/chapter_edit', page: () => ChapterEditScreen()),
        GetPage(name: '/library', page: () => LibraryScreen()),
        GetPage(name: '/character_type', page: () => CharacterTypeScreen()),
        GetPage(name: '/tools', page: () => ToolsScreen()),
        GetPage(name: '/tts', page: () => TTSScreen()),
        GetPage(name: '/import', page: () => ImportScreen()),
        GetPage(
          name: '/novel_continue',
          page: () => NovelContinueScreen(novel: Get.arguments),
        ),
      ],
    );
  }
}