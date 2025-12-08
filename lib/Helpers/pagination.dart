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
  final _box = GetStorage();

  late final RxInt currentPage;
  late final RxInt totalPages;

  PagingTextHandler({required this.paginate}) {
    currentPage = (_box.read<int>('currentPage') ?? 0).obs;
    totalPages = (_box.read<int>('totalPages') ?? 0).obs;

    ever(currentPage, (_) => _box.write('currentPage', currentPage.value));
    ever(totalPages, (_) => _box.write('totalPages', totalPages.value));
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

    Future<void> _paginate() async {
    print('📖 Starting pagination...');
    final pageSize = _initializedRenderBox.size;
    _pageSpans.clear();

    String contentToParse = widget.innerHtmlContent ?? widget.textContent;

    print(
        '📄 Content to parse (first 200 chars): ${contentToParse.substring(0, contentToParse.length > 200 ? 200 : contentToParse.length)}');

    var document = html_parser.parse(contentToParse);
    List<InlineSpan> spans = [];

    double maxWidth = pageSize.width - 64.w;

    for (var node in document.body!.nodes) {
      spans.add(await _parseNode(node, maxWidth));
    }

    print('✅ Parsed ${spans.length} top-level spans');

    await _paginateFlattened(spans, pageSize);
  }


Future<InlineSpan> _parseNode(dom.Node node, double maxWidth) async {
  if (node is dom.Text) {
    String text = node.text;
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    if (text.trim().isEmpty) {
      return const TextSpan(text: '');
    }

    return TextSpan(
      text: text,
      style: widget.style.copyWith(
        fontFamily: 'SFPro',
        height: 1.7,
        letterSpacing: 0.2,
        wordSpacing: 0.5,
      ),
    );
  } else if (node is dom.Element) {
    if (node.localName == 'img') {
      return await _handleImageNode(node, maxWidth);
    } else if (node.localName == 'br') {
      return const TextSpan(text: "\n");
    } else if (node.localName == 'p' || node.localName == 'div') {
      List<InlineSpan> children = [];
      for (var child in node.nodes) {
        final span = await _parseNode(child, maxWidth);
        children.add(span);
      }
      children.add(const TextSpan(text: "\n\n"));
      return TextSpan(children: children);
    } else if (node.localName == 'h1' ||
        node.localName == 'h2' ||
        node.localName == 'h3') {
      List<InlineSpan> children = [];
      for (var child in node.nodes) {
        children.add(await _parseNode(child, maxWidth));
      }
      return TextSpan(
        children: children,
        style: widget.style.copyWith(
          fontSize: (widget.style.fontSize ?? 16) + 4,
          fontWeight: FontWeight.bold,
          height: 1.5,
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
          Icon(Icons.warning_amber_rounded, size: 24, color: Colors.orange[700]),
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


  String cleanSrc = src.replaceAll('../', '').replaceAll('./', '').replaceAll('\\', '/').trim();
  
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

  print('❌ Image not found');
  return null;
}

Future<void> _paginateFlattened(List<InlineSpan> allSpans, Size pageSize) async {
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
  double maxWidth = pageSize.width - 64.w;
  double maxHeight = pageSize.height - 100.h;

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
      } catch (e) {
        spanHeight = 300; // Default image height estimate
        print('⚠️ Could not measure WidgetSpan, using estimate: $spanHeight');
      }

      print('🖼️ Widget span height: $spanHeight, current: $currentHeight/$maxHeight');

      // Check if we need a new page
      if (currentHeight + spanHeight > maxHeight && currentPageSpans.isNotEmpty) {
        _pageSpans.add(TextSpan(children: List.from(currentPageSpans)));
        print('📄 Created page ${_pageSpans.length} (widget overflow)');
        currentPageSpans.clear();
        currentHeight = 0;
      }

      currentPageSpans.add(span);
      currentHeight += spanHeight;

    } else if (span is TextSpan && span.text != null) {
      String text = span.text!;
      TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: span.style),
        textDirection: TextDirection.ltr,
        textScaleFactor: 1.0,
      );
      painter.layout(maxWidth: maxWidth);

      if (currentHeight + painter.height <= maxHeight) {
        // Fits on current page
        currentPageSpans.add(span);
        currentHeight += painter.height;
      } else {
        List<LineMetrics> lines = painter.computeLineMetrics();
        StringBuffer currentChunk = StringBuffer();
        double chunkHeight = 0;

        int charIndex = 0;
        for (var line in lines) {
          if (currentHeight + chunkHeight + line.height > maxHeight) {
            if (currentChunk.isNotEmpty) {
              currentPageSpans.add(
                TextSpan(text: currentChunk.toString(), style: span.style),
              );
            }
            
            // Create new page
            _pageSpans.add(TextSpan(children: List.from(currentPageSpans)));
            print('📄 Created page ${_pageSpans.length} (text split)');
            currentPageSpans.clear();
            currentHeight = 0;
            currentChunk.clear();
            chunkHeight = 0;
          }

          // Add line to chunk
          int endOffset = line.width > 0 
              ? painter.getPositionForOffset(Offset(line.width, line.baseline)).offset
              : charIndex + 1;
          endOffset = endOffset.clamp(charIndex, text.length);

          String lineText = text.substring(charIndex, endOffset);
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

          if (currentHeight + remainingPainter.height > maxHeight) {
            _pageSpans.add(TextSpan(children: List.from(currentPageSpans)));
            print('📄 Created page ${_pageSpans.length} (remaining text)');
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


  void _finalizePages() {
    final bottomNavHeight = widget.showNavBar ? 70.0 : 0.0;

    pages = _pageSpans.asMap().entries.map((entry) {
      int index = entry.key;
      TextSpan contentSpan = entry.value;

      final isFirstPageOfChapter = index == 0;

      return BookPageBuilder.buildBookPageSpan(
        contentSpan: contentSpan,
        style: widget.style,
        textDirection: RTLHelper.getTextDirection(widget.textContent),
        bookId: widget.bookId,
        onTextTap: widget.onTextTap,
        isFirstPage: isFirstPageOfChapter,
        chapterTitle: isFirstPageOfChapter ? widget.chapterTitle : null,
        pageNumber: index + 1,
        totalPages: _pageSpans.length,
        backgroundColor: widget.style.backgroundColor,
        bottomNavHeight: bottomNavHeight,
      );
    }).toList();

    _handler.totalPages.value = pages.length;
    print('✅ Finalized ${pages.length} page widgets');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: paginateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
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
              padding: EdgeInsets.all(32.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Error loading content',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
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
