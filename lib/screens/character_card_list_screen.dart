import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/character_card.dart';
import '../services/character_card_service.dart';
import 'character_card_edit_screen.dart';

class CharacterCardListScreen extends StatelessWidget {
  final CharacterCardService _cardService = Get.find<CharacterCardService>();

  CharacterCardListScreen({Key? key}) : super(key: key);

  void _addNewCard() {
    Get.to(() => const CharacterCardEditScreen());
  }

  void _editCard(CharacterCard card) {
    Get.to(() => CharacterCardEditScreen(card: card));
  }

  Future<void> _deleteCard(CharacterCard card) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除角色"${card.name}"吗？'),
        actions: [
          TextButton(
            child: const Text('取消'),
            onPressed: () => Get.back(result: false),
          ),
          TextButton(
            child: const Text('删除'),
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cardService.deleteCard(card.id);
    }
  }

  Widget _buildCardItem(CharacterCard card) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          card.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (card.gender != null && card.gender!.isNotEmpty)
              Text('性别: ${card.gender}'),
            if (card.age != null && card.age!.isNotEmpty)
              Text('年龄: ${card.age}'),
            if (card.race != null && card.race!.isNotEmpty)
              Text('种族: ${card.race}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editCard(card),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteCard(card),
            ),
          ],
        ),
        onTap: () => _showCardDetails(card),
      ),
    );
  }

  void _showCardDetails(CharacterCard card) {
    Get.dialog(
      AlertDialog(
        title: Text(card.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailSection('基本信息', [
                if (card.gender != null) '性别: ${card.gender}',
                if (card.age != null) '年龄: ${card.age}',
                if (card.race != null) '种族: ${card.race}',
              ]),
              _buildDetailSection('外貌特征', [
                if (card.bodyDescription != null) '体型: ${card.bodyDescription}',
                if (card.faceFeatures != null) '面部特征: ${card.faceFeatures}',
                if (card.clothingStyle != null) '服装风格: ${card.clothingStyle}',
                if (card.accessories != null) '配饰: ${card.accessories}',
              ]),
              _buildDetailSection('性格特征', [
                if (card.personalityTraits != null) '主要性格: ${card.personalityTraits}',
                if (card.personalityComplexity != null) '性格复杂性: ${card.personalityComplexity}',
                if (card.personalityFormation != null) '性格形成: ${card.personalityFormation}',
              ]),
              _buildDetailSection('背景故事', [
                if (card.background != null) '背景: ${card.background}',
                if (card.lifeExperiences != null) '经历: ${card.lifeExperiences}',
                if (card.pastEvents != null) '重要事件: ${card.pastEvents}',
              ]),
              _buildDetailSection('目标和动机', [
                if (card.shortTermGoals != null) '短期目标: ${card.shortTermGoals}',
                if (card.longTermGoals != null) '长期目标: ${card.longTermGoals}',
                if (card.motivation != null) '动机: ${card.motivation}',
              ]),
              _buildDetailSection('能力和技能', [
                if (card.specialAbilities != null) '特殊能力: ${card.specialAbilities}',
                if (card.normalSkills != null) '普通技能: ${card.normalSkills}',
              ]),
              _buildDetailSection('人际关系', [
                if (card.familyRelations != null) '家庭关系: ${card.familyRelations}',
                if (card.friendships != null) '朋友关系: ${card.friendships}',
                if (card.enemies != null) '敌人: ${card.enemies}',
                if (card.loveInterests != null) '恋人/情人: ${card.loveInterests}',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('关闭'),
            onPressed: () => Get.back(),
          ),
          TextButton(
            child: const Text('编辑'),
            onPressed: () {
              Get.back();
              _editCard(card);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<String> details) {
    final filteredDetails = details.where((detail) => detail.isNotEmpty).toList();
    if (filteredDetails.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...filteredDetails.map((detail) => Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
          child: Text(detail),
        )),
        const Divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('角色卡片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewCard,
          ),
        ],
      ),
      body: Obx(
        () => _cardService.cards.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '还没有角色卡片',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addNewCard,
                      child: const Text('创建角色卡片'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _cardService.cards.length,
                itemBuilder: (context, index) {
                  return _buildCardItem(_cardService.cards[index]);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewCard,
        child: const Icon(Icons.add),
      ),
    );
  }
} 