import 'dart:developer';

import 'package:cosmos_epub/Helpers/chapters_bottom_sheet.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/Helpers/progress_bar_widget.dart';
import 'package:cosmos_epub/book_options_menu.dart';
import 'package:cosmos_epub/widgets/font_settings_modal.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html/parser.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'Component/constants.dart';
import 'Component/theme_colors.dart';

import 'Helpers/custom_toast.dart';
import 'Helpers/pagination.dart';
import 'Helpers/progress_singleton.dart';
import 'Model/chapter_model.dart';

///TODO: Change Future to more controllable timer to control show/hide elements
///  BUG-1: https://github.com/Mamasodikov/cosmos_epub/issues/2
///- Add sub chapters support
///- Add image support
///- Add text style attributes / word-break support

late BookProgressSingleton bookProgress;

const double DESIGN_WIDTH = 375;
const double DESIGN_HEIGHT = 812;

String selectedFont = 'Segoe';
List<String> fontNames = [
  "Segoe",
  "Alegreya",
  "Amazon Ember",
  "Atkinson Hyperlegible",
  "Bitter Pro",
  "Bookerly",
  "Droid Sans",
  "EB Garamond",
  "Gentium Book Plus",
  "Halant",
  "IBM Plex Sans",
  "LinLibertine",
  "Literata",
  "Lora",
  "Ubuntu"
];

Color backColor = Colors.white;
Color fontColor = Colors.black;
int staticThemeId = 3;

// ignore: must_be_immutable
class ShowEpub extends StatefulWidget {
  EpubBook epubBook;
  bool shouldOpenDrawer;
  int starterChapter;
  final String bookId;
  final String chapterListTitle;
  final Function(int currentPage, int totalPages)? onPageFlip;
  final Function(int lastPageIndex)? onLastPage;
  final Color accentColor;

  ShowEpub({
    super.key,
    required this.epubBook,
    required this.accentColor,
    this.starterChapter = 0,
    this.shouldOpenDrawer = false,
    required this.bookId,
    required this.chapterListTitle,
    this.onPageFlip,
    this.onLastPage,
  });

  @override
  State<StatefulWidget> createState() => ShowEpubState();
}

class ShowEpubState extends State<ShowEpub> {
  String htmlContent = '';
  String? innerHtmlContent;
  String textContent = '';
  bool showBrightnessWidget = false;
  final controller = ScrollController();
  Future<void> loadChapterFuture = Future.value(true);
  List<LocalChapterModel> chaptersList = [];
  double fontSizeProgress = 17.0;
  double _fontSize = 17.0;
  TextDirection currentTextDirection = TextDirection.ltr;

  late EpubBook epubBook;
  late String bookId;
  String bookTitle = '';
  String chapterTitle = '';
  double brightnessLevel = 0.5;
  late String selectedTextStyle;

  bool showHeader = true;
  bool isLastPage = false;
  int lastSwipe = 0;
  int prevSwipe = 0;
  bool showPrevious = false;
  bool showNext = false;
  var dropDownFontItems;

  GetStorage gs = GetStorage();

  PagingTextHandler controllerPaging = PagingTextHandler(paginate: () {});

  Map<int, int> chapterPageCounts = {}; // chapterIndex -> pageCount
  int previousChaptersPagesCount = 0; 
  int totalBookPages = 0;
  String fullBookText = '';
  Map<int, int> chapterStartPages = {}; 
  List<String> allChapterTexts = [];

  bool isCalculatingPages = false;

  @override
  void initState() {
    loadThemeSettings();
    bookId = widget.bookId;
    epubBook = widget.epubBook;
    // allFonts = GoogleFonts.asMap().cast<String, String>();
    // fontNames = allFonts.keys.toList();
    // selectedTextStyle = GoogleFonts.getFont(selectedFont).fontFamily!;
    selectedTextStyle =
        fontNames.where((element) => element == selectedFont).first;

    getTitleFromXhtml();
    calculateFullBookText();
    reLoadChapter(init: true);

    super.initState();
  }

  void onAllChaptersPaginated(Map<int, int> pageCounts) {
    if (mounted) {
      setState(() {
        chapterPageCounts = pageCounts;
        calculateChapterStartPages();
        totalBookPages =
            chapterPageCounts.values.fold(0, (sum, count) => sum + count);
        controllerPaging.globalTotalPages.value = totalBookPages;
      });
    }
  }

  Future<void> calculateFullBookPagination() async {
    if (isCalculatingPages) return;
    isCalculatingPages = true;

    try {
      // Wait for render box to be available
      await Future.delayed(Duration(milliseconds: 500));

      StringBuffer fullText = StringBuffer();
      List<String> chapterTexts = [];

      // Collect all chapter texts
      for (var chapter in epubBook.Chapters!) {
        String content = chapter.HtmlContent ?? '';

        List<EpubChapter>? subChapters = chapter.SubChapters;
        if (subChapters != null && subChapters.isNotEmpty) {
          for (var subChapter in subChapters) {
            content += subChapter.HtmlContent ?? '';
          }
        }

        String chapterText = parse(content).documentElement?.text ?? '';
        chapterTexts.add(chapterText);
        fullText.write(chapterText + ' ');
      }

      fullBookText = fullText.toString();

      if (mounted) {
        setState(() {
          // Trigger update after calculation
        });
      }
    } finally {
      isCalculatingPages = false;
    }
  }

  // NEW: Calculate chapter start pages using the same logic as PagingWidget
  Future<void> calculateChapterStartPages() async {
    if (chapterPageCounts.isEmpty) return;

    chapterStartPages.clear();
    int cumulativePageCount = 0;

    for (int i = 0; i < epubBook.Chapters!.length; i++) {
      chapterStartPages[i] = cumulativePageCount + 1; // Pages are 1-indexed
      cumulativePageCount += chapterPageCounts[i] ?? 0;
    }

    // Update chapter list with start pages
    if (mounted) {
      setState(() {
        for (int i = 0; i < chaptersList.length; i++) {
          chaptersList[i].startPage = chapterStartPages[i] ?? 0;
        }
      });
    }
  }

  loadThemeSettings() {
    selectedFont = gs.read(libFont) ?? selectedFont;
    var themeId = gs.read(libTheme) ?? staticThemeId;
    updateTheme(themeId, isInit: true);
    _fontSize = gs.read(libFontSize) ?? _fontSize;
    fontSizeProgress = _fontSize;
  }

  getTitleFromXhtml() {
    if (epubBook.Title != null) {
      bookTitle = epubBook.Title!;
      updateUI();
    }
  }

  reLoadChapter({bool init = false, int index = -1}) async {
    int currentIndex =
        bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    setState(() {
      loadChapterFuture = loadChapter(
          index: init
              ? -1
              : index == -1
                  ? currentIndex
                  : index);
    });
  }

  loadChapter({int index = -1}) async {
    chaptersList = [];

    await Future.wait(epubBook.Chapters!.map((EpubChapter chapter) async {
      String? chapterTitle = chapter.Title;
      List<LocalChapterModel> subChapters = [];
      for (var element in chapter.SubChapters!) {
        subChapters.add(
            LocalChapterModel(chapter: element.Title!, isSubChapter: true));
      }

      chaptersList.add(LocalChapterModel(
          chapter: chapterTitle ?? '...', isSubChapter: false));

      chaptersList += subChapters;
    }));

    if (chapterStartPages.isEmpty) {
      await calculateChapterStartPages();
    }

    ///Choose initial chapter
    if (widget.starterChapter >= 0 &&
        widget.starterChapter < chaptersList.length) {
      setupNavButtons();
      await updateContentAccordingChapter(
          index == -1 ? widget.starterChapter : index);
    } else {
      setupNavButtons();
      await updateContentAccordingChapter(0);
      CustomToast.showToast(
          "Invalid chapter number. Range [0-${chaptersList.length}]");
    }
  }

  void onChapterPagesCalculated(int chapterIndex, int pageCount) {
    setState(() {
      chapterPageCounts[chapterIndex] = pageCount;

      // Recalculate total book pages
      totalBookPages =
          chapterPageCounts.values.fold(0, (sum, count) => sum + count);

      // Update global total in handler
      controllerPaging.globalTotalPages = totalBookPages as RxInt;
    });
  }

  Future<void> calculateFullBookText() async {
    StringBuffer fullText = StringBuffer();
    allChapterTexts.clear();

    await Future.wait(epubBook.Chapters!.map((EpubChapter chapter) async {
      String content = chapter.HtmlContent ?? '';

      List<EpubChapter>? subChapters = chapter.SubChapters;
      if (subChapters != null && subChapters.isNotEmpty) {
        for (var subChapter in subChapters) {
          content += subChapter.HtmlContent ?? '';
        }
      }
      allChapterTexts.add(content);
      fullText.write(content);
    }));

    fullBookText = fullText.toString();
  }

  updateContentAccordingChapter(int chapterIndex) async {
    ///Set current chapter index
    await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);

    String content = '';

    await Future.wait(epubBook.Chapters!.map((EpubChapter chapter) async {
      content = epubBook.Chapters![chapterIndex].HtmlContent!;

      List<EpubChapter>? subChapters = chapter.SubChapters;
      if (subChapters != null && subChapters.isNotEmpty) {
        for (int i = 0; i < subChapters.length; i++) {
          content = content + subChapters[i].HtmlContent!;
        }
      } else {
        subChapters?.forEach((element) {
          if (element.Title == epubBook.Chapters![chapterIndex].Title) {
            content = element.HtmlContent!;
          }
        });
      }
    }));

    htmlContent = content;
    textContent = parse(htmlContent).documentElement!.text;

    if (isHTML(textContent)) {
      innerHtmlContent = textContent;
    } else {
      textContent = textContent.replaceAll('Unknown', '').trim();
    }

    // Detect text direction for the current content
    currentTextDirection = RTLHelper.getTextDirection(textContent);

    controllerPaging.paginate();

    setupNavButtons();
  }

  bool isHTML(String str) {
    final RegExp htmlRegExp =
        RegExp('<[^>]*>', multiLine: true, caseSensitive: false);
    return htmlRegExp.hasMatch(str);
  }

  setupNavButtons() {
    int index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    setState(() {
      if (index == 0) {
        showPrevious = false;
      } else {
        showPrevious = true;
      }
      if (index == chaptersList.length - 1) {
        showNext = false;
      } else {
        showNext = true;
      }
    });
  }

  Future<bool> backPress() async {
    // Navigator.of(context).pop();
    return true;
  }

  void changeFontSize(double newSize) {
    setState(() {
      fontSizeProgress = newSize;
      _fontSize = newSize;
      gs.write(libFontSize, _fontSize);
      updateUI();
      controllerPaging.paginate();
    });
  }

  void onPageFlipUpdate(int localPageIndex, int totalChapterPages) {
    int currentChapterIndex =
        bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    int chapterStartPage = chapterStartPages[currentChapterIndex] ?? 1;

    setState(() {
      controllerPaging.globalPage.value = chapterStartPage + localPageIndex;
    });

    widget.onPageFlip?.call(localPageIndex, totalChapterPages);
  }

  // NEW: Called when global pagination completes
  void onGlobalPaginationComplete(int totalPages) {
    setState(() {
      totalBookPages = totalPages;
      controllerPaging.globalTotalPages.value = totalPages;
    });
  }

  openTableOfContents() async {
    bool? shouldUpdate = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ChaptersBottomSheet(
            title: bookTitle,
            bookId: bookId,
            chapters: chaptersList,
            accentColor: widget.accentColor,
            chapterListTitle: widget.chapterListTitle,
            currentPage: controllerPaging.globalPage.value,
            totalPages: controllerPaging.globalTotalPages.value,
          ),
        ) ??
        false;

    if (shouldUpdate) {
      var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
      await bookProgress.setCurrentPageIndex(bookId, 0);
      reLoadChapter(index: index);
    }
  }

  void setBrightness(double brightness) async {
    await ScreenBrightness().setScreenBrightness(brightness);
    await Future.delayed(const Duration(seconds: 2));
    showBrightnessWidget = false;
    updateUI();
  }

  Widget buildThemeCard({
    required BuildContext context,
    required int id,
    required String title,
    required Color backgroundColor,
    required Color textColor,
    required bool isSelected,
    required StateSetter setState,
  }) {
    return GestureDetector(
      onTap: () {
        updateTheme(id);
        setState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color:
                isSelected ? widget.accentColor : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                color: textColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  updateTheme(int id, {bool isInit = false}) {
    log('theme id $id');
    staticThemeId = id;
    if (id == 1) {
      backColor = cLightGrayColor;
      fontColor = Colors.black;
    } else if (id == 2) {
      backColor = Colors.white;
      fontColor = Colors.black;
    } else if (id == 3) {
      backColor = Colors.white;
      fontColor = Colors.black;
    } else if (id == 4) {
      backColor = cDarkGrayColor;
      fontColor = Colors.white;
    } else if (id == 5) {
      backColor = cCreamColor;
      fontColor = Colors.black;
    } else {
      backColor = cOffWhiteColor;
      fontColor = Colors.black;
    }

    gs.write(libTheme, id);

    if (!isInit) {
      Navigator.of(context).pop();
      controllerPaging.paginate();
      updateUI();
    }
  }

  ///Update widget tree
  updateUI() {
    setState(() {});
  }

  nextChapter() async {
    ///Set page to initial
    await bookProgress.setCurrentPageIndex(bookId, 0);

    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    if (index != chaptersList.length - 1) {
      reLoadChapter(index: index + 1);
    }
  }

  prevChapter() async {
    ///Set page to initial
    await bookProgress.setCurrentPageIndex(bookId, 0);

    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    if (index != 0) {
      reLoadChapter(index: index - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context,
        designSize: const Size(DESIGN_WIDTH, DESIGN_HEIGHT));

    // var currentChapterIndex =
    //     bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    // var chapterStart = chapterStartPages[currentChapterIndex] ?? 1;

    return WillPopScope(
        onWillPop: backPress,
        child: Scaffold(
          backgroundColor: backColor,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                        child: Stack(
                      children: [
                        FutureBuilder<void>(
                            future: loadChapterFuture,
                            builder: (context, snapshot) {
                              switch (snapshot.connectionState) {
                                case ConnectionState.waiting:
                                  {
                                    return Center(
                                        child: CupertinoActivityIndicator(
                                      color: Theme.of(context).primaryColor,
                                      radius: 20.r,
                                    ));
                                  }
                                default:
                                  {
                                    if (widget.shouldOpenDrawer) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        openTableOfContents();
                                      });
                                      widget.shouldOpenDrawer = false;
                                    }

                                    var currentChapterIndex = bookProgress
                                            .getBookProgress(bookId)
                                            .currentChapterIndex ??
                                        0;

                                    return PagingWidget(
                                      textContent,
                                      innerHtmlContent,
                                      lastWidget: null,
                                      starterPageIndex: bookProgress
                                              .getBookProgress(bookId)
                                              .currentPageIndex ??
                                          0,
                                      style: TextStyle(
                                          backgroundColor: backColor,
                                          fontSize: _fontSize.sp,
                                          fontFamily: selectedTextStyle,
                                          package: 'cosmos_epub',
                                          color: fontColor),
                                      handlerCallback: (ctrl) {
                                        controllerPaging = ctrl;
                                      },
                                      onTextTap: () {
                                        setState(() {
                                          showHeader = !showHeader;
                                        });
                                      },
                                      onPageFlip:
                                          (currentPage, totalPages) async {
                                        onPageFlipUpdate(
                                            currentPage, totalPages);
                                        if (widget.onPageFlip != null) {
                                          widget.onPageFlip!(
                                              currentPage, totalPages);
                                        }

                                        if (currentPage == totalPages - 1) {
                                          bookProgress.setCurrentPageIndex(
                                              bookId, 0);
                                        } else {
                                          bookProgress.setCurrentPageIndex(
                                              bookId, currentPage);
                                        }

                                        if (isLastPage) {
                                          showHeader = true;
                                        } else {
                                          lastSwipe = 0;
                                        }

                                        isLastPage = false;
                                        updateUI();

                                        if (currentPage == 0) {
                                          prevSwipe++;
                                          if (prevSwipe > 1) {
                                            var currentChapterIndex =
                                                bookProgress
                                                        .getBookProgress(bookId)
                                                        .currentChapterIndex ??
                                                    0;
                                            if (currentChapterIndex > 0) {
                                              var previousChapterIndex =
                                                  currentChapterIndex - 1;
                                              var pageCountOfPreviousChapter =
                                                  chapterPageCounts[
                                                          previousChapterIndex] ??
                                                      0;
                                              await bookProgress.setCurrentPageIndex(
                                                  bookId,
                                                  pageCountOfPreviousChapter -
                                                      1); // Go to last page of previous chapter
                                              reLoadChapter(
                                                  index:
                                                      previousChapterIndex); // Load the previous chapter
                                            } else {
                                              // Already at the first chapter, cannot go to previous page/chapter
                                              // Optionally, show a toast or disable further backward swipe
                                            }
                                          }
                                        } else {
                                          prevSwipe = 0;
                                        }
                                      },
                                      onLastPage: (index, totalPages) async {
                                        if (widget.onLastPage != null) {
                                          widget.onLastPage!(index);
                                        }

                                        if (totalPages > 1) {
                                          lastSwipe++;
                                        } else {
                                          lastSwipe = 2;
                                        }

                                        if (lastSwipe > 1) {
                                          nextChapter();
                                          setState(() {});
                                        }

                                        isLastPage = true;
                                        updateUI();
                                      },
                                      chapterTitle:
                                          chaptersList[currentChapterIndex]
                                              .chapter,
                                      totalChapters: chaptersList.length,
                                      fullBookText: fullBookText,
                                      allChapterTexts: allChapterTexts,
                                      onAllChaptersPaginated:
                                          onAllChaptersPaginated,
                                          bookId: bookId,
                                    );
                                  }
                              }
                            }),
                      ],
                    )),

                    // Bottom Navigation Bar (Image 1 style)
                    AnimatedContainer(
                      height: showHeader ? 60.h : 0,
                      duration: const Duration(milliseconds: 100),
                      color: backColor,
                      child: Container(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left - Menu/Contents button
                              Container(
                                width: 34.w,
                                height: 34.h,
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    shape: BoxShape.circle),
                                child: IconButton(
                                  onPressed: openTableOfContents,
                                  icon: Icon(
                                    size: 18,
                                    Icons.menu,
                                    color: fontColor,
                                  ),
                                  // SvgPicture.asset(
                                  //     'packages/cosmos_epub/assets/icons/r2.svg'),
                                  padding: EdgeInsets.zero,
                                ),
                              ),

                              // Center - Page progress indicator
                              Obx(() => ProgressBarWidget(
                                    currentPage:
                                        controllerPaging.globalPage.value + 1,
                                    totalPages:
                                        controllerPaging.globalTotalPages.value,
                                  )),

                              // Right - Font Settings button
                              Container(
                                width: 34.w,
                                height: 34.h,
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    shape: BoxShape.circle),
                                child: IconButton(
                                  onPressed: () {
                                    updateFontSettings(
                                      context: context,
                                      backColor: backColor,
                                      fontColor: fontColor,
                                      brightnessLevel: brightnessLevel,
                                      staticThemeId: staticThemeId,
                                      setBrightness: setBrightness,
                                      updateTheme: updateTheme,
                                      fontSizeProgress: _fontSize,
                                      onFontSizeChange: changeFontSize,
                                    );
                                  },
                                  icon: Text(
                                    "Aa",
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: fontColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Top Header Bar (Image 2 style)
                AnimatedContainer(
                  height: showHeader ? 60.h : 0,
                  duration: const Duration(milliseconds: 100),
                  // color: backColor,
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left - Close button
                        Container(
                          width: 34.w,
                          height: 34.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
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
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
