import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'font_size_controls.dart';
import 'brightness_slider.dart';
import 'theme_grid.dart';

Future updateFontSettings({
  required BuildContext context,
  required Color backColor,
  required Color fontColor,
  required double brightnessLevel,
  required int staticThemeId,
  required Function(double) setBrightness,
  required Function(int) updateTheme,
  required double fontSizeProgress,
  required Function(double) onFontSizeChange,
}) {
  return showModalBottomSheet(
    context: context,
    elevation: 10,
    clipBehavior: Clip.antiAlias,
    backgroundColor: backColor,
    enableDrag: true,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(20.r),
        topRight: Radius.circular(20.r),
      ),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, setState) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Themes & Settings',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: fontColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: fontColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // Font Size Controls
                FontSizeControls(
                  fontColor: fontColor,
                  fontSizeProgress: fontSizeProgress,
                  onFontSizeChange: (val) {
                    setState(() => onFontSizeChange(val));
                  },
                  staticThemeId: staticThemeId,
                  updateTheme: updateTheme,
                ),

                SizedBox(height: 12.h),

                // Brightness slider
                BrightnessSlider(
                  fontColor: fontColor,
                  backColor: backColor,
                  brightnessLevel: brightnessLevel,
                  onBrightnessChanged: (value) {
                    setState(() {
                      brightnessLevel = value;
                    });
                  },
                  onChangeEnd: (value) async {
                    await ScreenBrightness().setScreenBrightness(value);
                  },
                ),

                SizedBox(height: 20.h),

                ThemeGrid(
                  staticThemeId: staticThemeId,
                  updateTheme: updateTheme,
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
