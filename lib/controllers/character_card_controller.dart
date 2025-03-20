import 'package:get/get.dart';
import 'package:novel_app/models/character_card.dart';
import 'package:novel_app/services/character_card_service.dart';

class CharacterCardController extends GetxController {
  final CharacterCardService _service = Get.find<CharacterCardService>();
  
  final RxList<CharacterCard> characterCards = <CharacterCard>[].obs;
  
  @override
  void onInit() {
    super.onInit();
    loadCharacterCards();
  }
  
  void loadCharacterCards() {
    characterCards.value = _service.getCharacterCards();
  }
  
  void addCharacterCard(CharacterCard card) {
    _service.addCharacterCard(card);
    loadCharacterCards();
  }
  
  void updateCharacterCard(CharacterCard card) {
    _service.updateCharacterCard(card);
    loadCharacterCards();
  }
  
  void deleteCharacterCard(String id) {
    _service.deleteCharacterCard(id);
    loadCharacterCards();
  }
}