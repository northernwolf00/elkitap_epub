import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProgressBarWidget extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const ProgressBarWidget({
    Key? key,
    required this.currentPage,
    required this.totalPages,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Container(
          height: 40.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: const Color(0xFFE8E8E8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Stack(
              children: [
                // Progress bar
                LayoutBuilder(
                  builder: (context, constraints) {
                    final progress = totalPages > 0
                        ? (currentPage / totalPages).clamp(0.0, 1.0)
                        : 0.0;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: constraints.maxWidth * progress,
                      decoration: const BoxDecoration(
                        color: Color(0xFFA8A8A8),
                      ),
                    );
                  },
                ),
                // Page numbers
                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$currentPage',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 20.sp,
                            color: Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: ' /',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 20.sp,
                            color: Colors.black.withOpacity(0.4),
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: '$totalPages',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 20.sp,
                            color: Colors.black.withOpacity(0.4),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

