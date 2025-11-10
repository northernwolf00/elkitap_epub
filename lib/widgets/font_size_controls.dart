import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FontSizeControls extends StatelessWidget {
  final Color fontColor;
  final double fontSizeProgress;
  final Function(double) onFontSizeChange;
  final int staticThemeId;
  final Function(int) updateTheme;

  const FontSizeControls({
    super.key,
    required this.fontColor,
    required this.fontSizeProgress,
    required this.onFontSizeChange,
    required this.staticThemeId,
    required this.updateTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: MediaQuery.of(context).size.width - 120,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              _fontButton("A", 16.sp, -1),
              Container(width: 1, height: 30.h, color: Colors.grey.withOpacity(0.3)),
              _fontButton("A", 22.sp, 1),
            ],
          ),
        ),
        Container(
          width: 60.w,
          height: 43.h,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: IconButton(
            icon: Icon(
              staticThemeId == 4
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: fontColor,
              size: 20.sp,
            ),
            onPressed: () {
              updateTheme(staticThemeId == 4 ? 3 : 4);
            },
          ),
        ),
      ],
    );
  }

  Widget _fontButton(String label, double size, int direction) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        splashColor: Colors.grey.withOpacity(0.3),
        highlightColor: Colors.grey.withOpacity(0.1),
        onTap: () {
          double newSize = fontSizeProgress + direction;
          newSize = newSize.clamp(15.0, 30.0);
          onFontSizeChange(newSize);
        },
        child: Container(
          height: 40.h,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: size,
              color: fontColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
