import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

class ProgressBarWidget extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final bool isCalculating;
  final VoidCallback? onNextPage;
  final VoidCallback? onPreviousPage;
  final Function(int targetPage)? onJumpToPage;
  final String? chapterTitle;
  final Color? backgroundColor;
  final Color? textColor;

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

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget> {
  bool _isLongPressing = false;
  double _dragStartX = 0;
  double _currentSwipeDelta = 0;
  OverlayEntry? _overlayEntry;
  static const double _maxSwipeDistance = 200.0; // Max swipe distance for full effect
  int _targetPage = 0;
  int _lastHapticPage = -1;

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
    final displayPage = _isLongPressing && _currentSwipeDelta.abs() > 10 ? _targetPage : widget.currentPage;

    return Positioned(
      bottom: 74.h,
      left: 70.w,
      right: 70.w,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: Get.size.width,
            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x29787880),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${'page_t'.tr} $displayPage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                if (widget.chapterTitle != null && widget.chapterTitle!.isNotEmpty) ...[
                  Text(
                    widget.chapterTitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
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
        print('📊 Current state: Page ${widget.currentPage} / ${widget.totalPages}');
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

            // Calculate how many pages to jump based on swipe distance
            // Max distance maps to jumping ~50 pages or 10% of book
            final swipeRatio = (dx / _maxSwipeDistance).clamp(-1.0, 1.0);

            // Calculate max jump: 10% of total pages, but between 10 and 50
            final tenPercent = (widget.totalPages * 0.1).round();
            final maxJump = tenPercent < 10 ? 10 : (tenPercent > 50 ? 50 : tenPercent);

            // Calculate the actual page jump (can be negative for left swipe)
            final pageJump = (swipeRatio * maxJump).round();

            // Calculate target page
            final newTarget = widget.currentPage + pageJump;
            _targetPage = newTarget.clamp(1, widget.totalPages);

            print('👆 Swipe: $dx, Ratio: $swipeRatio, MaxJump: $maxJump, Jump: $pageJump, Current: ${widget.currentPage}, Target: $_targetPage');
          });

          // Haptic feedback every time we cross a new page threshold
          if (_targetPage != _lastHapticPage) {
            HapticFeedback.selectionClick();
            _lastHapticPage = _targetPage;
          }

          _updateOverlay();
        }
      },
      onLongPressEnd: (details) {
        print('📍 Long press ended on progress bar');
        print('📍 Target page: $_targetPage, Current page: ${widget.currentPage}');

        // Remove overlay first
        _removeOverlay();

        // Jump to target page if it's different from current
        if (_targetPage != widget.currentPage && widget.onJumpToPage != null) {
          print('🎯 Calling onJumpToPage callback with page $_targetPage');
          HapticFeedback.mediumImpact();

          // Call the callback
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
                  // Progress bar
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final progress = widget.totalPages > 0 ? (widget.currentPage / widget.totalPages).clamp(0.0, 1.0) : 0.0;

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
                  // Swipe indicators (left and right)
                  if (_isLongPressing && _currentSwipeDelta.abs() > 5)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isSwipingRight = _currentSwipeDelta > 0;
                        final swipeProgress = (_currentSwipeDelta.abs() / _maxSwipeDistance).clamp(0.0, 1.0);
                        final pagesDiff = (_targetPage - widget.currentPage).abs();

                        return Positioned(
                          left: isSwipingRight ? null : 0,
                          right: isSwipingRight ? 0 : null,
                          top: 0,
                          bottom: 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 50),
                            width: constraints.maxWidth * 0.6 * swipeProgress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: isSwipingRight ? Alignment.centerRight : Alignment.centerLeft,
                                end: isSwipingRight ? Alignment.centerLeft : Alignment.centerRight,
                                colors: [
                                  Colors.grey.withOpacity(0.5 + (swipeProgress * 0.3)),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Center(
                              child: pagesDiff > 1
                                  ? Text(
                                      '${isSwipingRight ? '+' : '-'}$pagesDiff',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : Icon(
                                      isSwipingRight ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                                      color: Colors.white,
                                      size: 20.sp,
                                    ),
                            ),
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
                            text: '${widget.currentPage}',
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
