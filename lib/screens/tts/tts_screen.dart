import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/novel_controller.dart';
import 'package:novel_app/controllers/tts_controller.dart';
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/api_config_controller.dart';

class TTSScreen extends StatelessWidget {
  final novelController = Get.find<NovelController>();
  final ttsController = Get.find<TTSController>();
  
  // 用于自定义文本输入的控制器
  final customTextController = TextEditingController();
  
  TTSScreen({super.key});

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('使用帮助'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '基本使用步骤：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text('1. 选择小说或输入自定义文本'),
              Text('2. 选择音色（预置或自定义）'),
              Text('3. 调整语速和音量'),
              Text('4. 点击"开始转换"'),
              SizedBox(height: 16),
              Text(
                '注意事项：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text('• 转换时需要保持网络连接'),
              Text('• 软文本会自动分段处理'),
              Text('• 转换完成后可直接播放或下载'),
              Text('• 支持传输播放和章节切换'),
              SizedBox(height: 16),
              Text(
                '音色设置：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text('• 预置音色：直接选择使用'),
              Text('• 自定义音色：需要上传参考音频'),
              Text('• 可保存常用音色设置'),
              SizedBox(height: 16),
              Text(
                '播放控制：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text('• 支持暂停/继续播放'),
              Text('• 可调节播放进度'),
              Text('• 支持音量实时调节'),
              Text('• 可切换上下章节'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文字转语音'),
        actions: [
          // 添加帮助按钮
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '使用帮助',
            onPressed: () => _showHelpDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'API配置',
            onPressed: () => _showApiConfigDialog(context),
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧章节列表区域
          Expanded(
            flex: 2,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 搜索框
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '搜索章节',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        // TODO: 实现搜索功能
                      },
                    ),
                  ),
                  // 小说选择下拉框
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Obx(() => DropdownButtonFormField<Novel>(
                      decoration: InputDecoration(
                        labelText: '选择小说',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: novelController.novels.map((novel) {
                        return DropdownMenuItem(
                          value: novel,
                          child: Text(novel.title),
                        );
                      }).toList(),
                      onChanged: (novel) {
                        if (novel != null) {
                          ttsController.selectNovel(novel);
                        }
                      },
                    )),
                  ),
                  // 章节列表
                  Expanded(
                    child: Obx(() => ListView.builder(
                      itemCount: ttsController.selectedNovel.value?.chapters.length ?? 0,
                      itemBuilder: (context, index) {
                        final chapter = ttsController.selectedNovel.value?.chapters[index];
                        if (chapter == null) return const SizedBox();
                        return Obx(() => CheckboxListTile(
                          title: Text('第${chapter.number}章：${chapter.title}'),
                          value: ttsController.selectedChapters.contains(chapter),
                          onChanged: (checked) {
                            if (checked == true) {
                              ttsController.addSelectedChapter(chapter);
                            } else {
                              ttsController.removeSelectedChapter(chapter);
                            }
                          },
                        ));
                      },
                    )),
                  ),
                ],
              ),
            ),
          ),
          // 右侧控制区域
          Expanded(
            flex: 3,
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 自定义文本输入区域
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: '自定义文本',
                        hintText: '在此输入要朗读的文本...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: ttsController.setCustomText,
                    ),
                  ),
                  // 语音设置区域
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 音色选择
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: '选择音色',
                                  border: OutlineInputBorder(),
                                ),
                                value: ttsController.selectedVoice.value,
                                items: ttsController.availableVoices.map((voice) {
                                  return DropdownMenuItem(
                                    value: voice,
                                    child: Text(voice),
                                  );
                                }).toList(),
                                onChanged: (voice) {
                                  if (voice != null) {
                                    ttsController.setVoice(voice);
                                    ttsController.clearCustomVoice();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('自定义音色'),
                              onPressed: () => _showCustomVoiceDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 语速调节
                        Row(
                          children: [
                            const Text('语速：'),
                            Expanded(
                              child: Obx(() => Slider(
                                value: ttsController.speed.value,
                                min: 0.5,
                                max: 2.0,
                                divisions: 30,
                                label: ttsController.speed.value.toStringAsFixed(1),
                                onChanged: ttsController.setSpeed,
                              )),
                            ),
                          ],
                        ),
                        // 音量调节
                        Row(
                          children: [
                            const Text('音量：'),
                            Expanded(
                              child: Obx(() => Slider(
                                value: ttsController.volume.value,
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                label: (ttsController.volume.value * 100).toStringAsFixed(0),
                                onChanged: ttsController.setVolume,
                              )),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 播放控制区域
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        // 进度条
                        Obx(() => LinearProgressIndicator(
                          value: ttsController.currentProgress.value,
                        )),
                        const SizedBox(height: 16),
                        // 播放控制按钮
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              onPressed: ttsController.previousChapter,
                            ),
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              onPressed: () => ttsController.seekTo(
                                (ttsController.currentPosition ?? Duration.zero) - 
                                const Duration(seconds: 10),
                              ),
                            ),
                            Obx(() => IconButton(
                              icon: Icon(
                                ttsController.isPlaying.value 
                                    ? Icons.pause_circle_filled 
                                    : Icons.play_circle_filled,
                                size: 48,
                              ),
                              onPressed: () {
                                if (ttsController.isPlaying.value) {
                                  ttsController.pauseAudio();
                                } else {
                                  ttsController.resumeAudio();
                                }
                              },
                            )),
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              onPressed: () => ttsController.seekTo(
                                (ttsController.currentPosition ?? Duration.zero) + 
                                const Duration(seconds: 10),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              onPressed: ttsController.nextChapter,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 转换按钮
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (ttsController.selectedChapters.isNotEmpty) {
                          ttsController.convertChaptersToSpeech(ttsController.selectedChapters);
                        } else if (ttsController.customText.isNotEmpty) {
                          ttsController.convertCustomTextToSpeech(ttsController.customText.value);
                        } else {
                          Get.snackbar('提示', '请选择章节或输入自定义文本');
                        }
                      },
                      icon: const Icon(Icons.transform),
                      label: const Text('开始转换'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  // 底部工具栏
                  BottomAppBar(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.file_download),
                          label: const Text('下载音频'),
                          onPressed: ttsController.downloadAudio,
                        ),
                        Obx(() => Text(
                          '已选择 ${ttsController.selectedChapters.length} 个章节',
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 添加API配置对话框方法
  void _showApiConfigDialog(BuildContext context) {
    final apiConfigController = Get.find<ApiConfigController>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文本转语音API配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => TextField(
              controller: TextEditingController(
                text: apiConfigController.ttsApiKey.value,
              ),
              decoration: const InputDecoration(
                labelText: 'API密钥',
                hintText: '请输入硅基流动API密钥',
                border: OutlineInputBorder(),
              ),
              onChanged: apiConfigController.setTTSApiKey,
            )),
            const SizedBox(height: 16),
            const Text(
              '提示：请访问 siliconflow.com 获取API密钥',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Get.snackbar('成功', 'API配置已保存');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // 添加自定义音色对话框方法
  void _showCustomVoiceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final textController = TextEditingController();
    final usePresetVoice = true.obs;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义音色设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 选择音色类型
              Obx(() => Column(
                children: [
                  RadioListTile<bool>(
                    title: const Text('使用预置音色'),
                    subtitle: const Text('适用于已在硅基流动平台上传并训练好的音色'),
                    value: true,
                    groupValue: usePresetVoice.value,
                    onChanged: (value) => usePresetVoice.value = value!,
                  ),
                  RadioListTile<bool>(
                    title: const Text('使用动态音色'),
                    subtitle: const Text('使用自己的音频作为参考，实时生成相似音色'),
                    value: false,
                    groupValue: usePresetVoice.value,
                    onChanged: (value) => usePresetVoice.value = value!,
                  ),
                ],
              )),
              const Divider(),
              const SizedBox(height: 16),
              
              // 预置音色说明
              Obx(() => usePresetVoice.value ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '预置音色使用说明：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. 访问 https://cloud.siliconflow.cn\n'
                    '2. 注册/登录账号\n'
                    '3. 上传音频文件并训练音色\n'
                    '4. 获取音色ID，格式如下：\n'
                    '   speech:your-voice-name:cm02xxx:mttkxxx',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '音色ID',
                      hintText: 'speech:your-voice-name:cm02xxx:mttkxxx',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ) : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '动态音色使用说明：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. 准备一段清晰的参考音频（5-10秒最佳）\n'
                    '2. 将音频上传到网络获取URL，或转为base64\n'
                    '3. 输入音频对应的文字内容\n'
                    '4. 系统将实时模仿该音频的音色特征',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: '参考音频URL',
                      hintText: 'https://example.com/audio.mp3 或 base64字符串',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: '参考音频文本',
                      hintText: '输入参考音频中说的具体内容',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (usePresetVoice.value) {
                if (nameController.text.isEmpty) {
                  Get.snackbar('错误', '请输入音色ID');
                  return;
                }
                ttsController.setCustomVoice(
                  name: nameController.text,
                  url: '',
                  text: '',
                );
              } else {
                if (urlController.text.isEmpty || textController.text.isEmpty) {
                  Get.snackbar('错误', '请填写参考音频URL和文本');
                  return;
                }
                ttsController.setCustomVoice(
                  name: '',
                  url: urlController.text,
                  text: textController.text,
                );
              }
              Navigator.pop(context);
              Get.snackbar('成功', '自定义音色已设置');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
} 