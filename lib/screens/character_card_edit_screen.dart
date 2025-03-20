import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../models/character_card.dart';
import '../services/character_card_service.dart';

class CharacterCardEditScreen extends StatefulWidget {
  final CharacterCard? card;

  const CharacterCardEditScreen({Key? key, this.card}) : super(key: key);

  @override
  _CharacterCardEditScreenState createState() => _CharacterCardEditScreenState();
}

class _CharacterCardEditScreenState extends State<CharacterCardEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardService = Get.find<CharacterCardService>();
  late final TextEditingController _nameController;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.card?.name ?? '');
    _initControllers();
  }

  void _initControllers() {
    final fields = [
      'gender', 'age', 'race', 'bodyDescription', 'faceFeatures',
      'clothingStyle', 'accessories', 'personalityTraits',
      'personalityComplexity', 'personalityFormation', 'background',
      'lifeExperiences', 'pastEvents', 'shortTermGoals', 'longTermGoals',
      'motivation', 'specialAbilities', 'normalSkills', 'familyRelations',
      'friendships', 'enemies', 'loveInterests'
    ];

    for (var field in fields) {
      _controllers[field] = TextEditingController(
        text: widget.card != null ? widget.card!.toJson()[field] as String? ?? '' : ''
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    final card = CharacterCard(
      id: widget.card?.id ?? const Uuid().v4(),
      name: _nameController.text,
      characterTypeId: widget.card?.characterTypeId ?? const Uuid().v4(),
      gender: _controllers['gender']!.text,
      age: _controllers['age']!.text,
      race: _controllers['race']!.text,
      bodyDescription: _controllers['bodyDescription']!.text,
      faceFeatures: _controllers['faceFeatures']!.text,
      clothingStyle: _controllers['clothingStyle']!.text,
      accessories: _controllers['accessories']!.text,
      personalityTraits: _controllers['personalityTraits']!.text,
      personalityComplexity: _controllers['personalityComplexity']!.text,
      personalityFormation: _controllers['personalityFormation']!.text,
      background: _controllers['background']!.text,
      lifeExperiences: _controllers['lifeExperiences']!.text,
      pastEvents: _controllers['pastEvents']!.text,
      shortTermGoals: _controllers['shortTermGoals']!.text,
      longTermGoals: _controllers['longTermGoals']!.text,
      motivation: _controllers['motivation']!.text,
      specialAbilities: _controllers['specialAbilities']!.text,
      normalSkills: _controllers['normalSkills']!.text,
      familyRelations: _controllers['familyRelations']!.text,
      friendships: _controllers['friendships']!.text,
      enemies: _controllers['enemies']!.text,
      loveInterests: _controllers['loveInterests']!.text,
    );

    if (widget.card == null) {
      await _cardService.addCard(card);
    } else {
      await _cardService.updateCard(card);
    }

    Get.back(result: true);
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        maxLines: label == '姓名' ? 1 : 3,
        validator: required ? (value) {
          if (value == null || value.isEmpty) {
            return '请输入$label';
          }
          return null;
        } : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.card == null ? '创建角色卡片' : '编辑角色卡片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('基本信息', [
                  _buildTextField('姓名', _nameController, required: true),
                  _buildTextField('性别', _controllers['gender']!),
                  _buildTextField('年龄', _controllers['age']!),
                  _buildTextField('种族', _controllers['race']!),
                ]),
                _buildSection('外貌特征', [
                  _buildTextField('体型描述', _controllers['bodyDescription']!),
                  _buildTextField('面部特征', _controllers['faceFeatures']!),
                  _buildTextField('服装风格', _controllers['clothingStyle']!),
                  _buildTextField('标志性配饰', _controllers['accessories']!),
                ]),
                _buildSection('性格特征', [
                  _buildTextField('主要性格', _controllers['personalityTraits']!),
                  _buildTextField('性格复杂性', _controllers['personalityComplexity']!),
                  _buildTextField('性格形成原因', _controllers['personalityFormation']!),
                ]),
                _buildSection('背景故事', [
                  _buildTextField('成长背景', _controllers['background']!),
                  _buildTextField('人生经历', _controllers['lifeExperiences']!),
                  _buildTextField('重要事件', _controllers['pastEvents']!),
                ]),
                _buildSection('目标和动机', [
                  _buildTextField('短期目标', _controllers['shortTermGoals']!),
                  _buildTextField('长期目标', _controllers['longTermGoals']!),
                  _buildTextField('动机', _controllers['motivation']!),
                ]),
                _buildSection('能力和技能', [
                  _buildTextField('特殊能力', _controllers['specialAbilities']!),
                  _buildTextField('普通技能', _controllers['normalSkills']!),
                ]),
                _buildSection('人际关系', [
                  _buildTextField('家庭关系', _controllers['familyRelations']!),
                  _buildTextField('朋友关系', _controllers['friendships']!),
                  _buildTextField('敌人', _controllers['enemies']!),
                  _buildTextField('恋人/情人', _controllers['loveInterests']!),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        const Divider(height: 32),
      ],
    );
  }
} 