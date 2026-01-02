import 'package:cosmos_epub/Helpers/progress_bar_widget.dart';
import 'package:cosmos_epub/widgets/font_settings_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bottom navigation bar widget for EPUB reader
class EpubBottomNavWidget extends StatelessWidget {
  final bool showHeader;
  final Color fontColor;
  final Color backColor;
  final int currentPage;
  final int totalPages;
  final bool isCalculating;
  final String chapterTitle;
  final VoidCallback onMenuPressed;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final Function(int) onJumpToPage;
  final VoidCallback onFontSettingsPressed;
  final double fontSize;
  final double brightnessLevel;
  final int staticThemeId;
  final Function(double) setBrightness;
  final Function(int) updateTheme;
  final Function(double) onFontSizeChange;

  const EpubBottomNavWidget({
    Key? key,
    required this.showHeader,
    required this.fontColor,
    required this.backColor,
    required this.currentPage,
    required this.totalPages,
    required this.isCalculating,
    required this.chapterTitle,
    required this.onMenuPressed,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onJumpToPage,
    required this.onFontSettingsPressed,
    required this.fontSize,
    required this.brightnessLevel,
    required this.staticThemeId,
    required this.setBrightness,
    required this.updateTheme,
    required this.onFontSizeChange,
  }) : super(key: key);

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Container(
      width: 44.w,
      height: 44.h,
      decoration: BoxDecoration(
        color: fontColor.withOpacity(0.08),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(22.r),
          splashColor: fontColor.withOpacity(0.1),
          highlightColor: fontColor.withOpacity(0.05),
          child: Center(
            child: Icon(
              icon,
              color: fontColor,
              size: 20.sp,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        height: showHeader ? 70.h : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 8.h,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildNavButton(
                  icon: Icons.menu,
                  onPressed: onMenuPressed,
                  tooltip: 'Table of Contents',
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: ProgressBarWidget(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      isCalculating: isCalculating,
                      onNextPage: onNextPage,
                      onPreviousPage: onPreviousPage,
                      onJumpToPage: onJumpToPage,
                      chapterTitle: chapterTitle,
                      backgroundColor: backColor,
                      textColor: fontColor,
                    ),
                  ),
                ),
                _buildNavButton(
                  icon: Icons.text_fields_rounded,
                  onPressed: () {
                    updateFontSettings(
                      context: context,
                      backColor: backColor,
                      fontColor: fontColor,
                      brightnessLevel: brightnessLevel,
                      staticThemeId: staticThemeId,
                      setBrightness: setBrightness,
                      updateTheme: updateTheme,
                      fontSizeProgress: fontSize,
                      onFontSizeChange: onFontSizeChange,
                    );
                  },
                  tooltip: 'Font Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
