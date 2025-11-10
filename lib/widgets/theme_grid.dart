import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ThemeGrid extends StatelessWidget {
  final int staticThemeId;
  final Function(int) updateTheme;

  const ThemeGrid({
    super.key,
    required this.staticThemeId,
    required this.updateTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Themes',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 12.h),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          crossAxisSpacing: 16.w,
          mainAxisSpacing: 16.h,
          childAspectRatio: 1.0,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ThemeCard(
              id: 1,
              title: 'Bold',
              isSelected: staticThemeId == 1,
              backgroundColor: cLightGrayColor,
              textColor: Colors.black,
              updateTheme: updateTheme,
            ),
            ThemeCard(
              id: 4,
              title: 'Quite',
              isSelected: staticThemeId == 4,
              backgroundColor: cDarkGrayColor,
              textColor: Colors.white,
              updateTheme: updateTheme,
            ),
            ThemeCard(
              id: 3,
              title: 'Paper',
              isSelected: staticThemeId == 3,
              backgroundColor: Colors.white,
              textColor: Colors.black,
              updateTheme: updateTheme,
            ),
            ThemeCard(
              id: 2,
              title: 'Bold',
              isSelected: staticThemeId == 2,
              backgroundColor: Colors.white,
              textColor: Colors.black,
              updateTheme: updateTheme,
            ),
            ThemeCard(
              id: 5,
              title: 'Calm',
              isSelected: staticThemeId == 5,
              backgroundColor: cCreamColor,
              textColor: Colors.black,
              updateTheme: updateTheme,
            ),
            ThemeCard(
              id: 6,
              title: 'Focus',
              isSelected: staticThemeId == 6,
              backgroundColor: cOffWhiteColor,
              textColor: Colors.black,
              updateTheme: updateTheme,
            ),
          ],
        ),
      ],
    );
  }
}

class ThemeCard extends StatelessWidget {
  final int id;
  final String title;
  final bool isSelected;
  final Color backgroundColor;
  final Color textColor;
  final Function(int) updateTheme;

  const ThemeCard({
    super.key,
    required this.id,
    required this.title,
    required this.isSelected,
    required this.backgroundColor,
    required this.textColor,
    required this.updateTheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => updateTheme(id),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? Colors.grey.shade400 : Colors.grey.shade300,
            width: isSelected ? 3 : 2,
          ),
        ),
        padding: EdgeInsets.all(12.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Make sure you have these color constants defined in your project
// Example:
const Color cLightGrayColor = Color(0xFFF5F5F5);
const Color cDarkGrayColor = Color(0xFF3D3D3D);
const Color cCreamColor = Color(0xFFFAF4E8);
const Color cOffWhiteColor = Color(0xFFFFFDF7);
