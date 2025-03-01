import 'dart:convert';
import 'package:get/get.dart';
import 'package:novel_app/prompts/genre_prompts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GenreController extends GetxController {
  final RxList<GenreCategory> categories = <GenreCategory>[].obs;
  final _prefs = Get.find<SharedPreferences>();
  final String _customGenresKey = 'custom_genres';
  
  // 默认类型列表
  final List<GenreCategory> _defaultCategories = GenrePrompts.categories;

  @override
  void onInit() {
    super.onInit();
    _loadGenres();
  }

  void _loadGenres() {
    try {
      // 首先加载默认类型
      categories.addAll(_defaultCategories);
      
      // 然后加载自定义类型
      final customGenresJson = _prefs.getString(_customGenresKey);
      if (customGenresJson != null) {
        final List<dynamic> customGenresList = jsonDecode(customGenresJson);
        final List<GenreCategory> customCategories = customGenresList
            .map((json) => GenreCategory(
                  name: json['name'],
                  genres: (json['genres'] as List)
                      .map((g) => NovelGenre(
                            name: g['name'],
                            description: g['description'],
                            prompt: g['prompt'],
                          ))
                      .toList(),
                ))
            .toList();
        categories.addAll(customCategories);
      }
    } catch (e) {
      print('加载类型失败: $e');
      // 如果加载失败，至少确保默认类型可用
      if (categories.isEmpty) {
        categories.addAll(_defaultCategories);
      }
    }
  }

  Future<void> _saveCustomGenres() async {
    try {
      final customCategories = categories
          .where((category) => !_isDefaultCategory(category.name))
          .toList();
      
      final customGenresJson = jsonEncode(customCategories
          .map((category) => {
                'name': category.name,
                'genres': category.genres
                    .map((genre) => {
                          'name': genre.name,
                          'description': genre.description,
                          'prompt': genre.prompt,
                        })
                    .toList(),
              })
          .toList());
      
      await _prefs.setString(_customGenresKey, customGenresJson);
    } catch (e) {
      print('保存类型失败: $e');
      rethrow;
    }
  }

  bool _isDefaultCategory(String categoryName) {
    return _defaultCategories.any((category) => category.name == categoryName);
  }

  bool isDefaultCategory(String categoryName) {
    return _isDefaultCategory(categoryName);
  }

  bool isDefaultGenre(String categoryName, String genreName) {
    final defaultCategory = _defaultCategories
        .firstWhereOrNull((category) => category.name == categoryName);
    if (defaultCategory == null) return false;
    return defaultCategory.genres.any((genre) => genre.name == genreName);
  }

  Future<void> addCategory(GenreCategory category) async {
    if (!categories.any((c) => c.name == category.name)) {
      categories.add(category);
      await _saveCustomGenres();
    }
  }

  Future<void> deleteCategory(int index) async {
    final category = categories[index];
    if (!_isDefaultCategory(category.name)) {
      categories.removeAt(index);
      await _saveCustomGenres();
    }
  }

  Future<void> addGenre(int categoryIndex, NovelGenre genre) async {
    if (!categories[categoryIndex].genres.any((g) => g.name == genre.name)) {
      final category = categories[categoryIndex];
      final updatedGenres = List<NovelGenre>.from(category.genres)..add(genre);
      categories[categoryIndex] = GenreCategory(
        name: category.name,
        genres: updatedGenres,
      );
      await _saveCustomGenres();
    }
  }

  Future<void> updateGenre(int categoryIndex, int genreIndex, NovelGenre newGenre) async {
    final category = categories[categoryIndex];
    if (!isDefaultGenre(category.name, category.genres[genreIndex].name)) {
      final updatedGenres = List<NovelGenre>.from(category.genres);
      updatedGenres[genreIndex] = newGenre;
      categories[categoryIndex] = GenreCategory(
        name: category.name,
        genres: updatedGenres,
      );
      await _saveCustomGenres();
    }
  }

  Future<void> deleteGenre(int categoryIndex, int genreIndex) async {
    final category = categories[categoryIndex];
    final genre = category.genres[genreIndex];
    if (!isDefaultGenre(category.name, genre.name)) {
      final updatedGenres = List<NovelGenre>.from(category.genres)
        ..removeAt(genreIndex);
      categories[categoryIndex] = GenreCategory(
        name: category.name,
        genres: updatedGenres,
      );
      await _saveCustomGenres();
    }
  }

  // 获取所有可用的类型名称列表
  List<String> getAllGenreNames() {
    return categories
        .expand((category) => category.genres)
        .map((genre) => genre.name)
        .toList();
  }

  // 获取所有类型列表，用于下拉选择
  List<NovelGenre> get genres {
    return categories
        .expand((category) => category.genres)
        .toList();
  }

  // 根据类型名称获取提示词
  String? getPromptByGenreName(String genreName) {
    for (var category in categories) {
      final genre = category.genres.firstWhereOrNull((g) => g.name == genreName);
      if (genre != null) {
        return genre.prompt;
      }
    }
    return null;
  }
} 