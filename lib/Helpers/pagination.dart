import 'package:cosmos_epub/Helpers/selectable_text_with_addnote.dart';
import 'package:cosmos_epub/PageFlip/page_flip_widget.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html/parser.dart';

class PagingTextHandler extends GetxController {
  final Function paginate;
  final _box = GetStorage();

  late final RxInt currentPage;
  late final RxInt totalPages;
  late final RxInt globalPage;
  late final RxInt globalTotalPages;

  PagingTextHandler({required this.paginate}) {
    currentPage = (_box.read<int>('currentPage') ?? 0).obs;
    totalPages = (_box.read<int>('totalPages') ?? 0).obs;
    globalPage = (_box.read<int>('globalPage') ?? 0).obs;
    globalTotalPages = (_box.read<int>('globalTotalPages') ?? 0).obs;

    ever(currentPage, (_) => _box.write('currentPage', currentPage.value));
    ever(totalPages, (_) => _box.write('totalPages', totalPages.value));
    ever(globalPage, (_) => _box.write('globalPage', globalPage.value));
    ever(globalTotalPages,
        (_) => _box.write('globalTotalPages', globalTotalPages.value));
  }
}

class PagingWidget extends StatefulWidget {
  final String textContent;
  final String? innerHtmlContent;
  final String chapterTitle;
  final int totalChapters;
  final int starterPageIndex;
  final String fullBookText;
  final Function(int)? onGlobalPaginationComplete;
  final List<String> allChapterTexts;
  final Function(Map<int, int>)? onAllChaptersPaginated;
  final TextStyle style;
  final Function handlerCallback;
  final VoidCallback onTextTap;
  final Function(int, int) onPageFlip;
  final Function(int, int) onLastPage;
  final Widget? lastWidget;
  final String bookId;
  final bool showNavBar;
  final int linesPerPage; // NEW: Customizable lines per page

  const PagingWidget(
    this.textContent,
    this.innerHtmlContent, {
    super.key,
    this.style = const TextStyle(
      color: Colors.black,
      fontSize: 12,
    ),
    required this.handlerCallback,
    required this.onTextTap,
    required this.onPageFlip,
    required this.onLastPage,
    this.starterPageIndex = 0,
    required this.chapterTitle,
    required this.totalChapters,
    this.fullBookText = '',
    this.onGlobalPaginationComplete,
    this.allChapterTexts = const [],
    this.onAllChaptersPaginated,
    this.lastWidget,
    required this.bookId,
    this.showNavBar = true,
    this.linesPerPage = 25, // DEFAULT: 25 lines per page
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
  int _globalTotalPages = 0;

  @override
  void initState() {
    super.initState();
    _handler = PagingTextHandler(paginate: rePaginate);
    widget.handlerCallback(_handler);
    rePaginate();
  }

  rePaginate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _initializedRenderBox = context.findRenderObject() as RenderBox;
        paginateFuture = _paginate();
      });
    });
  }

  int findLastHtmlTagIndex(String input) {
    RegExp regex = RegExp(r'<[^>]');
    Iterable<Match> matches = regex.allMatches(input);
    if (matches.isNotEmpty) {
      return matches.last.end;
    } else {
      return -1;
    }
  }

  Future<int> _calculateGlobalPageCount(String fullText) async {
    if (fullText.isEmpty) return 0;

    final pageSize = _initializedRenderBox.size;
    final textDirection = RTLHelper.getTextDirection(fullText);
    final textSpan = TextSpan(
      text: fullText,
      style: widget.style.copyWith(
        fontFamily: 'SFPro',
        height: 1.65,
        letterSpacing: 0.3,
        wordSpacing: 1.5,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
    );
    textPainter.layout(minWidth: 0, maxWidth: pageSize.width - 64.w);

    List<LineMetrics> lines = textPainter.computeLineMetrics();
    
    // Simple calculation: divide total lines by lines per page
    final int LINES_PER_PAGE = widget.linesPerPage;
    int pageCount = (lines.length / LINES_PER_PAGE).ceil();

    return pageCount > 0 ? pageCount : 1;
  }

  Future<int> _calculatePageCount(String text) async {
    if (text.isEmpty) return 0;

    final pageSize = _initializedRenderBox.size;
    final textDirection = RTLHelper.getTextDirection(text);
    final textSpan = TextSpan(
      text: text,
      style: widget.style.copyWith(
        fontFamily: 'SFPro',
        height: 1.65,
        letterSpacing: 0.3,
        wordSpacing: 1.5,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
    );
    textPainter.layout(minWidth: 0, maxWidth: pageSize.width - 64.w);

    List<LineMetrics> lines = textPainter.computeLineMetrics();
    
    // Simple calculation: divide total lines by lines per page
    final int LINES_PER_PAGE = widget.linesPerPage;
    int pageCount = (lines.length / LINES_PER_PAGE).ceil();

    return pageCount > 0 ? pageCount : 1;
  }

  Future<void> _paginate() async {
    final pageSize = _initializedRenderBox.size;
    _pageTexts.clear();

    // Calculate global pages
    if (widget.fullBookText.isNotEmpty) {
      String fullBookTextParsed =
          parse(widget.fullBookText).documentElement?.text ?? '';
      _globalTotalPages = await _calculateGlobalPageCount(fullBookTextParsed);
      _handler.globalTotalPages.value = _globalTotalPages;

      if (widget.onGlobalPaginationComplete != null) {
        widget.onGlobalPaginationComplete!(_globalTotalPages);
      }
    }

    // Calculate chapter pages
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

    // Create text painter for current chapter
    final textDirection = RTLHelper.getTextDirection(widget.textContent);
    final textSpan = TextSpan(
      text: widget.textContent,
      style: widget.style.copyWith(
        fontFamily: 'SFPro',
        height: 1.65,
        letterSpacing: 0.3,
        wordSpacing: 1.5,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: textDirection,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: pageSize.width - 64.w,
    );

    // SIMPLE APPROACH: Split by LINES (configurable lines per page)
    List<LineMetrics> lines = textPainter.computeLineMetrics();
    
    final int LINES_PER_PAGE = widget.linesPerPage; // Use widget parameter
    int lineCount = 0;
    int pageStartIndex = 0;
    bool isFirstPage = true;
    
    // For first page, reduce lines if there's a chapter title
    int effectiveLinesPerPage = LINES_PER_PAGE;
    if (isFirstPage && widget.chapterTitle.isNotEmpty) {
      effectiveLinesPerPage = (LINES_PER_PAGE * 0.7).round(); // 70% of normal lines on first page
    }

    for (int i = 0; i < lines.length; i++) {
      lineCount++;
      
      // Create new page after reaching line limit
      if (lineCount >= effectiveLinesPerPage) {
        final line = lines[i];
        
        // Get text position at end of this line
        final breakOffset = textPainter.getPositionForOffset(
          Offset(0, line.baseline + line.descent),
        );

        // Extract page text
        String pageText = widget.textContent.substring(
          pageStartIndex,
          breakOffset.offset.clamp(0, widget.textContent.length),
        );

        if (pageText.trim().isNotEmpty) {
          _pageTexts.add(pageText.trim());
        }

        // Reset for next page
        pageStartIndex = breakOffset.offset;
        lineCount = 0;
        isFirstPage = false;
        effectiveLinesPerPage = LINES_PER_PAGE; // Full lines for other pages
      }
    }

    // Add remaining text as last page
    if (pageStartIndex < widget.textContent.length) {
      final lastPageText = widget.textContent.substring(pageStartIndex);
      if (lastPageText.trim().isNotEmpty) {
        _pageTexts.add(lastPageText.trim());
      }
    }

    // Build page widgets
    final bottomNavHeight = widget.showNavBar ? 70.0 : 0.0;

    List<Future<Widget>> futures =
        _pageTexts.asMap().entries.map((entry) async {
      final index = entry.key;
      final text = entry.value;
      final isFirstPageOfChapter = index == 0;

      final cleanedText = BookPageBuilder.cleanBookText(text);
      final pageTextDirection = RTLHelper.getTextDirection(cleanedText);

      return BookPageBuilder.buildBookPage(
        text: cleanedText,
        style: widget.style,
        textDirection: pageTextDirection,
        bookId: widget.bookId,
        onTextTap: widget.onTextTap,
        isFirstPage: isFirstPageOfChapter,
        chapterTitle: isFirstPageOfChapter ? widget.chapterTitle : null,
        pageNumber: index + 1,
        totalPages: _pageTexts.length,
        backgroundColor: widget.style.backgroundColor,
        bottomNavHeight: bottomNavHeight,
      );
    }).toList();

    pages = await Future.wait(futures);
    _handler.totalPages.value = pages.length;
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
                        _handler.currentPage.value = pageIndex + 1;
                        _handler.totalPages.value = pages.length;

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

// import 'package:cosmos_epub/Helpers/selectable_text_with_addnote.dart';
// import 'package:cosmos_epub/PageFlip/page_flip_widget.dart';
// import 'package:cosmos_epub/Helpers/functions.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:get/get.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:html/parser.dart';

// /// 📘 Handler class shared with parent widget

// class PagingTextHandler extends GetxController {
//   final Function paginate;
//   final _box = GetStorage();

//   late final RxInt currentPage;
//   late final RxInt totalPages;
//   late final RxInt globalPage;
//   late final RxInt globalTotalPages;

//   PagingTextHandler({required this.paginate}) {
//     currentPage = (_box.read<int>('currentPage') ?? 0).obs;
//     totalPages = (_box.read<int>('totalPages') ?? 0).obs;
//     globalPage = (_box.read<int>('globalPage') ?? 0).obs;
//     globalTotalPages = (_box.read<int>('globalTotalPages') ?? 0).obs;

//     ever(currentPage, (_) => _box.write('currentPage', currentPage.value));
//     ever(totalPages, (_) => _box.write('totalPages', totalPages.value));
//     ever(globalPage, (_) => _box.write('globalPage', globalPage.value));
//     ever(globalTotalPages,
//         (_) => _box.write('globalTotalPages', globalTotalPages.value));
//   }
// }

// /// 📘 Main Pagination Widget
// class PagingWidget extends StatefulWidget {
//   final String textContent;
//   final String? innerHtmlContent;
//   final String chapterTitle;
//   final int totalChapters;
//   final int starterPageIndex;
//   final String fullBookText;
//   final Function(int)? onGlobalPaginationComplete;
//   final List<String> allChapterTexts;
//   final Function(Map<int, int>)? onAllChaptersPaginated;
//   final TextStyle style;
//   final Function handlerCallback;
//   final VoidCallback onTextTap;
//   final Function(int, int) onPageFlip;
//   final Function(int, int) onLastPage;
//   final Widget? lastWidget;
//   final String bookId;
//   final double pageHeightReduction;
//   final bool showNavBar; // NEW: Track if nav bar is visible

//   const PagingWidget(
//     this.textContent,
//     this.innerHtmlContent, {
//     super.key,
//     this.style = const TextStyle(
//       color: Colors.black,
//       fontSize: 12,
//     ),
//     required this.handlerCallback,
//     required this.onTextTap,
//     required this.onPageFlip,
//     required this.onLastPage,
//     this.starterPageIndex = 0,
//     required this.chapterTitle,
//     required this.totalChapters,
//     this.fullBookText = '',
//     this.onGlobalPaginationComplete,
//     this.allChapterTexts = const [],
//     this.onAllChaptersPaginated,
//     this.lastWidget,
//     required this.bookId,
//     this.pageHeightReduction = 220,
//     this.showNavBar = true, // NEW: Default true
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

//   final _pageKey = GlobalKey();
//   final _pageController = GlobalKey<PageFlipWidgetState>();

//   late PagingTextHandler _handler;

//   int _globalTotalPages = 0;

//   @override
//   void initState() {
//     super.initState();
//     _handler = PagingTextHandler(paginate: rePaginate);
//     widget.handlerCallback(_handler);
//     rePaginate();
//   }

//   /// Rebuild pagination after resize or font change
//   rePaginate() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       setState(() {
//         _initializedRenderBox = context.findRenderObject() as RenderBox;
//         paginateFuture = _paginate();
//       });
//     });
//   }

//   /// Helper to avoid cutting off HTML tags mid-page
//   int findLastHtmlTagIndex(String input) {
//     RegExp regex = RegExp(r'<[^>]');
//     Iterable<Match> matches = regex.allMatches(input);
//     if (matches.isNotEmpty) {
//       return matches.last.end;
//     } else {
//       return -1;
//     }
//   }

//   /// Calculate global page count for ENTIRE book
//   Future<int> _calculateGlobalPageCount(String fullText) async {
//     if (fullText.isEmpty) return 0;

//     final pageSize = _initializedRenderBox.size;
//     final textDirection = RTLHelper.getTextDirection(fullText);
//     final textSpan = TextSpan(text: fullText, style: widget.style);

//     final textPainter = TextPainter(
//       text: textSpan,
//       textDirection: textDirection,
//     );
//     textPainter.layout(minWidth: 0, maxWidth: pageSize.width);

//     List<LineMetrics> lines = textPainter.computeLineMetrics();
//     double currentPageBottom =
//         pageSize.height - 150.h; // Reduced initial height
//     int pageCount = 0;
//     int currentPageStartIndex = 0;

//     for (var line in lines) {
//       final top = line.baseline - line.ascent;
//       final bottom = line.baseline + line.descent;

//       if (currentPageBottom < bottom) {
//         pageCount++;
//         currentPageStartIndex = textPainter
//             .getPositionForOffset(Offset(line.left, top - 150.h))
//             .offset;
//         currentPageBottom = top +
//             pageSize.height -
//             widget.pageHeightReduction.h; // Use configurable value
//       }
//     }

//     // Add last page
//     if (currentPageStartIndex < fullText.length) {
//       pageCount++;
//     }

//     return pageCount;
//   }

//   Future<int> _calculatePageCount(String text) async {
//     if (text.isEmpty) return 0;

//     final pageSize = _initializedRenderBox.size;
//     final textDirection = RTLHelper.getTextDirection(text);
//     final textSpan = TextSpan(text: text, style: widget.style);

//     final textPainter = TextPainter(
//       text: textSpan,
//       textDirection: textDirection,
//     );
//     textPainter.layout(minWidth: 0, maxWidth: pageSize.width - 64.w);

//     List<LineMetrics> lines = textPainter.computeLineMetrics();

//     // Use same calculation as _paginate
//     final bottomNavHeight = widget.showNavBar ? 70.0 : 0.0;
//     final bottomPadding = bottomNavHeight + 50.0;

//     double currentPageBottom = pageSize.height - bottomPadding.h - 20.h;
//     int pageCount = 0;
//     int currentPageStartIndex = 0;

//     for (var line in lines) {
//       final top = line.baseline - line.ascent;
//       final bottom = line.baseline + line.descent;

//       if (currentPageBottom < bottom) {
//         pageCount++;
//         currentPageStartIndex = textPainter
//             .getPositionForOffset(Offset(line.left, top - 20.h))
//             .offset;
//         currentPageBottom = top + pageSize.height - bottomPadding.h - 20.h;
//       }
//     }

//     if (currentPageStartIndex < text.length) {
//       pageCount++;
//     }

//     return pageCount;
//   }

//   Future<void> _paginate() async {
//     final pageSize = _initializedRenderBox.size;
//     _pageTexts.clear();

//     final bottomNavHeight = widget.showNavBar ? 70.0 : 0.0;
//     final bottomPadding = bottomNavHeight + 50.0;

//     // Calculate global total pages from FULL book
//     if (widget.fullBookText.isNotEmpty) {
//       String fullBookTextParsed =
//           parse(widget.fullBookText).documentElement?.text ?? '';
//       _globalTotalPages = await _calculateGlobalPageCount(fullBookTextParsed);
//       _handler.globalTotalPages.value = _globalTotalPages;

//       // Notify parent widget of total pages
//       if (widget.onGlobalPaginationComplete != null) {
//         widget.onGlobalPaginationComplete!(_globalTotalPages);
//       }
//     }

//     if (widget.allChapterTexts.isNotEmpty) {
//       final Map<int, int> chapterPageCounts = {};
//       for (int i = 0; i < widget.allChapterTexts.length; i++) {
//         final chapterText =
//             parse(widget.allChapterTexts[i]).documentElement?.text ?? '';
//         final pageCount = await _calculatePageCount(chapterText);
//         chapterPageCounts[i] = pageCount;
//       }
//       if (widget.onAllChaptersPaginated != null) {
//         widget.onAllChaptersPaginated!(chapterPageCounts);
//       }
//     }

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
//       maxWidth: pageSize.width - 64.w, // Account for horizontal padding
//     );

//     List<LineMetrics> lines = textPainter.computeLineMetrics();

//     double currentPageBottom =
//         pageSize.height - bottomPadding.h - 20.h; // Extra 20h buffer
//     int currentPageStartIndex = 0;
//     int currentPageEndIndex = 0;

//     await Future.wait(lines.map((line) async {
//       final left = line.left;
//       final top = line.baseline - line.ascent;
//       final bottom = line.baseline + line.descent;

//       if (currentPageBottom < bottom) {
//         currentPageEndIndex =
//             textPainter.getPositionForOffset(Offset(left, top - 20.h)).offset;

//         var pageText = widget.textContent
//             .substring(currentPageStartIndex, currentPageEndIndex);

//         var index = findLastHtmlTagIndex(pageText) + currentPageStartIndex;

//         if (index != -1) {
//           int difference = currentPageEndIndex - index;
//           if (difference < 4) {
//             currentPageEndIndex = index - 2;
//           }

//           pageText = widget.textContent
//               .substring(currentPageStartIndex, currentPageEndIndex);
//         }

//         _pageTexts.add(pageText);
//         currentPageStartIndex = currentPageEndIndex;

//         // Reset for next page with proper spacing
//         currentPageBottom = top + pageSize.height - bottomPadding.h - 20.h;
//       }
//     }));

//     final lastPageText = widget.textContent.substring(currentPageStartIndex);
//     _pageTexts.add(lastPageText);

//     // Build page widgets
//     List<Future<Widget>> futures =
//         _pageTexts.asMap().entries.map((entry) async {
//       final index = entry.key;
//       final text = entry.value;
//       final isFirstPageOfChapter = index == 0;

//       final cleanedText = BookPageBuilder.cleanBookText(text);
//       final pageTextDirection = RTLHelper.getTextDirection(cleanedText);

//       return BookPageBuilder.buildBookPage(
//         text: cleanedText,
//         style: widget.style,
//         textDirection: pageTextDirection,
//         bookId: widget.bookId,
//         onTextTap: widget.onTextTap,
//         isFirstPage: isFirstPageOfChapter,
//         chapterTitle: isFirstPageOfChapter ? widget.chapterTitle : null,
//         pageNumber: index + 1,
//         totalPages: null,
//         backgroundColor: widget.style.backgroundColor,
//         bottomNavHeight: bottomNavHeight, // Pass the height
//       );
//     }).toList();

//     pages = await Future.wait(futures);
//     _handler.totalPages.value = pages.length;

//     // List<Future<Widget>> futures = _pageTexts.map((text) async {
//     //   final _scrollController = ScrollController();
//     //   final pageTextDirection = RTLHelper.getTextDirection(text);

//     //   return SizedBox(
//     //     height: MediaQuery.of(context).size.height - 50,
//     //     child: InkWell(
//     //       onTap: widget.onTextTap,
//     //       child: Container(
//     //         color: widget.style.backgroundColor,
//     //         child: FadingEdgeScrollView.fromSingleChildScrollView(
//     //           gradientFractionOnEnd: 0,
//     //           child: SingleChildScrollView(
//     //             controller: _scrollController,
//     //             physics: const NeverScrollableScrollPhysics(),
//     //             child: Padding(
//     //               padding: EdgeInsets.only(
//     //                   bottom: 10.h, top: 20.h, left: 10.w, right: 10.w),
//     //               child: Directionality(
//     //                 textDirection: pageTextDirection,
//     //                 child: widget.innerHtmlContent != null
//     //                     ? Html(
//     //                         data: text,
//     //                         style: {
//     //                           "*": Style(
//     //                               textAlign: TextAlign.justify,
//     //                               fontSize:
//     //                                   FontSize(widget.style.fontSize ?? 0),
//     //                               fontFamily: widget.style.fontFamily,
//     //                               color: widget.style.color),
//     //                         },
//     //                       )
//     //                     : SelectableTextWithCustomToolbar(
//     //                         text: text,
//     //                         textDirection: pageTextDirection,
//     //                         style: widget.style,
//     //                         bookId: widget.bookId,
//     //                       ),
//     //               ),
//     //             ),
//     //           ),
//     //         ),
//     //       ),
//     //     ),
//     //   );
//     // }).toList();

//     // pages = await Future.wait(futures);
//     // _handler.totalPages.value = pages.length;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<void>(
//       future: paginateFuture,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Center(
//             child: CupertinoActivityIndicator(
//               color: Theme.of(context).primaryColor,
//               radius: 20.r,
//             ),
//           );
//         }

//         return Stack(
//           children: [
//             Column(
//               children: [
//                 Expanded(
//                   child: SizedBox.expand(
//                     key: _pageKey,
//                     child: PageFlipWidget(
//                       key: _pageController,
//                       initialIndex: widget.starterPageIndex != 0
//                           ? (pages.isNotEmpty &&
//                                   widget.starterPageIndex < pages.length
//                               ? widget.starterPageIndex
//                               : 0)
//                           : widget.starterPageIndex,
//                       onPageFlip: (pageIndex) {
//                         _currentPageIndex = pageIndex;
//                         _handler.currentPage.value = pageIndex + 1;
//                         _handler.totalPages.value = pages.length;

//                         widget.onPageFlip(pageIndex, pages.length);
//                         if (_currentPageIndex == pages.length - 1) {
//                           widget.onLastPage(pageIndex, pages.length);
//                         }
//                       },
//                       backgroundColor:
//                           widget.style.backgroundColor ?? Colors.white,
//                       lastPage: widget.lastWidget,
//                       children: pages,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
