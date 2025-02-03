# 小说生成器技术文档

## 项目概述

这是一个基于Flutter开发的AI小说生成器应用，支持多个大语言模型API，可以自动生成小说大纲和章节内容。

## 技术栈

- Flutter SDK: >=3.0.0
- 状态管理: GetX (^4.6.5)
- 网络请求: http (^1.1.0)
- 数据持久化: Hive (^2.2.3)
- 文件分享: share_plus (^7.2.1)
- 权限管理: permission_handler (^11.3.0)
- 设备信息: device_info_plus (^9.1.2)

## 核心功能实现

### 1. AI模型集成

#### 支持的模型
- Gemini Pro
- Gemini Flash
- 通义千问
- Deepseek

#### 模型配置管理 (ApiConfigController)
```dart
class ApiConfigController extends GetxController {
  final Rx<AIModel> selectedModel = AIModel.geminiPro.obs;
  final Map<AIModel, ModelConfig> _configs = {
    AIModel.deepseek: ModelConfig(...),
    AIModel.qwen: ModelConfig(...),
    AIModel.geminiPro: ModelConfig(...),
    AIModel.geminiFlash: ModelConfig(...),
  };
}
```

- 使用Hive持久化存储API配置
- 支持动态切换模型
- 每个模型独立的API密钥和URL配置

### 2. 小说生成系统

#### 2.1 数据模型设计

##### Novel 类
```dart
class Novel {
  final String title;        // 小说标题
  final String genre;        // 小说类型
  final String outline;      // 故事大纲
  final List<Chapter> chapters;  // 章节列表
  final DateTime createdAt;  // 创建时间
  
  String get createTime => createdAt.toString().split('.')[0];
  
  // JSON序列化支持
  Map<String, dynamic> toJson() => {
    'title': title,
    'genre': genre,
    'outline': outline,
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };
  
  factory Novel.fromJson(Map<String, dynamic> json) => Novel(
    title: json['title'] as String,
    genre: json['genre'] as String,
    outline: json['outline'] as String,
    chapters: (json['chapters'] as List)
        .map((c) => Chapter.fromJson(c as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
```

##### Chapter 类
```dart
class Chapter {
  final int number;     // 章节序号
  final String title;   // 章节标题
  final String content; // 章节内容
  
  int get index => number - 1;  // 0基序号转换
  
  // JSON序列化支持
  Map<String, dynamic> toJson() => {
    'number': number,
    'title': title,
    'content': content,
  };
}
```

#### 2.2 生成控制器 (NovelController)

```dart
class NovelController extends GetxController {
  // 生成状态管理
  final RxBool isGenerating = false.obs;
  final RxString errorMessage = ''.obs;
  final RxDouble generationProgress = 0.0.obs;
  final RxString generationStatus = '准备生成...'.obs;
  final RxString currentContent = ''.obs;
  
  // 小说列表管理
  final RxList<Novel> novels = <Novel>[].obs;
  
  // 生成参数
  final RxString title = ''.obs;
  final RxList<NovelGenre> selectedGenres = <NovelGenre>[].obs;
  final RxString prompt = ''.obs;
  final RxString style = '硬核爽文'.obs;
  final RxInt totalChapters = 20.obs;
}
```

#### 2.3 生成流程详解

##### 2.3.1 参数准备
```dart
// 组合生成提示词
String _buildPrompt() {
  final genres = selectedGenres.map((g) => g.prompt).join('、');
  return '''
标题：${title.value}
类型：$genres
风格：${style.value}
要求：
1. 符合${style.value}风格
2. 紧凑的剧情发展
3. 合理的人物塑造
4. 吸引人的故事情节
''';
}
```

##### 2.3.2 生成步骤
1. 大纲生成
```dart
// 生成大纲
final outline = await _generateOutline(prompt);
generationProgress.value = 0.1;
generationStatus.value = '大纲生成完成';
```

2. 章节生成
```dart
// 按章节顺序生成
List<Chapter> chapters = [];
for (int i = 0; i < totalChapters.value; i++) {
  final chapter = await _generateChapter(
    outline,
    chapterIndex: i,
    totalChapters: totalChapters.value
  );
  chapters.add(chapter);
  
  // 更新进度
  generationProgress.value = (i + 1) / totalChapters.value;
  generationStatus.value = '正在生成第${i + 1}章';
}
```

3. 实时状态更新
```dart
// 进度更新回调
void onProgress(String status) {
  generationStatus.value = status;
  currentContent.value = status;
  
  // 解析章节进度
  if (status.contains('第')) {
    final currentChapter = int.tryParse(
      status.replaceAll(RegExp(r'[^0-9]'), '')
    ) ?? 0;
    generationProgress.value = currentChapter / (totalChapters.value + 1);
  }
}
```

#### 2.4 AI模型调用

##### 2.4.1 请求格式
```dart
// Gemini Pro 示例
final response = await http.post(
  Uri.parse('${config.apiUrl}/models/gemini-pro:generateContent'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${config.apiKey}',
  },
  body: jsonEncode({
    'contents': [{
      'parts': [{
        'text': prompt
      }]
    }],
    'generationConfig': {
      'temperature': 0.7,
      'maxOutputTokens': 2048,
    },
  }),
);
```

##### 2.4.2 流式响应处理
```dart
Stream<String> generateTextStream(String prompt) async* {
  try {
    final request = http.Request(
      'POST',
      Uri.parse('${config.apiUrl}/models/gemini-pro:streamGenerateContent'),
    );
    
    // 设置请求头和内容
    request.headers['Authorization'] = 'Bearer ${config.apiKey}';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({...});
    
    // 获取响应流
    final response = await _client.send(request);
    
    // 处理响应数据
    await for (final chunk in response.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
      if (chunk.isEmpty) continue;
      
      try {
        final json = jsonDecode(chunk);
        final text = _extractTextFromJson(json);
        if (text.isNotEmpty) {
          yield text;
        }
      } catch (e) {
        print('解析响应出错: $e');
      }
    }
  } catch (e) {
    throw Exception('生成失败: $e');
  }
}
```

#### 2.5 错误处理

##### 2.5.1 生成错误
```dart
try {
  await generateNovel();
} catch (e) {
  errorMessage.value = e.toString();
  generationStatus.value = '生成失败';
} finally {
  isGenerating.value = false;
}
```

##### 2.5.2 重试机制
```dart
Future<T> _withRetry<T>(Future<T> Function() action) async {
  int attempts = 0;
  while (attempts < maxRetries) {
    try {
      return await action();
    } catch (e) {
      attempts++;
      if (attempts >= maxRetries) rethrow;
      await Future.delayed(Duration(seconds: attempts));
    }
  }
  throw Exception('超过最大重试次数');
}
```

#### 2.6 数据持久化

##### 2.6.1 使用Hive存储
```dart
// 保存小说
await _box.put(novel.id, novel.toJson());

// 读取小说列表
final novels = _box.values
    .map((json) => Novel.fromJson(Map<String, dynamic>.from(json)))
    .toList();
```

##### 2.6.2 自动保存
```dart
// 生成完成后自动保存
void _autoSave(Novel novel) {
  novels.add(novel);
  _box.put(novel.id, novel.toJson());
}
```

### 3. 小说管理功能

#### 小说列表显示
- 使用ListView.builder实现高效列表
- 支持小说卡片展示
- 显示基本信息:
  - 标题
  - 类型
  - 创建时间
  - 章节数量

#### 小说详情页面
```dart
class NovelDetailScreen extends StatefulWidget {
  // 使用NavigationRail实现左侧导航
  // 支持大纲和章节两种视图
  // 集成导出和分享功能
}
```

特点:
- 左侧导航栏切换视图
- 大纲视图显示小说信息和完整大纲
- 章节列表使用ExpansionTile实现可折叠效果
- 支持导出和分享功能

### 4. 导出与分享功能

#### 文件导出实现
```dart
Future<void> _exportNovel() async {
  // 1. 请求存储权限
  // 2. 获取存储目录
  // 3. 生成TXT文件
  // 4. 提供分享选项
}
```

#### 权限管理
- 智能判断Android版本:
  ```dart
  Future<bool> _requestStoragePermission() async {
    if (GetPlatform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        // Android 12及以下需要请求权限
        return await Permission.storage.request().isGranted;
      }
    }
    return true;
  }
  ```

- 权限请求流程:
  1. 检查Android版本
  2. 根据版本决定是否请求权限
  3. 处理权限拒绝情况
  4. 提供设置页面跳转

#### 文件生成格式
```
标题: xxx
类型: xxx
创建时间: xxx

大纲:
xxx

第1章 xxx
内容...

第2章 xxx
内容...
```

### 5. UI/UX设计

#### 主要页面结构
1. 首页/小说列表
2. 生成器页面
3. 小说详情页
4. 设置页面

#### 交互设计
- 使用GetX进行页面导航
- 实现平滑的页面过渡
- 提供操作反馈:
  - 加载指示器
  - 进度提示
  - 错误提示
  - 成功反馈

#### 响应式设计
- 使用Obx实现响应式UI更新
- 支持横竖屏适配
- 适配不同尺寸设备

## 数据持久化

### Hive数据库
- 存储API配置
- 缓存生成的小说
- 支持JSON序列化

### 文件存储
- 导出的TXT文件存储在外部存储目录
- 支持文件分享功能

## 错误处理

### API错误
- 网络连接错误处理
- API限流处理
- 超时处理
- 格式错误处理

### 权限错误
- 存储权限处理
- 提供用户引导
- 优雅的降级处理

## 性能优化

### UI性能
- 使用const构造器
- 实现列表懒加载
- 合理使用StatelessWidget
- 避免不必要的重建

### 内存管理
- 及时释放资源
- 处理页面销毁
- 控制图片缓存

## 安全性

### API密钥保护
- 本地加密存储
- 避免明文传输
- 定期更新机制

### 文件安全
- 安全的文件操作
- 权限控制
- 错误处理

## 后续优化方向

1. 支持更多AI模型
2. 添加更多生成参数
3. 优化生成速度
4. 增加批量导出功能
5. 支持更多导出格式
6. 添加编辑功能
7. 云端备份功能
8. 用户系统集成 

## 项目维护记录

### 2024-01-18 项目清理
1. 删除冗余项目目录
   - 移除 `novel_app_code/` - 旧代码备份目录
   - 移除 `novel_app_new/` - 旧项目目录
2. 删除临时文件
   - 移除 `新建 DOCX 文档.docx`
3. 保留文件说明
   - `TECHNICAL.md` - 技术文档
   - `README.md` - 项目说明
   - `安卓版本使用说明.txt` - 安卓版本使用指南 

### 2024-01-18 代码优化
1. API服务整合
   - 删除 `api_service.dart`，统一使用 `deepseek_service.dart`
   - 原因：`deepseek_service.dart` 实现更完善，支持分段生成和更好的字数控制
   - 避免代码重复维护，减少潜在的混淆 

### 2024-01-18 功能增强
1. 内容校对功能
   - 新增 `ContentReviewService` 类，支持内容优化和校对
   - 支持自定义模型选择，默认使用当前选择的模型
   - 实现重试机制和超时处理
   - 优化重点：
     - 爽点优化（情节爽感、装逼打脸效果等）
     - 内容检查（情节连贯性、人物性格等）
     - 文字润色（语言表达、文学性等）
     - 网文元素（装逼打脸、实力提升等）

2. 爽文生成增强
   - 更新 `DeepseekService` 的提示词系统
   - 增加爽文特定要求：
     - 爽点设计（层次感、递进性等）
     - 写作风格（金手指、打脸装逼等）
     - 章节结构（开头吸引、结尾悬念等）
     - 写作技巧（场景细节、对话张力等）
   - 优化生成参数配置 