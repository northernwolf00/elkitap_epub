import 'dart:developer';

import 'package:cosmos_epub/Helpers/chapters_bottom_sheet.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:html/parser.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'Component/constants.dart';
import 'Helpers/pagination.dart';
import 'Helpers/progress_singleton.dart';
import 'Model/chapter_model.dart';
import 'helpers/epub_cache_helper.dart';
import 'helpers/epub_chapter_helper.dart';
import 'helpers/epub_pagination_helper.dart';
import 'widgets/epub_bottom_nav_widget.dart';
import 'widgets/epub_header_widget.dart';

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
    this.starterPageInBook,
  });

  final Function(int currentPage, int totalPages)? onPageFlip;
  final Function(int lastPageIndex)? onLastPage;
  final Color accentColor;
  final String bookId;
  final String chapterListTitle;
  EpubBook epubBook;
  final String imageUrl;
  bool shouldOpenDrawer;
  int starterChapter;
  final int? starterPageInBook;

  @override
  State<StatefulWidget> createState() => ShowEpubState();
}

class ShowEpubState extends State<ShowEpub> {
  int accumulatedPagesBeforeCurrentChapter = 0;
  bool allChaptersCalculated = false; // Track if we've calculated all chapters
  late String bookId;
  String bookTitle = '';
  double brightnessLevel = 0.5;
  // Track pages per chapter and cumulative totals
  Map<int, int> chapterPageCounts = {};

  String chapterTitle = '';
  List<LocalChapterModel> chaptersList = [];
  final controller = ScrollController();
  PagingTextHandler controllerPaging =
      PagingTextHandler(paginate: () {}, bookId: '');
  TextDirection currentTextDirection = TextDirection.ltr;
  var dropDownFontItems;
  late EpubBook epubBook;
  double fontSizeProgress = 14.0;
  GetStorage gs = GetStorage();
  String htmlContent = '';
  String? innerHtmlContent;
  bool isCalculatingTotalPages = false;
  bool isLastPage = false;
  int lastSwipe = 0;
  Future<void> loadChapterFuture = Future.value(true);
  int prevSwipe = 0;
  late String selectedTextStyle;
  bool showBrightnessWidget = false;
  bool showHeader = true;
  bool showNext = false;
  bool showPrevious = false;
  String textContent = '';
  int totalPagesInBook = 0; // Total pages across all chapters

  int _cachedKnownPagesTotal =
      0; // Cache to avoid recalculating fold every time
  // Mapping from filtered chapter index to original EPUB chapter index
  Map<int, int> _filteredToOriginalIndex = {};
  int _currentChapterPageCount =
      0; // Current chapter's actual page count from PagingWidget

  double _fontSize = 14.0;
  // Audio progress synchronization
  bool _hasAppliedAudioSync = false;

  bool _isLoadingChapter = false; // Prevent multiple simultaneous chapter loads
  int? _pendingCurrentPageInBook;
  int? _pendingTotalPages;
  int? _targetChapterFromAudioSync;
  int? _targetPageFromAudioSync;

  // Track current subchapter title to display
  String? _currentSubchapterTitle;

  // Helper instances
  late EpubCacheHelper _cacheHelper;
  late EpubChapterHelper _chapterHelper;
  late EpubPaginationHelper _paginationHelper;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ❌ DISABLED: Precalculation should be done BEFORE opening book (in download/loading screen)
    // This prevents UI freezing when opening the book
    // if (!_precalcScheduled) {
    //   _precalcScheduled = true;
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (!mounted || _isDisposed) return;
    //
    //     final size = MediaQuery.of(context).size;
    //
    //     // Only start precalc if size has changed or this is the first time
    //     final sizeChanged = _lastPrecalcSize == null || (_lastPrecalcSize!.width != size.width || _lastPrecalcSize!.height != size.height);
    //
    //     if (sizeChanged && !allChaptersCalculated) {
    //       _lastPrecalcSize = size;
    //       // Start precalc immediately but with loading indicator
    //       // This prevents page count jumping from 1 to final count
    //       Future.delayed(const Duration(milliseconds: 100), () {
    //         if (!mounted || _isDisposed) return;
    //         _precalculateAllChaptersTotal(size);
    //       });
    //     }
    //   });
    // }
  }

  @override
  void dispose() {
    // _isDisposed = true;
    isCalculatingTotalPages = false;
    super.dispose();
  }

  @override
  void initState() {
    loadThemeSettings();
    bookId = widget.bookId;
    epubBook = widget.epubBook;
    controllerPaging = PagingTextHandler(paginate: () {}, bookId: bookId);

    // Set selectedTextStyle BEFORE initializing helpers that depend on it
    selectedTextStyle = fontNames.firstWhere(
      (element) => element == selectedFont,
      orElse: () => fontNames.first,
    );

    // Initialize helpers (after selectedTextStyle is set)
    _cacheHelper = EpubCacheHelper(bookId: bookId, gs: gs);
    _chapterHelper = EpubChapterHelper(
      epubBook: epubBook,
      bookId: bookId,
      bookProgress: bookProgress,
    );
    _paginationHelper = EpubPaginationHelper(
      epubBook: epubBook,
      fontSize: _fontSize,
      selectedTextStyle: selectedTextStyle,
      fontColor: fontColor,
    );

    // Initialize EPUB structure
    _chapterHelper.initializeEpubStructure();

    getTitleFromXhtml();

    // Load cached page counts
    _loadCachedPageCounts();

    reLoadChapter(init: true);

    super.initState();
  }

  loadThemeSettings() {
    selectedFont = gs.read(libFont) ?? selectedFont;
    var themeId = gs.read(libTheme) ?? staticThemeId;
    updateTheme(themeId, isInit: true);
    _fontSize = gs.read(libFontSize) ?? 14.0;
    fontSizeProgress = _fontSize;
  }

  getTitleFromXhtml() {
    if (epubBook.Title != null) {
      bookTitle = epubBook.Title!;
      updateUI();
    }
  }

  reLoadChapter({bool init = false, int index = -1, int startPage = 0}) async {
    // Prevent multiple simultaneous loads
    if (_isLoadingChapter) {
      return;
    }

    _isLoadingChapter = true;
    int currentIndex =
        bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    int targetIndex = index == -1 ? currentIndex : index;

    // Always reset swipe counters when loading a chapter to prevent accidental navigation
    lastSwipe = 0;
    prevSwipe = 0;

    // If chapter is changing (not init and index provided), update the saved chapter index
    if (!init && index != -1 && index != currentIndex) {
      await bookProgress.setCurrentChapterIndex(bookId, index);
      await bookProgress.setCurrentPageIndex(bookId, startPage);
    } else if (startPage > 0) {
      // Same chapter but different page (sub-chapter navigation)
      await bookProgress.setCurrentPageIndex(bookId, startPage);
    }

    setState(() {
      loadChapterFuture = loadChapter(init: init, index: targetIndex).then((_) {
        _isLoadingChapter = false;
      }).catchError((e, stackTrace) {
        _isLoadingChapter = false;
        // Don't rethrow - let FutureBuilder handle the error state
      });
    });
  }

  loadChapter({int index = -1, bool init = false}) async {
    chaptersList = [];

    // Debug: Print EPUB structure FIRST
    print('');
    print('📚 ═══════════════════════════════════════════════════════');
    print('📚 EPUB STRUCTURE DEBUG');
    print('📚 Total chapters in EPUB: ${_chapters.length}');
    for (int i = 0; i < _chapters.length; i++) {
      var ch = _chapters[i];
      print('📚 Chapter $i: "${ch.Title}"');
      if (ch.SubChapters != null && ch.SubChapters!.isNotEmpty) {
        print('📚   └─ Has ${ch.SubChapters!.length} sub-chapters:');
        for (int j = 0; j < ch.SubChapters!.length; j++) {
          print('📚      └─ Sub $j: "${ch.SubChapters![j].Title}"');
        }
      }
    }
    print('📚 ═══════════════════════════════════════════════════════');
    print('');

    // Try to get chapter titles from Navigation (TOC) first
    Map<String, String> navTitles = {};
    if (epubBook.Schema?.Navigation?.NavMap?.Points != null) {
      for (var point in epubBook.Schema!.Navigation!.NavMap!.Points!) {
        if (point.Content?.Source != null &&
            point.NavigationLabels != null &&
            point.NavigationLabels!.isNotEmpty) {
          // Extract the HTML file name from the Source path
          String source = point.Content!.Source!;
          String fileName = source.split('#').first; // Remove anchor
          fileName = fileName.split('/').last; // Get just the filename
          // Use the first navigation label's text
          String? labelText = point.NavigationLabels!.first.Text;
          if (labelText != null && labelText.isNotEmpty) {
            navTitles[fileName] = labelText;
          }
        }
      }
    }

    // Add all chapters (don't filter by content length)
    for (int i = 0; i < _chapters.length; i++) {
      var chapter = _chapters[i];

      // Use the title from cosmos_epub - it's already extracted properly
      String? chapterTitle = chapter.Title;

      // Only try to improve if title is REALLY generic/useless
      final needsExtraction = chapterTitle == null ||
          chapterTitle.isEmpty ||
          chapterTitle.contains('_split_') ||
          chapterTitle.toLowerCase().startsWith('index split') ||
          chapterTitle.contains('.html') ||
          chapterTitle.contains('.xhtml') ||
          chapterTitle.toLowerCase() == 'titlepage' ||
          chapterTitle.toLowerCase() == 'index' ||
          chapterTitle.toLowerCase() == 'cover';

      // If title is just "Chapter X" (without description), try to get a better one from navigation
      final isBasicChapterTitle = chapterTitle != null &&
          RegExp(r'^Chapter \d+$', caseSensitive: false).hasMatch(chapterTitle);

      if (needsExtraction || isBasicChapterTitle) {
        // Try navigation TOC for a better title
        String? contentRef = chapter.ContentFileName;
        if (contentRef != null) {
          String fileName = contentRef.split('/').last.split('#').first;
          if (navTitles.containsKey(fileName)) {
            String navTitle = navTitles[fileName]!;
            // Use navigation title if it's better (not empty and different)
            if (navTitle.isNotEmpty && navTitle != chapterTitle) {
              chapterTitle = navTitle;
            }
          }
        }
      }

      // Calculate startPage for this chapter based on accumulated pages
      int chapterStartPage = 1; // Default to page 1
      int accumulatedPages = 0;

      // Calculate accumulated pages from all previous chapters AND their sub-chapters
      for (int j = 0; j < i; j++) {
        // Add main chapter pages
        accumulatedPages += chapterPageCounts[j] ?? 0;
      }
      chapterStartPage = accumulatedPages + 1; // Pages are 1-indexed

      // Add chapter to list with page information
      chaptersList.add(LocalChapterModel(
        chapter: chapterTitle ?? 'Chapter ${i + 1}',
        isSubChapter: false,
        startPage: chapterPageCounts.containsKey(i)
            ? chapterStartPage
            : 0, // 0 means not calculated yet
        pageCount: chapterPageCounts[i] ?? 0,
      ));
      final listIndex = chaptersList.length - 1;
      _filteredToOriginalIndex[listIndex] = i;

      // Add sub-chapters as SEPARATE entries in TOC (like Apple Books)
      // Each sub-chapter points to the same parent content but shows in TOC
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        for (int subIdx = 0; subIdx < chapter.SubChapters!.length; subIdx++) {
          var subChapter = chapter.SubChapters![subIdx];
          String? subTitle = subChapter.Title;
          if (subTitle != null && subTitle.isNotEmpty) {
            final subChapterIndex = chaptersList.length;

            // Store sub-chapter index to calculate pageInChapter later in _updateChapterPageNumbers
            // when parent's actual page count is known
            chaptersList.add(LocalChapterModel(
              chapter: subTitle,
              isSubChapter: true,
              startPage: 0, // Will be calculated in _updateChapterPageNumbers
              pageCount: 0, // Sub-chapters don't have their own page count
              parentChapterIndex: listIndex,
              pageInChapter:
                  subIdx, // Store subIdx, will calculate actual position in _updateChapterPageNumbers
            ));
            // Map sub-chapter back to parent chapter's original index
            _filteredToOriginalIndex[subChapterIndex] = i;
          }
        }
      }
    }

    // Chapter list built (debug logs removed for clarity)

    // Debug: print chapter map immediately after list build
    _updateChapterPageNumbers();

    // Start background calculation if we don't have all chapters cached
    if (chapterPageCounts.length < _chapters.length) {
      _calculateTotalPagesInBackground();
    }

    // Decide which chapter to open
    final progress = bookProgress.getBookProgress(bookId);
    final savedChapter = progress.currentChapterIndex ?? 0;
    final savedPage = progress.currentPageIndex ?? 0;
    final hasProgress = (savedChapter != 0) || (savedPage != 0);

    int targetIndex = index;
    if (init) {
      // Priority 1: Audio sync (starterPageInBook) - only if we have cached page counts
      if (widget.starterPageInBook != null && chapterPageCounts.isNotEmpty) {
        print('');
        print('🎵 ═══════════════════════════════════════════════════════');
        print('🎵 AUDIO SYNC REQUESTED');
        print('🎵 Target page in book: ${widget.starterPageInBook}');
        print('🎵 ═══════════════════════════════════════════════════════');
        print('');

        final result =
            _calculateChapterAndPageFromBookPage(widget.starterPageInBook!);
        if (result != null) {
          targetIndex = result['chapter']!;
          _targetChapterFromAudioSync = result['chapter'];
          _targetPageFromAudioSync = result['page'];
          print(
              '🎵 Will start at Chapter $targetIndex, Page ${result['page']}');
        } else {
          print(
              '⚠️ Could not calculate chapter/page, falling back to saved progress');
          if (hasProgress) {
            targetIndex = savedChapter;
          } else {
            targetIndex = 0;
          }
        }
      }
      // Priority 2: Saved progress from last read
      else if (hasProgress) {
        targetIndex = savedChapter;
      }
      // Priority 3: Explicit starter chapter
      else if (widget.starterChapter >= 0 &&
          widget.starterChapter < chaptersList.length) {
        targetIndex = widget.starterChapter;
      }
      // Priority 4: First chapter
      else {
        targetIndex = 0;
      }
    }

    if (targetIndex < 0 || targetIndex >= chaptersList.length) {
      targetIndex = 0;
    }

    setupNavButtons();
    await updateContentAccordingChapter(targetIndex);
  }

  updateContentAccordingChapter(int chapterIndex) async {
    // Save chapter index to progress (if not during init, it's already saved)
    final currentSavedIndex =
        bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    if (currentSavedIndex != chapterIndex) {
      await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
    }

    // Map filtered index to original EPUB chapter index
    final originalChapterIndex =
        _filteredToOriginalIndex[chapterIndex] ?? chapterIndex;

    // Calculate accumulated pages before current chapter (only use KNOWN chapters)
    // Use original EPUB chapter indices, not filtered chaptersList indices
    accumulatedPagesBeforeCurrentChapter = 0;
    for (int i = 0; i < originalChapterIndex; i++) {
      if (chapterPageCounts.containsKey(i)) {
        accumulatedPagesBeforeCurrentChapter += chapterPageCounts[i]!;
      }
      // Don't estimate - just skip unknown chapters
    }

    String content = '';

    try {
      // Directly access the chapter by original index
      if (originalChapterIndex >= 0 &&
          originalChapterIndex < _chapters.length) {
        content = _chapters[originalChapterIndex].HtmlContent ?? '';

        // Add subchapters content if they exist
        List<EpubChapter>? subChapters =
            _chapters[originalChapterIndex].SubChapters;
        if (subChapters != null && subChapters.isNotEmpty) {
          for (var subChapter in subChapters) {
            content += subChapter.HtmlContent ?? '';
          }
        }
      } else {
        content = '<html><body><p>Chapter not found</p></body></html>';
      }
    } catch (e) {
      content = '<html><body><p>Error loading chapter: $e</p></body></html>';
    }

    htmlContent = content;

    // ✅ IMPORTANT: Keep the full HTML content for images
    // Pass the raw HTML to innerHtmlContent so images are preserved
    innerHtmlContent = htmlContent;

    // Extract text content only for text direction detection
    textContent = parse(htmlContent).documentElement!.text;
    textContent = textContent.replaceAll('Unknown', '').trim();

    // Detect text direction for the current content
    currentTextDirection = RTLHelper.getTextDirection(textContent);

    // DON'T call controllerPaging.paginate() here - PagingWidget will handle it in initState
    // controllerPaging.paginate() won't work yet anyway since handler callback hasn't been called

    // Sync progress bar immediately using known totals (even before page flip)
    final storedPageIndex =
        bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
    final currentPageInBook =
        accumulatedPagesBeforeCurrentChapter + storedPageIndex;
    final displayTotalPages = allChaptersCalculated
        ? totalPagesInBook
        : (_cachedKnownPagesTotal > 0
            ? _cachedKnownPagesTotal
            : (chapterPageCounts[chapterIndex] ?? totalPagesInBook));

    // If handler not yet attached, stash values to apply later
    _pendingCurrentPageInBook = currentPageInBook;
    _pendingTotalPages = displayTotalPages;

    // If handler already attached, apply immediately
    controllerPaging.currentPage.value = currentPageInBook;
    controllerPaging.totalPages.value = displayTotalPages;

    // Re-apply after frame to override PagingWidget's initial chapter-total
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controllerPaging.currentPage.value =
          _pendingCurrentPageInBook ?? currentPageInBook;
      controllerPaging.totalPages.value =
          _pendingTotalPages ?? displayTotalPages;
    });

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
    return true;
  }

  void changeFontSize(double newSize) {
    setState(() {
      fontSizeProgress = newSize;
      _fontSize = newSize;
      gs.write(libFontSize, _fontSize);

      // Reset all page count logic
      if (chapterPageCounts.isNotEmpty) {
        chapterPageCounts.clear();
        _cachedKnownPagesTotal = 0;
        totalPagesInBook = 0;
        allChaptersCalculated = false;

        // We can't know accumulated pages accurately until we recalculate previous chapters
        // But we reset it to 0 so we don't have out-of-bounds errors using old large counts
        accumulatedPagesBeforeCurrentChapter = 0;

        // Clear persistent storage
        gs.remove('book_${bookId}_page_counts');
      }

      updateUI();
      controllerPaging.paginate();

      // ❌ DISABLED: Don't recalculate on theme/font changes - use cached values only
      // User should recalculate from download/loading screen if needed
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   if (!mounted) return;
      //   final size = MediaQuery.of(context).size;
      //   _precalculateAllChaptersTotal(size);
      // });
    });
  }

  void onPageFlipUpdate(int currentPageInBook, int totalPagesInBook) {
    // Update internal page tracking for UI (slider, etc.)
    controllerPaging.currentPage.value = currentPageInBook;
    controllerPaging.totalPages.value = totalPagesInBook;
  }

  // Get the chapter title to display
  String _getChapterTitleForDisplay(int currentChapterIndex) {
    return _chapterHelper.getChapterTitleForDisplay(
      currentChapterIndex: currentChapterIndex,
      chaptersList: chaptersList,
      currentSubchapterTitle: _currentSubchapterTitle,
    );
  }

  // Update the current subchapter title based on page position
  void _updateSubchapterTitleForPage(
      int currentChapterIndex, int pageInChapter) {
    _currentSubchapterTitle = _chapterHelper.updateSubchapterTitleForPage(
      currentChapterIndex: currentChapterIndex,
      pageInChapter: pageInChapter,
      chaptersList: chaptersList,
    );
  }

  openTableOfContents() async {
    final originalChapterIndex =
        bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    final currentPageInBook = controllerPaging.currentPage.value;

    // Calculate current page within the chapter
    int currentPageInChapter = 0;
    if (originalChapterIndex < chaptersList.length) {
      int accumulatedPages = 0;
      for (int i = 0; i < originalChapterIndex; i++) {
        accumulatedPages += chaptersList[i].pageCount;
      }
      currentPageInChapter = currentPageInBook - accumulatedPages;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
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
        currentPageInChapter: currentPageInChapter,
      ),
    );

    // Handle navigation result
    if (result == null) {
      return;
    }

    final chapterIndex = result['chapterIndex'] as int;
    final pageIndex = result['pageIndex'] as int;
    final isSubChapter = result['isSubChapter'] as bool;
    final subchapterTitle = result['subchapterTitle'] as String?;

    if (isSubChapter) {
      // Set the subchapter title to display
      _currentSubchapterTitle = subchapterTitle;

      // Sub-chapter navigation
      if (chapterIndex == originalChapterIndex) {
        // Same chapter - reload to navigate to the page and update UI
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);

        // Reload the chapter with the target page to ensure UI updates
        reLoadChapter(index: chapterIndex, startPage: pageIndex);
      } else {
        // Different chapter - reload chapter and go to page
        await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);
        reLoadChapter(index: chapterIndex, startPage: pageIndex);
      }
    } else {
      // Regular chapter navigation - clear subchapter title
      _currentSubchapterTitle = null;

      if (chapterIndex != originalChapterIndex) {
        await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
        await bookProgress.setCurrentPageIndex(
            bookId, pageIndex); // Use provided pageIndex
        reLoadChapter(index: chapterIndex, startPage: pageIndex);
      } else {
        // Same chapter tapped - go to the specified page (usually 0 for first page)
        await bookProgress.setCurrentPageIndex(bookId, pageIndex);
        reLoadChapter(index: chapterIndex, startPage: pageIndex);
      }
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
    bool isDarkMode = Get.isDarkMode;

    if (id == 1) {
      // Original: White background in light mode, Black in dark mode
      backColor = isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      fontColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    } else if (id == 2) {
      // Quiet: Dark gray in both modes
      backColor = const Color(0xFF1C1C1E);
      fontColor = isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFFE5E5EA);
    } else if (id == 3) {
      // Paper: Light gray in light mode, Dark gray in dark mode
      backColor = isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
      fontColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    } else if (id == 4) {
      // Bold: White in light mode, Black in dark mode (same as Original but with bold text)
      backColor = isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      fontColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    } else if (id == 5) {
      // Calm: Warm beige in light mode, Dark brown in dark mode
      backColor = isDarkMode ? const Color(0xFF3A2E2A) : const Color(0xFFFBF1E6);
      fontColor = isDarkMode ? const Color(0xFFD9C5B2) : const Color(0xFF000000);
    } else {
      // Focus: Light gray in light mode, Dark gray in dark mode
      backColor = isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF8F8F8);
      fontColor = isDarkMode ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
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
    // Check if already loading to prevent race conditions
    if (_isLoadingChapter) {
      return;
    }

    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    // Reset swipe counters when changing chapters
    lastSwipe = 0;
    prevSwipe = 0;

    if (index < chaptersList.length - 1) {
      int newIndex = index + 1;

      // CRITICAL: Update current chapter's page count in cache before leaving
      // This ensures accumulated pages are correct for the next chapter
      var originalIdx = _filteredToOriginalIndex[index] ?? index;
      var currentTotal =
          _currentChapterPageCount; // Use actual chapter page count, not book total!
      if (currentTotal > 0 && chapterPageCounts[originalIdx] != currentTotal) {
        print(
            '🔄 Updating chapter $index (original: $originalIdx) page count: ${chapterPageCounts[originalIdx]} → $currentTotal');
        int oldCount = chapterPageCounts[originalIdx] ?? 0;
        chapterPageCounts[originalIdx] = currentTotal;
        _cachedKnownPagesTotal =
            _cachedKnownPagesTotal - oldCount + currentTotal;
        totalPagesInBook = _cachedKnownPagesTotal; // Update book total
        _saveCachedPageCounts();
        _updateChapterPageNumbers();
      }

      // Reset page to first page
      await bookProgress.setCurrentPageIndex(bookId, 0);
      // Reload with new chapter - DON'T update chapter index here, reLoadChapter will do it
      reLoadChapter(index: newIndex);
    } else {
      // Show a message that this is the end of the book
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('end_of_book'.tr),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  prevChapter() async {
    // Check if already loading to prevent race conditions
    if (_isLoadingChapter) {
      return;
    }

    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    // Reset swipe counters when changing chapters
    lastSwipe = 0;
    prevSwipe = 0;

    if (index > 0) {
      int newIndex = index - 1;

      // CRITICAL: Update current chapter's page count in cache before leaving
      var originalIdx = _filteredToOriginalIndex[index] ?? index;
      var currentTotal =
          _currentChapterPageCount; // Use actual chapter page count, not book total!
      if (currentTotal > 0 && chapterPageCounts[originalIdx] != currentTotal) {
        print(
            '🔄 Updating chapter $index (original: $originalIdx) page count: ${chapterPageCounts[originalIdx]} → $currentTotal');
        int oldCount = chapterPageCounts[originalIdx] ?? 0;
        chapterPageCounts[originalIdx] = currentTotal;
        _cachedKnownPagesTotal =
            _cachedKnownPagesTotal - oldCount + currentTotal;
        totalPagesInBook = _cachedKnownPagesTotal; // Update book total
        _saveCachedPageCounts();
        _updateChapterPageNumbers();
      }

      // Page index should already be set correctly before calling prevChapter()
      // (either to last page when swiping back, or to 0 when navigating from TOC)
      // Just keep whatever value was already set - DON'T reset it!
      final currentPageIndex =
          bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;

      print(
          '🔙 prevChapter: Keeping page index at $currentPageIndex for chapter $newIndex');

      // Reload with new chapter - DON'T update chapter index here, reLoadChapter will do it
      reLoadChapter(index: newIndex, startPage: currentPageIndex);
    }
  }

  List<EpubChapter> get _chapters => epubBook.Chapters ?? <EpubChapter>[];

  // Calculate which chapter and page corresponds to a page in the book
  Map<String, int>? _calculateChapterAndPageFromBookPage(int targetPageInBook) {
    return _paginationHelper.calculateChapterAndPageFromBookPage(
      targetPageInBook,
      chapterPageCounts,
    );
  }

  // Load cached page counts from storage
  void _loadCachedPageCounts() {
    chapterPageCounts = _cacheHelper.loadCachedPageCounts(_chapters.length);

    if (chapterPageCounts.isEmpty) {
      // ❌ DISABLED: Don't calculate here - should be done before opening book
      // For now, just use placeholder values so book can open
      print(
          '⚠️ No cached page counts - book should be pre-calculated before opening!');
      // Set placeholder: estimate 10 pages per chapter
      for (int i = 0; i < _chapters.length; i++) {
        chapterPageCounts[i] = 10;
      }
      _cachedKnownPagesTotal = _chapters.length * 10;
      totalPagesInBook = _cachedKnownPagesTotal;
      allChaptersCalculated = false;
      return;
    }

    // Calculate total from cached values
    _cachedKnownPagesTotal = 0;
    for (var count in chapterPageCounts.values) {
      _cachedKnownPagesTotal += count;
    }
    totalPagesInBook = _cachedKnownPagesTotal;

    // Check if all chapters are cached
    allChaptersCalculated = chapterPageCounts.length == _chapters.length;

    // Update UI immediately if we have all chapters
    if (allChaptersCalculated) {
      controllerPaging.totalPages.value = totalPagesInBook;
    }
  }

  // Save page counts to storage
  void _saveCachedPageCounts() {
    _cacheHelper.saveCachedPageCounts(chapterPageCounts);
  }

  // Update chapter list with calculated page numbers
  void _updateChapterPageNumbers() {
    if (!mounted) return;
    _paginationHelper.updateChapterPageNumbers(
      chaptersList,
      chapterPageCounts,
      _filteredToOriginalIndex,
    );
    if (mounted) {
      setState(() {}); // Refresh UI if needed
    }
  }

  // Calculate total pages for all chapters in background
  Future<void> _calculateTotalPagesInBackground() async {
    if (isCalculatingTotalPages) return;
    if (allChaptersCalculated) {
      log('📚 All chapters already calculated');
      return;
    }

    isCalculatingTotalPages = true;
    isCalculatingTotalPages = false;
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
                            // Show loading only during initial waiting state
                            if (snapshot.connectionState ==
                                    ConnectionState.none ||
                                snapshot.connectionState ==
                                    ConnectionState.waiting) {
                              return Center(
                                child: LoadingWidget(
                                  height: 100,
                                  animationWidth: 50,
                                  animationHeight: 50,
                                ),
                              );
                            }

                            // Handle errors
                            if (snapshot.hasError) {
                              print('❌ FutureBuilder error: ${snapshot.error}');
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 48, color: Colors.red),
                                    SizedBox(height: 16),
                                    Text(
                                      'Error loading chapter',
                                      style: TextStyle(
                                          fontSize: 16, color: fontColor),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '${snapshot.error}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: fontColor.withOpacity(0.7)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Only render content when done
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
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

                              // Determine starting page: use audio sync target if available and matches current chapter
                              int startPageIndex = bookProgress
                                      .getBookProgress(bookId)
                                      .currentPageIndex ??
                                  0;
                              if (_targetChapterFromAudioSync ==
                                      currentChapterIndex &&
                                  _targetPageFromAudioSync != null &&
                                  !_hasAppliedAudioSync) {
                                startPageIndex = _targetPageFromAudioSync!;
                                _hasAppliedAudioSync = true;
                                print(
                                    '🎵 Starting at audio sync page: $startPageIndex in chapter $currentChapterIndex');
                              }

                              return PagingWidget(
                                textContent,
                                epubBook: epubBook,
                                innerHtmlContent,
                                lastWidget: null,
                                starterPageIndex: startPageIndex,
                                style: TextStyle(
                                  backgroundColor: backColor,
                                  fontSize: _fontSize.sp,
                                  fontFamily: selectedTextStyle,
                                  fontWeight: staticThemeId == 2
                                      ? FontWeight.bold
                                      : FontWeight.w400,
                                  package: 'cosmos_epub',
                                  color: fontColor,
                                  // Improved text spacing for better readability
                                  height: 1.5,
                                  letterSpacing: 0.1,
                                ),
                                handlerCallback: (ctrl) {
                                  controllerPaging = ctrl;
                                  // Always preserve book-level total pages (not chapter total)
                                  // Use at least 1 to avoid division by zero issues in progress bar
                                  final bookTotal = allChaptersCalculated
                                      ? totalPagesInBook
                                      : (_cachedKnownPagesTotal > 0
                                          ? _cachedKnownPagesTotal
                                          : (totalPagesInBook > 0
                                              ? totalPagesInBook
                                              : 1));
                                  controllerPaging.totalPages.value = bookTotal;

                                  // Apply any pending values computed before handler was attached
                                  if (_pendingCurrentPageInBook != null) {
                                    controllerPaging.currentPage.value =
                                        _pendingCurrentPageInBook!;
                                    _pendingCurrentPageInBook = null;
                                  }
                                  if (_pendingTotalPages != null) {
                                    controllerPaging.totalPages.value =
                                        _pendingTotalPages!;
                                    _pendingTotalPages = null;
                                  }
                                },
                                onTextTap: () {
                                  setState(() {
                                    showHeader = !showHeader;
                                  });
                                },
                                onPageFlip: (currentPage, totalPages) async {
                                  // Store page count for current chapter
                                  var currentChapterIdx = bookProgress
                                          .getBookProgress(bookId)
                                          .currentChapterIndex ??
                                      0;

                                  // Map to original EPUB chapter index for consistent keying
                                  var originalChapterIdx =
                                      _filteredToOriginalIndex[
                                              currentChapterIdx] ??
                                          currentChapterIdx;

                                  // Save current chapter's page count for later use (e.g., chapter transitions)
                                  _currentChapterPageCount = totalPages;

                                  print('');
                                  print(
                                      '🔄 onPageFlip called: Chapter $currentChapterIdx (original: $originalChapterIdx), Page $currentPage/$totalPages');

                                  // Only update page count if precalc hasn't completed yet
                                  // Once all chapters are precalculated, don't update to avoid total pages jumping
                                  if (!allChaptersCalculated) {
                                    bool pageCountChanged =
                                        chapterPageCounts[originalChapterIdx] !=
                                            totalPages;

                                    if (pageCountChanged) {
                                      // Update the cached total incrementally (much faster than fold)
                                      int oldPageCount = chapterPageCounts[
                                              originalChapterIdx] ??
                                          0;
                                      _cachedKnownPagesTotal =
                                          _cachedKnownPagesTotal -
                                              oldPageCount +
                                              totalPages;
                                      chapterPageCounts[originalChapterIdx] =
                                          totalPages;

                                      // Recalculate estimate for unknown chapters
                                      int knownChapters =
                                          chapterPageCounts.length;
                                      int totalChapters = _chapters.length;

                                      print('');
                                      print(
                                          '╔═════════════════════════════════════════════════════════╗');
                                      print(
                                          '║           PAGE COUNT UPDATE - CHAPTER $currentChapterIdx (original: $originalChapterIdx)              ║');
                                      print(
                                          '╠═════════════════════════════════════════════════════════╣');
                                      print(
                                          '║ Current chapter pages: $totalPages');
                                      print(
                                          '║ Known chapters: $knownChapters / $totalChapters');
                                      print(
                                          '║ Known pages total: $_cachedKnownPagesTotal');

                                      // No estimation: only count known chapters
                                      if (knownChapters < totalChapters) {
                                        totalPagesInBook =
                                            _cachedKnownPagesTotal;

                                        print(
                                            '║ Unknown chapters remaining: ${totalChapters - knownChapters}');
                                        print(
                                            '║ CURRENT KNOWN TOTAL: $totalPagesInBook pages (will show "hesaplanıyor...")');
                                        log('📊 Chapter $currentChapterIdx (orig: $originalChapterIdx): $totalPages pages | Known total (no estimate): $totalPagesInBook pages');
                                      } else {
                                        // All chapters known
                                        totalPagesInBook =
                                            _cachedKnownPagesTotal;
                                        allChaptersCalculated = true;
                                        print('║ ✅ ALL CHAPTERS KNOWN');
                                        print(
                                            '║ TOTAL BOOK PAGES: $totalPagesInBook pages');
                                        log('📊 Chapter $currentChapterIdx (orig: $originalChapterIdx): $totalPages pages | Total book: $totalPagesInBook pages (all chapters known)');
                                      }

                                      // Print cache contents
                                      print('║ ');
                                      print('║ 📋 Chapter page counts:');
                                      chapterPageCounts.forEach((idx, pages) {
                                        print(
                                            '║    Chapter $idx: $pages pages');
                                      });
                                      print(
                                          '╚═════════════════════════════════════════════════════════╝');
                                      print('');

                                      // Save to cache
                                      _saveCachedPageCounts();

                                      // Update chapter page numbers in the list
                                      _updateChapterPageNumbers();
                                    }
                                  }

                                  // Calculate current position in book (where we are across all chapters)
                                  int currentPageInBook =
                                      accumulatedPagesBeforeCurrentChapter +
                                          currentPage;

                                  // Show only known pages; no estimation. If not all chapters are calculated, show the known total so far.
                                  int displayTotalPages = allChaptersCalculated
                                      ? totalPagesInBook
                                      : (_cachedKnownPagesTotal > 0
                                          ? _cachedKnownPagesTotal
                                          : totalPages);

                                  // 📊 DEBUG: Print what we're showing in progress bar
                                  print('');
                                  print(
                                      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                                  print('📊 PROGRESS BAR DISPLAY');
                                  print(
                                      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                                  print(
                                      'Current page in chapter: $currentPage / $totalPages');
                                  print(
                                      'Accumulated pages before this chapter: $accumulatedPagesBeforeCurrentChapter');
                                  print(
                                      'Current page in book: $currentPageInBook');
                                  print(
                                      'Total pages to display: $displayTotalPages');
                                  print(
                                      'SHOWING: $currentPageInBook / $displayTotalPages');
                                  print(
                                      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                                  print('');

                                  // Update subchapter title based on current page position
                                  _updateSubchapterTitleForPage(
                                      currentChapterIdx, currentPage);

                                  // Update UI with cumulative page numbers
                                  onPageFlipUpdate(
                                      currentPageInBook, displayTotalPages);

                                  if (widget.onPageFlip != null) {
                                    widget.onPageFlip!(
                                        currentPageInBook, displayTotalPages);
                                  }

                                  if (currentPage == totalPages - 1) {
                                    bookProgress.setCurrentPageIndex(bookId, 0);
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

                                  print(
                                      '🔙 Swipe left: page $currentPage/$totalPages, prevSwipe=$prevSwipe');

                                  if (currentPage == 0) {
                                    // Only change chapter if we swipe left AGAIN while already on page 0
                                    // For single-page chapters, skip prev logic (will be handled by onLastPage)
                                    if (totalPages > 1) {
                                      prevSwipe++;
                                      lastSwipe = 0;

                                      print(
                                          '🔙 At page 0, prevSwipe now = $prevSwipe');

                                      if (prevSwipe > 1 && !_isLoadingChapter) {
                                        var currentChapterIndex = bookProgress
                                                .getBookProgress(bookId)
                                                .currentChapterIndex ??
                                            0;
                                        if (currentChapterIndex > 0) {
                                          var previousChapterIndex =
                                              currentChapterIndex - 1;
                                          print(
                                              '⬅️ Swiping to previous chapter: $currentChapterIndex → $previousChapterIndex');

                                          // Get the original chapter index for the previous chapter
                                          final prevOriginalIdx =
                                              _filteredToOriginalIndex[
                                                  previousChapterIndex];

                                          // Get the last page of the previous chapter
                                          int lastPageOfPrevChapter = 0;
                                          if (prevOriginalIdx != null &&
                                              chapterPageCounts.containsKey(
                                                  prevOriginalIdx)) {
                                            lastPageOfPrevChapter =
                                                chapterPageCounts[
                                                        prevOriginalIdx]! -
                                                    1; // -1 because pages are 0-indexed
                                          }

                                          print(
                                              '📄 Previous chapter last page: $lastPageOfPrevChapter');

                                          // Set to the LAST page of previous chapter, not 999
                                          await bookProgress
                                              .setCurrentPageIndex(bookId,
                                                  lastPageOfPrevChapter);
                                          prevChapter();
                                        }
                                      }
                                    }
                                  } else {
                                    // Reset prevSwipe counter when NOT on page 0
                                    // This ensures we don't accidentally trigger chapter change
                                    prevSwipe = 0;
                                  }
                                },
                                onLastPage: (index, totalPages) async {
                                  if (widget.onLastPage != null) {
                                    widget.onLastPage!(index);
                                  }

                                  if (!_isLoadingChapter) {
                                    // For single-page chapters, navigate immediately (set to 2)
                                    // For multi-page chapters, increment normally
                                    if (totalPages > 1) {
                                      lastSwipe++;
                                    } else {
                                      lastSwipe = 2;
                                    }
                                    prevSwipe = 0;

                                    if (lastSwipe > 1) {
                                      nextChapter();
                                      setState(() {});
                                    }
                                  }

                                  isLastPage = true;
                                  updateUI();
                                },
                                chapterTitle: _getChapterTitleForDisplay(
                                    currentChapterIndex),
                                totalChapters: chaptersList.length,

                                bookId: bookId,
                                showNavBar: showHeader, // PASS THIS
                              );
                            }

                            // Fallback: show loading if not done yet
                            return Center(
                              child: LoadingWidget(
                                height: 100,
                                animationWidth: 50,
                                animationHeight: 50,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Top Header Bar - OVERLAY
              EpubHeaderWidget(
                showHeader: showHeader,
                fontColor: fontColor,
                backColor: backColor,
                bookTitle: bookTitle,
                bookImage: widget.imageUrl,
                bookId: bookId,
                onBackPressed: () => Navigator.pop(context),
              ),

              Obx(() {
                final currentChapterIdx =
                    bookProgress.getBookProgress(bookId).currentChapterIndex ??
                        0;
                final currentChapterTitle = currentChapterIdx >= 0 &&
                        currentChapterIdx < chaptersList.length
                    ? chaptersList[currentChapterIdx].chapter
                    : '';

                return EpubBottomNavWidget(
                  showHeader: showHeader,
                  fontColor: fontColor,
                  backColor: backColor,
                  currentPage: controllerPaging.currentPage.value,
                  totalPages: controllerPaging.totalPages.value,
                  isCalculating: !allChaptersCalculated,
                  chapterTitle: currentChapterTitle,
                  onMenuPressed: openTableOfContents,
                  onNextPage: () => controllerPaging.goToNextPage(),
                  onPreviousPage: () => controllerPaging.goToPreviousPage(),
                  onJumpToPage: (targetPageInBook) {
                    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                    print(
                        '🎯 SHOW_EPUB: User wants to jump to BOOK page $targetPageInBook');
                    print(
                        '📊 Current state: Page ${controllerPaging.currentPage.value} / ${controllerPaging.totalPages.value}');
                    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

                    final result =
                        _calculateChapterAndPageFromBookPage(targetPageInBook);

                    if (result != null) {
                      final targetChapter = result['chapter']!;
                      final targetPageInChapter = result['page']!;

                      print(
                          '✅ Calculated: Chapter $targetChapter, Page $targetPageInChapter in chapter');

                      bookProgress
                          .setCurrentPageIndex(bookId, targetPageInChapter)
                          .then((_) {
                        reLoadChapter(index: targetChapter);
                      });
                    } else {
                      print(
                          '⚠️ Could not calculate chapter/page for book page $targetPageInBook');
                      print(
                          '⚠️ This might be because page counts are not fully cached yet');
                    }
                  },
                  onFontSettingsPressed: () {},
                  fontSize: _fontSize,
                  brightnessLevel: brightnessLevel,
                  staticThemeId: staticThemeId,
                  setBrightness: setBrightness,
                  updateTheme: updateTheme,
                  onFontSizeChange: changeFontSize,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
