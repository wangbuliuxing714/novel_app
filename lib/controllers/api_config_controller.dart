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
    if (!modelVariants.contains(variant) && variant.isNotEmpty) {
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
  late final Box<dynamic> _box;
  
  final RxString selectedModelId = ''.obs;
  final RxList<ModelConfig> models = <ModelConfig>[].obs;
  final RxDouble temperature = 0.7.obs;
  final RxDouble topP = 1.0.obs;
  final RxInt maxTokens = 4000.obs;
  final RxDouble repetitionPenalty = 1.3.obs; // 添加重复惩罚参数的响应式变量

  // 添加双模型模式相关的变量
  final RxBool isDualModelMode = false.obs;
  final RxString outlineModelId = ''.obs;
  final RxString chapterModelId = ''.obs;
  // 添加模型变体选择支持
  final RxString outlineModelVariant = ''.obs;
  final RxString chapterModelVariant = ''.obs;

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
      name: '硅基流动',
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
      name: '阿里百炼（通义）',
      apiKey: '',
      apiUrl: 'https://dashscope.aliyuncs.com',
      apiPath: '/compatible-mode/v1/chat/completions',
      model: 'qwen-turbo-2024-11-01',
      modelVariants: [
        'qwen2.5-7b-instruct-1m',  // 阿里云比较好用的模型
        'deepseek-r1',             // 阿里云的deepseek标识符
        'qwq-32b',                 // 阿里云推理模型
        'qwq-plus-2025-03-05',     // 阿里云推理模型plus
      ],
      apiFormat: 'OpenAI API兼容',
    ),
    ModelConfig(
      name: '火山引擎（豆包）',
      apiKey: '',
      apiUrl: 'https://ork.cn-beijing.volces.com',
      apiPath: '/api/v3/chat/completions',
      model: 'doupo-1-5-pro-256k-250115',
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
      apiPath: '/v1/models/gemini-pro:generateContent',
      model: 'gemini-pro',
      apiFormat: 'Google API',
      modelVariants: [
        'gemini-1.5-pro',
        'gemini-1.5-flash',
      ],
    ),
    
    // 添加另一个可能通过镜像访问的Gemini
    ModelConfig(
      name: 'Gemini代理版',
      apiKey: '',
      apiUrl: 'https://gemini-proxy-api.vercel.app',
      apiPath: '/v1/models/gemini-pro:generateContent',
      model: 'gemini-pro',
      apiFormat: 'Google API',
      modelVariants: [
        'gemini-1.5-pro',
        'gemini-1.5-flash',
        'gemini-2.0-flash-thinking-exp-01-21',
        'gemini-2.0-flash-exp',
      ],
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
    maxTokens: 7000,
    temperature: 0.7,
  ).obs;

  @override
  void onInit() async {
    super.onInit();
    await _initializeBox();
  }

  Future<void> _initializeBox() async {
    _box = await Hive.openBox(_boxName);
    _loadModels();
    _loadConfig();
    loadDualModelConfig(); // 加载双模型配置
    // 在所有配置加载后执行修复
    Future.delayed(Duration(milliseconds: 100), () {
      _checkAndFixModelNames();
    });
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
  }

  void _updateCurrentModelConfig() {
    final config = getCurrentModel();
    temperature.value = config.temperature;
    topP.value = config.topP;
    maxTokens.value = config.maxTokens;
    repetitionPenalty.value = config.repetitionPenalty; // 更新重复惩罚参数
  }

  ModelConfig getCurrentModel() {
    if (selectedModelId.value.isEmpty) {
      if (models.isNotEmpty) {
        selectedModelId.value = models[0].name;
      } else {
        throw Exception('未找到可用的模型');
      }
    }

    return models.firstWhere(
      (model) => model.name == selectedModelId.value,
      orElse: () => models.isNotEmpty ? models[0] : throw Exception('未找到可用的模型'),
    );
  }

  // 获取大纲生成模型配置 (新增)
  ModelConfig getOutlineModel() {
    if (!isDualModelMode.value) {
      return getCurrentModel();
    }
    
    if (outlineModelId.value.isEmpty) {
      outlineModelId.value = selectedModelId.value;
    }

    ModelConfig model = models.firstWhere(
      (model) => model.name == outlineModelId.value,
      orElse: () => getCurrentModel(),
    );
    
    // 如果有指定变体且变体存在，切换到该变体
    if (outlineModelVariant.value.isNotEmpty && 
        model.modelVariants.contains(outlineModelVariant.value)) {
      // 创建一个副本并修改模型标识符
      return model.copyWith(model: outlineModelVariant.value);
    }
    
    return model;
  }

  // 获取章节生成模型配置 (新增)
  ModelConfig getChapterModel() {
    if (!isDualModelMode.value) {
      return getCurrentModel();
    }
    
    if (chapterModelId.value.isEmpty) {
      chapterModelId.value = selectedModelId.value;
    }

    ModelConfig model = models.firstWhere(
      (model) => model.name == chapterModelId.value,
      orElse: () => getCurrentModel(),
    );
    
    // 如果有指定变体且变体存在，切换到该变体
    if (chapterModelVariant.value.isNotEmpty && 
        model.modelVariants.contains(chapterModelVariant.value)) {
      // 创建一个副本并修改模型标识符
      return model.copyWith(model: chapterModelVariant.value);
    }
    
    return model;
  }

  // 保存双模型模式设置 (新增)
  Future<void> saveDualModelConfig() async {
    await _box.put('dual_model_mode', isDualModelMode.value);
    await _box.put('outline_model_id', outlineModelId.value);
    await _box.put('chapter_model_id', chapterModelId.value);
    await _box.put('outline_model_variant', outlineModelVariant.value);
    await _box.put('chapter_model_variant', chapterModelVariant.value);
  }

  // 载入双模型模式设置 (新增)
  void loadDualModelConfig() {
    isDualModelMode.value = _box.get('dual_model_mode', defaultValue: false);
    outlineModelId.value = _box.get('outline_model_id', defaultValue: '');
    chapterModelId.value = _box.get('chapter_model_id', defaultValue: '');
    outlineModelVariant.value = _box.get('outline_model_variant', defaultValue: '');
    chapterModelVariant.value = _box.get('chapter_model_variant', defaultValue: '');
    
    // 修复模型名称更改问题
    if (outlineModelId.value == '通义千问') {
      outlineModelId.value = '阿里百炼（通义）';
      saveDualModelConfig();
    }
    
    if (chapterModelId.value == '通义千问') {
      chapterModelId.value = '阿里百炼（通义）';
      saveDualModelConfig();
    }
  }
  
  // 当模型变体发生变化时同步更新相关配置
  void updateModelVariants(String modelName, List<String> variants) {
    // 更新模型变体列表
    final index = models.indexWhere((m) => m.name == modelName);
    if (index != -1) {
      models[index] = models[index].copyWith(modelVariants: variants);
      
      // 如果当前大纲或章节模型是该模型，检查变体是否仍然有效
      if (outlineModelId.value == modelName && 
          outlineModelVariant.value.isNotEmpty && 
          !variants.contains(outlineModelVariant.value)) {
        // 变体不再存在，重置
        outlineModelVariant.value = '';
        saveDualModelConfig();
      }
      
      if (chapterModelId.value == modelName && 
          chapterModelVariant.value.isNotEmpty && 
          !variants.contains(chapterModelVariant.value)) {
        // 变体不再存在，重置
        chapterModelVariant.value = '';
        saveDualModelConfig();
      }
    }
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
    // 加载配置
    final savedModelId = _box.get('selected_model');
    if (savedModelId != null) {
      selectedModelId.value = savedModelId;
    } else if (models.isNotEmpty) {
      selectedModelId.value = models[0].name;
    }
    
    // 修复模型名称更改问题
    if (selectedModelId.value == '通义千问') {
      selectedModelId.value = '阿里百炼（通义）';
      _box.put('selected_model', selectedModelId.value);
    }
    
    _updateCurrentModelConfig();
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
      // 添加变体到模型
      models[index].addModelVariant(variant);
      await _box.put(modelName, models[index].toJson());
      
      // 如果是当前选中的模型，更新当前模型配置
      if (modelName == selectedModelId.value) {
        _updateCurrentModelConfig();
      }
      
      // 同步更新双模型模式中的模型变体选择
      updateModelVariants(modelName, models[index].modelVariants);
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
      
      // 同步更新双模型模式中的模型变体选择
      updateModelVariants(modelName, models[index].modelVariants);
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

  // 添加一个检查并修复模型名称更改的函数
  void _checkAndFixModelNames() {
    // 检查并修复双模型模式中的模型引用
    if (outlineModelId.value == '通义千问') {
      outlineModelId.value = '阿里百炼（通义）';
      saveDualModelConfig();
    }
    
    if (chapterModelId.value == '通义千问') {
      chapterModelId.value = '阿里百炼（通义）';
      saveDualModelConfig();
    }
    
    // 检查当前选择的模型
    if (selectedModelId.value == '通义千问') {
      selectedModelId.value = '阿里百炼（通义）';
      _box.put('selected_model', selectedModelId.value);
    }
  }
} 