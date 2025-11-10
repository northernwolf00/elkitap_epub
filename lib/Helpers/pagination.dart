// import 'dart:ui';

// import 'package:cosmos_epub/PageFlip/page_flip_widget.dart';
// import 'package:cosmos_epub/Helpers/functions.dart';
// import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_html_reborn/flutter_html_reborn.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// class PagingTextHandler {
//   final Function paginate;
//     int currentPage = 0;
//   int totalPages = 0;

//   PagingTextHandler(
//       {required this.paginate}); // will point to widget show method
// }

// class PagingWidget extends StatefulWidget {
//   final String textContent;
//   final String? innerHtmlContent;
//   final String chapterTitle;
//   final int totalChapters;
//   final int starterPageIndex;
//   final TextStyle style;
//   final Function handlerCallback;
//   final VoidCallback onTextTap;
//   final Function(int, int) onPageFlip;
//   final Function(int, int) onLastPage;
//   final Widget? lastWidget;

//   const PagingWidget(
//     this.textContent,
//     this.innerHtmlContent, {
//     super.key,
//     this.style = const TextStyle(
//       color: Colors.black,
//       fontSize: 30,
//     ),
//     required this.handlerCallback(PagingTextHandler handler),
//     required this.onTextTap,
//     required this.onPageFlip,
//     required this.onLastPage,
//     this.starterPageIndex = 0,
//     required this.chapterTitle,
//     required this.totalChapters,
//     this.lastWidget,
//   });

//   @override
//   _PagingWidgetState createState() => _PagingWidgetState();
// }

// class _PagingWidgetState extends State<PagingWidget> {
//   final List<String> _pageTexts = [];
//   List<Widget> pages = [];
//   int _currentPageIndex = 0;
//   Future<void> paginateFuture = Future.value(true);
//   late RenderBox _initializedRenderBox;
//   Widget? lastWidget;

//   int get currentPage => _currentPageIndex + 1;
//   int get totalPages => _pageTexts.length;

//   final _pageKey = GlobalKey();
//   final _pageController = GlobalKey<PageFlipWidgetState>();

//   @override
//   void initState() {
//     rePaginate();

//     var handler = PagingTextHandler(paginate: rePaginate);
//     // widget.handlerCallback(handler); // callback call.
//     widget.handlerCallback(this);
//     super.initState();
//   }

//   rePaginate() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       setState(() {
//         _initializedRenderBox = context.findRenderObject() as RenderBox;
//         paginateFuture = _paginate();
//       });
//     });
//   }

//   int findLastHtmlTagIndex(String input) {
//     // Regular expression pattern to match HTML tags
//     RegExp regex = RegExp(r'<[^>]');

//     // Find all matches
//     Iterable<Match> matches = regex.allMatches(input);

//     // If matches are found
//     if (matches.isNotEmpty) {
//       // Return the end index of the last match
//       return matches.last.end;
//     } else {
//       // If no match is found, return -1
//       return -1;
//     }
//   }

//   Future<void> _paginate() async {
//     final pageSize = _initializedRenderBox.size;

//     _pageTexts.clear();

//     // Detect text direction based on content
//     final textDirection = RTLHelper.getTextDirection(widget.textContent);

//     final textSpan = TextSpan(
//       text: widget.textContent,
//       style: widget.style,
//     );

//     final textPainter = TextPainter(
//       text: textSpan,
//       textDirection: textDirection,
//     );
//     textPainter.layout(
//       minWidth: 0,
//       maxWidth: pageSize.width,
//     );

//     // https://medium.com/swlh/flutter-line-metrics-fd98ab180a64
//     List<LineMetrics> lines = textPainter.computeLineMetrics();
//     double currentPageBottom = pageSize.height;
//     int currentPageStartIndex = 0;
//     int currentPageEndIndex = 0;

//     await Future.wait(lines.map((line) async {
//       final left = line.left;
//       final top = line.baseline - line.ascent;
//       final bottom = line.baseline + line.descent;

//       var innerHtml = widget.innerHtmlContent;

//       // Current line overflow page
//       if (currentPageBottom < bottom) {
//         currentPageEndIndex = textPainter
//             .getPositionForOffset(
//                 Offset(left, top - (innerHtml != null ? 0 : 100.h)))
//             .offset;

//         var pageText = widget.textContent
//             .substring(currentPageStartIndex, currentPageEndIndex);

//         var index = findLastHtmlTagIndex(pageText) + currentPageStartIndex;

//         /// Offset to the left from last HTML tag
//         if (index != -1) {
//           int difference = currentPageEndIndex - index;
//           if (difference < 4) {
//             currentPageEndIndex = index - 2;
//           }

//           pageText = widget.textContent
//               .substring(currentPageStartIndex, currentPageEndIndex);
//           // print('start : $currentPageStartIndex');
//           // print('end : $currentPageEndIndex');
//           // print('last html tag : $index');
//         }

//         _pageTexts.add(pageText);

//         currentPageStartIndex = currentPageEndIndex;
//         currentPageBottom =
//             top + pageSize.height - (innerHtml != null ? 120.h : 150.h);
//       }
//     }));

//     final lastPageText = widget.textContent.substring(currentPageStartIndex);
//     _pageTexts.add(lastPageText);

//     // Assuming each operation within the loop is asynchronous and returns a Future
//     List<Future<Widget>> futures = _pageTexts.map((text) async {
//       final _scrollController = ScrollController();
//       // Detect text direction for each page text
//       final pageTextDirection = RTLHelper.getTextDirection(text);

//       return InkWell(
//         onTap: widget.onTextTap,
//         child: Container(
//           color: widget.style.backgroundColor,
//           child: FadingEdgeScrollView.fromSingleChildScrollView(
//             gradientFractionOnEnd: 0.2,
//             child: SingleChildScrollView(
//               controller: _scrollController,
//               physics: const BouncingScrollPhysics(),
//               child: Padding(
//                 padding: EdgeInsets.only(
//                     bottom: 40.h, top: 60.h, left: 10.w, right: 10.w),
//                 child: Directionality(
//                   textDirection: pageTextDirection,
//                   child: widget.innerHtmlContent != null
//                       ? Html(
//                           data: text,
//                           style: {
//                             "*": Style(
//                                 textAlign: TextAlign.justify,
//                                 fontSize: FontSize(widget.style.fontSize ?? 0),
//                                 fontFamily: widget.style.fontFamily,
//                                 color: widget.style.color),
//                           },
//                         )
//                       : Text(
//                           text,
//                           textAlign: TextAlign.justify,
//                           textDirection: pageTextDirection,
//                           style: widget.style,
//                           overflow: TextOverflow.visible,
//                         ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//     }).toList();

//     pages = await Future.wait(futures);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<void>(
//         future: paginateFuture,
//         builder: (context, snapshot) {
//           switch (snapshot.connectionState) {
//             case ConnectionState.waiting:
//               {
//                 // Otherwise, display a loading indicator.
//                 return Center(
//                     child: CupertinoActivityIndicator(
//                   color: Theme.of(context).primaryColor,
//                   radius: 30.r,
//                 ));
//               }
//             default:
//               {
//                 return Stack(
//                   children: [
//                     Column(
//                       children: [
//                         Expanded(
//                           child: SizedBox.expand(
//                             key: _pageKey,
//                             child: PageFlipWidget(
//                               key: _pageController,
//                               initialIndex: widget.starterPageIndex != 0
//                                   ? (pages.isNotEmpty &&
//                                           widget.starterPageIndex < pages.length
//                                       ? widget.starterPageIndex
//                                       : 0)
//                                   : widget.starterPageIndex,
//                               onPageFlip: (pageIndex) {
//                                 _currentPageIndex = pageIndex;
//                                 widget.onPageFlip(pageIndex, pages.length);
//                                 if (_currentPageIndex == pages.length - 1) {
//                                   widget.onLastPage(pageIndex, pages.length);
//                                 }
//                               },
//                               backgroundColor:
//                                   widget.style.backgroundColor ?? Colors.white,
//                               lastPage: widget.lastWidget,
//                               children: pages,
//                             ),
//                           ),
//                         ),
//                         Visibility(
//                           visible: false,
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               IconButton(
//                                 icon: Icon(Icons.first_page),
//                                 onPressed: () {
//                                   setState(() {
//                                     _currentPageIndex = 0;
//                                     _pageController.currentState
//                                         ?.goToPage(_currentPageIndex);
//                                   });
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.navigate_before),
//                                 onPressed: () {
//                                   setState(() {
//                                     if (_currentPageIndex > 0)
//                                       _currentPageIndex--;
//                                     _pageController.currentState
//                                         ?.goToPage(_currentPageIndex);
//                                   });
//                                 },
//                               ),
//                               Text(
//                                 '${_currentPageIndex + 1}/${_pageTexts.length}',
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.navigate_next),
//                                 onPressed: () {
//                                   setState(() {
//                                     if (_currentPageIndex <
//                                         _pageTexts.length - 1)
//                                       _currentPageIndex++;
//                                     _pageController.currentState
//                                         ?.goToPage(_currentPageIndex);
//                                   });
//                                 },
//                               ),
//                               IconButton(
//                                 icon: Icon(Icons.last_page),
//                                 onPressed: () {
//                                   setState(() {
//                                     _currentPageIndex = _pageTexts.length - 1;
//                                     _pageController.currentState
//                                         ?.goToPage(_currentPageIndex);
//                                   });
//                                 },
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 );
//               }
//           }
//         });
//   }
// }
import 'dart:developer';
import 'dart:ui';
import 'package:cosmos_epub/Helpers/selectable_text_with_addnote.dart';
import 'package:cosmos_epub/PageFlip/page_flip_widget.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:fading_edge_scrollview/fading_edge_scrollview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html_reborn/flutter_html_reborn.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:html/parser.dart';

/// 📘 Handler class shared with parent widget
class PagingTextHandler {
  final Function paginate;
  int currentPage = 0; 
  int totalPages = 0; 
  int globalPage = 0; 
  int globalTotalPages = 0; 

  PagingTextHandler({required this.paginate});
}

/// 📘 Main Pagination Widget
class PagingWidget extends StatefulWidget {
  final String textContent;
  final String? innerHtmlContent;
  final String chapterTitle;
  final int totalChapters;
  final int starterPageIndex;
  final String fullBookText; // NEW: Full book text for global calculation
  final Function(int)?
      onGlobalPaginationComplete; // NEW: Callback for total pages
  final List<String> allChapterTexts;
  final Function(Map<int, int>)? onAllChaptersPaginated;
  final TextStyle style;
  final Function handlerCallback;
  final VoidCallback onTextTap;
  final Function(int, int) onPageFlip;
  final Function(int, int) onLastPage;
  final Widget? lastWidget;

  const PagingWidget(
    this.textContent,
    this.innerHtmlContent, {
    super.key,
    this.style = const TextStyle(
      color: Colors.black,
      fontSize: 14,
    ),
    required this.handlerCallback,
    required this.onTextTap,
    required this.onPageFlip,
    required this.onLastPage,
    this.starterPageIndex = 0,
    required this.chapterTitle,
    required this.totalChapters,
    this.fullBookText = '', // NEW
    this.onGlobalPaginationComplete, // NEW
    this.allChapterTexts = const [],
    this.onAllChaptersPaginated,
    this.lastWidget,
  });

  @override
  _PagingWidgetState createState() => _PagingWidgetState();
}

class _PagingWidgetState extends State<PagingWidget> {
  final List<String> _pageTexts = [];
  List<Widget> pages = [];
  int _currentPageIndex = 0;
  Future<void> paginateFuture = Future.value(true);
  late RenderBox _initializedRenderBox;

  final _pageKey = GlobalKey();
  final _pageController = GlobalKey<PageFlipWidgetState>();

  late PagingTextHandler _handler;

  // NEW: For global page calculation
  int _globalTotalPages = 0;
 

  @override
  void initState() {
    super.initState();
    _handler = PagingTextHandler(paginate: rePaginate);
    widget.handlerCallback(_handler);
    rePaginate();
  }

  /// Rebuild pagination after resize or font change
  rePaginate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _initializedRenderBox = context.findRenderObject() as RenderBox;
        paginateFuture = _paginate();
      });
    });
  }

  /// Helper to avoid cutting off HTML tags mid-page
  int findLastHtmlTagIndex(String input) {
    RegExp regex = RegExp(r'<[^>]');
    Iterable<Match> matches = regex.allMatches(input);
    if (matches.isNotEmpty) {
      return matches.last.end;
    } else {
      return -1;
    }
  }

  /// Calculate global page count for ENTIRE book
  Future<int> _calculateGlobalPageCount(String fullText) async {
    if (fullText.isEmpty) return 0;

    final pageSize = _initializedRenderBox.size;
    final textDirection = RTLHelper.getTextDirection(fullText);
    final textSpan = TextSpan(text: fullText, style: widget.style);

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
    );
    textPainter.layout(minWidth: 0, maxWidth: pageSize.width);

    List<LineMetrics> lines = textPainter.computeLineMetrics();
    double currentPageBottom = pageSize.height;
    int pageCount = 0;
    int currentPageStartIndex = 0;

    for (var line in lines) {
      final top = line.baseline - line.ascent;
      final bottom = line.baseline + line.descent;

      if (currentPageBottom < bottom) {
        pageCount++;
        currentPageStartIndex = textPainter
            .getPositionForOffset(Offset(line.left, top - 100.h))
            .offset;
        currentPageBottom = top + pageSize.height - 150.h;
      }
    }

    // Add last page
    if (currentPageStartIndex < fullText.length) {
      pageCount++;
    }

    return pageCount;
  }

  Future<int> _calculatePageCount(String text) async {
    if (text.isEmpty) return 0;

    final pageSize = _initializedRenderBox.size;
    final textDirection = RTLHelper.getTextDirection(text);
    final textSpan = TextSpan(text: text, style: widget.style);

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
    );
    textPainter.layout(minWidth: 0, maxWidth: pageSize.width);

    List<LineMetrics> lines = textPainter.computeLineMetrics();
    double currentPageBottom = pageSize.height;
    int pageCount = 0;
    int currentPageStartIndex = 0;

    for (var line in lines) {
      final top = line.baseline - line.ascent;
      final bottom = line.baseline + line.descent;

      if (currentPageBottom < bottom) {
        pageCount++;
        currentPageStartIndex = textPainter
            .getPositionForOffset(Offset(line.left, top - 100.h))
            .offset;
        currentPageBottom = top + pageSize.height - 150.h;
      }
    }

    // Add last page
    if (currentPageStartIndex < text.length) {
      pageCount++;
    }

    return pageCount;
  }

  Future<void> _paginate() async {
    final pageSize = _initializedRenderBox.size;
    _pageTexts.clear();

    // Calculate global total pages from FULL book
    if (widget.fullBookText.isNotEmpty) {
      String fullBookTextParsed =
          parse(widget.fullBookText).documentElement?.text ?? '';
      _globalTotalPages = await _calculateGlobalPageCount(fullBookTextParsed);
      _handler.globalTotalPages = _globalTotalPages;

      // Notify parent widget of total pages
      if (widget.onGlobalPaginationComplete != null) {
        widget.onGlobalPaginationComplete!(_globalTotalPages);
      }
    }
    if (widget.allChapterTexts.isNotEmpty) {
      final Map<int, int> chapterPageCounts = {};
      for (int i = 0; i < widget.allChapterTexts.length; i++) {
        final chapterText =
            parse(widget.allChapterTexts[i]).documentElement?.text ?? '';
        final pageCount = await _calculatePageCount(chapterText);
        chapterPageCounts[i] = pageCount;
      }
      if (widget.onAllChaptersPaginated != null) {
        widget.onAllChaptersPaginated!(chapterPageCounts);
      }
    }

    final textDirection = RTLHelper.getTextDirection(widget.textContent);
    final textSpan = TextSpan(
      text: widget.textContent,
      style: widget.style,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: pageSize.width,
    );

    List<LineMetrics> lines = textPainter.computeLineMetrics();
    double currentPageBottom = pageSize.height;
    int currentPageStartIndex = 0;
    int currentPageEndIndex = 0;

    await Future.wait(lines.map((line) async {
      final left = line.left;
      final top = line.baseline - line.ascent;
      final bottom = line.baseline + line.descent;

      var innerHtml = widget.innerHtmlContent;

      if (currentPageBottom < bottom) {
        currentPageEndIndex = textPainter
            .getPositionForOffset(
                Offset(left, top - (innerHtml != null ? 0 : 100.h)))
            .offset;

        var pageText = widget.textContent
            .substring(currentPageStartIndex, currentPageEndIndex);

        var index = findLastHtmlTagIndex(pageText) + currentPageStartIndex;

        if (index != -1) {
          int difference = currentPageEndIndex - index;
          if (difference < 4) {
            currentPageEndIndex = index - 2;
          }

          pageText = widget.textContent
              .substring(currentPageStartIndex, currentPageEndIndex);
        }

        _pageTexts.add(pageText);
        currentPageStartIndex = currentPageEndIndex;
        currentPageBottom =
            top + pageSize.height - (innerHtml != null ? 120.h : 150.h);
      }
    }));

    final lastPageText = widget.textContent.substring(currentPageStartIndex);
    _pageTexts.add(lastPageText);

    // Build page widgets
    List<Future<Widget>> futures = _pageTexts.map((text) async {
      final _scrollController = ScrollController();
      final pageTextDirection = RTLHelper.getTextDirection(text);

      // log('pageTextDirection: $pageTextDirection');
      // log('text: $text');

      return InkWell(
        onTap: widget.onTextTap,
        child: Container(
          color: widget.style.backgroundColor,
          child: FadingEdgeScrollView.fromSingleChildScrollView(
            gradientFractionOnEnd: 0,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: 10.h, top: 10.h, left: 10.w, right: 10.w),
                child: Directionality(
                  textDirection: pageTextDirection,
                  child: widget.innerHtmlContent != null
                      ? Html(
                          data: text,
                          style: {
                            "*": Style(
                                textAlign: TextAlign.justify,
                                fontSize: FontSize(widget.style.fontSize ?? 0),
                                fontFamily: widget.style.fontFamily,
                                color: widget.style.color),
                          },
                        )
                      :
                      //  Text(
                      //     text,
                      //     textAlign: TextAlign.justify,
                      // textDirection: pageTextDirection,
                      // style: widget.style,
                      // overflow: TextOverflow.visible,
                      //   ),
                      SelectableTextWithCustomToolbar(
                          text: text,
                          textDirection: pageTextDirection,
                          style: widget.style,
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    pages = await Future.wait(futures);
    _handler.totalPages = pages.length;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: paginateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CupertinoActivityIndicator(
              color: Theme.of(context).primaryColor,
              radius: 20.r,
            ),
          );
        }

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SizedBox.expand(
                    key: _pageKey,
                    child: PageFlipWidget(
                      key: _pageController,
                      initialIndex: widget.starterPageIndex != 0
                          ? (pages.isNotEmpty &&
                                  widget.starterPageIndex < pages.length
                              ? widget.starterPageIndex
                              : 0)
                          : widget.starterPageIndex,
                      onPageFlip: (pageIndex) {
                        _currentPageIndex = pageIndex;
                        _handler.currentPage = pageIndex + 1;
                        _handler.totalPages = pages.length;

                        // Calculate approximate global page position
                        // This is approximate since we're paginating chapter by chapter

                        widget.onPageFlip(pageIndex, pages.length);
                        if (_currentPageIndex == pages.length - 1) {
                          widget.onLastPage(pageIndex, pages.length);
                        }
                      },
                      backgroundColor:
                          widget.style.backgroundColor ?? Colors.white,
                      lastPage: widget.lastWidget,
                      children: pages,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
