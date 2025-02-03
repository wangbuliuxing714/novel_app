import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:intl/intl.dart';
import 'package:novel_app/controllers/main_screen_controller.dart';

class NovelListScreen extends StatelessWidget {
  final novelController = Get.find<NovelController>();

  NovelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的作品'),
      ),
      body: Obx(() {
        if (novelController.novels.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('还没有作品'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Get.find<MainScreenController>().changePage(1),
                  child: const Text('开始创作'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: novelController.novels.length,
          itemBuilder: (context, index) {
            final novel = novelController.novels[index];
            return NovelCard(novel: novel);
          },
        );
      }),
    );
  }
}

class NovelCard extends StatelessWidget {
  final Novel novel;

  const NovelCard({super.key, required this.novel});

  Color _getStatusColor() {
    switch (novel.status) {
      case Novel.STATUS_GENERATING:
        return Colors.orange;
      case Novel.STATUS_COMPLETED:
        return Colors.green;
      case Novel.STATUS_FAILED:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (novel.status) {
      case Novel.STATUS_GENERATING:
        return '生成中';
      case Novel.STATUS_COMPLETED:
        return '已完成';
      case Novel.STATUS_FAILED:
        return '生成失败';
      default:
        return '未知状态';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Get.toNamed('/novel_detail', arguments: novel);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      novel.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                novel.prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${novel.style} · ${novel.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(novel.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}