import 'package:cosmos_epub/book_options_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Header widget for EPUB reader with back button and options menu
class EpubHeaderWidget extends StatelessWidget {
  final bool showHeader;
  final Color fontColor;
  final Color backColor;
  final String bookTitle;
  final String? bookImage;
  final String bookId;
  final VoidCallback onBackPressed;

  const EpubHeaderWidget({
    Key? key,
    required this.showHeader,
    required this.fontColor,
    required this.backColor,
    required this.bookTitle,
    required this.bookImage,
    required this.bookId,
    required this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        height: showHeader ? 60.h : 0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34.w,
                height: 34.h,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: onBackPressed,
                  icon: Icon(
                    Icons.close,
                    color: fontColor,
                    size: 16.sp,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
              BookOptionsMenu(
                fontColor: fontColor,
                backColor: backColor,
                bookTitle: bookTitle,
                bookImage: bookImage ?? '',
                bookId: bookId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
