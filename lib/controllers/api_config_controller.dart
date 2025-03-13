import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:novel_app/services/ai_service.dart';
import 'package:get_storage/get_storage.dart';

class ModelConfig {
  String name;           // 模型名称
  String apiKey;         // API密钥
  String apiUrl;         // API地址
  String apiPath;        // API路径
  String model;          // 具体模型名称
  List<String> modelVariants; // 模型变体列表（多模型标识符）
  String apiFormat;      // API格式（如OpenAI API兼容等）
  String appId;          // 应用ID（百度千帆等需要）
  bool isCustom;         // 是否为自定义模型
  double temperature;
  double topP;
  int maxTokens;
  double repetitionPenalty; // 添加重复惩罚参数

  ModelConfig({
    required this.name,
    required this.apiKey,
    required this.apiUrl,
    required this.apiPath,
    required this.model,
    this.modelVariants = const [],
    required this.apiFormat,
    this.appId = '',
    this.isCustom = false,
    this.temperature = 0.7,
    this.topP = 1.0,
    this.maxTokens = 6000,
    this.repetitionPenalty = 1.3, // 设置默认值
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'apiKey': apiKey,
    'apiUrl': apiUrl,
    'apiPath': apiPath,
    'model': model,
    'modelVariants': modelVariants,
    'apiFormat': apiFormat,
    'appId': appId,
    'isCustom': isCustom,
    'temperature': temperature,
    'topP': topP,
    'maxTokens': maxTokens,
    'repetitionPenalty': repetitionPenalty, // 添加到 JSON
  };

  factory ModelConfig.fromJson(Map<String, dynamic> json) => ModelConfig(
    name: json['name'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
    apiUrl: json['apiUrl'] as String? ?? '',
    apiPath: json['apiPath'] as String? ?? '',
    model: json['model'] as String? ?? '',
    modelVariants: json['modelVariants'] != null 
        ? List<String>.from(json['modelVariants']) 
        : [],
    apiFormat: json['apiFormat'] as String? ?? 'OpenAI API兼容',
    appId: json['appId'] as String? ?? '',
    isCustom: json['isCustom'] as bool? ?? false,
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
    maxTokens: (json['maxTokens'] as num?)?.toInt() ?? 4000,
    repetitionPenalty: (json['repetitionPenalty'] as num?)?.toDouble() ?? 1.3, // 从 JSON 读取
  );

  ModelConfig copyWith({
    String? name,
    String? apiKey,
    String? apiUrl,
    String? apiPath,
    String? model,
    List<String>? modelVariants,
    String? apiFormat,
    String? appId,
    bool? isCustom,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repetitionPenalty, // 添加到 copyWith
  }) {
    return ModelConfig(
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      apiUrl: apiUrl ?? this.apiUrl,
      apiPath: apiPath ?? this.apiPath,
      model: model ?? this.model,
      modelVariants: modelVariants ?? this.modelVariants,
      apiFormat: apiFormat ?? this.apiFormat,
      appId: appId ?? this.appId,
      isCustom: isCustom ?? this.isCustom,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty, // 添加到构造
    );
  }
  
  // 添加模型变体
  void addModelVariant(String variant) {
    // 不添加空字符串、与主模型相同的标识符或已存在的变体
    if (variant.isNotEmpty && variant != model && !modelVariants.contains(variant)) {
      modelVariants.add(variant);
    }
  }
  
  // 删除模型变体
  void removeModelVariant(String variant) {
    modelVariants.remove(variant);
  }
  
  // 切换当前模型为指定变体
  void switchToVariant(String variant) {
    if (modelVariants.contains(variant)) {
      model = variant;
    }
  }
}

class ApiConfigController extends GetxController {
  static const _boxName = 'api_config';
  static const _customModelsKey = 'custom_models';
  static const _dualModeEnabledKey = 'dual_mode_enabled';
  static const _outlineModelIdKey = 'outline_model_id';
  static const _chapterModelIdKey = 'chapter_model_id';
  static const _outlineModelVariantKey = 'outline_model_variant';
  static const _chapterModelVariantKey = 'chapter_model_variant';
  late final Box<dynamic> _box;
  
  final RxString selectedModelId = ''.obs;
  final RxList<ModelConfig> models = <ModelConfig>[].obs;
  final RxDouble temperature = 0.7.obs;
  final RxDouble topP = 1.0.obs;
  final RxInt maxTokens = 4000.obs;
  final RxDouble repetitionPenalty = 1.3.obs;

  // 添加双模型模式相关的状态
  final RxBool isDualModeEnabled = false.obs;
  final RxString outlineModelId = ''.obs;
  final RxString chapterModelId = ''.obs;
  final RxString outlineModelVariant = ''.obs; // 添加大纲模型变体
  final RxString chapterModelVariant = ''.obs; // 添加章节模型变体

  final List<ModelConfig> _defaultModels = [
    ModelConfig(
      name: 'ChatGPT',
      apiKey: '',
      apiUrl: 'https://api.openai.com',
      apiPath: '/v1/chat/completions',
      model: 'gpt-4',
      apiFormat: 'OpenAI API兼容',
    ),
    ModelConfig(
      name: '硅基流动 DeepSeek',
      apiKey: '',
      apiUrl: 'https://api.siliconflow.cn',
      apiPath: '/v1/chat/completions',
      model: 'deepseek-ai/DeepSeek-V3',
      apiFormat: 'OpenAI API兼容',
    ),
    ModelConfig(
      name: 'Deepseek',
      apiKey: '',
      apiUrl: 'https://api.deepseek.com',
      apiPath: '/v1/chat/completions',
      model: 'deepseek-reasoner',
      apiFormat: 'OpenAI API兼容',
    ),
    ModelConfig(
      name: '通义千问',
      apiKey: '',
      apiUrl: 'https://dashscope.aliyuncs.com',
      apiPath: '/compatible-mode/v1/chat/completions',
      model: 'qwen-turbo-2024-11-01',
      apiFormat: 'OpenAI API兼容',
    ),
    ModelConfig(
      name: '百度千帆',
      apiKey: '',
      apiUrl: 'https://qianfan.baidubce.com',
      apiPath: '/v2/chat/completions',
      model: 'deepseek-v3',
      apiFormat: 'OpenAI API兼容',
      appId: '',
    ),
    ModelConfig(
      name: 'Gemini Pro',
      apiKey: '',
      apiUrl: 'https://generativelanguage.googleapis.com',
      apiPath: '/v1/models/gemini-pro:streamGenerateContent',
      model: 'gemini-pro',
      apiFormat: 'Google API',
    ),
  ];

  final _storage = GetStorage();
  final apiKey = ''.obs;
  final baseUrl = ''.obs;
  final ttsApiKey = ''.obs;
  final isTextToSpeechMode = false.obs;

  static const String _apiKeyKey = 'api_key';
  static const String _baseUrlKey = 'base_url';
  static const String _ttsApiKeyKey = 'tts_api_key';
  static const String _configModeKey = 'config_mode';

  final Rx<ModelConfig> currentModel = ModelConfig(
    name: 'default',
    apiKey: '',
    apiUrl: '',
    apiPath: '/v1/chat/completions',
    model: 'gpt-3.5-turbo',
    apiFormat: 'openai',
    maxTokens: 8000,
    temperature: 0.7,
  ).obs;

  @override
  void onInit() async {
    super.onInit();
    await _initHive();
    _loadModels();
    _cleanupModelVariants(); // 清理重复的模型变体
    if (models.isNotEmpty) {
      selectedModelId.value = models[0].name;
      _updateCurrentModelConfig();
    }
    _loadConfig();
    _loadDualModeConfig(); // 加载双模型模式配置
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  void _loadModels() {
    // 加载默认模型
    models.addAll(_defaultModels);

    // 加载自定义模型
    final savedCustomModels = _box.get(_customModelsKey);
    if (savedCustomModels != null) {
      final customModels = (savedCustomModels as List)
          .map((e) => ModelConfig.fromJson(Map<String, dynamic>.from(e)))
          .where((model) => model.isCustom)
          .toList();
      models.addAll(customModels);
    }

    // 加载每个模型的配置
    for (var i = 0; i < models.length; i++) {
      final savedConfig = _box.get(models[i].name);
      if (savedConfig != null) {
        models[i] = ModelConfig.fromJson(Map<String, dynamic>.from(savedConfig));
      }
    }

    // 在加载模型后清理重复的变体
    _cleanupModelVariants();
  }

  void _updateCurrentModelConfig() {
    final config = getCurrentModel();
    temperature.value = config.temperature;
    topP.value = config.topP;
    maxTokens.value = config.maxTokens;
    repetitionPenalty.value = config.repetitionPenalty; // 更新重复惩罚参数
  }

  ModelConfig getCurrentModel() {
    return models.firstWhere((m) => m.name == selectedModelId.value);
  }

  void updateSelectedModel(String modelName) {
    selectedModelId.value = modelName;
    _updateCurrentModelConfig();
  }

  void updateTemperature(double value) {
    temperature.value = value;
    _saveCurrentConfig();
  }

  void updateTopP(double value) {
    topP.value = value;
    _saveCurrentConfig();
  }

  void updateMaxTokens(int value) {
    maxTokens.value = value;
    currentModel.update((model) {
      model?.maxTokens = value;
    });
    // 同步更新到models中
    final index = models.indexWhere((m) => m.name == selectedModelId.value);
    if (index != -1) {
      models[index] = models[index].copyWith(maxTokens: value);
      _box.put(selectedModelId.value, models[index].toJson());
    }
  }

  void updateRepetitionPenalty(double value) {
    repetitionPenalty.value = value;
    _saveCurrentConfig();
  }

  Future<void> addCustomModel(ModelConfig model) async {
    model.isCustom = true;
    models.add(model);
    await _saveCustomModels();
    await _box.put(model.name, model.toJson());
  }

  Future<void> removeCustomModel(String modelName) async {
    models.removeWhere((m) => m.name == modelName && m.isCustom);
    await _saveCustomModels();
    await _box.delete(modelName);
    if (selectedModelId.value == modelName) {
      selectedModelId.value = models.first.name;
      _updateCurrentModelConfig();
    }
  }

  Future<void> updateModelConfig(String modelName, {
    String? apiKey,
    String? apiUrl,
    String? apiPath,
    String? model,
    List<String>? modelVariants,
    String? apiFormat,
    String? appId,
    int? maxTokens,
  }) async {
    final index = models.indexWhere((m) => m.name == modelName);
    if (index != -1) {
      models[index] = models[index].copyWith(
        apiKey: apiKey,
        apiUrl: apiUrl,
        apiPath: apiPath,
        model: model,
        modelVariants: modelVariants,
        apiFormat: apiFormat,
        appId: appId,
        maxTokens: maxTokens,
      );
      await _box.put(modelName, models[index].toJson());
      
      // 如果是当前选中的模型，同步更新currentModel
      if (modelName == selectedModelId.value) {
        currentModel.update((model) {
          if (model != null) {
            if (maxTokens != null) model.maxTokens = maxTokens;
            if (apiKey != null) model.apiKey = apiKey;
            if (apiUrl != null) model.apiUrl = apiUrl;
            if (apiPath != null) model.apiPath = apiPath;
            if (apiFormat != null) model.apiFormat = apiFormat;
            if (appId != null) model.appId = appId;
          }
        });
      }
    }
  }

  Future<void> _saveCustomModels() async {
    final customModels = models
        .where((m) => m.isCustom)
        .map((m) => m.toJson())
        .toList();
    await _box.put(_customModelsKey, customModels);
  }

  Future<void> _saveCurrentConfig() async {
    final index = models.indexWhere((m) => m.name == selectedModelId.value);
    if (index != -1) {
      models[index] = models[index].copyWith(
        temperature: temperature.value,
        topP: topP.value,
        maxTokens: maxTokens.value,
        repetitionPenalty: repetitionPenalty.value, // 保存重复惩罚参数
      );
      await _box.put(selectedModelId.value, models[index].toJson());
    }
  }

  // 重置为默认配置
  Future<void> resetToDefaults() async {
    // 删除所有自定义模型
    final customModels = models.where((m) => m.isCustom).toList();
    for (final model in customModels) {
      await _box.delete(model.name);
    }
    models.removeWhere((m) => m.isCustom);
    await _box.delete(_customModelsKey);

    // 重置默认模型配置
    models.clear();
    models.addAll(_defaultModels);
    selectedModelId.value = models[0].name;
    _updateCurrentModelConfig();
  }

  void _loadConfig() {
    apiKey.value = _storage.read(_apiKeyKey) ?? '';
    baseUrl.value = _storage.read(_baseUrlKey) ?? '';
    ttsApiKey.value = _storage.read(_ttsApiKeyKey) ?? '';
    isTextToSpeechMode.value = _storage.read(_configModeKey) ?? false;
  }

  void setApiKey(String value) {
    apiKey.value = value;
    _storage.write(_apiKeyKey, value);
  }

  void setBaseUrl(String value) {
    baseUrl.value = value;
    _storage.write(_baseUrlKey, value);
  }

  void setTTSApiKey(String value) {
    ttsApiKey.value = value;
    _storage.write(_ttsApiKeyKey, value);
  }

  void toggleConfigMode() {
    isTextToSpeechMode.value = !isTextToSpeechMode.value;
    _storage.write(_configModeKey, isTextToSpeechMode.value);
  }

  // 添加模型变体到指定模型
  Future<void> addModelVariant(String modelName, String variant) async {
    if (variant.isEmpty) return;
    
    final index = models.indexWhere((m) => m.name == modelName);
    if (index != -1) {
      // 确保不添加重复的变体，包括和主模型标识符相同的变体
      if (models[index].model != variant && !models[index].modelVariants.contains(variant)) {
        // 添加变体到模型
        models[index].addModelVariant(variant);
        await _box.put(modelName, models[index].toJson());
        
        // 如果是当前选中的模型，更新当前模型配置
        if (modelName == selectedModelId.value) {
          _updateCurrentModelConfig();
        }
      }
    }
  }
  
  // 删除指定模型的变体
  Future<void> removeModelVariant(String modelName, String variant) async {
    final index = models.indexWhere((m) => m.name == modelName);
    if (index != -1) {
      // 删除变体
      models[index].removeModelVariant(variant);
      await _box.put(modelName, models[index].toJson());
      
      // 如果当前模型正在使用这个变体，切换回主模型标识符
      if (modelName == selectedModelId.value && models[index].model == variant) {
        // 重置为主模型标识符
        final mainModel = models[index].model;
        updateModelIdentifier(modelName, mainModel);
      }
    }
  }
  
  // 切换到指定模型的指定变体
  Future<void> switchToModelVariant(String modelName, String variant) async {
    final index = models.indexWhere((m) => m.name == modelName);
    if (index != -1 && models[index].modelVariants.contains(variant)) {
      // 切换模型标识符
      updateModelIdentifier(modelName, variant);
    }
  }
  
  // 更新模型标识符
  Future<void> updateModelIdentifier(String modelName, String newIdentifier) async {
    final index = models.indexWhere((m) => m.name == modelName);
    if (index != -1) {
      models[index] = models[index].copyWith(model: newIdentifier);
      await _box.put(modelName, models[index].toJson());
      
      // 如果是当前选中的模型，同步更新currentModel
      if (modelName == selectedModelId.value) {
        currentModel.update((model) {
          if (model != null) {
            model.model = newIdentifier;
          }
        });
      }
    }
  }
  
  // 获取指定模型的所有变体
  List<String> getModelVariants(String modelName) {
    final index = models.indexWhere((m) => m.name == modelName);
    if (index != -1) {
      return [...models[index].modelVariants];
    }
    return [];
  }
  
  // 获取当前选中模型的所有变体
  List<String> getCurrentModelVariants() {
    return getModelVariants(selectedModelId.value);
  }

  // 加载双模型模式配置
  void _loadDualModeConfig() {
    final enabled = _box.get(_dualModeEnabledKey, defaultValue: false) as bool;
    final outlineId = _box.get(_outlineModelIdKey, defaultValue: '') as String;
    final chapterId = _box.get(_chapterModelIdKey, defaultValue: '') as String;
    final outlineVariant = _box.get(_outlineModelVariantKey, defaultValue: '') as String;
    final chapterVariant = _box.get(_chapterModelVariantKey, defaultValue: '') as String;
    
    isDualModeEnabled.value = enabled;
    
    // 检查保存的模型ID是否存在于当前模型列表中
    if (outlineId.isNotEmpty && models.any((m) => m.name == outlineId)) {
      outlineModelId.value = outlineId;
      
      // 检查保存的模型变体是否存在
      final outlineModel = models.firstWhere((m) => m.name == outlineId);
      if (outlineVariant.isNotEmpty && 
          (outlineVariant == outlineModel.model || 
           outlineModel.modelVariants.contains(outlineVariant))) {
        outlineModelVariant.value = outlineVariant;
      } else {
        outlineModelVariant.value = outlineModel.model; // 使用默认模型标识符
      }
    } else if (models.isNotEmpty) {
      outlineModelId.value = models[0].name; // 设置默认值
      outlineModelVariant.value = models[0].model; // 使用默认模型标识符
    }
    
    if (chapterId.isNotEmpty && models.any((m) => m.name == chapterId)) {
      chapterModelId.value = chapterId;
      
      // 检查保存的模型变体是否存在
      final chapterModel = models.firstWhere((m) => m.name == chapterId);
      if (chapterVariant.isNotEmpty && 
          (chapterVariant == chapterModel.model || 
           chapterModel.modelVariants.contains(chapterVariant))) {
        chapterModelVariant.value = chapterVariant;
      } else {
        chapterModelVariant.value = chapterModel.model; // 使用默认模型标识符
      }
    } else if (models.isNotEmpty) {
      chapterModelId.value = models[0].name; // 设置默认值
      chapterModelVariant.value = models[0].model; // 使用默认模型标识符
    }
  }
  
  // 切换双模型模式
  void toggleDualMode(bool enabled) {
    isDualModeEnabled.value = enabled;
    _box.put(_dualModeEnabledKey, enabled);
    
    // 如果启用双模型模式但未设置模型，则设置默认模型
    if (enabled) {
      if (outlineModelId.value.isEmpty && models.isNotEmpty) {
        outlineModelId.value = models[0].name;
        _box.put(_outlineModelIdKey, outlineModelId.value);
      }
      
      if (chapterModelId.value.isEmpty && models.isNotEmpty) {
        chapterModelId.value = models[0].name;
        _box.put(_chapterModelIdKey, chapterModelId.value);
      }
    }
  }
  
  // 更新大纲生成模型
  void updateOutlineModel(String modelId) {
    outlineModelId.value = modelId;
    _box.put(_outlineModelIdKey, modelId);
    
    // 更新模型变体为新模型的默认标识符
    final model = models.firstWhere((m) => m.name == modelId);
    outlineModelVariant.value = model.model;
    _box.put(_outlineModelVariantKey, model.model);
  }
  
  // 更新章节生成模型
  void updateChapterModel(String modelId) {
    chapterModelId.value = modelId;
    _box.put(_chapterModelIdKey, modelId);
    
    // 更新模型变体为新模型的默认标识符
    final model = models.firstWhere((m) => m.name == modelId);
    chapterModelVariant.value = model.model;
    _box.put(_chapterModelVariantKey, model.model);
  }
  
  // 添加更新大纲模型变体的方法
  void updateOutlineModelVariant(String variant) {
    if (variant.isEmpty) return;
    
    // 检查变体是否存在于选定的模型中
    final modelId = outlineModelId.value;
    if (modelId.isNotEmpty) {
      final modelIndex = models.indexWhere((m) => m.name == modelId);
      if (modelIndex != -1) {
        final model = models[modelIndex];
        // 确保变体有效（是主模型或者是模型的变体）
        if (variant == model.model || model.modelVariants.contains(variant)) {
          outlineModelVariant.value = variant;
          _box.put(_outlineModelVariantKey, variant);
        }
      }
    }
  }
  
  // 添加更新章节模型变体的方法
  void updateChapterModelVariant(String variant) {
    if (variant.isEmpty) return;
    
    // 检查变体是否存在于选定的模型中
    final modelId = chapterModelId.value;
    if (modelId.isNotEmpty) {
      final modelIndex = models.indexWhere((m) => m.name == modelId);
      if (modelIndex != -1) {
        final model = models[modelIndex];
        // 确保变体有效（是主模型或者是模型的变体）
        if (variant == model.model || model.modelVariants.contains(variant)) {
          chapterModelVariant.value = variant;
          _box.put(_chapterModelVariantKey, variant);
        }
      }
    }
  }
  
  // 修改获取大纲生成模型配置的方法
  ModelConfig getOutlineModel() {
    if (isDualModeEnabled.value && outlineModelId.value.isNotEmpty) {
      final model = models.firstWhere(
        (m) => m.name == outlineModelId.value,
        orElse: () => getCurrentModel()
      );
      
      // 使用指定的模型变体
      if (outlineModelVariant.value.isNotEmpty) {
        return model.copyWith(model: outlineModelVariant.value);
      }
      
      return model;
    }
    return getCurrentModel();
  }
  
  // 修改获取章节生成模型配置的方法
  ModelConfig getChapterModel() {
    if (isDualModeEnabled.value && chapterModelId.value.isNotEmpty) {
      final model = models.firstWhere(
        (m) => m.name == chapterModelId.value,
        orElse: () => getCurrentModel()
      );
      
      // 使用指定的模型变体
      if (chapterModelVariant.value.isNotEmpty) {
        return model.copyWith(model: chapterModelVariant.value);
      }
      
      return model;
    }
    return getCurrentModel();
  }

  // 修改ModelConfig类的addModelVariant方法，确保不添加重复变体
  void _ensureUniqueModelVariants(String modelName) {
    final index = models.indexWhere((m) => m.name == modelName);
    if (index != -1) {
      // 去除重复的变体
      final uniqueVariants = models[index].modelVariants.toSet().toList();
      // 确保变体列表中不包含主模型标识符
      uniqueVariants.remove(models[index].model);
      // 更新模型变体列表
      models[index] = models[index].copyWith(modelVariants: uniqueVariants);
      // 保存到存储
      _box.put(modelName, models[index].toJson());
    }
  }
  
  // 在加载模型后清理重复的变体
  void _cleanupModelVariants() {
    for (var i = 0; i < models.length; i++) {
      _ensureUniqueModelVariants(models[i].name);
    }
  }
} 