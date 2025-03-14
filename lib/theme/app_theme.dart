import 'package:flutter/material.dart';
import 'package:novel_app/theme/animation_config.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    cardTheme: AnimationConfig.cardTheme,
    listTileTheme: AnimationConfig.listTileTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: AnimationConfig.buttonStyle,
    ),
    // 添加页面过渡动画
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    // 添加滚动物理效果
    scrollbarTheme: ScrollbarThemeData(
      thickness: MaterialStateProperty.all(6),
      thumbColor: MaterialStateProperty.all(Colors.grey.withOpacity(0.5)),
      radius: const Radius.circular(3),
      crossAxisMargin: 2,
      mainAxisMargin: 2,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    cardTheme: AnimationConfig.cardTheme,
    listTileTheme: AnimationConfig.listTileTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: AnimationConfig.buttonStyle,
    ),
    // 添加页面过渡动画
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    // 添加滚动物理效果
    scrollbarTheme: ScrollbarThemeData(
      thickness: MaterialStateProperty.all(6),
      thumbColor: MaterialStateProperty.all(Colors.grey.withOpacity(0.5)),
      radius: const Radius.circular(3),
      crossAxisMargin: 2,
      mainAxisMargin: 2,
    ),
  );
} 