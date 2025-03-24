import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:novel_app/services/conversation_manager.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ConversationDebugScreen extends StatefulWidget {
  const ConversationDebugScreen({Key? key}) : super(key: key);

  @override
  State<ConversationDebugScreen> createState() => _ConversationDebugScreenState();
}

class _ConversationDebugScreenState extends State<ConversationDebugScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取所有会话ID
    final allConversations = ConversationManager.getAllConversationIds();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('会话历史调试'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '会话列表', icon: Icon(Icons.list)),
            Tab(text: '统计仪表盘', icon: Icon(Icons.dashboard)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // 刷新会话列表
                _tabController.animateTo(_tabController.index);
              });
            },
            tooltip: '刷新会话列表',
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _exportAllConversations,
            tooltip: '导出所有会话',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 第一个标签页：会话列表
          allConversations.isEmpty 
              ? const Center(child: Text('没有找到任何会话记录', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  itemCount: allConversations.length,
                  itemBuilder: (context, index) {
                    final conversationId = allConversations[index];
                    final messages = ConversationManager.getMessages(conversationId);
                    final conversationType = _getConversationType(conversationId);
                    
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ExpansionTile(
                        title: Text(
                          '会话ID: $conversationId',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('类型: $conversationType'),
                            Text('消息数量: ${messages.length}'),
                            _buildStatsRow(conversationId),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.delete),
                                  label: const Text('删除会话'),
                                  onPressed: () {
                                    _confirmDeleteConversation(context, conversationId);
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.copy),
                                  label: const Text('复制ID'),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: conversationId));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('会话ID已复制到剪贴板')),
                                    );
                                  },
                                ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text('导出'),
                                  onPressed: () {
                                    _exportConversation(conversationId);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: messages.length,
                            itemBuilder: (context, msgIndex) {
                              final message = messages[msgIndex];
                              final role = message['role'] as String;
                              final content = message['content'] as String;
                              
                              return ListTile(
                                title: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 4.0),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(role),
                                        borderRadius: BorderRadius.circular(4.0),
                                      ),
                                      child: Text(role, 
                                        style: const TextStyle(
                                          color: Colors.white, 
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Text('#$msgIndex'),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: content));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('消息内容已复制到剪贴板')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                subtitle: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4.0),
                                  ),
                                  child: Text(
                                    content.length > 300 
                                      ? '${content.substring(0, 300)}...'
                                      : content,
                                    style: const TextStyle(fontSize: 12.0),
                                  ),
                                ),
                                onTap: () {
                                  _showFullMessage(context, role, content);
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
          
          // 第二个标签页：统计仪表盘
          _buildDashboard(allConversations),
        ],
      ),
    );
  }
  
  // 构建统计仪表盘
  Widget _buildDashboard(List<String> allConversations) {
    if (allConversations.isEmpty) {
      return const Center(child: Text('没有可用的会话数据', style: TextStyle(fontSize: 16)));
    }
    
    // 汇总统计数据
    int totalConversations = allConversations.length;
    int totalMessages = 0;
    int totalSystemMessages = 0;
    int totalUserMessages = 0;
    int totalAssistantMessages = 0;
    
    // 会话类型统计
    int outlineConversations = 0;
    int regenerateConversations = 0;
    int normalConversations = 0;
    int unknownConversations = 0;
    
    for (final conversationId in allConversations) {
      final stats = ConversationManager.getConversationStats(conversationId);
      totalMessages += stats['total'] ?? 0;
      totalSystemMessages += stats['system'] ?? 0;
      totalUserMessages += stats['user'] ?? 0;
      totalAssistantMessages += stats['assistant'] ?? 0;
      
      if (conversationId.startsWith('_outline_')) {
        outlineConversations++;
      } else if (conversationId.startsWith('_regenerate_')) {
        regenerateConversations++;
      } else if (conversationId.startsWith('conv_')) {
        normalConversations++;
      } else {
        unknownConversations++;
      }
    }
    
    // 计算平均值
    double avgMessagesPerConversation = totalConversations > 0 ? totalMessages / totalConversations : 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('会话统计', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          // 总体统计卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('总体数据', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _buildStatCard('总会话数', totalConversations, Icons.forum),
                      _buildStatCard('总消息数', totalMessages, Icons.message),
                      _buildStatCard('系统消息', totalSystemMessages, Icons.settings),
                      _buildStatCard('用户消息', totalUserMessages, Icons.person),
                      _buildStatCard('助手消息', totalAssistantMessages, Icons.assistant),
                      _buildStatCard('平均消息数/会话', avgMessagesPerConversation.toStringAsFixed(1), Icons.analytics),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 会话类型统计卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('会话类型分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _buildStatCard('小说大纲会话', outlineConversations, Icons.book),
                      _buildStatCard('章节重生成会话', regenerateConversations, Icons.refresh),
                      _buildStatCard('普通会话', normalConversations, Icons.chat),
                      _buildStatCard('未知类型', unknownConversations, Icons.help),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 操作按钮
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('操作', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('清除所有会话'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          _confirmClearAllConversations(context);
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt),
                        label: const Text('导出所有会话'),
                        onPressed: () {
                          _exportAllConversations();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 构建统计信息卡片
  Widget _buildStatCard(String title, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  value.toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 获取会话类型，根据ID前缀推测
  String _getConversationType(String id) {
    if (id.startsWith('_outline_')) {
      final novelTitle = id.substring('_outline_'.length).replaceAll('_', ' ');
      return '小说大纲会话 - "$novelTitle"';
    } else if (id.startsWith('_regenerate_')) {
      return '章节重生成会话';
    } else if (id.startsWith('conv_')) {
      return '普通会话';
    } else {
      return '未知类型';
    }
  }

  // 构建统计信息行
  Widget _buildStatsRow(String conversationId) {
    final stats = ConversationManager.getConversationStats(conversationId);
    
    return Row(
      children: [
        _buildStatBadge('系统', stats['system'] ?? 0, Colors.blueGrey),
        const SizedBox(width: 8),
        _buildStatBadge('用户', stats['user'] ?? 0, Colors.blue),
        const SizedBox(width: 8),
        _buildStatBadge('助手', stats['assistant'] ?? 0, Colors.green),
      ],
    );
  }
  
  // 构建统计数字徽章
  Widget _buildStatBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 根据角色获取颜色
  Color _getRoleColor(String role) {
    switch (role) {
      case 'system':
        return Colors.blueGrey;
      case 'user':
        return Colors.blue;
      case 'assistant':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // 显示完整消息的对话框
  void _showFullMessage(BuildContext context, String role, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$role 消息详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content),
              const SizedBox(height: 16),
              Text('字符长度: ${content.length}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('消息内容已复制到剪贴板')),
              );
            },
            child: const Text('复制内容'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 删除会话前的确认对话框
  void _confirmDeleteConversation(BuildContext context, String conversationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定要删除这个会话吗？这将永久删除所有相关的历史记录，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ConversationManager.clearConversation(conversationId);
              Navigator.of(context).pop();
              setState(() {});
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
  
  // 清除所有会话确认对话框
  void _confirmClearAllConversations(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有会话'),
        content: const Text('确定要清除所有会话吗？这将永久删除所有历史记录，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ConversationManager.clearAllConversations();
              Navigator.of(context).pop();
              setState(() {});
            },
            child: const Text('清除'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  // 导出指定会话到文件
  Future<void> _exportConversation(String conversationId) async {
    try {
      final messages = ConversationManager.getMessages(conversationId);
      final conversationType = _getConversationType(conversationId);
      
      // 创建导出数据
      final exportData = {
        'conversation_id': conversationId,
        'conversation_type': conversationType,
        'messages': messages,
        'export_time': DateTime.now().toIso8601String(),
      };
      
      // 转换为JSON
      final jsonData = jsonEncode(exportData);
      
      // 保存到临时文件
      final fileName = 'conversation_${conversationId.replaceAll(':', '_')}.json';
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(jsonData);
      
      // 分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '导出会话记录 - $conversationType',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('会话导出成功')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }
  
  // 导出所有会话记录
  Future<void> _exportAllConversations() async {
    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // 获取所有会话数据
      Map<String, dynamic> allConversations = ConversationManager.exportAllConversations();
      
      // 转换为JSON格式
      String jsonData = jsonEncode(allConversations);
      
      // 获取临时目录
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/conversations_export_${DateTime.now().millisecondsSinceEpoch}.json';
      
      // 写入文件
      final file = File(filePath);
      await file.writeAsString(jsonData);
      
      // 关闭加载指示器
      Navigator.pop(context);
      
      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出成功，准备分享文件')),
      );
      
      // 分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '会话历史记录导出 - ${DateTime.now().toString()}',
      );
    } catch (e) {
      // 关闭加载指示器
      Navigator.pop(context);
      
      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }
} 