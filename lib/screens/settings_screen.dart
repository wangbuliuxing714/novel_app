import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:novel_app/services/ai_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ApiConfigController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
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
                      const Text(
                        '模型设置',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(() => DropdownButtonFormField<AIModel>(
                        value: controller.selectedModel.value,
                        decoration: const InputDecoration(
                          labelText: '选择模型',
                        ),
                        items: AIModel.values.map((model) => DropdownMenuItem(
                          value: model,
                          child: Text(controller.getModelName(model)),
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
              Obx(() => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${controller.getModelName(controller.selectedModel.value)} 配置',
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
                        ),
                        onChanged: (value) => controller.saveConfig(
                          controller.selectedModel.value,
                          apiKey: value,
                        ),
                        controller: TextEditingController(
                          text: controller.getModelConfig(
                            controller.selectedModel.value,
                          ).apiKey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'API URL',
                          hintText: '请输入 API 服务器地址',
                        ),
                        onChanged: (value) => controller.saveConfig(
                          controller.selectedModel.value,
                          apiUrl: value,
                        ),
                        controller: TextEditingController(
                          text: controller.getModelConfig(
                            controller.selectedModel.value,
                          ).apiUrl,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
} 