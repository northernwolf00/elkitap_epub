import 'dart:developer';

import 'package:cosmos_epub/Helpers/chapters_bottom_sheet.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/book_options_menu.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html/parser.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'Component/constants.dart';
import 'Component/theme_colors.dart';
import 'Helpers/chapters.dart';
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
  double _fontSizeProgress = 17.0;
  double _fontSize = 17.0;
  TextDirection currentTextDirection = TextDirection.ltr;

  late EpubBook epubBook;
  late String bookId;
  String bookTitle = '';
  String chapterTitle = '';
  double brightnessLevel = 0.5;

  // late Map<String, String> allFonts;

  // Initialize with the first font in the list
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
  int previousChaptersPagesCount = 0; // Pages from chapters before current
  int totalBookPages = 0;
  String fullBookText = '';
  Map<int, int> chapterStartPages = {}; // chapterIndex -> startPage

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

      // This will be called after PagingWidget is initialized
      // Store chapter texts for later calculation
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
    if (fullBookText.isEmpty) return;

    chapterStartPages.clear();
    int cumulativePageCount = 0;

    for (int i = 0; i < epubBook.Chapters!.length; i++) {
      chapterStartPages[i] = cumulativePageCount + 1; // Pages are 1-indexed

      // Get chapter text
      String content = epubBook.Chapters![i].HtmlContent ?? '';
      List<EpubChapter>? subChapters = epubBook.Chapters![i].SubChapters;
      if (subChapters != null && subChapters.isNotEmpty) {
        for (var subChapter in subChapters) {
          content += subChapter.HtmlContent ?? '';
        }
      }

      String chapterText = parse(content).documentElement?.text ?? '';

      // Estimate page count for this chapter (will be refined by PagingWidget)
      int estimatedPages = (chapterText.length / 2000).ceil(); // Rough estimate
      cumulativePageCount += estimatedPages;
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
    _fontSizeProgress = _fontSize;
  }

  getTitleFromXhtml() {
    ///Listener for slider
    // controller.addListener(() {
    //   if (controller.position.userScrollDirection == ScrollDirection.forward &&
    //       showHeader == false) {
    //     showHeader = true;
    //     update();
    //   } else if (controller.position.userScrollDirection ==
    //           ScrollDirection.reverse &&
    //       showHeader) {
    //     showHeader = false;
    //     update();
    //   }
    // });

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
      controllerPaging.globalTotalPages = totalBookPages;
    });
  }

  Future<void> calculateFullBookText() async {
    StringBuffer fullText = StringBuffer();

    await Future.wait(epubBook.Chapters!.map((EpubChapter chapter) async {
      String content = chapter.HtmlContent ?? '';

      List<EpubChapter>? subChapters = chapter.SubChapters;
      if (subChapters != null && subChapters.isNotEmpty) {
        for (var subChapter in subChapters) {
          content += subChapter.HtmlContent ?? '';
        }
      }

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

  void onPageFlipUpdate(int localPageIndex, int totalChapterPages) {
    int currentChapterIndex =
        bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    int chapterStartPage = chapterStartPages[currentChapterIndex] ?? 1;

    setState(() {
      controllerPaging.globalPage = chapterStartPage + localPageIndex;
    });

    widget.onPageFlip?.call(localPageIndex, totalChapterPages);
  }

  // NEW: Called when global pagination completes
  void onGlobalPaginationComplete(int totalPages) {
    setState(() {
      totalBookPages = totalPages;
      controllerPaging.globalTotalPages = totalPages;
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
            currentPage: controllerPaging.globalPage,
            totalPages: controllerPaging.globalTotalPages,
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
    await Future.delayed(const Duration(seconds: 5));
    showBrightnessWidget = false;
    updateUI();
  }

  updateFontSettings() {
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
                topRight: Radius.circular(20.r))),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, setState) => Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
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

                        // Font Size Slider Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width - 120,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Small A (decrease)

                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _fontSizeProgress -= 1.0;
                                          // Clamp value between min and max
                                          _fontSizeProgress = _fontSizeProgress
                                              .clamp(15.0, 30.0);
                                          _fontSize = _fontSizeProgress;
                                          gs.write(libFontSize, _fontSize);
                                          updateUI();
                                          controllerPaging.paginate();
                                        });
                                      },
                                      child: Container(
                                        width: 40.w,
                                        height: 40.h,
                                        alignment: Alignment.center,
                                        child: Text(
                                          "A",
                                          style: TextStyle(
                                              fontSize: 16.sp,
                                              color: fontColor,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Divider
                                  Container(
                                    width: 1,
                                    height: 30.h,
                                    margin:
                                        EdgeInsets.symmetric(horizontal: 12.w),
                                    color: Colors.grey.withOpacity(0.3),
                                  ),

                                  // Large A (increase)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 20),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _fontSizeProgress += 1.0;
                                          // Clamp value between min and max
                                          _fontSizeProgress = _fontSizeProgress
                                              .clamp(15.0, 30.0);
                                          _fontSize = _fontSizeProgress;
                                          gs.write(libFontSize, _fontSize);
                                          updateUI();
                                          controllerPaging.paginate();
                                        });
                                      },
                                      child: Container(
                                        width: 40.w,
                                        height: 40.h,
                                        alignment: Alignment.center,
                                        child: Text(
                                          "A",
                                          style: TextStyle(
                                              fontSize: 22.sp,
                                              color: fontColor,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Brightness toggle
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
                                padding: EdgeInsets.zero,
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
                        ),

                        SizedBox(height: 12.h),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Visibility(
                            visible: true,
                            child: Container(
                              width: double.infinity,
                              // padding: EdgeInsets.symmetric(
                              //     horizontal: 20.w, vertical: 12.h),
                              margin: EdgeInsets.only(
                                  bottom: 20.h, left: 10.w, right: 10.w),
                              decoration: BoxDecoration(
                                color: backColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                children: [
                                  // The '0' symbol on the left
                                  Padding(
                                      padding: EdgeInsets.only(
                                          right: 15.0
                                              .w), // Adjust padding as needed
                                      child: Container(
                                        height: 18,
                                        width: 18,
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: fontColor, width: 2),
                                            shape: BoxShape.circle),
                                      )),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight:
                                            24.0, // Significantly increased height for the thick look
                                        trackShape:
                                            const RoundedRectSliderTrackShape(), // Default is already good for this shape

                                        // 2. Set colors to match the grey gradient in the image
                                        activeTrackColor: Colors.grey
                                            .shade600, // Darker grey for the active (filled) part
                                        inactiveTrackColor: Colors.grey
                                            .shade300, // Lighter grey for the inactive part

                                        // 3. Make the thumb (the drag handle) practically invisible
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius:
                                              0.0, // Set radius to 0 to hide it
                                          disabledThumbRadius: 0.0,
                                        ),
                                        overlayShape:
                                            const RoundSliderOverlayShape(
                                          overlayRadius:
                                              0.0, // Also hide the overlay
                                        ),
                                        // Ensure the thumb is transparent just in case
                                        thumbColor: Colors.transparent,
                                        disabledThumbColor: Colors.transparent,

                                        // ------------------------------------------
                                      ),
                                      child: Slider(
                                        value: brightnessLevel,
                                        min: 0.0,
                                        max: 1.0,
                                        onChangeEnd: (double value) {
                                          setBrightness(value);
                                        },
                                        onChanged: (double value) {
                                          setState(() {
                                            brightnessLevel = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  // The sun icon on the right
                                  Padding(
                                    padding: EdgeInsets.only(left: 15.0.w),
                                    child: Icon(
                                      Icons.wb_sunny_outlined,
                                      size: 25.sp,
                                      color: fontColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Slider below
                        // Row(
                        //   children: [
                        //     Icon(Icons.brightness_low,
                        //         color: Colors.grey, size: 20.sp),
                        //     Expanded(
                        //       child: Slider(
                        //         activeColor: widget.accentColor,
                        //         inactiveColor: Colors.grey.withOpacity(0.3),
                        //         value: _fontSizeProgress,
                        //         min: 15.0,
                        //         max: 30.0,
                        //         onChangeEnd: (double value) {
                        //           _fontSize = value;
                        //           gs.write(libFontSize, _fontSize);
                        //           updateUI();
                        //           controllerPaging.paginate();
                        //         },
                        //         onChanged: (double value) {
                        //           setState(() {
                        //             _fontSizeProgress = value;
                        //           });
                        //         },
                        //       ),
                        //     ),
                        //     Icon(Icons.brightness_high,
                        //         color: Colors.grey, size: 20.sp),
                        //   ],
                        // ),

                        // Theme Cards Grid
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          crossAxisSpacing: 12.w,
                          mainAxisSpacing: 12.h,
                          childAspectRatio: 1.1,
                          physics: NeverScrollableScrollPhysics(),
                          children: [
                            _buildThemeCard(
                              context: context,
                              id: 3,
                              title: 'Bold',
                              backgroundColor: staticThemeId == 4
                                  ? Colors.black87
                                  : Colors.white,
                              textColor: staticThemeId == 4
                                  ? Colors.white
                                  : Colors.black,
                              isSelected: staticThemeId == 3,
                              setState: setState,
                            ),
                            _buildThemeCard(
                              context: context,
                              id: 4,
                              title: 'Quite',
                              backgroundColor: Color(0xFF4A4A4C),
                              textColor: Colors.white,
                              isSelected: staticThemeId == 4,
                              setState: setState,
                            ),
                            _buildThemeCard(
                              context: context,
                              id: 1,
                              title: 'Paper',
                              backgroundColor: staticThemeId == 4
                                  ? Colors.grey
                                  : Color(0xFFF0ECED),
                              textColor: Colors.black,
                              isSelected: staticThemeId == 1,
                              setState: setState,
                            ),
                            _buildThemeCard(
                              context: context,
                              id: 2,
                              title: 'Bold',
                              backgroundColor: staticThemeId == 4
                                  ? Colors.black87
                                  : Colors.white,
                              textColor: staticThemeId == 4
                                  ? Colors.white
                                  : Colors.black,
                              isSelected: staticThemeId == 2,
                              setState: setState,
                            ),
                            _buildThemeCard(
                              context: context,
                              id: 5,
                              title: 'Calm',
                              backgroundColor: staticThemeId == 4
                                  ? const Color.fromARGB(255, 85, 78, 65)
                                  : Color(0xFFFFF8E7),
                              textColor: Colors.black,
                              isSelected: staticThemeId == 5,
                              setState: setState,
                            ),
                            _buildThemeCard(
                              context: context,
                              id: 6,
                              title: 'Focus',
                              backgroundColor: Color(0xFFFFFCF4),
                              textColor: Colors.black,
                              isSelected: staticThemeId == 6,
                              setState: setState,
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),
                      ],
                    ),
                  ));
        });
  }

  Widget _buildThemeCard({
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
                                      onPageFlip: (currentPage, totalPages) {
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
                                            prevChapter();
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
                                        }

                                        isLastPage = true;
                                        updateUI();
                                      },
                                      chapterTitle:
                                          chaptersList[currentChapterIndex]
                                              .chapter,
                                      totalChapters: chaptersList.length,
                                      fullBookText: fullBookText,
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
                              Expanded(
                                child: Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 16.w),
                                  child: Container(
                                    height: 28.h,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(50),
                                      color: Colors.grey.withOpacity(0.15),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Progress bar based on GLOBAL pages
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final globalTotal = controllerPaging
                                                .globalTotalPages;
                                            final globalCurrent =
                                                controllerPaging.globalPage;
                                            final progress = globalTotal > 0
                                                ? (globalCurrent / globalTotal)
                                                    .clamp(0.0, 1.0)
                                                : 0.0;

                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 5),
                                              child: Container(
                                                width: constraints.maxWidth *
                                                    progress,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey,
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        // Display GLOBAL page numbers
                                        Center(
                                          child: Text(
                                            '${controllerPaging.currentPage} / ${controllerPaging.globalTotalPages}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.sp,
                                              color: fontColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Right - Font Settings button
                              Container(
                                width: 34.w,
                                height: 34.h,
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    shape: BoxShape.circle),
                                child: IconButton(
                                  onPressed: updateFontSettings,
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

                        // Center - Book title
                        // Expanded(
                        //   child: Center(
                        //     child: Text(
                        //       bookTitle,
                        //       style: TextStyle(
                        //         fontWeight: FontWeight.w500,
                        //         fontSize: 16.sp,
                        //         color: fontColor,
                        //       ),
                        //       overflow: TextOverflow.ellipsis,
                        //       maxLines: 1,
                        //     ),
                        //   ),
                        // ),

                        BookOptionsMenu(
                          fontColor: fontColor,
                          backColor: backColor,
                        )

                        // Container(
                        //   width: 34
                        //       .w,
                        //   height: 34
                        //       .h,
                        //   decoration: BoxDecoration(

                        //     color: Colors.grey.withOpacity(0.2),
                        //     shape: BoxShape.circle,
                        //   ),
                        //   child: PopupMenuButton<String>(

                        //     icon: Icon(
                        //       Icons.more_horiz,
                        //       color: fontColor,
                        //       size: 16
                        //           .sp,
                        //     ),

                        //     color: backColor,

                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(12
                        //           .r),
                        //     ),

                        //     offset: Offset(0,
                        //         50.h),

                        //     onSelected: (value) {
                        //       switch (value) {
                        //         case 'contents':
                        //           openTableOfContents();
                        //           break;
                        //         case 'settings':
                        //           updateFontSettings();
                        //           break;
                        //         case 'brightness':
                        //           setState(() {
                        //             showBrightnessWidget = true;
                        //           });

                        //           Future.delayed(const Duration(seconds: 7),
                        //               () {
                        //             if (mounted) {
                        //               setState(() {
                        //                 showBrightnessWidget = false;
                        //               });
                        //             }
                        //           });
                        //           break;
                        //       }
                        //     },

                        //     itemBuilder: (BuildContext context) => [

                        //       PopupMenuItem<String>(
                        //         value: 'contents',
                        //         child: Row(
                        //           children: [
                        //             Icon(Icons.menu,
                        //                 color: fontColor, size: 20.sp),
                        //             SizedBox(width: 12.w),
                        //             Text(
                        //               'Table of Contents',
                        //               style: TextStyle(
                        //                   color: fontColor, fontSize: 14.sp),
                        //             ),
                        //           ],
                        //         ),
                        //       ),

                        //       PopupMenuItem<String>(
                        //         value: 'settings',
                        //         child: Row(
                        //           children: [
                        //             Icon(Icons.text_fields,
                        //                 color: fontColor, size: 20.sp),
                        //             SizedBox(width: 12.w),
                        //             Text(
                        //               'Font Settings',
                        //               style: TextStyle(
                        //                   color: fontColor, fontSize: 14.sp),
                        //             ),
                        //           ],
                        //         ),
                        //       ),

                        //       PopupMenuItem<String>(
                        //         value: 'brightness',
                        //         child: Row(
                        //           children: [
                        //             Icon(Icons.brightness_6,
                        //                 color: fontColor, size: 20.sp),
                        //             SizedBox(width: 12.w),
                        //             Text(
                        //               'Brightness',
                        //               style: TextStyle(
                        //                   color: fontColor, fontSize: 14.sp),
                        //             ),
                        //           ],
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }

//   openTableOfContents() async {
//     bool? shouldUpdate = await Navigator.of(context).push(MaterialPageRoute(
//             builder: (context) => ChaptersList(
//                   bookId: bookId,
//                   chapters: chaptersList,
//                   leadingIcon: null,
//                   accentColor: widget.accentColor,
//                   chapterListTitle: widget.chapterListTitle,
//                 ))) ??
//         false;
//     if (shouldUpdate) {
//       var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
//       await bookProgress.setCurrentPageIndex(bookId, 0);
//       reLoadChapter(index: index);
//     }
//   }
}

// ignore: must_be_immutable
