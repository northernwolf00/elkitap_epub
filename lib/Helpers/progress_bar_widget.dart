import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class ProgressBarWidget extends StatefulWidget {
  const ProgressBarWidget({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    this.isCalculating = false,
    this.onNextPage,
    this.onPreviousPage,
    this.onJumpToPage,
    this.chapterTitle,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  final Function(int targetPage)? onJumpToPage;
  final Color? backgroundColor;
  final String? chapterTitle;
  final int currentPage;
  final bool isCalculating;
  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;
  final Color? textColor;
  final int totalPages;

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget> {
  static const double _maxSwipeDistance = 200.0;

  double _currentSwipeDelta = 0;
  double _dragStartX = 0;
  bool _isLongPressing = false;
  int _lastHapticPage = -1;
  OverlayEntry? _overlayEntry;
  int _targetPage = 0;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildOverlayContent(),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildOverlayContent() {
    final displayPage = _isLongPressing && _currentSwipeDelta.abs() > 10
        ? _targetPage
        : widget.currentPage;

    return Positioned(
      bottom: 84.h,
      left: 60.w,
      right: 60.w,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page $displayPage',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.chapterTitle != null &&
                        widget.chapterTitle!.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        widget.chapterTitle!,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.black45,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        print('📍 Long press started on progress bar');
        print(
            '📊 Current state: Page ${widget.currentPage} / ${widget.totalPages}');
        HapticFeedback.mediumImpact();
        setState(() {
          _isLongPressing = true;
          _dragStartX = details.globalPosition.dx;
          _currentSwipeDelta = 0;
          _targetPage = widget.currentPage;
          _lastHapticPage = widget.currentPage;
        });
        _showOverlay();
      },
      onLongPressMoveUpdate: (details) {
        if (_isLongPressing) {
          final dx = details.globalPosition.dx - _dragStartX;

          setState(() {
            _currentSwipeDelta = dx;

            final swipeRatio = (dx / _maxSwipeDistance).clamp(-1.0, 1.0);

            final tenPercent = (widget.totalPages * 0.1).round();
            final maxJump =
                tenPercent < 10 ? 10 : (tenPercent > 50 ? 50 : tenPercent);

            final pageJump = (swipeRatio * maxJump).round();

            final newTarget = widget.currentPage + pageJump;
            _targetPage = newTarget.clamp(1, widget.totalPages);
          });

          if (_targetPage != _lastHapticPage) {
            HapticFeedback.selectionClick();
            _lastHapticPage = _targetPage;
          }

          _updateOverlay();
        }
      },
      onLongPressEnd: (details) {
        print('📍 Long press ended on progress bar');
        print(
            '📍 Target page: $_targetPage, Current page: ${widget.currentPage}');

        _removeOverlay();

        if (_targetPage != widget.currentPage && widget.onJumpToPage != null) {
          print('🎯 Calling onJumpToPage callback with page $_targetPage');
          HapticFeedback.mediumImpact();

          widget.onJumpToPage!(_targetPage);
        } else {
          HapticFeedback.lightImpact();
          print('⏭️ No jump needed - same page');
        }

        setState(() {
          _isLongPressing = false;
          _currentSwipeDelta = 0;
          _targetPage = widget.currentPage;
          _lastHapticPage = -1;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isLongPressing ? 1.02 : 1.0),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            height: 44.h,
            width: Get.size.width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              color: const Color(0xFF787880).withOpacity(.2),
              boxShadow: _isLongPressing
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final displayProgress = _isLongPressing
                          ? (widget.totalPages > 0
                              ? (_targetPage / widget.totalPages)
                                  .clamp(0.0, 1.0)
                              : 0.0)
                          : (widget.totalPages > 0
                              ? (widget.currentPage / widget.totalPages)
                                  .clamp(0.0, 1.0)
                              : 0.0);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: constraints.maxWidth * displayProgress,
                        decoration: BoxDecoration(
                          color: const Color(0xFF636366).withOpacity(0.35),
                        ),
                      );
                    },
                  ),
                  if (_isLongPressing)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final targetProgress = widget.totalPages > 0
                            ? (_targetPage / widget.totalPages).clamp(0.0, 1.0)
                            : 0.0;
                        return Positioned(
                          left: (constraints.maxWidth * targetProgress) - 1,
                          top: 10.h,
                          bottom: 10.h,
                          child: Container(
                            width: 2.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        );
                      },
                    ),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${widget.currentPage}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20.sp,
                              fontFamily: 'Gilroy',
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
                            text: ' ${widget.totalPages}',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 20.sp,
                              color: Colors.black.withOpacity(0.4),
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (widget.isCalculating)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(left: 8.w),
                                child: SizedBox(
                                  width: 14.w,
                                  height: 14.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black.withOpacity(0.4),
                                    ),
                                  ),
                                ),
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
      ),
    );
  }
}
