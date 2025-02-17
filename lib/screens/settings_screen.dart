import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/api_config_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ApiConfigController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddModelDialog(context, controller),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '模型设置',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => controller.resetToDefaults(),
                            child: const Text('重置默认配置'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Obx(() => DropdownButtonFormField<String>(
                        value: controller.selectedModelId.value,
                        decoration: const InputDecoration(
                          labelText: '选择模型',
                          border: OutlineInputBorder(),
                        ),
                        items: controller.models.map((model) => DropdownMenuItem(
                          value: model.name,
                          child: SizedBox(
                            width: 300,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(child: Text(model.name)),
                                if (model.isCustom)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    onPressed: () {
                                      controller.removeCustomModel(model.name);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        )).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            controller.updateSelectedModel(value);
                          }
                        },
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final currentModel = controller.getCurrentModel();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${currentModel.name} 配置',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'API Key',
                            hintText: '请输入您的 API Key',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => controller.updateModelConfig(
                            currentModel.name,
                            apiKey: value,
                          ),
                          controller: TextEditingController(
                            text: currentModel.apiKey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'API URL',
                            hintText: '请输入 API 服务器地址',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => controller.updateModelConfig(
                            currentModel.name,
                            apiUrl: value,
                          ),
                          controller: TextEditingController(
                            text: currentModel.apiUrl,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'API 路径',
                            hintText: '请输入 API 路径（如 /v1/chat/completions）',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => controller.updateModelConfig(
                            currentModel.name,
                            apiPath: value,
                          ),
                          controller: TextEditingController(
                            text: currentModel.apiPath,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: '模型名称',
                            hintText: '请输入具体的模型名称',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => controller.updateModelConfig(
                            currentModel.name,
                            model: value,
                          ),
                          controller: TextEditingController(
                            text: currentModel.model,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'App ID',
                            hintText: '请输入应用ID（百度千帆等需要）',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) => controller.updateModelConfig(
                            currentModel.name,
                            appId: value,
                          ),
                          controller: TextEditingController(
                            text: currentModel.appId,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: '每章字数限制',
                            hintText: '建议设置在4000-8000之间，过短可能导致情节单薄，过长则生成较慢',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => controller.updateModelConfig(
                            currentModel.name,
                            maxTokens: int.tryParse(value) ?? 5000,
                          ),
                          controller: TextEditingController(
                            text: currentModel.maxTokens.toString(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: currentModel.apiFormat,
                          decoration: const InputDecoration(
                            labelText: 'API 格式',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'OpenAI API兼容',
                              child: Text('OpenAI API兼容'),
                            ),
                            DropdownMenuItem(
                              value: 'Google API',
                              child: Text('Google API'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              controller.updateModelConfig(
                                currentModel.name,
                                apiFormat: value,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '高级设置',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('温度 (Temperature)'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: controller.temperature.value,
                                    min: 0.0,
                                    max: 2.0,
                                    divisions: 20,
                                    label: controller.temperature.value.toStringAsFixed(1),
                                    onChanged: (value) => controller.updateTemperature(value),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    controller.temperature.value.toStringAsFixed(1),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Top P'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: controller.topP.value,
                                    min: 0.0,
                                    max: 1.0,
                                    divisions: 10,
                                    label: controller.topP.value.toStringAsFixed(1),
                                    onChanged: (value) => controller.updateTopP(value),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    controller.topP.value.toStringAsFixed(1),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('重复惩罚 (Repetition Penalty)'),
                            const Text(
                              '控制文本重复的程度，值越大越不容易重复\n建议范围：1.0-1.5，默认1.3',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: controller.repetitionPenalty.value,
                                    min: 1.0,
                                    max: 2.0,
                                    divisions: 20,
                                    label: controller.repetitionPenalty.value.toStringAsFixed(2),
                                    onChanged: (value) => controller.updateRepetitionPenalty(value),
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    controller.repetitionPenalty.value.toStringAsFixed(2),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('最大生成长度'),
                            const Text(
                              '控制每章生成的最大长度，建议4000-8000之间\n数值越大生成内容越长，但速度也越慢',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: currentModel.maxTokens.toDouble(),
                                    min: 2000,
                                    max: 16384,
                                    divisions: 144,
                                    label: '${currentModel.maxTokens} tokens',
                                    onChanged: (value) {
                                      final tokens = value.toInt();
                                      controller.updateMaxTokens(tokens);
                                      controller.updateModelConfig(
                                        currentModel.name,
                                        maxTokens: tokens,
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    '${currentModel.maxTokens}\ntokens',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(height: 1.2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddModelDialog(BuildContext context, ApiConfigController controller) {
    final nameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final apiUrlController = TextEditingController();
    final apiPathController = TextEditingController();
    final modelController = TextEditingController();
    final appIdController = TextEditingController();
    String selectedApiFormat = 'OpenAI API兼容';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加自定义模型'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '模型名称',
                  hintText: '请输入模型显示名称',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: '请输入 API Key',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: apiUrlController,
                decoration: const InputDecoration(
                  labelText: 'API URL',
                  hintText: '请输入 API 服务器地址',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: apiPathController,
                decoration: const InputDecoration(
                  labelText: 'API 路径',
                  hintText: '如 /v1/chat/completions',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: '模型标识符',
                  hintText: '请输入具体的模型标识符',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: appIdController,
                decoration: const InputDecoration(
                  labelText: 'App ID',
                  hintText: '请输入应用ID（百度千帆等需要）',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedApiFormat,
                decoration: const InputDecoration(
                  labelText: 'API 格式',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'OpenAI API兼容',
                    child: Text('OpenAI API兼容'),
                  ),
                  DropdownMenuItem(
                    value: 'Google API',
                    child: Text('Google API'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedApiFormat = value;
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                Get.snackbar(
                  '提示',
                  '请输入模型名称',
                  backgroundColor: Colors.red.withOpacity(0.1),
                  duration: const Duration(seconds: 2),
                );
                return;
              }
              
              // 检查是否已存在同名模型
              if (controller.models.any((m) => m.name == nameController.text)) {
                Get.snackbar(
                  '提示',
                  '已存在同名模型，请使用其他名称',
                  backgroundColor: Colors.red.withOpacity(0.1),
                  duration: const Duration(seconds: 2),
                );
                return;
              }

              controller.addCustomModel(ModelConfig(
                name: nameController.text,
                apiKey: apiKeyController.text,
                apiUrl: apiUrlController.text,
                apiPath: apiPathController.text,
                model: modelController.text,
                appId: appIdController.text,
                apiFormat: selectedApiFormat,
                isCustom: true,
              ));
              
              Get.back();
              Get.snackbar(
                '成功',
                '模型添加成功',
                backgroundColor: Colors.green.withOpacity(0.1),
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
} 