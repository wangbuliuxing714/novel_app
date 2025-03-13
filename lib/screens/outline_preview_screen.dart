import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OutlinePreviewScreen extends StatefulWidget {
  final String outline;
  final String title;
  final Function()? onContinue;
  final Function(String)? onOutlineConfirmed;

  const OutlinePreviewScreen({
    Key? key,
    required this.outline,
    this.title = '',
    this.onContinue,
    this.onOutlineConfirmed,
  }) : super(key: key);

  @override
  State<OutlinePreviewScreen> createState() => _OutlinePreviewScreenState();
}

class _OutlinePreviewScreenState extends State<OutlinePreviewScreen> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.outline);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isNotEmpty ? '《${widget.title}》大纲预览' : '大纲预览'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                // 保存修改
                if (widget.onOutlineConfirmed != null) {
                  widget.onOutlineConfirmed!(_controller.text);
                }
                setState(() => _isEditing = false);
              } else {
                // 进入编辑模式
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: _isEditing
                  ? TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '在此编辑大纲内容...',
                      ),
                    )
                  : SingleChildScrollView(
                      child: Text(
                        _controller.text,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _isEditing = true);
                    },
                    child: const Text('修改大纲'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (widget.onContinue != null) {
                        widget.onContinue!();
                      }
                      // 关闭当前页面
                      Get.back();
                    },
                    child: const Text('确认并继续'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
} 