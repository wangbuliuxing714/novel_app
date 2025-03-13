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
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(text: '模型配置'),
                Tab(text: '模型列表'),
                Tab(text: '双模型模式'),
              ],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // 第一个标签页 - 原有的模型配置
                  SingleChildScrollView(
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
                                    // 模型标识符组件
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                          decoration: const InputDecoration(
                                                  labelText: '模型标识符',
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
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle),
                                              tooltip: '添加模型变体',
                                              onPressed: () {
                                                _showAddModelVariantDialog(context, controller, currentModel);
                                              },
                                            ),
                                          ],
                                        ),
                                        if (currentModel.modelVariants.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '可用的模型变体 (${currentModel.modelVariants.length})',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 6.0,
                                                  runSpacing: 6.0,
                                                  children: List.generate(
                                                    currentModel.modelVariants.length, 
                                                    (index) => _buildVariantChip(
                                                      context, 
                                                      controller, 
                                                      currentModel, 
                                                      currentModel.modelVariants[index],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
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
                  // 第二个标签页 - 模型列表
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Obx(() => Column(
                      children: List.generate(
                        controller.models.length, 
                        (index) => _buildModelDetailCard(context, controller, index)
                      ),
                    )),
                  ),
                  // 第三个标签页 - 双模型模式
                  _buildDualModeTab(context, controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 创建模型变体芯片
  Widget _buildVariantChip(BuildContext context, ApiConfigController controller, ModelConfig model, String variant) {
    final bool isCurrentModel = variant == model.model;
    
    return Chip(
      backgroundColor: isCurrentModel 
          ? Theme.of(context).primaryColor.withOpacity(0.2) 
          : Colors.grey.shade200,
      label: Text(
        variant,
        style: TextStyle(
          color: isCurrentModel ? Theme.of(context).primaryColor : Colors.black87,
          fontWeight: isCurrentModel ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      deleteIcon: Icon(
        isCurrentModel ? Icons.check : Icons.close,
        size: 18,
        color: isCurrentModel ? Theme.of(context).primaryColor : Colors.black54,
      ),
      onDeleted: () {
        if (isCurrentModel) {
          // 如果是当前使用的模型变体，只显示勾号不做操作
          return;
        }
        // 确认是否删除变体
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除模型变体 "$variant" 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  controller.removeModelVariant(model.name, variant);
                  Navigator.of(context).pop();
                },
                child: const Text('删除'),
              ),
            ],
          ),
        );
      },
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }

  void _showAddModelDialog(BuildContext context, ApiConfigController controller) {
    final nameController = TextEditingController();
    final apiKeyController = TextEditingController();
    final apiUrlController = TextEditingController();
    final apiPathController = TextEditingController();
    final modelController = TextEditingController();
    final appIdController = TextEditingController();
    final variantController = TextEditingController();
    String selectedApiFormat = 'OpenAI API兼容';
    
    List<String> modelVariants = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
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
                      labelText: 'API Path',
                      hintText: '例如: /v1/chat/completions',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(
                  labelText: '模型标识符',
                      hintText: '请输入模型标识符',
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: variantController,
                          decoration: const InputDecoration(
                            labelText: '模型变体',
                            hintText: '添加可选的模型变体标识符',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () {
                          if (variantController.text.isNotEmpty && 
                              !modelVariants.contains(variantController.text)) {
                            setState(() {
                              modelVariants.add(variantController.text);
                              variantController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  
                  if (modelVariants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('已添加的模型变体:'),
                    SizedBox(
                      height: modelVariants.length > 3 ? 120 : null,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: modelVariants.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(modelVariants[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, size: 20),
                              onPressed: () {
                                setState(() {
                                  modelVariants.removeAt(index);
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  
              const SizedBox(height: 8),
              TextField(
                controller: appIdController,
                decoration: const InputDecoration(
                  labelText: 'App ID',
                      hintText: '部分模型需要App ID',
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
                        setState(() {
                    selectedApiFormat = value;
                        });
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
                    modelVariants: modelVariants,
                appId: appIdController.text,
                apiFormat: selectedApiFormat,
                isCustom: true,
              ));
              
                  Navigator.of(context).pop();
                  Get.snackbar(
                    '成功',
                    '模型添加成功',
                    backgroundColor: Colors.green.withOpacity(0.1),
                    duration: const Duration(seconds: 2),
                  );
                },
                child: const Text('确定'),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildModelDetailCard(BuildContext context, ApiConfigController controller, int index) {
    final model = controller.models[index];
    final isCurrentSelected = model.name == controller.selectedModelId.value;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isCurrentSelected ? Colors.blue.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  model.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: isCurrentSelected ? FontWeight.bold : null,
                    color: isCurrentSelected ? Theme.of(context).primaryColor : null,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 选择此模型按钮
                    if (!isCurrentSelected)
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        tooltip: '使用此模型',
                        onPressed: () {
                          controller.updateSelectedModel(model.name);
                          Get.snackbar(
                            '已切换模型',
                            '当前使用模型: ${model.name}',
                            backgroundColor: Colors.green.withOpacity(0.1),
                            duration: const Duration(seconds: 2),
                          );
                        },
                      ),
                    if (model.isCustom)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: '删除此模型',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('确认删除'),
                              content: Text('确定要删除模型 "${model.name}" 吗？此操作不可撤销。'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    controller.removeCustomModel(model.name);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('删除'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 当前模型标识符
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('当前模型标识符:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(model.model),
                    ],
                  ),
                ),
                // 编辑按钮
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: '编辑模型标识符',
                  onPressed: () {
                    _showEditModelIdentifierDialog(context, controller, model);
                  },
                ),
              ],
            ),
            
            // 模型变体列表
            if (model.modelVariants.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('可用模型变体:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: model.modelVariants.length,
                  itemBuilder: (context, variantIndex) {
                    final variant = model.modelVariants[variantIndex];
                    final isCurrentModel = variant == model.model;
                    
                    return ListTile(
                      dense: true,
                      title: Text(
                        variant,
                        style: TextStyle(
                          fontWeight: isCurrentModel ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentModel ? Theme.of(context).primaryColor : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 使用此变体按钮
                          if (!isCurrentModel)
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, size: 20),
                              onPressed: () {
                                controller.updateModelIdentifier(model.name, variant);
                              },
                              tooltip: '使用此模型标识符',
                            ),
                          // 删除变体按钮
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('确认删除'),
                                  content: Text('确定要删除模型变体 "$variant" 吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        controller.removeModelVariant(model.name, variant);
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('删除'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            tooltip: '删除此变体',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            
            // 添加模型变体按钮
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加模型变体'),
              onPressed: () {
                _showAddModelVariantDialog(context, controller, model);
              },
            ),
            
            const SizedBox(height: 12),
            const Divider(),
            
            // 模型API配置信息
            Text('API URL: ${model.apiUrl}'),
            const SizedBox(height: 4),
            Text('API 路径: ${model.apiPath}'),
            const SizedBox(height: 4),
            Text('API 格式: ${model.apiFormat}'),
            if (model.appId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('App ID: ${model.appId}'),
            ],
          ],
        ),
      ),
    );
  }
  
  // 显示添加模型变体对话框
  void _showAddModelVariantDialog(BuildContext context, ApiConfigController controller, ModelConfig model) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加模型变体'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: '模型变体标识符',
                hintText: '请输入新的模型标识符',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.isEmpty) {
                Get.snackbar(
                  '提示',
                  '请输入模型变体标识符',
                  backgroundColor: Colors.red.withOpacity(0.1),
                  duration: const Duration(seconds: 2),
                );
                return;
              }
              
              if (model.modelVariants.contains(textController.text) || model.model == textController.text) {
                Get.snackbar(
                  '提示',
                  '该模型变体已存在',
                  backgroundColor: Colors.red.withOpacity(0.1),
                  duration: const Duration(seconds: 2),
                );
                return;
              }
              
              controller.addModelVariant(model.name, textController.text);
              Navigator.of(context).pop();
              Get.snackbar(
                '成功',
                '模型变体添加成功',
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
  
  // 显示编辑模型标识符对话框
  void _showEditModelIdentifierDialog(BuildContext context, ApiConfigController controller, ModelConfig model) {
    final textController = TextEditingController(text: model.model);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑模型标识符'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: '模型标识符',
                hintText: '请输入模型标识符',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.isEmpty) {
                Get.snackbar(
                  '提示',
                  '请输入模型标识符',
                  backgroundColor: Colors.red.withOpacity(0.1),
                  duration: const Duration(seconds: 2),
                );
                return;
              }
              
              controller.updateModelIdentifier(model.name, textController.text);
              Navigator.of(context).pop();
              Get.snackbar(
                '成功',
                '模型标识符已更新',
                backgroundColor: Colors.green.withOpacity(0.1),
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 构建双模型模式设置界面
  Widget _buildDualModeTab(BuildContext context, ApiConfigController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '双模型模式',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '开启此功能后，您可以为大纲生成和章节/集生成分别指定不同的模型或模型变体。这样可以使用高性能模型来生成大纲，再使用稳定的模型来生成具体内容。',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  // 开关
                  Obx(() => SwitchListTile(
                    title: const Text('启用双模型模式'),
                    subtitle: const Text('分别为大纲和章节指定不同的模型或模型变体'),
                    value: controller.isDualModeEnabled.value,
                    onChanged: (value) {
                      controller.toggleDualMode(value);
                    },
                  )),
                  
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // 模型选择部分
                  Obx(() => controller.isDualModeEnabled.value 
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 大纲模型选择
                          const Text(
                            '大纲生成模型',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '推荐选择创造力更强的大模型，如GPT-4等，以获得更有创意的故事大纲。',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: controller.outlineModelId.value.isEmpty 
                              ? (controller.models.isNotEmpty ? controller.models[0].name : null)
                              : controller.outlineModelId.value,
                            decoration: const InputDecoration(
                              labelText: '选择大纲生成模型',
                              border: OutlineInputBorder(),
                            ),
                            items: controller.models.map((model) => DropdownMenuItem(
                              value: model.name,
                              child: Text(model.name),
                            )).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                controller.updateOutlineModel(value);
                              }
                            },
                          ),
                          
                          // 添加大纲模型变体选择
                          const SizedBox(height: 12),
                          _buildModelVariantSelector(
                            context: context,
                            controller: controller,
                            labelText: '选择大纲生成模型变体',
                            helpText: '您可以为大纲生成选择特定的模型变体',
                            modelIdGetter: () => controller.outlineModelId.value,
                            variantGetter: () => controller.outlineModelVariant.value,
                            variantSetter: (variant) => controller.updateOutlineModelVariant(variant),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // 章节模型选择
                          const Text(
                            '章节/集生成模型',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '推荐选择更稳定的模型，如QwenTurbo等，以确保生成内容符合大纲要求，并避免出现偏离主题的内容。',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: controller.chapterModelId.value.isEmpty 
                              ? (controller.models.isNotEmpty ? controller.models[0].name : null)
                              : controller.chapterModelId.value,
                            decoration: const InputDecoration(
                              labelText: '选择章节/集生成模型',
                              border: OutlineInputBorder(),
                            ),
                            items: controller.models.map((model) => DropdownMenuItem(
                              value: model.name,
                              child: Text(model.name),
                            )).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                controller.updateChapterModel(value);
                              }
                            },
                          ),
                          
                          // 添加章节模型变体选择
                          const SizedBox(height: 12),
                          _buildModelVariantSelector(
                            context: context,
                            controller: controller,
                            labelText: '选择章节生成模型变体',
                            helpText: '您可以为章节生成选择特定的模型变体',
                            modelIdGetter: () => controller.chapterModelId.value,
                            variantGetter: () => controller.chapterModelVariant.value,
                            variantSetter: (variant) => controller.updateChapterModelVariant(variant),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 模型测试按钮
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.tune),
                                label: const Text('测试模型组合'),
                                onPressed: () {
                                  _showTestDualModeDialog(context, controller);
                                },
                              ),
                            ],
                          ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '请先启用双模型模式',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ),
                  ),
                ],
              ),
            ),
          ),
          
          // 说明卡片
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '使用建议',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('1. 大纲生成：建议使用创造力更强的模型，如DeepSeek、GPT-4等'),
                  SizedBox(height: 4),
                  Text('2. 章节生成：建议使用遵循指令性更强的模型，如Qwen-Turbo等'),
                  SizedBox(height: 4),
                  Text('3. 您可以使用同一个模型的不同变体，例如同一个DeepSeek模型下选择不同的变体用于不同的生成任务'),
                  SizedBox(height: 4),
                  Text('4. 如有不同模型的API凭证，可以分别配置不同的API密钥'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建模型变体选择器
  Widget _buildModelVariantSelector({
    required BuildContext context,
    required ApiConfigController controller,
    required String labelText,
    required String helpText,
    required String Function() modelIdGetter,
    required String Function() variantGetter,
    required Function(String) variantSetter,
  }) {
    final modelId = modelIdGetter();
    if (modelId.isEmpty || !controller.models.any((m) => m.name == modelId)) {
      return const SizedBox.shrink();
    }
    
    final model = controller.models.firstWhere((m) => m.name == modelId);
    
    // 确保所有变体都是唯一的：先创建一个Set去重，然后转回List
    final variantSet = <String>{model.model};
    variantSet.addAll(model.modelVariants);
    final allVariants = variantSet.toList();
    
    // 如果只有一个变体，不显示选择器
    if (allVariants.length <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          '当前模型没有可用的变体',
          style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          helpText,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final currentVariant = variantGetter();
          String dropdownValue = model.model; // 默认值
          
          // 确保下拉框的当前值存在于选项列表中
          if (currentVariant.isNotEmpty && allVariants.contains(currentVariant)) {
            dropdownValue = currentVariant;
          }
          
          return DropdownButtonFormField<String>(
            value: dropdownValue,
            decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
            ),
            items: allVariants.map((variant) => DropdownMenuItem(
              value: variant,
              child: Row(
                children: [
                  Text(variant),
                  if (variant == model.model)
                    const SizedBox(
                      width: 8,
                      child: Padding(
                        padding: EdgeInsets.only(left: 5.0),
                        child: Text('(默认)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            )).toList(),
            onChanged: (value) {
              if (value != null) {
                variantSetter(value);
              }
            },
          );
        }),
      ],
    );
  }
  
  // 显示双模型模式测试对话框
  void _showTestDualModeDialog(BuildContext context, ApiConfigController controller) {
    final outlineModelName = controller.models.firstWhere(
      (m) => m.name == controller.outlineModelId.value,
      orElse: () => controller.models[0]
    ).name;
    
    final chapterModelName = controller.models.firstWhere(
      (m) => m.name == controller.chapterModelId.value,
      orElse: () => controller.models[0]
    ).name;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('双模型模式测试'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('大纲生成使用: $outlineModelName'),
            Text('大纲模型变体: ${controller.outlineModelVariant.value}'),
            const SizedBox(height: 8),
            Text('章节生成使用: $chapterModelName'),
            Text('章节模型变体: ${controller.chapterModelVariant.value}'),
            const SizedBox(height: 16),
            const Text('模型组合已设置完成，您可以返回创作页面测试双模型生成效果。'),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('关闭'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
} 