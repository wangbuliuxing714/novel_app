import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/api_config_controller.dart';

class ApiConfigScreen extends StatelessWidget {
  ApiConfigScreen({super.key});

  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ApiConfigController());
    
    // 初始化文本控制器
    _apiKeyController.text = controller.apiKey.value;
    _apiUrlController.text = controller.apiUrl.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 配置'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'DeepSeek API 配置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: '请输入您的 DeepSeek API Key',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入 API Key';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiUrlController,
              decoration: const InputDecoration(
                labelText: 'API URL',
                hintText: '请输入 API 地址',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入 API URL';
                }
                if (!Uri.tryParse(value)!.isAbsolute) {
                  return '请输入有效的 URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  controller.saveConfig(
                    apiKey: _apiKeyController.text,
                    apiUrl: _apiUrlController.text,
                  );
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('保存配置'),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '说明',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. API Key 可以从 DeepSeek 官网获取\n'
                      '2. 默认 API 地址为 http://127.0.0.1:8000\n'
                      '3. 请确保 API Key 的安全，不要泄露给他人',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 