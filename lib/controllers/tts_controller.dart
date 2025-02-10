import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:novel_app/models/novel.dart';
import 'package:novel_app/controllers/api_config_controller.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

class TTSController extends GetxController {
  final ApiConfigController _apiConfig = Get.find<ApiConfigController>();
  final _player = AudioPlayer();
  
  // 基本状态
  final isConverting = false.obs;
  final currentProgress = 0.0.obs;
  final isPlaying = false.obs;
  final currentAudioPath = ''.obs;

  // 选择状态
  final selectedNovel = Rx<Novel?>(null);
  final selectedChapters = <Chapter>[].obs;
  final customText = ''.obs;
  
  // 语音设置
  final selectedVoice = 'alex'.obs;
  final speed = 1.0.obs;
  final volume = 1.0.obs;
  
  // 播放状态
  final currentChapterIndex = 0.obs;
  
  // 可用音色列表
  final availableVoices = [
    'alex',
    'anna',
    'bella',
    'benjamin',
    'charles',
    'claire',
    'david',
    'diana',
  ].obs;

  // 添加自定义音色相关的变量
  final customVoiceName = ''.obs;
  final customVoiceUrl = ''.obs;
  final customVoiceText = ''.obs;
  final isUsingCustomVoice = false.obs;

  static const String _baseUrl = 'https://api.siliconflow.cn/v1';
  static const String _defaultModel = 'FunAudioLLM/CosyVoice2-0.5B';

  void selectNovel(Novel novel) {
    selectedNovel.value = novel;
    selectedChapters.clear();
  }

  void addSelectedChapter(Chapter chapter) {
    selectedChapters.add(chapter);
    selectedChapters.sort((a, b) => a.number.compareTo(b.number));
  }

  void removeSelectedChapter(Chapter chapter) {
    selectedChapters.remove(chapter);
  }

  void setCustomText(String text) {
    customText.value = text;
  }

  void setVoice(String voice) {
    selectedVoice.value = voice;
  }

  void setSpeed(double value) {
    speed.value = value;
  }

  void setVolume(double value) {
    volume.value = value;
    _player.setVolume(value);
  }

  Future<void> startPlayback() async {
    if (selectedChapters.isEmpty && customText.isEmpty) {
      Get.snackbar('提示', '请选择章节或输入文本');
      return;
    }

    if (!isConverting.value) {
      if (selectedChapters.isNotEmpty) {
        await convertChaptersToSpeech(selectedChapters);
      } else {
        await convertCustomTextToSpeech(customText.value);
      }
    } else {
      await resumeAudio();
    }
  }

  Future<void> convertCustomTextToSpeech(String text) async {
    if (text.isEmpty) {
      Get.snackbar('提示', '请输入要转换的文本');
      return;
    }

    try {
      isConverting.value = true;
      currentProgress.value = 0;

      final apiKey = _apiConfig.ttsApiKey;
      if (apiKey.isEmpty) {
        throw '请先在设置中配置文本转语音API密钥';
      }

      final segments = _splitTextIntoSegments(text);
      final allAudioData = <int>[];

      for (var i = 0; i < segments.length; i++) {
        final payload = {
          'model': _defaultModel,
          'voice': isUsingCustomVoice.value ? customVoiceName.value : '${_defaultModel}:${selectedVoice.value}',
          'input': segments[i],
          'response_format': 'mp3',
          'speed': speed.value,
        };

        // 如果使用动态音色，添加extra_body
        if (isUsingCustomVoice.value && customVoiceUrl.isNotEmpty) {
          payload['extra_body'] = {
            'references': [
              {
                'audio': customVoiceUrl.value,
                'text': customVoiceText.value,
              }
            ]
          };
        }

        final headers = {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        };

        final response = await http.post(
          Uri.parse('$_baseUrl/audio/speech'),
          headers: headers,
          body: jsonEncode(payload),
        );

        if (response.statusCode != 200) {
          throw '转换失败：${response.statusCode} - ${response.body}';
        }

        allAudioData.addAll(response.bodyBytes);
        currentProgress.value = (i + 1) / segments.length;
        
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final audioPath = await _saveAudioFile(allAudioData, 'custom_text');
      currentAudioPath.value = audioPath;
      
      await playAudio(audioPath);
      
      Get.snackbar('成功', '转换完成，开始播放');
    } catch (e) {
      Get.snackbar('错误', e.toString());
    } finally {
      isConverting.value = false;
      currentProgress.value = 0;
    }
  }

  Future<void> convertChaptersToSpeech(List<Chapter> chapters) async {
    if (isConverting.value) {
      Get.snackbar('提示', '正在转换中，请稍后再试');
      return;
    }

    try {
      isConverting.value = true;
      currentProgress.value = 0;

      final apiKey = _apiConfig.ttsApiKey;
      if (apiKey.isEmpty) {
        throw '请先在设置中配置文本转语音API密钥';
      }

      final allAudioData = <int>[];
      var totalChapters = chapters.length;
      
      for (var i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final segments = _splitTextIntoSegments(chapter.content);
        
        for (var j = 0; j < segments.length; j++) {
          final payload = {
            'model': _defaultModel,
            'voice': '${_defaultModel}:${selectedVoice.value}',
            'input': segments[j],
            'response_format': 'mp3',
            'speed': speed.value,
          };

          final headers = {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          };

          final response = await http.post(
            Uri.parse('$_baseUrl/audio/speech'),
            headers: headers,
            body: jsonEncode(payload),
          );

          if (response.statusCode != 200) {
            throw '转换失败：${response.statusCode} - ${response.body}';
          }

          allAudioData.addAll(response.bodyBytes);
          currentProgress.value = (i + (j + 1) / segments.length) / totalChapters;
          
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      final title = '${chapters.first.number}-${chapters.last.number}章';
      final audioPath = await _saveAudioFile(allAudioData, title);
      currentAudioPath.value = audioPath;
      
      await playAudio(audioPath);
      
      Get.snackbar('成功', '转换完成，开始播放');
    } catch (e) {
      Get.snackbar('错误', e.toString());
    } finally {
      isConverting.value = false;
      currentProgress.value = 0;
    }
  }

  List<String> _splitTextIntoSegments(String text, {int maxLength = 300}) {
    final segments = <String>[];
    final sentences = text.split(RegExp(r'[。！？.!?]'));
    
    String currentSegment = '';
    
    for (var sentence in sentences) {
      if (sentence.trim().isEmpty) continue;
      
      if (currentSegment.length + sentence.length > maxLength) {
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment.trim());
        }
        currentSegment = sentence;
      } else {
        currentSegment += sentence;
      }
    }
    
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment.trim());
    }
    
    return segments;
  }

  Future<String> _saveAudioFile(List<int> audioData, String title) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(path.join(appDir.path, 'audio'));
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${title}_$timestamp.mp3';
      final filePath = path.join(audioDir.path, fileName);

      final file = File(filePath);
      await file.writeAsBytes(audioData);

      return filePath;
    } catch (e) {
      throw '保存音频文件失败：$e';
    }
  }

  Future<void> playAudio(String audioPath) async {
    try {
      await _player.setFilePath(audioPath);
      await _player.setVolume(volume.value);
      await _player.play();
      isPlaying.value = true;
      
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          isPlaying.value = false;
        }
      });
    } catch (e) {
      Get.snackbar('错误', '播放失败：$e');
    }
  }

  Future<void> pauseAudio() async {
    await _player.pause();
    isPlaying.value = false;
  }

  Future<void> resumeAudio() async {
    await _player.play();
    isPlaying.value = true;
  }

  Future<void> stopAudio() async {
    await _player.stop();
    isPlaying.value = false;
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  void previousChapter() {
    if (currentChapterIndex.value > 0) {
      currentChapterIndex.value--;
      // TODO: 实现切换到上一章
    }
  }

  void nextChapter() {
    if (currentChapterIndex.value < selectedChapters.length - 1) {
      currentChapterIndex.value++;
      // TODO: 实现切换到下一章
    }
  }

  Future<void> downloadAudio() async {
    if (currentAudioPath.isEmpty) {
      Get.snackbar('提示', '没有可下载的音频文件');
      return;
    }

    try {
      final file = File(currentAudioPath.value);
      if (await file.exists()) {
        await Share.shareXFiles([XFile(file.path)], text: '分享音频文件');
      } else {
        Get.snackbar('错误', '音频文件不存在');
      }
    } catch (e) {
      Get.snackbar('错误', '下载失败：$e');
    }
  }

  Duration? get currentPosition => _player.position;
  Duration? get totalDuration => _player.duration;
  Stream<Duration?> get positionStream => _player.positionStream;

  // 添加设置自定义音色的方法
  void setCustomVoice({
    required String name,
    required String url,
    required String text,
  }) {
    customVoiceName.value = name;
    customVoiceUrl.value = url;
    customVoiceText.value = text;
    isUsingCustomVoice.value = true;
  }

  void clearCustomVoice() {
    customVoiceName.value = '';
    customVoiceUrl.value = '';
    customVoiceText.value = '';
    isUsingCustomVoice.value = false;
  }

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }
} 