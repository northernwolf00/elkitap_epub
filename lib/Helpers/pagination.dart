import 'dart:typed_data';

import 'package:cosmos_epub/Helpers/selectable_text_with_addnote.dart';
import 'package:cosmos_epub/PageFlip/page_flip_widget.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:epubx/epubx.dart' hide Image;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'dart:ui' as ui;

class PagingTextHandler extends GetxController {
  final Function paginate;
  final String bookId;
  final _box = GetStorage();

  late final RxInt currentPage;
  late final RxInt totalPages;

  // Reference to the PageFlipWidget controller for programmatic navigation
  GlobalKey<PageFlipWidgetState>? _pageFlipController;

  PagingTextHandler({required this.paginate, required this.bookId}) {
    currentPage = (_box.read<int>('currentPage_$bookId') ?? 0).obs;
    totalPages = (_box.read<int>('totalPages_$bookId') ?? 0).obs;

    ever(currentPage,
        (_) => _box.write('currentPage_$bookId', currentPage.value));
    ever(totalPages, (_) => _box.write('totalPages_$bookId', totalPages.value));
  }

  // Set the page flip controller reference
  void setPageFlipController(GlobalKey<PageFlipWidgetState> controller) {
    _pageFlipController = controller;
  }

  // Navigate to next page
  Future<void> goToNextPage() async {
    print('🔄 goToNextPage called');
    final state = _pageFlipController?.currentState;
    if (state == null) {
      print('❌ PageFlipController state is null!');
      return;
    }

    final currentPageNum = state.pageNumber;
    final totalPages = state.pages.length;
    print('📄 Current: $currentPageNum, Total: $totalPages');

    // Check if not on last page
    if (currentPageNum < totalPages - 1) {
      print('✅ Navigating to next page...');
      final targetPage = currentPageNum + 1;

      // Use goToPage for proper animation and state management
      await state.goToPage(targetPage);

      // Trigger the onPageFlip callback after navigation
      state.widget.onPageFlip(targetPage);
      print('✅ Navigation complete. New page: $targetPage');
    } else {
      print('⚠️ Already on last page');
    }
  }

  // Navigate to previous page
  Future<void> goToPreviousPage() async {
    print('🔄 goToPreviousPage called');
    final state = _pageFlipController?.currentState;
    if (state == null) {
      print('❌ PageFlipController state is null!');
      return;
    }

    final currentPageNum = state.pageNumber;
    print('📄 Current page: $currentPageNum');

    // Check if not on first page
    if (currentPageNum > 0) {
      print('✅ Navigating to previous page...');
      final targetPage = currentPageNum - 1;

      // Use goToPage for proper animation and state management
      await state.goToPage(targetPage);

      // Trigger the onPageFlip callback after navigation
      state.widget.onPageFlip(targetPage);
      print('✅ Navigation complete. New page: $targetPage');
    } else {
      print('⚠️ Already on first page');
    }
  }

  // Navigate to specific page (for sub-chapter navigation)
  Future<bool> goToPage(int pageIndex) async {
    print('🔄 goToPage called: $pageIndex');
    final state = _pageFlipController?.currentState;
    if (state == null) {
      print('❌ PageFlipController state is null!');
      return false;
    }

    final totalPagesCount = state.pages.length;
    print('📄 Target: $pageIndex, Total: $totalPagesCount');

    // Validate page index
    if (pageIndex >= 0 && pageIndex < totalPagesCount) {
      print('✅ Navigating to page $pageIndex...');

      // Use goToPage for proper animation and state management
      await state.goToPage(pageIndex);

      // Trigger the onPageFlip callback after navigation
      state.widget.onPageFlip(pageIndex);
      print('✅ Navigation complete. New page: $pageIndex');
      return true;
    } else {
      print('⚠️ Invalid page index: $pageIndex (total: $totalPagesCount)');
      return false;
    }
  }
}

class PagingWidget extends StatefulWidget {
  final String textContent;
  final String? innerHtmlContent;
  final String chapterTitle;
  final int totalChapters;
  final int starterPageIndex;
  final TextStyle style;
  final Function handlerCallback;
  final VoidCallback onTextTap;
  final Function(int, int) onPageFlip;
  final Function(int, int) onLastPage;
  final Widget? lastWidget;
  final String bookId;
  final bool showNavBar;
  final int linesPerPage;
  final EpubBook? epubBook;

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
    this.lastWidget,
    required this.bookId,
    this.showNavBar = true,
    this.linesPerPage = 30,
    this.epubBook,
  });

  @override
  _PagingWidgetState createState() => _PagingWidgetState();
}

class _PagingWidgetState extends State<PagingWidget> {
  final List<TextSpan> _pageSpans = [];
  List<Widget> pages = [];
  int _currentPageIndex = 0;
  Future<void> paginateFuture = Future.value(true);
  late RenderBox _initializedRenderBox;

  final _pageKey = GlobalKey();
  final _pageController = GlobalKey<PageFlipWidgetState>();

  late PagingTextHandler _handler;

  @override
  void initState() {
    super.initState();
    _handler = PagingTextHandler(paginate: rePaginate, bookId: widget.bookId);
    _handler.setPageFlipController(_pageController);
    widget.handlerCallback(_handler);
    rePaginate();
  }

  @override
  void didUpdateWidget(covariant PagingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.style.fontSize != oldWidget.style.fontSize ||
        widget.style.fontFamily != oldWidget.style.fontFamily ||
        widget.style.color != oldWidget.style.color ||
        widget.style.height != oldWidget.style.height ||
        widget.innerHtmlContent != oldWidget.innerHtmlContent ||
        widget.textContent != oldWidget.textContent) {
      print('🔄 Style or content changed - triggering re-pagination');
      print(
          '   Old Size: ${oldWidget.style.fontSize}, New Size: ${widget.style.fontSize}');
      rePaginate();
    }
  }

  rePaginate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        print('⚠️ Widget not mounted, skipping pagination');
        return;
      }

      final renderObject = context.findRenderObject();
      if (renderObject == null) {
        print('⚠️ RenderObject is null, retrying pagination...');
        // Retry after a short delay
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) rePaginate();
        });
        return;
      }

      setState(() {
        _initializedRenderBox = renderObject as RenderBox;
        print('✅ RenderBox initialized: ${_initializedRenderBox.size}');
        paginateFuture = _paginate();
      });
    });
  }

  // Helper function to extract ONLY text from a node, excluding cite elements
  String _extractTextOnly(dom.Element element, {bool excludeCite = false}) {
    StringBuffer buffer = StringBuffer();

    for (var child in element.nodes) {
      if (child is dom.Text) {
        buffer.write(child.text);
      } else if (child is dom.Element) {
        // Skip cite elements completely if excludeCite is true
        if (excludeCite && child.localName == 'cite') {
          continue;
        }
        // Recursively get text from other elements
        buffer.write(_extractTextOnly(child, excludeCite: excludeCite));
      }
    }

    return buffer.toString();
  }

  Future<void> _paginate() async {
    print('📖 Starting pagination...');
    final pageSize = _initializedRenderBox.size;
    _pageSpans.clear();

    String contentToParse = widget.innerHtmlContent ?? widget.textContent;

    print(
        '📄 Content to parse (first 200 chars): ${contentToParse.substring(0, contentToParse.length > 200 ? 200 : contentToParse.length)}');

    var document = html_parser.parse(contentToParse);
    List<InlineSpan> spans = [];

    double maxWidth = pageSize.width - 32.w;

    // Prepare chapter title for matching
    final chapterTitleLower = widget.chapterTitle.trim().toLowerCase();
    print('📌 Chapter title to skip: "$chapterTitleLower"');

    for (var i = 0; i < document.body!.nodes.length; i++) {
      final node = document.body!.nodes[i];

      // Check if this node is just the chapter title - skip it
      String nodeText = '';
      if (node is dom.Element) {
        nodeText = node.text.trim();
      } else if (node is dom.Text) {
        nodeText = node.text.trim();
      }

      // Skip if node text matches chapter title exactly or is contained in it
      if (chapterTitleLower.isNotEmpty && nodeText.isNotEmpty) {
        final nodeTextLower = nodeText.toLowerCase();
        if (nodeTextLower == chapterTitleLower ||
            chapterTitleLower.contains(nodeTextLower) && nodeText.length > 2) {
          print('🗑️ Skipping duplicate chapter title node: "$nodeText"');
          continue;
        }
      }

      spans.add(await _parseNode(node, maxWidth));
    }

    print('✅ Parsed ${spans.length} top-level spans');

    await _paginateFlattened(spans, pageSize);
  }

  Future<InlineSpan> _parseNode(dom.Node node, double maxWidth) async {
    if (node is dom.Text) {
      String text = node.text;

      // Remove all types of excessive whitespace BUT preserve newlines
      text = text.replaceAll('\u00A0', ' '); // Non-breaking space
      text = text.replaceAll('\u200B', ''); // Zero-width space
      text = text.replaceAll('\u2009', ' '); // Thin space
      text = text.replaceAll('\u202F', ' '); // Narrow no-break space
      // Replace ALL whitespace (including newlines) with single space for continuous text flow
      text = text.replaceAll(RegExp(r'\s+'), ' ');

      if (text.trim().isEmpty) {
        return const TextSpan(text: '');
      }

      // Clean up punctuation spacing
      text = text.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), '\$1');
      text = text.replaceAll(RegExp(r'([([«])\s+'), '\$1');

      return TextSpan(
        text: text,
        style: widget.style.copyWith(
          fontFamily: 'SFPro',
          height: 1.5,
          letterSpacing: 0.1,
          wordSpacing: 0.5,
          // Enable word breaking for long words in Turkmen/Russian
          overflow: TextOverflow.visible,
        ),
      );
    } else if (node is dom.Element) {
      if (node.localName == 'img') {
        return await _handleImageNode(node, maxWidth);
      } else if (node.localName == 'br') {
        return const TextSpan(text: "\n");
      } else if (node.localName == 'p' || node.localName == 'div') {
        // Normal paragraph
        List<InlineSpan> children = [];

        // Add paragraph indent using non-breaking spaces
        children.add(TextSpan(
          text:
              '\u00A0\u00A0\u00A0\u00A0\u00A0', // 5 non-breaking spaces for indent
          style: widget.style,
        ));

        for (var child in node.nodes) {
          final span = await _parseNode(child, maxWidth);
          children.add(span);
        }

        // Add single line paragraph break like Apple Books
        children.add(const TextSpan(text: '\n'));

        return TextSpan(children: children);
      } else if (node.localName == 'h1' ||
          node.localName == 'h2' ||
          node.localName == 'h3') {
        List<InlineSpan> children = [];

        // Add spacing before heading
        children.add(const TextSpan(text: '\n'));

        for (var child in node.nodes) {
          children.add(await _parseNode(child, maxWidth));
        }

        // Add spacing after heading
        children.add(const TextSpan(text: '\n\n'));

        return TextSpan(
          children: children,
          style: widget.style.copyWith(
            fontSize: (widget.style.fontSize ?? 16) + 4,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        );
      } else if (node.localName == 'blockquote') {
        // Epigraph/quote - right aligned, italic like Apple Books
        // ONLY extract text, completely ignore ALL child elements (including cite)
        String fullText = _extractTextOnly(node, excludeCite: true);

        fullText = fullText.trim();
        if (fullText.isEmpty) {
          return const TextSpan(text: '');
        }

        print('📝 Blockquote full text: "$fullText"');

        // Try to detect author name at the end
        // Simple approach: Last 2-4 capitalized words without ending punctuation
        String? authorName;
        String quoteText = fullText;

        // Split into words
        List<String> words = fullText.split(RegExp(r'\s+'));

        // Check last 2-4 words
        if (words.length >= 4) {
          // Try last 2 words
          String lastTwo = words.sublist(words.length - 2).join(' ');
          bool allCaps = words.sublist(words.length - 2).every((w) {
            if (w.isEmpty) return false;
            return w[0] == w[0].toUpperCase() && w[0] != w[0].toLowerCase();
          });

          // No punctuation at end
          bool noPunct = !lastTwo.endsWith('.') &&
              !lastTwo.endsWith('!') &&
              !lastTwo.endsWith('?') &&
              !lastTwo.endsWith(',');

          if (allCaps && noPunct) {
            print('🔍 Detected 2-word author: "$lastTwo"');
            authorName = lastTwo;
            quoteText = words.sublist(0, words.length - 2).join(' ');
          } else {
            // Try last 3 words
            if (words.length >= 5) {
              String lastThree = words.sublist(words.length - 3).join(' ');
              bool allCaps3 = words.sublist(words.length - 3).every((w) {
                if (w.isEmpty) return false;
                return w[0] == w[0].toUpperCase() && w[0] != w[0].toLowerCase();
              });
              bool noPunct3 = !lastThree.endsWith('.') &&
                  !lastThree.endsWith('!') &&
                  !lastThree.endsWith('?') &&
                  !lastThree.endsWith(',');

              if (allCaps3 && noPunct3) {
                print('🔍 Detected 3-word author: "$lastThree"');
                authorName = lastThree;
                quoteText = words.sublist(0, words.length - 3).join(' ');
              }
            }
          }
        }

        // Clean up whitespace and punctuation
        quoteText = quoteText.replaceAll('\u00A0', ' ');
        quoteText = quoteText.replaceAll('\u200B', '');
        quoteText = quoteText.replaceAll('\u2009', ' ');
        quoteText = quoteText.replaceAll('\u202F', ' ');
        quoteText = quoteText.replaceAll(RegExp(r'\s+'), ' ');
        quoteText = quoteText.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), '\$1');
        quoteText = quoteText.replaceAll(RegExp(r'([([«])\s+'), '\$1');
        quoteText = quoteText.trim();

        print('📖 Final quote text: "$quoteText"');
        if (authorName != null) {
          print('✍️ Final author name: "$authorName"');
        }

        // ALWAYS show quote text, even if empty after author detection
        if (quoteText.isEmpty && authorName != null) {
          // If we accidentally removed all text, restore it
          quoteText = fullText;
          authorName = null;
          print(
              '⚠️ Quote was empty after author detection - restoring full text');
        }

        // Build the widget - quote only (author will be separate)
        List<InlineSpan> spans = [];

        // Add quote
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            padding: EdgeInsets.fromLTRB(maxWidth / 2.5, 0.h, 0.w, 8.h),
            child: RichText(
              textAlign: TextAlign.justify,
              text: TextSpan(
                style: widget.style.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: '\u00A0\u00A0\u00A0\u00A0\u00A0'),
                  TextSpan(text: quoteText),
                ],
              ),
            ),
          ),
        ));

        // Add author if detected
        if (authorName != null && authorName.isNotEmpty) {
          print('✅ Adding author widget: "$authorName"');
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              padding: EdgeInsets.fromLTRB(maxWidth / 3, 3.h, 0.w, 4.h),
              child: Center(
                child: Text(
                  authorName,
                  textAlign: TextAlign.center,
                  style: widget.style.copyWith(
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ));
        } else {
          print('⚠️ No author detected in blockquote');
        }

        return TextSpan(children: spans);
      } else if (node.localName == 'cite') {
        // Author/citation - centered below quote like Apple Books
        String authorText = '';
        for (var child in node.nodes) {
          if (child is dom.Text) {
            authorText += child.text;
          } else if (child is dom.Element) {
            authorText += child.text;
          }
        }

        authorText = authorText.trim();
        if (authorText.isEmpty) {
          return const TextSpan(text: '');
        }

        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            width: maxWidth,
            padding: EdgeInsets.fromLTRB(0.w, 16.h, 0.w, 24.h),
            child: Text(
              authorText,
              textAlign: TextAlign.center,
              style: widget.style.copyWith(
                fontStyle: FontStyle.normal,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),
        );
      } else if (node.localName == 'em' || node.localName == 'i') {
        // Italic text
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNode(child, maxWidth));
        }
        return TextSpan(
          children: children,
          style: widget.style.copyWith(
            fontStyle: FontStyle.italic,
          ),
        );
      } else if (node.localName == 'strong' || node.localName == 'b') {
        // Bold text
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNode(child, maxWidth));
        }
        return TextSpan(
          children: children,
          style: widget.style.copyWith(
            fontWeight: FontWeight.bold,
          ),
        );
      } else {
        List<InlineSpan> children = [];
        for (var child in node.nodes) {
          children.add(await _parseNode(child, maxWidth));
        }
        return TextSpan(children: children);
      }
    }
    return const TextSpan(text: "");
  }

  Future<InlineSpan> _handleImageNode(dom.Element node, double maxWidth) async {
    String? src = node.attributes['src'];
    print('📷 Found img tag with src: "$src"');

    if (src == null || widget.epubBook == null) {
      return const TextSpan(text: "");
    }

    final imageContent = _findImage(src);

    if (imageContent == null) {
      print('⚠️ Image not found in EPUB: $src');
      return _createNotFoundWidget(src);
    }

    try {
      final bytes = imageContent.Content as List<int>;
      final uint8list = Uint8List.fromList(bytes);

      print('🖼️ Decoding image, size: ${bytes.length} bytes');

      final codec = await ui.instantiateImageCodec(uint8list);
      final frameInfo = await codec.getNextFrame();
      final imageWidth = frameInfo.image.width.toDouble();
      final imageHeight = frameInfo.image.height.toDouble();

      print('📐 Image dimensions: ${imageWidth}x${imageHeight}');

      double availableWidth = maxWidth * 0.95;
      double displayWidth = imageWidth;
      double displayHeight = imageHeight;

      if (displayWidth > availableWidth) {
        displayWidth = availableWidth;
        displayHeight = (displayWidth / imageWidth) * imageHeight;
      }

      double maxDisplayHeight = _initializedRenderBox.size.height * 0.7;
      if (displayHeight > maxDisplayHeight) {
        displayHeight = maxDisplayHeight;
        displayWidth = (displayHeight / imageHeight) * imageWidth;
      }

      print('✅ Rendering image at: ${displayWidth}x${displayHeight}');

      return WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                uint8list,
                width: displayWidth,
                height: displayHeight,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('❌ Error rendering image: $error');
                  return _buildImageError(displayWidth);
                },
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error decoding image "$src": $e');
      return _createErrorWidget(src, maxWidth);
    }
  }

  Widget _buildImageError(double width) {
    return Container(
      width: width,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 40, color: Colors.grey[600]),
          SizedBox(height: 8),
          Text(
            'Image error',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  InlineSpan _createErrorWidget(String src, double maxWidth) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        width: maxWidth * 0.9,
        margin: EdgeInsets.symmetric(vertical: 12.h),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          border: Border.all(color: Colors.orange[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 24, color: Colors.orange[700]),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to load image',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    src.split('/').last,
                    style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InlineSpan _createNotFoundWidget(String src) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.h),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported, size: 20, color: Colors.grey[600]),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Image not found: ${src.split('/').last}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  EpubByteContentFile? _findImage(String src) {
    if (widget.epubBook?.Content?.Images == null) {
      print('❌ No images in EPUB');
      return null;
    }

    final images = widget.epubBook!.Content!.Images!;
    print('🔍 Looking for image: "$src"');

    // Exact match
    if (images.containsKey(src)) {
      print('✅ Found exact match: $src');
      return images[src];
    }

    // Decode URL-encoded paths
    try {
      final decoded = Uri.decodeFull(src);
      if (images.containsKey(decoded)) {
        print('✅ Found decoded match: $decoded');
        return images[decoded];
      }
    } catch (_) {}

    // Remove leading slash
    final noLeading = src.startsWith('/') ? src.substring(1) : src;
    if (images.containsKey(noLeading)) {
      print('✅ Found no-leading-slash match: $noLeading');
      return images[noLeading];
    }

    String cleanSrc = src
        .replaceAll('../', '')
        .replaceAll('./', '')
        .replaceAll('\\', '/')
        .trim();

    if (images.containsKey(cleanSrc)) {
      print('✅ Found cleaned match: $cleanSrc');
      return images[cleanSrc];
    }

    final filename = cleanSrc.split('/').last;

    for (var key in images.keys) {
      final cleanKey = key.replaceAll('\\', '/');

      if (cleanKey == cleanSrc ||
          cleanKey.endsWith(filename) ||
          cleanKey.toLowerCase().endsWith(filename.toLowerCase())) {
        print('✅ Found via matching: $key');
        return images[key];
      }
    }

    // Case-insensitive full-key match
    final lowerSrc = cleanSrc.toLowerCase();
    for (var key in images.keys) {
      if (key.toLowerCase() == lowerSrc) {
        print('✅ Found via case-insensitive key: $key');
        return images[key];
      }
    }

    print('❌ Image not found');
    return null;
  }

  Future<void> _paginateFlattened(
      List<InlineSpan> allSpans, Size pageSize) async {
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

    for (var s in allSpans) flatten(s);

    print('📚 Flattened to ${flatSpans.length} spans');

    List<InlineSpan> currentPageSpans = [];
    double currentHeight = 0;

    double horizontalPadding = 10.w; // Consistent minimal padding
    if (pageSize.width >= 600) {
      horizontalPadding =
          20.w; // Slightly more for tablets but still much less than before
    }
    double maxWidth = pageSize.width - horizontalPadding;

    // Calculate available height for content to FILL THE PAGE COMPLETELY
    // CRITICAL: Must fill page like a real book - NO large empty spaces!
    // No reserved space - fill page completely!
    double reservedSpace = 0.0;
    double maxHeight = pageSize.height - reservedSpace;

    print('📏 Page size: ${pageSize.width} x ${pageSize.height}');
    print(
        '📏 Reserved: $reservedSpace | Available: $maxHeight (${((maxHeight / pageSize.height) * 100).toStringAsFixed(0)}% of page)');

    for (int i = 0; i < flatSpans.length; i++) {
      final span = flatSpans[i];

      if (span is WidgetSpan) {
        double spanHeight = 0;

        try {
          TextPainter painter = TextPainter(
            text: TextSpan(children: [span]),
            textDirection: TextDirection.ltr,
            textScaleFactor: 1.0,
          );
          painter.layout(maxWidth: maxWidth);
          spanHeight = painter.height;
          painter.dispose();
          print('✅ Measured WidgetSpan: $spanHeight');
        } catch (e) {
          // Much smaller estimate for quotes/author names
          // Quote typically: padding + text (~80-120h)
          // Author name: padding + text (~40-60h)
          spanHeight = 100.h; // Realistic estimate instead of 300!
          print(
              '⚠️ Could not measure WidgetSpan, using REDUCED estimate: $spanHeight');
        }

        print(
            '🖼️ Widget span height: $spanHeight, current: $currentHeight/$maxHeight');

        // Aggressive page filling: Try to fit widget on current page
        // Only create new page if widget + current content significantly exceeds limit
        // Use 20% tolerance to fill pages better and reduce empty space
        if (currentHeight + spanHeight > maxHeight * 1.20 &&
            currentPageSpans.isNotEmpty) {
          // Only create new page if we really need it
          _pageSpans.add(TextSpan(children: List.from(currentPageSpans)));
          currentPageSpans.clear();
          currentHeight = 0;
          print(
              '📄 New page created before widget (would significantly exceed)');
        }

        currentPageSpans.add(span);
        currentHeight += spanHeight;

        // IMPORTANT: Don't create new page immediately after widget!
        // Allow text to continue filling the page to maximum capacity
      } else if (span is TextSpan && span.text != null) {
        String text = span.text!;
        TextPainter painter = TextPainter(
          text: TextSpan(text: text, style: span.style),
          textDirection: TextDirection.ltr,
          textScaleFactor: 1.0,
        );
        painter.layout(maxWidth: maxWidth);

        // Allow 10% overflow to fill pages completely (like real books)
        if (currentHeight + painter.height <= maxHeight * 1.10) {
          // Fits on current page (with tolerance)
          currentPageSpans.add(span);
          currentHeight += painter.height;
        } else {
          List<LineMetrics> lines = painter.computeLineMetrics();
          StringBuffer currentChunk = StringBuffer();
          double chunkHeight = 0;

          int charIndex = 0;
          for (var line in lines) {
            // Allow overflow per line for maximum page filling
            if (currentHeight + chunkHeight + line.height > maxHeight * 1.10) {
              if (currentChunk.isNotEmpty) {
                currentPageSpans.add(
                  TextSpan(text: currentChunk.toString(), style: span.style),
                );
              }

              // Create new page
              _pageSpans.add(TextSpan(children: List.from(currentPageSpans)));
              currentPageSpans.clear();
              currentHeight = 0;
              currentChunk.clear();
              chunkHeight = 0;
            }

            // Add line to chunk
            int endOffset = line.width > 0
                ? painter
                    .getPositionForOffset(Offset(line.width, line.baseline))
                    .offset
                : charIndex + 1;
            endOffset = endOffset.clamp(charIndex, text.length);

            String lineText = text.substring(charIndex, endOffset);

            // Check if line breaks mid-word and add hyphen if needed
            lineText = _addHyphenIfLineBreaksMidWord(lineText, text, endOffset);

            currentChunk.write(lineText);
            chunkHeight += line.height;
            charIndex = endOffset;
          }

          // Add remaining chunk
          if (currentChunk.isNotEmpty) {
            currentPageSpans.add(
              TextSpan(text: currentChunk.toString(), style: span.style),
            );
            currentHeight += chunkHeight;
          }
          if (charIndex < text.length) {
            String remaining = text.substring(charIndex);
            TextPainter remainingPainter = TextPainter(
              text: TextSpan(text: remaining, style: span.style),
              textDirection: TextDirection.ltr,
              textScaleFactor: 1.0,
            );
            remainingPainter.layout(maxWidth: maxWidth);

            // Allow 10% overflow for remaining text too
            if (currentHeight + remainingPainter.height > maxHeight * 1.10) {
              _pageSpans.add(TextSpan(children: List.from(currentPageSpans)));
              currentPageSpans.clear();
              currentHeight = 0;
            }

            currentPageSpans.add(TextSpan(text: remaining, style: span.style));
            currentHeight += remainingPainter.height;
            remainingPainter.dispose();
          }
        }

        painter.dispose();
      }
    }

    // Add final page
    if (currentPageSpans.isNotEmpty) {
      _pageSpans.add(TextSpan(children: List.from(currentPageSpans)));
      print('📄 Created final page ${_pageSpans.length}');
    }

    print('✅ Pagination complete: ${_pageSpans.length} pages');

    _finalizePages();
  }

  // Function to detect if line breaks mid-word and add hyphen ONLY there
  // Improved for English, Russian, and Turkmen word breaking
  String _addHyphenIfLineBreaksMidWord(
      String lineText, String fullText, int endOffset) {
    // Check if we're at end of full text
    if (endOffset >= fullText.length) return lineText;

    // Don't add hyphen if line is empty or already ends with whitespace/punctuation
    if (lineText.isEmpty ||
        lineText.endsWith(' ') ||
        lineText.endsWith('\n') ||
        lineText.endsWith('-') ||
        lineText.endsWith('.') ||
        lineText.endsWith(',') ||
        lineText.endsWith('!') ||
        lineText.endsWith('?')) {
      return lineText;
    }

    // Check if next character in full text is whitespace or punctuation (natural word boundary)
    if (endOffset < fullText.length) {
      final nextChar = fullText[endOffset];
      if (nextChar == ' ' ||
          nextChar == '\n' ||
          nextChar == '.' ||
          nextChar == ',' ||
          nextChar == '!' ||
          nextChar == '?') {
        return lineText; // Natural word boundary, no hyphen needed
      }
    }

    // Word is actually broken mid-word!
    // Check if it contains alphabetic characters (English/Russian/Turkmen)
    // Minimum 6 characters to avoid breaking short words
    // Supports:
    // - Latin (English): a-z, A-Z
    // - Cyrillic (Russian): U+0400-04FF
    // - Cyrillic Extended (Turkmen): U+0500-052F
    final match =
        RegExp(r'[a-zA-Z\u0400-\u04FF\u0500-\u052F]{6,}$').firstMatch(lineText);
    if (match == null) return lineText;

    // Extract the word that's being broken
    final brokenWord = match.group(0);
    if (brokenWord == null || brokenWord.length < 6) return lineText;

    // Make sure we're not breaking too close to the beginning
    // At least 3 characters should remain on first line
    final remainingChars =
        lineText.length - lineText.lastIndexOf(RegExp(r'\s')) - 1;
    if (remainingChars < 3) return lineText;

    // Add hyphen at line break for better readability
    // Examples:
    // English: "instructions" → "instruc-" + "tions"
    // Russian: "инструкция" → "инстру-" + "кция"
    // Turkmen: "kitaphanasy" → "kitap-" + "hanasy"
    return lineText + '-';
  }

  void _finalizePages() {
    final bottomNavHeight = widget.showNavBar ? 10.0 : 0.0;

    pages = _pageSpans.asMap().entries.map((entry) {
      int index = entry.key;
      TextSpan contentSpan = entry.value;

      final isFirstPageOfChapter = index == 0;

      return BookPageBuilder.buildBookPageSpan(
        context: context,
        contentSpan: contentSpan,
        style: widget.style,
        textDirection: RTLHelper.getTextDirection(widget.textContent),
        bookId: widget.bookId,
        onTextTap: widget.onTextTap,
        isFirstPage: isFirstPageOfChapter,
        chapterTitle:
            widget.chapterTitle, // Always show chapter title on every page
        pageNumber: index + 1,
        totalPages: _pageSpans.length,
        backgroundColor: widget.style.backgroundColor,
        bottomNavHeight: bottomNavHeight,
      );
    }).toList();

    // Note: totalPages is managed by show_epub.dart to preserve book-level total
    print('✅ Finalized ${pages.length} page widgets');

    // Trigger initial onPageFlip for the starting page so progress bar updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (pages.isNotEmpty) {
        final startIndex = widget.starterPageIndex < pages.length
            ? widget.starterPageIndex
            : 0;
        widget.onPageFlip(startIndex, pages.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: paginateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingWidget(
              height: 100,
              animationWidth: 50,
              animationHeight: 50,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(18.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading content',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        if (pages.isEmpty) {
          return Center(
            child: Text(
              'No content to display',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                        // Note: totalPages is managed by show_epub.dart to preserve book-level total

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

  /// Add soft hyphens to long words for better text breaking in justified text
}
