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
import 'package:html/dom.dart' as dom;
import 'package:screen_brightness/screen_brightness.dart';

import 'Component/constants.dart';
import 'Component/theme_colors.dart';
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
  List<EpubChapter> get _chapters => epubBook.Chapters ?? <EpubChapter>[];
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
  bool _precalcScheduled = false;
  int? _pendingCurrentPageInBook;
  int? _pendingTotalPages;
  Size? _lastPrecalcSize; // Track the size used for last precalculation

  GetStorage gs = GetStorage();

  PagingTextHandler controllerPaging = PagingTextHandler(paginate: () {}, bookId: '');

  // Track pages per chapter and cumulative totals
  Map<int, int> chapterPageCounts = {};
  int accumulatedPagesBeforeCurrentChapter = 0;
  int totalPagesInBook = 0; // Total pages across all chapters
  bool isCalculatingTotalPages = false;
  int _cachedKnownPagesTotal = 0; // Cache to avoid recalculating fold every time
  bool allChaptersCalculated = false; // Track if we've calculated all chapters
  bool _isDisposed = false; // Track if widget is disposed to stop background tasks
  bool _isLoadingChapter = false; // Prevent multiple simultaneous chapter loads

  // Mapping from filtered chapter index to original EPUB chapter index
  Map<int, int> _filteredToOriginalIndex = {};

  @override
  void initState() {
    loadThemeSettings();
    bookId = widget.bookId;
    epubBook = widget.epubBook;
    controllerPaging = PagingTextHandler(paginate: () {}, bookId: bookId);

    // Debug EPUB structure
    print("----------------------------------------------/////////////////////--------------------");
    log('📚 EPUB Debug Info:');
    log('   Title: ${epubBook.Title}');
    log('   Author: ${epubBook.Author}');
    log('   Total Chapters: ${epubBook.Chapters?.length ?? 0}');
    log('   Schema: ${epubBook.Schema}');
    log('   Content: ${epubBook.Content != null ? "Present" : "Null"}');
    if (epubBook.Content != null) {
      log('   HTML Files: ${epubBook.Content!.Html?.keys.length ?? 0}');
      log('   CSS Files: ${epubBook.Content!.Css?.keys.length ?? 0}');
      log('   Images: ${epubBook.Content!.Images?.keys.length ?? 0}');
    }

    // allFonts = GoogleFonts.asMap().cast<String, String>();
    // fontNames = allFonts.keys.toList();
    // selectedTextStyle = GoogleFonts.getFont(selectedFont).fontFamily!;
    selectedTextStyle = fontNames.firstWhere((element) => element == selectedFont, orElse: () => fontNames.first);

    getTitleFromXhtml();

    // Load cached page counts
    _loadCachedPageCounts();

    reLoadChapter(init: true);

    super.initState();
  }

  @override
  void dispose() {
    _isDisposed = true;
    isCalculatingTotalPages = false;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precalcScheduled) {
      _precalcScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) return;

        final size = MediaQuery.of(context).size;

        // Only start precalc if size has changed or this is the first time
        final sizeChanged = _lastPrecalcSize == null || (_lastPrecalcSize!.width != size.width || _lastPrecalcSize!.height != size.height);

        if (sizeChanged && !allChaptersCalculated) {
          _lastPrecalcSize = size;
          // Start precalc shortly after first frame so initial chapter renders immediately
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted || _isDisposed) return;
            _precalculateAllChaptersTotal(size);
          });
        }
      });
    }
  }

  // Load cached page counts from storage
  void _loadCachedPageCounts() {
    final cached = gs.read('book_${bookId}_page_counts');
    if (cached != null && cached is Map) {
      // Keys may have been stored as strings; normalize to int keys
      chapterPageCounts = cached.map<int, int>((key, value) {
        final intKey = key is int ? key : int.tryParse(key.toString()) ?? 0;
        return MapEntry(intKey, value as int);
      });

      // Validate cache: if cached chapters don't match current chapter count, clear cache
      if (chapterPageCounts.length != _chapters.length) {
        print('⚠️ Cache mismatch: Cached ${chapterPageCounts.length} chapters, book has ${_chapters.length} chapters');
        print('⚠️ Clearing cache and recalculating...');
        chapterPageCounts.clear();
        _cachedKnownPagesTotal = 0;
        totalPagesInBook = 0;
        allChaptersCalculated = false;
        gs.remove('book_${bookId}_page_counts');
        log('📚 Cache cleared, will recalculate all chapters');
        return;
      }

      // Calculate total from cached values (use simple sum, not fold in loop)
      _cachedKnownPagesTotal = 0;
      for (var count in chapterPageCounts.values) {
        _cachedKnownPagesTotal += count;
      }
      totalPagesInBook = _cachedKnownPagesTotal;

      // Check if all chapters are cached
      allChaptersCalculated = chapterPageCounts.length == _chapters.length;

      print('');
      print('💾 ═══════════════════════════════════════════════════════');
      print('💾 LOADED FROM CACHE');
      print('💾 ═══════════════════════════════════════════════════════');
      log('📚 Loaded cached page counts: ${chapterPageCounts.length} chapters, $totalPagesInBook total pages');
      print('💾 Cached chapters: ${chapterPageCounts.length} / ${_chapters.length}');
      print('💾 All chapters calculated: $allChaptersCalculated');
      print('💾 Cached total pages: $_cachedKnownPagesTotal');
      print('💾 Chapter page counts from cache:');
      chapterPageCounts.forEach((idx, pages) {
        print('💾    Chapter $idx: $pages pages');
      });
      print('💾 ═══════════════════════════════════════════════════════');
      print('');

      // Update UI immediately if we have all chapters
      if (allChaptersCalculated) {
        controllerPaging.totalPages.value = totalPagesInBook;
      }
    } else {
      log('📚 No cached page counts found, will calculate all chapters');
    }
  } // Save page counts to storage

  void _saveCachedPageCounts() {
    // Store with string keys to keep JSON encoder happy
    final stringKeyed = chapterPageCounts.map<String, int>((key, value) => MapEntry(key.toString(), value));
    gs.write('book_${bookId}_page_counts', stringKeyed);
    log('💾 Saved page counts to cache');
  }

  // Calculate total pages for all chapters in background
  Future<void> _calculateTotalPagesInBackground() async {
    if (isCalculatingTotalPages) return;
    if (allChaptersCalculated) {
      log('📚 All chapters already calculated');
      return;
    }

    isCalculatingTotalPages = true;

    print('');
    print('🔄 ═══════════════════════════════════════════════════════');
    print('🔄 WILL CALCULATE REMAINING CHAPTERS AS USER READS');
    print('🔄 ═══════════════════════════════════════════════════════');
    print('🔄 Known chapters: ${chapterPageCounts.length} / ${_chapters.length}');
    print('🔄 Known pages: $_cachedKnownPagesTotal');
    print('🔄 Will show "calculating..." in progress bar until all chapters visited');
    print('🔄 ═══════════════════════════════════════════════════════');
    print('');

    isCalculatingTotalPages = false;
  }

  Future<void> _precalculateAllChaptersTotal(Size pageSize) async {
    if (allChaptersCalculated || isCalculatingTotalPages) return;

    isCalculatingTotalPages = true;

    print('');
    print('🧮 ═══════════════════════════════════════════════════════');
    print('🧮 PRECALCULATING ALL CHAPTERS IN BACKGROUND');
    print('🧮 Page area: ${pageSize.width} x ${pageSize.height}');
    print('🧮 Known chapters before start: ${chapterPageCounts.length}');
    print('🧮 ═══════════════════════════════════════════════════════');
    print('');

    final totalChapters = _chapters.length;
    final contentWidth = pageSize.width - 64.w;
    final contentHeight = pageSize.height - 100.h;

    for (int i = 0; i < totalChapters; i++) {
      // Stop if widget is disposed
      if (_isDisposed || !mounted) {
        print('🛑 Precalc stopped - widget disposed');
        isCalculatingTotalPages = false;
        return;
      }

      if (chapterPageCounts.containsKey(i)) {
        continue; // Already known from cache or reading
      }

      try {
        final html = _buildChapterHtml(i);
        final pages = await _countPages(html, contentWidth, contentHeight);
        chapterPageCounts[i] = pages;
        _cachedKnownPagesTotal += pages;

        // Persist incrementally to avoid data loss on exit
        _saveCachedPageCounts();

        print('🧮 Chapter $i precalculated: $pages pages (known total: $_cachedKnownPagesTotal)');
      } catch (e, st) {
        print('⚠️ Failed to precalculate chapter $i: $e');
        log('⚠️ Precalc error chapter $i: $e\n$st');
      }

      // Yield to UI between chapters - longer delay for better responsiveness
      await Future.delayed(Duration(milliseconds: 50));
    }

    totalPagesInBook = _cachedKnownPagesTotal;
    allChaptersCalculated = true;
    isCalculatingTotalPages = false;

    // Update UI totals
    controllerPaging.totalPages.value = totalPagesInBook;

    print('');
    print('✅ ═══════════════════════════════════════════════════════');
    print('✅ PRECALC COMPLETE - TOTAL PAGES: $totalPagesInBook');
    print('✅ Chapters processed: ${chapterPageCounts.length} / $totalChapters');
    print('✅ ═══════════════════════════════════════════════════════');
    print('');
  }

  String _buildChapterHtml(int chapterIndex) {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) return '';
    String content = _chapters[chapterIndex].HtmlContent ?? '';
    final subChapters = _chapters[chapterIndex].SubChapters;
    if (subChapters != null && subChapters.isNotEmpty) {
      for (var sub in subChapters) {
        content += sub.HtmlContent ?? '';
      }
    }
    return content;
  }

  Future<int> _countPages(String html, double maxWidth, double maxHeight) async {
    final document = parse(html);
    List<InlineSpan> spans = [];

    for (var node in document.body!.nodes) {
      spans.add(await _parseNodeForCount(node, maxWidth, maxHeight));
    }

    return _paginateAndCount(spans, maxWidth, maxHeight);
  }

  Future<InlineSpan> _parseNodeForCount(dom.Node node, double maxWidth, double maxHeight) async {
    if (node is dom.Text) {
      String text = node.text.replaceAll(RegExp(r'[ \t]+'), ' ');
      if (text.trim().isEmpty) return const TextSpan(text: '');

      return TextSpan(
        text: text,
        style: TextStyle(
          fontSize: _fontSize,
          fontFamily: selectedTextStyle,
          height: 1.7,
          letterSpacing: 0.2,
          wordSpacing: 0.5,
          color: fontColor,
        ),
      );
    }

    if (node is dom.Element) {
      if (node.localName == 'img') {
        // Approximate image height to keep count lightweight
        return WidgetSpan(
          child: SizedBox(
            width: maxWidth * 0.9,
            height: maxHeight * 0.4,
          ),
        );
      }

      if (node.localName == 'br') {
        return const TextSpan(text: "\n");
      }

      if (node.localName == 'p' || node.localName == 'div') {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNodeForCount(child, maxWidth, maxHeight));
        }
        children.add(const TextSpan(text: "\n\n"));
        return TextSpan(children: children);
      }

      if (node.localName == 'h1' || node.localName == 'h2' || node.localName == 'h3') {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNodeForCount(child, maxWidth, maxHeight));
        }
        return TextSpan(
          children: children,
          style: TextStyle(
            fontSize: (_fontSize) + 4,
            fontWeight: FontWeight.bold,
            height: 1.5,
            color: fontColor,
          ),
        );
      }

      List<InlineSpan> children = [];
      for (var child in node.nodes) {
        children.add(await _parseNodeForCount(child, maxWidth, maxHeight));
      }
      return TextSpan(children: children);
    }

    return const TextSpan(text: '');
  }

  int _paginateAndCount(List<InlineSpan> allSpans, double maxWidth, double maxHeight) {
    List<InlineSpan> flatSpans = [];

    void flatten(InlineSpan span) {
      if (span is TextSpan) {
        if (span.children != null && span.children!.isNotEmpty) {
          for (var child in span.children!) flatten(child);
        } else if (span.text != null && span.text!.isNotEmpty) {
          flatSpans.add(span);
        }
      } else if (span is WidgetSpan) {
        flatSpans.add(span);
      }
    }

    for (var s in allSpans) {
      flatten(s);
    }

    int pageCount = 0;
    List<InlineSpan> currentPageSpans = [];
    double currentHeight = 0;

    for (var span in flatSpans) {
      if (span is WidgetSpan) {
        double spanHeight = 200; // Approximate; enough for counting
        if (currentHeight + spanHeight > maxHeight && currentPageSpans.isNotEmpty) {
          pageCount++;
          currentPageSpans.clear();
          currentHeight = 0;
        }
        currentPageSpans.add(span);
        currentHeight += spanHeight;
      } else if (span is TextSpan && span.text != null) {
        final painter = TextPainter(
          text: TextSpan(text: span.text, style: span.style),
          textDirection: TextDirection.ltr,
          textScaleFactor: 1.0,
        );
        painter.layout(maxWidth: maxWidth);

        if (currentHeight + painter.height <= maxHeight) {
          currentPageSpans.add(span);
          currentHeight += painter.height;
        } else {
          final lines = painter.computeLineMetrics();
          double chunkHeight = 0;

          for (final line in lines) {
            if (currentHeight + chunkHeight + line.height > maxHeight) {
              if (chunkHeight > 0 || currentPageSpans.isNotEmpty) {
                pageCount++;
                currentPageSpans.clear();
                currentHeight = 0;
                chunkHeight = 0;
              }
            }
            chunkHeight += line.height;
          }

          currentHeight += chunkHeight;
          currentPageSpans.add(span);
        }
        painter.dispose();
      }
    }

    if (currentPageSpans.isNotEmpty) {
      pageCount++;
    }

    return pageCount;
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

  // _extractTitleFromHtml removed - cosmos_epub.dart handles title extraction properly

  reLoadChapter({bool init = false, int index = -1}) async {
    // Prevent multiple simultaneous loads
    if (_isLoadingChapter) {
      print('⚠️ Chapter load already in progress, ignoring duplicate request');
      return;
    }

    _isLoadingChapter = true;
    int currentIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    int targetIndex = index == -1 ? currentIndex : index;

    print('🔄 reLoadChapter called: init=$init, index=$index, targetIndex=$targetIndex');

    // If not init (i.e., chapter changed), reset page to 0 and swipe counters
    if (!init && index != -1) {
      await bookProgress.setCurrentPageIndex(bookId, 0);
      // Reset swipe counters to prevent accidental chapter changes
      lastSwipe = 0;
      prevSwipe = 0;
    }

    setState(() {
      loadChapterFuture = loadChapter(init: init, index: targetIndex).then((_) {
        print('✅ Chapter load complete, resetting flag');
        _isLoadingChapter = false;
      }).catchError((e) {
        print('❌ Chapter load error, resetting flag: $e');
        _isLoadingChapter = false;
        throw e;
      });
    });
  }

  loadChapter({int index = -1, bool init = false}) async {
    chaptersList = [];

    // Try to get chapter titles from Navigation (TOC) first
    Map<String, String> navTitles = {};
    if (epubBook.Schema?.Navigation?.NavMap?.Points != null) {
      for (var point in epubBook.Schema!.Navigation!.NavMap!.Points!) {
        if (point.Content?.Source != null && point.NavigationLabels != null && point.NavigationLabels!.isNotEmpty) {
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
      final isBasicChapterTitle = chapterTitle != null && RegExp(r'^Chapter \d+$', caseSensitive: false).hasMatch(chapterTitle);

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

      // Add chapter to list
      chaptersList.add(LocalChapterModel(chapter: chapterTitle ?? 'Chapter ${i + 1}', isSubChapter: false));
      _filteredToOriginalIndex[i] = i;
    }

    // Chapter list built (debug logs removed for clarity)

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
      if (hasProgress) {
        targetIndex = savedChapter;
      } else if (widget.starterChapter >= 0 && widget.starterChapter < chaptersList.length) {
        targetIndex = widget.starterChapter;
      } else {
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
    final currentSavedIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    if (currentSavedIndex != chapterIndex) {
      print('💾 Updating saved chapter index: $currentSavedIndex → $chapterIndex');
      await bookProgress.setCurrentChapterIndex(bookId, chapterIndex);
    }

    // Map filtered index to original EPUB chapter index
    final originalChapterIndex = _filteredToOriginalIndex[chapterIndex] ?? chapterIndex;

    // Calculate accumulated pages before current chapter (only use KNOWN chapters)
    accumulatedPagesBeforeCurrentChapter = 0;
    for (int i = 0; i < chapterIndex; i++) {
      if (chapterPageCounts.containsKey(i)) {
        accumulatedPagesBeforeCurrentChapter += chapterPageCounts[i]!;
      }
      // Don't estimate - just skip unknown chapters
    }

    print('📖 Loading Chapter $chapterIndex (accumulated pages: $accumulatedPagesBeforeCurrentChapter, total: $totalPagesInBook)');

    String content = '';

    try {
      // Directly access the chapter by original index
      if (originalChapterIndex >= 0 && originalChapterIndex < _chapters.length) {
        content = _chapters[originalChapterIndex].HtmlContent ?? '';

        // Add subchapters content if they exist
        List<EpubChapter>? subChapters = _chapters[originalChapterIndex].SubChapters;
        if (subChapters != null && subChapters.isNotEmpty) {
          for (var subChapter in subChapters) {
            content += subChapter.HtmlContent ?? '';
          }
        }
      } else {
        print('⚠️ WARNING: Chapter index $originalChapterIndex out of range (0-${_chapters.length - 1})');
        content = '<html><body><p>Chapter not found</p></body></html>';
      }
    } catch (e, st) {
      print('❌ Error loading chapter $originalChapterIndex: $e');
      print('Stack trace: $st');
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
    final storedPageIndex = bookProgress.getBookProgress(bookId).currentPageIndex ?? 0;
    final currentPageInBook = accumulatedPagesBeforeCurrentChapter + storedPageIndex;
    final displayTotalPages = allChaptersCalculated ? totalPagesInBook : (_cachedKnownPagesTotal > 0 ? _cachedKnownPagesTotal : (chapterPageCounts[chapterIndex] ?? totalPagesInBook));

    // If handler not yet attached, stash values to apply later
    _pendingCurrentPageInBook = currentPageInBook;
    _pendingTotalPages = displayTotalPages;

    // If handler already attached, apply immediately
    controllerPaging.currentPage.value = currentPageInBook;
    controllerPaging.totalPages.value = displayTotalPages;

    // Re-apply after frame to override PagingWidget's initial chapter-total
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controllerPaging.currentPage.value = _pendingCurrentPageInBook ?? currentPageInBook;
      controllerPaging.totalPages.value = _pendingTotalPages ?? displayTotalPages;
    });

    setupNavButtons();
  }

  bool isHTML(String str) {
    final RegExp htmlRegExp = RegExp('<[^>]*>', multiLine: true, caseSensitive: false);
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

  void onPageFlipUpdate(int currentPageInBook, int totalPagesInBook) {
    // Update internal page tracking for UI (slider, etc.)
    controllerPaging.currentPage.value = currentPageInBook;
    controllerPaging.totalPages.value = totalPagesInBook;
  }

  openTableOfContents() async {
    final originalChapterIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    print('🔵 Opening TOC - Current chapter: $originalChapterIndex');

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

    // Only reload if chapter actually changed
    final newChapterIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
    print('🔵 TOC closed - shouldUpdate: $shouldUpdate, original: $originalChapterIndex, new: $newChapterIndex');

    if (shouldUpdate && newChapterIndex != originalChapterIndex) {
      print('✅ Chapter changed from $originalChapterIndex to $newChapterIndex - reloading...');
      // PagingWidget will start from starterPageIndex (which is 0 for new chapters)
      reLoadChapter(index: newChapterIndex);
    } else {
      print('⏭️ Skipping reload - same chapter or cancelled');
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
            color: isSelected ? widget.accentColor : Colors.grey.withOpacity(0.3),
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
    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    // Reset swipe counters when changing chapters
    lastSwipe = 0;
    prevSwipe = 0;

    if (index < chaptersList.length - 1) {
      int newIndex = index + 1;
      print('➡️ Moving to next chapter: $index → $newIndex');

      // Update chapter index first
      await bookProgress.setCurrentChapterIndex(bookId, newIndex);
      // Reset page to first page
      await bookProgress.setCurrentPageIndex(bookId, 0);
      // Reload with new chapter
      reLoadChapter(index: newIndex);
    } else {
      print('⚠️ Already at last chapter ($index)');
    }
  }

  prevChapter() async {
    var index = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

    // Reset swipe counters when changing chapters
    lastSwipe = 0;
    prevSwipe = 0;

    if (index > 0) {
      int newIndex = index - 1;
      print('⬅️ Moving to previous chapter: $index → $newIndex');

      // Update chapter index first
      await bookProgress.setCurrentChapterIndex(bookId, newIndex);
      // Reset page to first page
      await bookProgress.setCurrentPageIndex(bookId, 0);
      // Reload with new chapter
      reLoadChapter(index: newIndex);
    } else {
      print('⚠️ Already at first chapter (0)');
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
    ScreenUtil.init(context, designSize: const Size(DESIGN_WIDTH, DESIGN_HEIGHT));

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
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    openTableOfContents();
                                  });
                                  widget.shouldOpenDrawer = false;
                                }

                                var currentChapterIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

                                return PagingWidget(
                                  textContent,
                                  epubBook: epubBook,
                                  innerHtmlContent,
                                  lastWidget: null,
                                  starterPageIndex: bookProgress.getBookProgress(bookId).currentPageIndex ?? 0,
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
                                    // Always preserve book-level total pages (not chapter total)
                                    // Use at least 1 to avoid division by zero issues in progress bar
                                    final bookTotal = allChaptersCalculated ? totalPagesInBook : (_cachedKnownPagesTotal > 0 ? _cachedKnownPagesTotal : (totalPagesInBook > 0 ? totalPagesInBook : 1));
                                    controllerPaging.totalPages.value = bookTotal;

                                    // Apply any pending values computed before handler was attached
                                    if (_pendingCurrentPageInBook != null) {
                                      controllerPaging.currentPage.value = _pendingCurrentPageInBook!;
                                      _pendingCurrentPageInBook = null;
                                    }
                                    if (_pendingTotalPages != null) {
                                      controllerPaging.totalPages.value = _pendingTotalPages!;
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
                                    var currentChapterIdx = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;

                                    print('');
                                    print('🔄 onPageFlip called: Chapter $currentChapterIdx, Page $currentPage/$totalPages');

                                    // Only update page count if precalc hasn't completed yet
                                    // Once all chapters are precalculated, don't update to avoid total pages jumping
                                    if (!allChaptersCalculated) {
                                      bool pageCountChanged = chapterPageCounts[currentChapterIdx] != totalPages;

                                      if (pageCountChanged) {
                                        // Update the cached total incrementally (much faster than fold)
                                        int oldPageCount = chapterPageCounts[currentChapterIdx] ?? 0;
                                        _cachedKnownPagesTotal = _cachedKnownPagesTotal - oldPageCount + totalPages;
                                        chapterPageCounts[currentChapterIdx] = totalPages;

                                        // Recalculate estimate for unknown chapters
                                        int knownChapters = chapterPageCounts.length;
                                        int totalChapters = _chapters.length;

                                        print('');
                                        print('╔═════════════════════════════════════════════════════════╗');
                                        print('║           PAGE COUNT UPDATE - CHAPTER $currentChapterIdx              ║');
                                        print('╠═════════════════════════════════════════════════════════╣');
                                        print('║ Current chapter pages: $totalPages');
                                        print('║ Known chapters: $knownChapters / $totalChapters');
                                        print('║ Known pages total: $_cachedKnownPagesTotal');

                                        // No estimation: only count known chapters
                                        if (knownChapters < totalChapters) {
                                          totalPagesInBook = _cachedKnownPagesTotal;

                                          print('║ Unknown chapters remaining: ${totalChapters - knownChapters}');
                                          print('║ CURRENT KNOWN TOTAL: $totalPagesInBook pages (will show "hesaplanıyor...")');
                                          log('📊 Chapter $currentChapterIdx: $totalPages pages | Known total (no estimate): $totalPagesInBook pages');
                                        } else {
                                          // All chapters known
                                          totalPagesInBook = _cachedKnownPagesTotal;
                                          allChaptersCalculated = true;
                                          print('║ ✅ ALL CHAPTERS KNOWN');
                                          print('║ TOTAL BOOK PAGES: $totalPagesInBook pages');
                                          log('📊 Chapter $currentChapterIdx: $totalPages pages | Total book: $totalPagesInBook pages (all chapters known)');
                                        }

                                        // Print cache contents
                                        print('║ ');
                                        print('║ 📋 Chapter page counts:');
                                        chapterPageCounts.forEach((idx, pages) {
                                          print('║    Chapter $idx: $pages pages');
                                        });
                                        print('╚═════════════════════════════════════════════════════════╝');
                                        print('');

                                        // Save to cache
                                        _saveCachedPageCounts();
                                      }
                                    }

                                    // Calculate current position in book (where we are across all chapters)
                                    int currentPageInBook = accumulatedPagesBeforeCurrentChapter + currentPage;

                                    // Show only known pages; no estimation. If not all chapters are calculated, show the known total so far.
                                    int displayTotalPages = allChaptersCalculated ? totalPagesInBook : (_cachedKnownPagesTotal > 0 ? _cachedKnownPagesTotal : totalPages);

                                    // 📊 DEBUG: Print what we're showing in progress bar
                                    print('');
                                    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                                    print('📊 PROGRESS BAR DISPLAY');
                                    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                                    print('Current page in chapter: $currentPage / $totalPages');
                                    print('Accumulated pages before this chapter: $accumulatedPagesBeforeCurrentChapter');
                                    print('Current page in book: $currentPageInBook');
                                    print('Total pages to display: $displayTotalPages');
                                    print('SHOWING: $currentPageInBook / $displayTotalPages');
                                    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                                    print('');

                                    // Update UI with cumulative page numbers
                                    onPageFlipUpdate(currentPageInBook, displayTotalPages);

                                    if (widget.onPageFlip != null) {
                                      widget.onPageFlip!(currentPageInBook, displayTotalPages);
                                    }

                                    if (currentPage == totalPages - 1) {
                                      bookProgress.setCurrentPageIndex(bookId, 0);
                                    } else {
                                      bookProgress.setCurrentPageIndex(bookId, currentPage);
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
                                        var currentChapterIndex = bookProgress.getBookProgress(bookId).currentChapterIndex ?? 0;
                                        if (currentChapterIndex > 0) {
                                          var previousChapterIndex = currentChapterIndex - 1;
                                          print('⬅️ Swiping to previous chapter: $currentChapterIndex → $previousChapterIndex');

                                          // Update chapter index first (IMPORTANT!)
                                          await bookProgress.setCurrentChapterIndex(bookId, previousChapterIndex);
                                          // Go to last page of previous chapter
                                          await bookProgress.setCurrentPageIndex(bookId, 999); // Will be clamped to last page
                                          reLoadChapter(index: previousChapterIndex);
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
                                  chapterTitle: chaptersList[currentChapterIndex].chapter,
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
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                                      currentPage: controllerPaging.currentPage.value,
                                      totalPages: controllerPaging.totalPages.value,
                                      isCalculating: !allChaptersCalculated,
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
