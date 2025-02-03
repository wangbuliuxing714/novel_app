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
              '通义千问API获取教程',
              [
                '1. 访问阿里云官网：https://www.aliyun.com',
                '2. 注册/登录阿里云账号',
                '3. 搜索"通义千问"，进入产品页面',
                '4. 点击"立即开通"，开通服务',
                '5. 进入"通义千问API"控制台',
                '6. 创建新的API Key：',
                '   - 点击"创建API Key"按钮',
                '   - 填写名称和描述',
                '   - 选择使用场景',
                '   - 确认创建',
                '7. 复制API Key：',
                '   - 在API Key列表中找到刚创建的Key',
                '   - 点击"查看"按钮',
                '   - 复制API Key字符串',
                '8. 在本应用的设置中：',
                '   - 选择"通义千问"作为AI模型',
                '   - 粘贴API Key',
                '   - 保存设置',
                '注意事项：',
                '• API Key属于敏感信息，请勿泄露给他人',
                '• 首次使用有免费额度',
                '• 超出免费额度后需要充值',
                '• 可以在控制台查看使用量和余额',
              ],
            ),
            _buildSection(
              '基本功能说明',
              [
                '1. 小说生成：',
                '   • 填写小说标题和设定',
                '   • 选择小说类型和风格',
                '   • 设置章节数量',
                '   • 点击"开始生成"',
                '',
                '2. 章节管理：',
                '   • 查看已生成的章节',
                '   • 编辑章节内容',
                '   • 删除单个章节',
                '   • 清空所有章节',
                '',
                '3. 草稿本功能：',
                '   • 创建和管理草稿',
                '   • 自动保存内容',
                '   • 使用AI修改文本',
                '',
                '4. 导出功能：',
                '   • 支持多种格式导出',
                '   • 自动保存到下载目录',
                '',
                '5. 阅读设置：',
                '   • 护眼模式',
                '   • 背景颜色选择',
                '   • 色温调节',
              ],
            ),
            _buildSection(
              '常见问题',
              [
                'Q: 生成速度较慢怎么办？',
                'A: 生成速度受网络和API响应速度影响，建议耐心等待。',
                '',
                'Q: 内容审核未通过怎么办？',
                'A: 修改设定中可能违规的内容，重新生成。',
                '',
                'Q: 如何获得更好的生成效果？',
                'A: 提供详细的角色设定和故事背景，选择合适的写作风格。',
                '',
                'Q: 数据会丢失吗？',
                'A: 所有内容都会自动保存，建议及时导出重要内容。',
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _launchURL('https://help.aliyun.com/document_detail/2399480.html'),
              child: const Text('查看通义千问API详细文档'),
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