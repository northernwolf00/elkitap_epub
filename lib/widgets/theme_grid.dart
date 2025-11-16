import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:cosmos_epub/cosmos_epub.dart';

class ThemeGrid extends StatefulWidget {
  final int staticThemeId;
  final Function(int) updateTheme;

  const ThemeGrid({
    super.key,
    required this.staticThemeId,
    required this.updateTheme,
  });

  @override
  State<ThemeGrid> createState() => _ThemeGridState();
}

class _ThemeGridState extends State<ThemeGrid> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Using Obx to reactively rebuild when language changes
    return Obx(() {
      CosmosEpub.currentLocale; // ensures rebuild when locale changes
      return Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                CosmosEpubLocalization.t('themes'),
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
                    isSelected: widget.staticThemeId == 1,
                    backgroundColor: cLightGrayColor,
                    textColor: Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 4,
                    title: 'Quiet',
                    isSelected: widget.staticThemeId == 4,
                    backgroundColor: cDarkGrayColor,
                    textColor: Colors.white,
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 3,
                    title: 'Paper',
                    isSelected: widget.staticThemeId == 3,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 2,
                    title: 'Bold',
                    isSelected: widget.staticThemeId == 2,
                    backgroundColor: Colors.white,
                    textColor: Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 5,
                    title: 'Calm',
                    isSelected: widget.staticThemeId == 5,
                    backgroundColor: cCreamColor,
                    textColor: Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                  ThemeCard(
                    id: 6,
                    title: 'Focus',
                    isSelected: widget.staticThemeId == 6,
                    backgroundColor: cOffWhiteColor,
                    textColor: Colors.black,
                    updateTheme: _handleThemeChange,
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Future<void> _handleThemeChange(int id) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    await widget.updateTheme(id);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
      onTap: () async {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        // Update theme
        await updateTheme(id);

        // Close loading dialog if still mounted
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
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

// Color constants
const Color cLightGrayColor = Color(0xFFF5F5F5);
const Color cDarkGrayColor = Color(0xFF3D3D3D);
const Color cCreamColor = Color(0xFFFAF4E8);
const Color cOffWhiteColor = Color(0xFFFFFDF7);
