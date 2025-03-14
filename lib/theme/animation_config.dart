import 'package:flutter/material.dart';

class AnimationConfig {
  // 按钮点击动画持续时间
  static const Duration buttonAnimationDuration = Duration(milliseconds: 150);
  
  // 卡片点击动画持续时间
  static const Duration cardAnimationDuration = Duration(milliseconds: 200);
  
  // 列表项点击动画持续时间
  static const Duration listItemAnimationDuration = Duration(milliseconds: 180);
  
  // 默认曲线
  static const Curve defaultCurve = Curves.easeInOut;
  
  // 弹性曲线
  static const Curve springCurve = Curves.elasticOut;
  
  // 按钮缩放比例
  static const double buttonScaleFactor = 0.95;
  
  // 卡片缩放比例
  static const double cardScaleFactor = 0.98;
  
  // 列表项缩放比例
  static const double listItemScaleFactor = 0.97;
  
  // 波纹效果颜色
  static Color rippleColor(BuildContext context) {
    return Theme.of(context).primaryColor.withOpacity(0.1);
  }
  
  // 按钮样式
  static ButtonStyle buttonStyle(BuildContext context) {
    return ElevatedButton.styleFrom(
      elevation: 2,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      animationDuration: buttonAnimationDuration,
    );
  }
  
  // 卡片样式
  static CardTheme cardTheme(BuildContext context) {
    return CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
    );
  }
  
  // 列表项样式
  static ListTileThemeData listTileTheme(BuildContext context) {
    return ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
} 