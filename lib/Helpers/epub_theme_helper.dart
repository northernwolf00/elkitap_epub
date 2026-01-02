import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import '../Component/constants.dart';

/// Helper class for EPUB theme and font settings
class EpubThemeHelper {
  final GetStorage gs;
  final BuildContext context;

  EpubThemeHelper({
    required this.gs,
    required this.context,
  });

  /// Load theme settings from storage
  Map<String, dynamic> loadThemeSettings(String selectedFont) {
    String font = gs.read(libFont) ?? selectedFont;
    int themeId = gs.read(libTheme) ?? 1; // Default to theme 1
    double fontSize = gs.read(libFontSize) ?? 12.0;

    return {
      'selectedFont': font,
      'themeId': themeId,
      'fontSize': fontSize,
    };
  }

  /// Update theme and return colors
  Map<String, Color> updateTheme(int id) {
    Color backColor;
    Color fontColor;

    if (id == 1) {
      // Original - Light gray
      backColor = Color(0xFFF5F5F5);
      fontColor = Colors.black;
    } else if (id == 2) {
      // Bold - Pure white
      backColor = Colors.white;
      fontColor = Colors.black;
    } else if (id == 3) {
      // Paper - Light pinkish gray
      backColor = Color(0xFFF0ECED);
      fontColor = Colors.black;
    } else if (id == 4) {
      // Quiet - Dark gray background with light gray text
      backColor = Color(0xFF4A4A4C);
      fontColor = Color(0xFFB8B8B8);
    } else if (id == 5) {
      // Calm - Cream
      backColor = Color(0xFFf5ebda);
      fontColor = Colors.black;
    } else {
      // Focus - Off white
      backColor = Color(0xFFFFFDF7);
      fontColor = Colors.black;
    }

    gs.write(libTheme, id);

    return {
      'backColor': backColor,
      'fontColor': fontColor,
    };
  }

  /// Build theme selection card widget
  Widget buildThemeCard({
    required int id,
    required String title,
    required Color backgroundColor,
    required Color textColor,
    required bool isSelected,
    required Color accentColor,
    required StateSetter setState,
    required Function(int) onThemeUpdate,
  }) {
    return GestureDetector(
      onTap: () {
        onThemeUpdate(id);
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Save font size to storage
  void saveFontSize(double fontSize) {
    gs.write(libFontSize, fontSize);
  }

  /// Save selected font to storage
  void saveFont(String fontName) {
    gs.write(libFont, fontName);
  }

  /// Get theme data for specific theme ID
  static Map<String, dynamic> getThemeData(int id) {
    switch (id) {
      case 1:
        return {
          'title': 'Original',
          'backgroundColor': Color(0xFFF5F5F5),
          'textColor': Colors.black,
        };
      case 2:
        return {
          'title': 'Bold',
          'backgroundColor': Colors.white,
          'textColor': Colors.black,
        };
      case 3:
        return {
          'title': 'Paper',
          'backgroundColor': Color(0xFFF0ECED),
          'textColor': Colors.black,
        };
      case 4:
        return {
          'title': 'Quiet',
          'backgroundColor': Color(0xFF4A4A4C),
          'textColor': Color(0xFFB8B8B8),
        };
      case 5:
        return {
          'title': 'Calm',
          'backgroundColor': Color(0xFFf5ebda),
          'textColor': Colors.black,
        };
      case 6:
      default:
        return {
          'title': 'Focus',
          'backgroundColor': Color(0xFFFFFDF7),
          'textColor': Colors.black,
        };
    }
  }
}
