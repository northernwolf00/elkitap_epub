import 'dart:developer';

import 'package:cosmos_epub/Helpers/chapters_bottom_sheet.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/Helpers/progress_bar_widget.dart';
import 'package:cosmos_epub/book_options_menu.dart';
import 'package:cosmos_epub/widgets/font_settings_modal.dart';
import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
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
  final String imageUrl;
  final String bookId;
  final String chapterListTitle;
  final Function(int currentPage, int totalPages)? onPageFlip;
  final Function(int lastPageIndex)? onLastPage;
  final Color accentColor;

  ShowEpub({
    super.key,
    required this.epubBook,
    required this.accentColor,
    required this.imageUrl,
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
  double fontSizeProgress = 12.0;
  double _fontSize = 12.0;
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
    reLoadChapter(init: true);

    super.initState();
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

    // Use simple for-loop instead of Future.wait
    for (var chapter in epubBook.Chapters!) {
      String? chapterTitle = chapter.Title;
      List<LocalChapterModel> subChapters = [];
      for (var element in chapter.SubChapters!) {
        subChapters.add(
            LocalChapterModel(chapter: element.Title!, isSubChapter: true));
      }

      chaptersList.add(LocalChapterModel(
          chapter: chapterTitle ?? '...', isSubChapter: false));

      chaptersList += subChapters;
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

  updateContentAccordingChapter(int chapterIndex) async {
    ///Set current chapter index
    await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);

    // Directly access the chapter by index instead of iterating all chapters
    String content = epubBook.Chapters![chapterIndex].HtmlContent ?? '';

    // Add subchapters content if they exist
    List<EpubChapter>? subChapters =
        epubBook.Chapters![chapterIndex].SubChapters;
    if (subChapters != null && subChapters.isNotEmpty) {
      for (var subChapter in subChapters) {
        content += subChapter.HtmlContent ?? '';
      }
    }

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
    widget.onPageFlip?.call(localPageIndex, totalChapterPages);
  }

  openTableOfContents() async {
    bool? shouldUpdate = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ChaptersBottomSheet(
            title: bookTitle,
            bookId: bookId,
            imageUrl: widget.imageUrl,
            chapters: chaptersList,
            accentColor: widget.accentColor,
            chapterListTitle: widget.chapterListTitle,
            currentPage: controllerPaging.currentPage.value,
            totalPages: controllerPaging.totalPages.value,
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

  /// Helper method to build navigation buttons
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
    ScreenUtil.init(context,
        designSize: const Size(DESIGN_WIDTH, DESIGN_HEIGHT));

    return WillPopScope(
      onWillPop: backPress,
      child: Scaffold(
        backgroundColor: backColor,
        body: SafeArea(
          child: Stack(
            children: [
              // Main Content Area - Full Screen
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
                                return Center(
                                  child: LoadingWidget(
                                    height: 100,
                                    animationWidth: 50,
                                    animationHeight: 50,
                                  ),
                                );
                              default:
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
                                    fontWeight: FontWeight.w400,
                                    package: 'cosmos_epub',
                                    color: fontColor,
                                  ),
                                  handlerCallback: (ctrl) {
                                    controllerPaging = ctrl;
                                  },
                                  onTextTap: () {
                                    setState(() {
                                      showHeader = !showHeader;
                                    });
                                  },
                                  onPageFlip: (currentPage, totalPages) async {
                                    onPageFlipUpdate(currentPage, totalPages);
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
                                        var currentChapterIndex = bookProgress
                                                .getBookProgress(bookId)
                                                .currentChapterIndex ??
                                            0;
                                        if (currentChapterIndex > 0) {
                                          var previousChapterIndex =
                                              currentChapterIndex - 1;
                                          // Go to last page of previous chapter
                                          await bookProgress.setCurrentPageIndex(
                                              bookId,
                                              999); // Will be clamped to last page
                                          reLoadChapter(
                                              index: previousChapterIndex);
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
                                      chaptersList[currentChapterIndex].chapter,
                                  totalChapters: chaptersList.length,

                                  bookId: bookId,
                                  showNavBar: showHeader, // PASS THIS
                                );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Top Header Bar - OVERLAY
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedContainer(
                  height: showHeader ? 60.h : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    // color: backColor,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                          bookTitle: bookTitle,
                          bookImage: widget.imageUrl,
                          bookId: bookId,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedContainer(
                  height: showHeader ? 70.h : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Container(
                    decoration: BoxDecoration(
                        // color: backColor,
                        // boxShadow: [
                        //   BoxShadow(
                        //     color: Colors.black.withOpacity(0.08),
                        //     blurRadius: 12,
                        //     offset: Offset(0, -2),
                        //   ),
                        // ],
                        // border: Border(
                        //   top: BorderSide(
                        //     color: fontColor.withOpacity(0.08),
                        //     width: 0.5,
                        //   ),
                        // ),
                        ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 8.h,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildNavButton(
                              icon: Icons.menu,
                              onPressed: openTableOfContents,
                              tooltip: 'Table of Contents',
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                child: Obx(() => ProgressBarWidget(
                                      currentPage:
                                          controllerPaging.currentPage.value,
                                      totalPages:
                                          controllerPaging.totalPages.value,
                                    )),
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
                                  fontSizeProgress: _fontSize,
                                  onFontSizeChange: changeFontSize,
                                );
                              },
                              tooltip: 'Font Settings',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
