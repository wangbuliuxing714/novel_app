import 'package:get/get.dart';
import 'package:novel_app/models/character_type.dart';
import 'package:novel_app/services/character_type_service.dart';

class CharacterTypeController extends GetxController {
  final CharacterTypeService _service = Get.find<CharacterTypeService>();
  
  final RxList<CharacterType> characterTypes = <CharacterType>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    loadCharacterTypes();
  }
  
  void loadCharacterTypes() {
    characterTypes.value = _service.getCharacterTypes();
  }
  
  void addCharacterType(CharacterType type) {
    _service.addCharacterType(type);
    loadCharacterTypes();
  }
  
  void updateCharacterType(CharacterType type) {
    _service.updateCharacterType(type);
    loadCharacterTypes();
  }
  
  void deleteCharacterType(String id) {
    _service.deleteCharacterType(id);
    loadCharacterTypes();
  }
} 