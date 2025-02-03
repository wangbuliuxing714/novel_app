import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/editor_controller.dart';
import 'package:novel_app/widgets/outline_navigator.dart';
import 'package:novel_app/widgets/ai_advisor.dart';

class RealtimeEditorScreen extends StatelessWidget {
  const RealtimeEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EditorController>();
    final isSmallScreen = MediaQuery.of(context).size.width < 600;  // 添加屏幕宽度检查
    // 添加 GlobalKey
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,  // 设置 Scaffold 的 key
      appBar: AppBar(
        title: const Text('实时在线编辑'),
        actions: [
          // 字体大小调整
          IconButton(
            icon: const Text('A-'),
            onPressed: () => controller.changeFontSize(-2),
          ),
          IconButton(
            icon: const Text('A+'),
            onPressed: () => controller.changeFontSize(2),
          ),
          // 保存状态
          Obx(() => controller.isSaving.value
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: controller.saveContent,
                  icon: const Icon(Icons.save),
                  label: Text(
                    controller.lastSaveTime.value.isEmpty
                        ? '保存'
                        : '上次保存: ${controller.lastSaveTime.value}',
                  ),
                )),
          const SizedBox(width: 8),
        ],
      ),
      // 在小屏幕上使用抽屉菜单显示大纲导航
      drawer: isSmallScreen ? const Drawer(
        child: OutlineNavigator(),
      ) : null,
      // 在小屏幕上使用 endDrawer 显示 AI 顾问
      endDrawer: isSmallScreen ? const Drawer(
        child: AIAdvisor(),
      ) : null,
      body: Row(
        children: [
          // 大纲导航 - 仅在大屏幕上显示
          if (!isSmallScreen)
            const SizedBox(
              width: 250,
              child: OutlineNavigator(),
            ),
          
          // 编辑区
          Expanded(
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 8.0 : 16.0),  // 调整内边距
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 标题和保存按钮行
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller.titleController,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 20 : 24,  // 调整字体大小
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: '请输入标题...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      // 保存按钮
                      Obx(() => AnimatedOpacity(
                        opacity: controller.hasUnsavedChanges() ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton.icon(
                          onPressed: controller.saveContent,
                          icon: const Icon(Icons.save),
                          label: Text(isSmallScreen ? '' : '保存'),  // 在小屏幕上只显示图标
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 8),  // 减小间距
                  Expanded(
                    child: Obx(() => TextField(
                      controller: controller.contentController,
                      maxLines: null,
                      style: TextStyle(
                        fontSize: controller.fontSize.value,
                        height: 1.8,
                      ),
                      decoration: const InputDecoration(
                        hintText: '开始创作你的故事...',
                        border: InputBorder.none,
                      ),
                      contextMenuBuilder: (context, editableTextState) {
                        final TextEditingValue value = editableTextState.textEditingValue;
                        
                        if (value.selection.isValid && !value.selection.isCollapsed) {
                          final selectedText = value.text.substring(
                            value.selection.start,
                            value.selection.end,
                          );
                          
                          return AdaptiveTextSelectionToolbar(
                            anchors: editableTextState.contextMenuAnchors,
                            children: [
                              TextSelectionToolbarTextButton(
                                padding: const EdgeInsets.all(12.0),
                                onPressed: () {
                                  editableTextState.hideToolbar();
                                  controller.showAIEditDialog(
                                    selectedText,
                                    value.selection,
                                    controller.contentController,
                                  );
                                },
                                child: const Text(
                                  'AI修改',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                indent: 8,
                                endIndent: 8,
                              ),
                              TextSelectionToolbarTextButton(
                                padding: const EdgeInsets.all(12.0),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: selectedText));
                                  editableTextState.hideToolbar();
                                },
                                child: const Text(
                                  '复制',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                indent: 8,
                                endIndent: 8,
                              ),
                              TextSelectionToolbarTextButton(
                                padding: const EdgeInsets.all(12.0),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: selectedText));
                                  final newText = controller.contentController.text.replaceRange(
                                    value.selection.start,
                                    value.selection.end,
                                    '',
                                  );
                                  controller.contentController.text = newText;
                                  editableTextState.hideToolbar();
                                },
                                child: const Text(
                                  '剪切',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              const VerticalDivider(
                                width: 1,
                                indent: 8,
                                endIndent: 8,
                              ),
                              TextSelectionToolbarTextButton(
                                padding: const EdgeInsets.all(12.0),
                                onPressed: () async {
                                  final data = await Clipboard.getData('text/plain');
                                  if (data?.text != null) {
                                    final newText = controller.contentController.text.replaceRange(
                                      value.selection.start,
                                      value.selection.end,
                                      data!.text!,
                                    );
                                    controller.contentController.text = newText;
                                  }
                                  editableTextState.hideToolbar();
                                },
                                child: const Text(
                                  '粘贴',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          );
                        }
                        
                        return AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: editableTextState.contextMenuButtonItems,
                        );
                      },
                    )),
                  ),
                  const SizedBox(height: 8),
                  // 字数统计和编辑工具栏
                  Row(
                    children: [
                      // 字数统计
                      Expanded(
                        child: Obx(() => Text(
                          '字数：${controller.wordCount}',
                          style: const TextStyle(color: Colors.grey),
                        )),
                      ),
                      // 编辑工具栏
                      Row(
                        children: [
                          // 撤销按钮
                          Obx(() => IconButton(
                            onPressed: controller.canUndo.value
                                ? controller.undo
                                : null,
                            icon: const Icon(Icons.undo),
                            tooltip: '撤销',
                            color: controller.canUndo.value
                                ? Colors.blue
                                : Colors.grey,
                          )),
                          // 重做按钮
                          Obx(() => IconButton(
                            onPressed: controller.canRedo.value
                                ? controller.redo
                                : null,
                            icon: const Icon(Icons.redo),
                            tooltip: '重做',
                            color: controller.canRedo.value
                                ? Colors.blue
                                : Colors.grey,
                          )),
                          if (!isSmallScreen) const SizedBox(width: 16),
                          // 保存状态 - 仅在大屏幕上显示
                          if (!isSmallScreen)
                            Obx(() => AnimatedOpacity(
                              opacity: controller.lastSaveTime.value.isEmpty ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                '上次保存: ${controller.lastSaveTime.value}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // AI顾问 - 仅在大屏幕上显示
          if (!isSmallScreen)
            const SizedBox(
              width: 300,
              child: AIAdvisor(),
            ),
        ],
      ),
      // 在小屏幕上添加浮动按钮来打开大纲和AI顾问
      floatingActionButton: isSmallScreen ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // AI顾问按钮
              FloatingActionButton(
                heroTag: 'ai_advisor',
                onPressed: () => scaffoldKey.currentState?.openEndDrawer(),  // 使用 scaffoldKey
                child: const Icon(Icons.lightbulb_outline),
              ),
              const SizedBox(height: 16),
              // 大纲按钮
              FloatingActionButton(
                heroTag: 'outline',
                onPressed: () => scaffoldKey.currentState?.openDrawer(),  // 使用 scaffoldKey
                child: const Icon(Icons.list),
              ),
            ],
          ),
        ],
      ) : null,
    );
  }
} 