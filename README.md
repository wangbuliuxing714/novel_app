# AI小说生成器项目文档

## 项目结构

```
novel_app/
├── lib/                    # 主要源代码目录
│   ├── controllers/       # 控制器目录
│   ├── models/           # 数据模型目录
│   ├── prompts/          # AI提示词目录
│   ├── screens/          # 界面目录
│   ├── services/         # 服务目录
│   └── main.dart         # 应用入口文件
```

## 主要目录说明

### 1. controllers/ - 控制器目录
- `api_config_controller.dart`: API配置控制器，管理AI服务的API设置
- `novel_controller.dart`: 小说控制器，管理小说生成的核心逻辑
- `genre_controller.dart`: 类型控制器，管理小说类型和分类
- `style_controller.dart`: 风格控制器，管理写作风格
- `theme_controller.dart`: 主题控制器，管理应用主题
- `draft_controller.dart`: 草稿控制器，管理小说草稿

### 2. models/ - 数据模型目录
- `novel.dart`: 小说模型，定义小说的数据结构
- `character_card.dart`: 角色卡片模型，定义角色的属性和方法
- `character_type.dart`: 角色类型模型，定义角色类型的属性和方法

### 3. prompts/ - AI提示词目录
- `master_prompts.dart`: 主要提示词，定义AI写作的基本原则
- `outline_generation.dart`: 大纲生成相关提示词
- `chapter_generation.dart`: 章节生成相关提示词
- `genre_prompts.dart`: 类型相关提示词
- `character_prompts.dart`: 角色相关提示词

### 4. screens/ - 界面目录
- `home/`: 主页相关界面
- `character_type/`: 角色类型管理界面
- `character_card_list_screen.dart`: 角色卡片列表界面
- `character_card_edit_screen.dart`: 角色卡片编辑界面
- `genre_manager_screen.dart`: 类型管理界面
- `module_repository_screen.dart`: 模块仓库界面

### 5. services/ - 服务目录
- `ai_service.dart`: AI服务，处理与AI API的通信
- `novel_generator_service.dart`: 小说生成服务，处理小说生成的核心逻辑
- `character_type_service.dart`: 角色类型服务，管理角色类型数据
- `character_card_service.dart`: 角色卡片服务，管理角色卡片数据
- `cache_service.dart`: 缓存服务，管理数据缓存
- `content_review_service.dart`: 内容审查服务，检查生成内容的质量

## 小说生成流程

### 1. 用户输入阶段
1. 用户在主界面输入：
   - 小说标题
   - 选择小说类型（最多5个）
   - 选择角色类型和角色卡片
   - 设置章节数量
   - 输入背景设定和其他要求

### 2. 大纲生成阶段
1. `NovelController`调用`NovelGeneratorService`的`generateNovel`方法
2. 系统根据用户输入构建提示词：
   ```dart
   final systemPrompt = OutlineGeneration.getSystemPrompt(title, genre, theme);
   final outlinePrompt = OutlineGeneration.getOutlinePrompt(title, genre, theme, totalChapters);
   ```
3. 分批生成大纲（每批10章）：
   ```dart
   for (int start = 1; start <= totalChapters; start += batchSize) {
     final end = (start + batchSize - 1).clamp(1, totalChapters);
     // 生成大纲内容
   }
   ```

### 3. 章节生成阶段
1. 系统根据生成的大纲，开始逐章生成内容：
   ```dart
   final List<Chapter> chapters = [];
   for (int i = 1; i <= totalChapters; i++) {
     final chapter = await generateChapter(
       title: title,
       number: i,
       outline: outline,
       previousChapters: chapters,  // 传入之前生成的章节
       totalChapters: totalChapters,
       genre: genre,
       theme: theme,
     );
     chapters.add(chapter);
   }
   ```

2. 每个章节的生成过程：
   - 构建章节专用的系统提示词
   - 根据大纲和前文构建用户提示词
   - 动态调整生成参数
   - 生成内容并进行格式化
   - 进行内容审查和质量验证

3. 动态调整生成参数：
   - 根据章节进度调整temperature（创造性）
   - 根据章节长度调整maxTokens（令牌数量）

### 4. 内容审查阶段
1. 检查生成内容的质量：
   - 验证章节长度
   - 检查内容连贯性
   - 检查是否重复
2. 必要时重新生成内容

### 5. 最终处理
1. 将所有生成的内容整合到Novel对象中：
   ```dart
   return Novel(
     title: title,
     genre: genre,
     outline: outline,
     content: chapters.map((c) => c.content).join('\n\n'),
     chapters: chapters,
     createdAt: DateTime.now(),
   );
   ```

2. 保存生成的内容：
   - 将小说保存到本地存储
   - 更新用户界面显示
   - 提供导出和分享功能

## 模块仓库功能

### 1. 类型管理模块
- 功能：管理小说类型和分类
- 实现：
  ```dart
  class GenreController extends GetxController {
    // 添加新分类
    Future<void> addCategory(GenreCategory category) async {
      categories.add(category);
      await _saveCustomGenres();
    }
    
    // 添加新类型
    Future<void> addGenre(int categoryIndex, NovelGenre genre) async {
      // 添加类型实现
    }
  }
  ```

### 2. 角色管理模块
- 功能：管理角色类型和角色卡片
- 实现：
  ```dart
  class CharacterTypeService extends GetxService {
    // 添加角色类型
    Future<void> addCharacterType(CharacterType type) async {
      characterTypes.add(type);
      await _saveToStorage();
    }
  }
  
  class CharacterCardService extends GetxService {
    // 添加角色卡片
    Future<void> addCard(CharacterCard card) async {
      cards.add(card);
      await _saveCards();
    }
  }
  ```

### 3. 写作风格模块
- 功能：管理写作风格和提示词
- 实现：通过`StyleController`管理不同的写作风格和对应的提示词

## 数据存储

### 1. 本地存储
- 使用`SharedPreferences`存储配置和小型数据
- 使用`Hive`存储大型数据（如生成的章节）

### 2. 缓存机制
- 使用`CacheService`管理数据缓存
- 缓存生成的内容以提高性能
- 实现内容查重和验证

## 注意事项

1. 生成过程中的错误处理：
   - 网络错误自动重试
   - 内容生成失败时的回退机制
   - 用户取消操作的处理

2. 性能优化：
   - 分批生成大纲和章节
   - 缓存已生成的内容
   - 异步处理耗时操作

3. 用户体验：
   - 实时显示生成进度
   - 提供生成过程的取消功能
   - 支持断点续传
