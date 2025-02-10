import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:novel_app/controllers/theme_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('岱宗文脉 - 使用帮助'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '岱宗文脉 - 承载文学梦想的摇篮',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '汲取泰山灵气，传承文学精髓，助您开启文学创作之旅。',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            _buildSection(
              'API获取说明',
              [
                '请访问以下网盘链接获取API配置文件：',
                'https://pan.baidu.com/s/xxxxx',
                '提取码：xxxx',
                '',
                '文件包含：',
                '• 通义千问API配置说明',
                '• 硅基流动API配置说明',
                '• API使用教程',
                '',
                '注意事项：',
                '• API密钥属于敏感信息，请勿泄露',
                '• 请遵守相关平台的使用规范',
                '• 如遇问题请参考配置文档',
              ],
            ),
            _buildSection(
              '主要功能',
              [
                '1. 小说创作：',
                '   • AI辅助创作，支持多种风格',
                '   • 大纲生成与管理',
                '   • 角色卡设定',
                '   • 章节续写功能',
                '',
                '2. 文本转语音：',
                '   • 支持整本小说朗读',
                '   • 自定义音色设置',
                '   • 语速音量调节',
                '   • 音频导出功能',
                '',
                '3. 草稿本功能：',
                '   • 实时保存',
                '   • AI润色修改',
                '   • 多设备同步',
                '',
                '4. 书库管理：',
                '   • 作品分类整理',
                '   • 导出多种格式',
                '   • 阅读进度记录',
              ],
            ),
            _buildSection(
              '使用指南',
              [
                '1. 创作新小说：',
                '   • 点击首页"新建小说"',
                '   • 填写基本信息和设定',
                '   • 选择创作风格和类型',
                '   • 开始AI辅助创作',
                '',
                '2. 续写功能：',
                '   • 在小说详情页点击"续写"',
                '   • 查看当前大纲',
                '   • 输入续写提示',
                '   • 选择生成章节数量',
                '',
                '3. 语音转换：',
                '   • 进入语音工具',
                '   • 选择小说或输入文本',
                '   • 设置音色和参数',
                '   • 开始转换并试听',
                '',
                '4. 作品导出：',
                '   • 支持TXT、PDF、HTML格式',
                '   • 可选择导出章节范围',
                '   • 支持音频导出',
              ],
            ),
            _buildSection(
              '常见问题',
              [
                'Q: 如何获取API密钥？',
                'A: 请查看网盘中的API配置文档，按步骤申请。',
                '',
                'Q: 生成速度较慢？',
                'A: 受网络和API响应影响，请耐心等待。',
                '',
                'Q: 如何提升生成质量？',
                'A: 提供详细的设定和提示，选择合适的写作风格。',
                '',
                'Q: 数据会丢失吗？',
                'A: 所有内容都会自动保存，建议及时导出备份。',
                '',
                'Q: 支持哪些音色？',
                'A: 支持预置音色和自定义音色，可参考音色设置说明。',
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '如有其他问题，请联系开发者获取支持',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> contents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...contents.map((content) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        )),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      Get.snackbar('错误', '无法打开链接');
    }
  }
} 