import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:novel_app/services/ai_service.dart';

class ModelConfig {
  String apiKey;
  String apiUrl;

  ModelConfig({
    required this.apiKey,
    required this.apiUrl,
  });

  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'apiUrl': apiUrl,
  };

  factory ModelConfig.fromJson(Map<String, dynamic> json) => ModelConfig(
    apiKey: json['apiKey'] as String? ?? '',
    apiUrl: json['apiUrl'] as String? ?? '',
  );
}

class ApiConfigController extends GetxController {
  static const _boxName = 'api_config';
  late final Box<dynamic> _box;
  
  final Rx<AIModel> selectedModel = AIModel.geminiPro.obs;
  final Map<AIModel, ModelConfig> _configs = {
    AIModel.deepseek: ModelConfig(
      apiKey: '',
      apiUrl: 'https://api.deepseek.com/v1',
    ),
    AIModel.deepseekChat: ModelConfig(
      apiKey: '',
      apiUrl: 'https://api.deepseek.com/v1',
    ),
    AIModel.qwen: ModelConfig(
      apiKey: '',
      apiUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    ),
    AIModel.geminiPro: ModelConfig(
      apiKey: '',
      apiUrl: 'https://generativelanguage.googleapis.com/v1',
    ),
    AIModel.geminiFlash: ModelConfig(
      apiKey: '',
      apiUrl: 'https://generativelanguage.googleapis.com/v1',
    ),
  };

  @override
  void onInit() async {
    super.onInit();
    await _initHive();
    _loadConfigs();
  }

  Future<void> _initHive() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  void _loadConfigs() {
    for (final model in AIModel.values) {
      final key = model.toString();
      final savedConfig = _box.get(key);
      if (savedConfig != null) {
        _configs[model] = ModelConfig.fromJson(Map<String, dynamic>.from(savedConfig));
      }
    }
  }

  String getModelName(AIModel model) {
    switch (model) {
      case AIModel.deepseek:
        return 'Deepseek Reasoner';
      case AIModel.deepseekChat:
        return 'Deepseek Chat';
      case AIModel.qwen:
        return '通义千问';
      case AIModel.geminiPro:
        return 'Gemini Pro';
      case AIModel.geminiFlash:
        return 'Gemini 1.5 Flash';
    }
  }

  String getModelDescription(AIModel model) {
    switch (model) {
      case AIModel.deepseek:
        return '开源大模型，无AI味，价格高';
      case AIModel.deepseekChat:
        return '开源大模型，擅长对话和创作';
      case AIModel.qwen:
        return '阿里云通义千问，支持中文创作';
      case AIModel.geminiPro:
        return 'Google Gemini Pro，支持多语言创作';
      case AIModel.geminiFlash:
        return 'Google Gemini 1.5 Flash，更快的生成速度';
    }
  }

  ModelConfig getModelConfig(AIModel model) {
    return _configs[model]!;
  }

  void updateSelectedModel(AIModel model) {
    selectedModel.value = model;
  }

  Future<void> saveConfig(AIModel model, {String? apiKey, String? apiUrl}) async {
    final config = _configs[model]!;
    
    if (apiKey != null) {
      config.apiKey = apiKey;
    }
    if (apiUrl != null) {
      config.apiUrl = apiUrl;
    }

    await _box.put(model.toString(), config.toJson());
  }

  // 重置为默认配置
  Future<void> resetToDefaults() async {
    final config = _configs[AIModel.deepseek]!;
    config.apiUrl = 'https://api.deepseek.com/v1';
    config.apiKey = '';
    await _box.put(AIModel.deepseek.toString(), config.toJson());
    selectedModel.value = AIModel.deepseek;
  }
} 