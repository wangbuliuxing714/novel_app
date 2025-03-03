  String _getTypeDisplayName(String type) {
    final Map<String, String> typeNames = {
      'master': '主提示词',
      'outline': '大纲提示词',
      'chapter': '章节提示词',
      'target_reader': '目标读者提示词',
      'expectation': '期待感提示词',
      'character': '角色提示词',
      'short_novel': '短篇小说提示词',
    };
    return typeNames[type] ?? type;
  }
  
  List<String> _getTypeOptions() {
    return [
      'master',
      'outline',
      'chapter',
      'target_reader',
      'expectation',
      'character',
      'short_novel',
    ];
  } 