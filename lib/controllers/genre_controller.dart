import 'dart:convert';
import 'package:get/get.dart';
import 'package:novel_app/models/genre_category.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GenreController extends GetxController {
  final RxList<GenreCategory> categories = <GenreCategory>[].obs;
  final _prefs = Get.find<SharedPreferences>();
  final String _customGenresKey = 'custom_genres';
  
  // 默认类型列表
  final List<GenreCategory> _defaultCategories = GenreCategories.categories;

  @override
  void onInit() {
    super.onInit();
    _loadGenres();
  }

  void _loadGenres() {
    // 首先加载默认类型
    categories.addAll(_defaultCategories);
    
    // 然后加载自定义类型
    final customGenresJson = _prefs.getString(_customGenresKey);
    if (customGenresJson != null) {
      try {
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
      } catch (e) {
        print('加载自定义类型失败: $e');
      }
    }
  }

  void _saveCustomGenres() {
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
    
    _prefs.setString(_customGenresKey, customGenresJson);
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

  void addCategory(GenreCategory category) {
    if (!categories.any((c) => c.name == category.name)) {
      categories.add(category);
      _saveCustomGenres();
    }
  }

  void deleteCategory(int index) {
    final category = categories[index];
    if (!_isDefaultCategory(category.name)) {
      categories.removeAt(index);
      _saveCustomGenres();
    }
  }

  void addGenre(int categoryIndex, NovelGenre genre) {
    if (!categories[categoryIndex].genres.any((g) => g.name == genre.name)) {
      final category = categories[categoryIndex];
      final updatedGenres = List<NovelGenre>.from(category.genres)..add(genre);
      categories[categoryIndex] = GenreCategory(
        name: category.name,
        genres: updatedGenres,
      );
      _saveCustomGenres();
    }
  }

  void updateGenre(int categoryIndex, int genreIndex, NovelGenre newGenre) {
    final category = categories[categoryIndex];
    final updatedGenres = List<NovelGenre>.from(category.genres);
    updatedGenres[genreIndex] = newGenre;
    categories[categoryIndex] = GenreCategory(
      name: category.name,
      genres: updatedGenres,
    );
    _saveCustomGenres();
  }

  void deleteGenre(int categoryIndex, int genreIndex) {
    final category = categories[categoryIndex];
    final genre = category.genres[genreIndex];
    if (!isDefaultGenre(category.name, genre.name)) {
      final updatedGenres = List<NovelGenre>.from(category.genres)
        ..removeAt(genreIndex);
      categories[categoryIndex] = GenreCategory(
        name: category.name,
        genres: updatedGenres,
      );
      _saveCustomGenres();
    }
  }
} 