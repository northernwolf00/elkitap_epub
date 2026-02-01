import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Handles page distribution and splitting of content
class PageDistributor {
  final TextStyle contentStyle;
  final bool isFrontMatter;

  // Map to store which subchapter appears on which page (0-indexed page number)
  final Map<String, int> subchapterPageMap = {};

  PageDistributor({
    required this.contentStyle,
    required this.isFrontMatter,
  });

  /// Distributes spans across multiple pages based on character limits
  List<TextSpan> distributeContent(List<InlineSpan> allSpans, Size pageSize,
      {double bottomPadding = 0}) {
    subchapterPageMap.clear(); // Clear previous mapping

    List<InlineSpan> flatSpans = _flattenSpans(allSpans);

    final metrics =
        _calculateMetrics(flatSpans, pageSize, bottomPadding: bottomPadding);

    // If content fits in single page - BALANCED
    if (metrics.pageRatio <= 1.0 && metrics.weightedTotalChars <= 1400) {
      // Check for subchapters even in single page
      _detectSubchaptersInSpans(flatSpans, 0);
      return [TextSpan(children: List.from(flatSpans))];
    }

    return _distributeToPages(flatSpans, metrics);
  }

  List<InlineSpan> _flattenSpans(List<InlineSpan> allSpans) {
    List<InlineSpan> flatSpans = [];

    void flatten(InlineSpan span, {TextStyle? inheritedStyle}) {
      if (span is TextSpan) {
        final effectiveStyle = inheritedStyle != null
            ? inheritedStyle.merge(span.style)
            : span.style;

        if (span.children != null && span.children!.isNotEmpty) {
          for (var child in span.children!) {
            flatten(child, inheritedStyle: effectiveStyle);
          }
        } else if (span.text != null && span.text!.isNotEmpty) {
          // Preserve semanticsLabel when flattening - critical for subchapter detection
          flatSpans.add(TextSpan(
            text: span.text,
            style: effectiveStyle,
            semanticsLabel: span.semanticsLabel, // PRESERVE THIS!
          ));
        }
      } else if (span is WidgetSpan) {
        flatSpans.add(span);
      }
    }

    for (var s in allSpans) {
      flatten(s);
    }
    return flatSpans;
  }

  _PageMetrics _calculateMetrics(List<InlineSpan> flatSpans, Size pageSize,
      {double bottomPadding = 0}) {
    double horizontalPadding = 10.w;
    if (pageSize.width >= 600) {
      horizontalPadding = 20.w;
    }
    double maxWidth = pageSize.width - horizontalPadding;

    // BALANCED: İyi doluluk + güvenli alt margin
    double containerPadding = isFrontMatter ? 10.h : 16.h;
    double chapterHeaderSpace = isFrontMatter ? 6.h : 12.h;
    double bottomSafeArea = isFrontMatter ? 6.h : 10.h;
    double reservedSpace =
        containerPadding + chapterHeaderSpace + bottomSafeArea + bottomPadding;
    double maxHeight = pageSize.height - reservedSpace;

    double totalContentHeight = 0;
    double weightedTotalChars = 0;
    int totalChars = 0;

    for (var span in flatSpans) {
      if (span is TextSpan && span.text != null) {
        double penalty = 1.0;
        final label = span.semanticsLabel;
        if (label != null) {
          if (label.contains('ATTR:PENALTY=')) {
            final parts = label.split('ATTR:PENALTY=');
            penalty = double.tryParse(parts[1].split('|').first) ?? 1.0;
          }
          if (label.contains('ATTR:TYPE=IMAGE')) {
            weightedTotalChars += 450; // Virtual cost for image
          }
        }
        final len = span.text!.length;
        totalChars += len;
        weightedTotalChars += len * penalty;
      }
      if (span is WidgetSpan) {
        try {
          TextPainter painter = TextPainter(
            text: TextSpan(children: [span]),
            textDirection: TextDirection.ltr,
            textScaleFactor: 1.0,
          );
          painter.layout(maxWidth: maxWidth);
          totalContentHeight += painter.height;
          painter.dispose();
        } catch (e) {
          totalContentHeight += 100.h;
        }
      } else if (span is TextSpan && span.text != null) {
        TextPainter painter = TextPainter(
          text: TextSpan(text: span.text, style: span.style),
          textDirection: TextDirection.ltr,
          textScaleFactor: 1.0,
        );
        painter.layout(maxWidth: maxWidth);
        totalContentHeight += painter.height;
        painter.dispose();
      }
    }

    double pageRatio = totalContentHeight / maxHeight;

    // Calculate character limits - BALANCED: İyi doluluk ama güvenli
    const double baseFontSize = 13.0;
    const int baseMinChars = 1100; // Orijinal: 800, Agresif: 1200
    const int baseMaxChars = 1300; // Orijinal: 1000, Agresif: 1600
    const double referenceArea = 350.0 * 600.0;

    final double currentArea = maxWidth * maxHeight;
    double screenCapacityFactor =
        (currentArea / referenceArea).clamp(0.8, 1.15);

    final currentFontSize = contentStyle.fontSize ?? baseFontSize;
    final fontScaleFactor = baseFontSize / currentFontSize;

    int minCharsPerPage =
        (baseMinChars * fontScaleFactor * screenCapacityFactor).round();
    int maxCharsPerPage =
        (baseMaxChars * fontScaleFactor * screenCapacityFactor).round();

    // Dengeli limitler
    if (maxCharsPerPage > 1300) maxCharsPerPage = 1300; // Refined from 1600
    if (maxCharsPerPage < 600) maxCharsPerPage = 600; // Refined from 700
    if (minCharsPerPage > maxCharsPerPage)
      minCharsPerPage = maxCharsPerPage - 80;

    return _PageMetrics(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      totalChars: totalChars,
      weightedTotalChars: weightedTotalChars,
      pageRatio: pageRatio,
      minCharsPerPage: minCharsPerPage,
      maxCharsPerPage: maxCharsPerPage,
    );
  }

  List<TextSpan> _distributeToPages(
      List<InlineSpan> flatSpans, _PageMetrics metrics) {
    List<List<InlineSpan>> allPages = [];
    List<InlineSpan> currentPageList = [];
    double currentPageWeightedChars = 0;

    double getRemainingWeightedChars(int fromIndex) {
      double remaining = 0;
      for (int j = fromIndex; j < flatSpans.length; j++) {
        final span = flatSpans[j];
        double penalty = 1.0;
        double virtualCost = 0;
        if (span is TextSpan) {
          final label = span.semanticsLabel;
          if (label != null) {
            if (label.contains('ATTR:PENALTY=')) {
              final parts = label.split('ATTR:PENALTY=');
              penalty = double.tryParse(parts[1].split('|').first) ?? 1.0;
            }
            if (label.contains('ATTR:TYPE=IMAGE')) {
              virtualCost = 450;
            }
          }
          remaining += (span.text?.length ?? 0) * penalty + virtualCost;
        }
      }
      return remaining;
    }

    for (int i = 0; i < flatSpans.length; i++) {
      final span = flatSpans[i];
      double penalty = 1.0;
      double virtualCost = 0;
      if (span is TextSpan) {
        final label = span.semanticsLabel;
        if (label != null) {
          if (label.contains('ATTR:PENALTY=')) {
            final parts = label.split('ATTR:PENALTY=');
            penalty = double.tryParse(parts[1].split('|').first) ?? 1.0;
          }
          if (label.contains('ATTR:TYPE=IMAGE')) {
            virtualCost = 450;
          }
        }
      }
      final spanChars =
          (span is TextSpan && span.text != null) ? span.text!.length : 0;
      final weightedSpanChars = spanChars * penalty + virtualCost;

      // SUBCHAPTER kontrolü - semanticsLabel ile işaretli başlıklar
      bool isSubchapterHeading = false;
      if (span is TextSpan &&
          span.semanticsLabel != null &&
          span.semanticsLabel!.startsWith('SUBCHAPTER:')) {
        isSubchapterHeading = true;
      }

      // SUBCHAPTER BAŞLIKLARI için ÖZEL KURAL: Her zaman yeni sayfa başlat
      if (isSubchapterHeading && currentPageList.isNotEmpty) {
        // Subchapter başlığı tespit edildi - mevcut sayfayı bitir, yeni sayfa aç
        _detectSubchaptersInSpans(currentPageList, allPages.length);
        allPages.add(List.from(currentPageList));
        currentPageList.clear();
        currentPageWeightedChars = 0;
      }
      // Normal başlıklar (h1/h2/h3) için - sadece sayfa yeterince doluysa yeni sayfa aç
      else if (_isHeadingSpan(span) &&
          currentPageList.isNotEmpty &&
          currentPageWeightedChars > metrics.minCharsPerPage * 0.55) {
        _detectSubchaptersInSpans(currentPageList, allPages.length);
        allPages.add(List.from(currentPageList));
        currentPageList.clear();
        currentPageWeightedChars = 0;
      }

      if (currentPageWeightedChars + weightedSpanChars >
          metrics.maxCharsPerPage) {
        // Orphan prevention - AMA başlıklar için UYGULAMA
        // Başlık ise ve sayfa doluysa, yeni sayfaya taşıma
        double remainingAfterThis = getRemainingWeightedChars(i + 1);

        // BALANCED: Orphan prevention - kısa metinleri taşıma
        if (!_isHeadingSpan(span) &&
            remainingAfterThis > 0 &&
            remainingAfterThis < 150) {
          currentPageList.add(span);
          currentPageWeightedChars += weightedSpanChars;
          continue;
        }

        if (currentPageList.isNotEmpty &&
            (currentPageWeightedChars >= metrics.minCharsPerPage ||
                currentPageWeightedChars + weightedSpanChars >
                    metrics.maxCharsPerPage * 1.1)) {
          _detectSubchaptersInSpans(currentPageList, allPages.length);
          allPages.add(List.from(currentPageList));
          currentPageList.clear();
          currentPageWeightedChars = 0;
        }

        if (weightedSpanChars <= metrics.maxCharsPerPage) {
          currentPageList.add(span);
          currentPageWeightedChars += weightedSpanChars;
          continue;
        }

        // Split large text spans
        if (span is TextSpan && span.text != null) {
          _splitLargeTextSpan(
            span,
            currentPageList,
            currentPageWeightedChars.round(),
            metrics,
            allPages,
          );
          currentPageList = [];
          currentPageWeightedChars = 0;
        } else {
          _handleLargeWidgetSpan(span, spanChars, currentPageList,
              currentPageWeightedChars.round(), allPages);
          currentPageList = [];
          currentPageWeightedChars = 0;
        }
      } else {
        currentPageList.add(span);
        currentPageWeightedChars += weightedSpanChars;
      }
    }

    // Add remaining content
    if (currentPageList.isNotEmpty) {
      bool hasRealContent = currentPageList.any((s) {
        if (s is TextSpan && s.text != null) return s.text!.trim().isNotEmpty;
        if (s is WidgetSpan) return true;
        return false;
      });

      if (hasRealContent) {
        _detectSubchaptersInSpans(currentPageList, allPages.length);
        allPages.add(currentPageList);
      } else if (allPages.isNotEmpty) {
        allPages.last.addAll(currentPageList);
      }
    }

    // OVERFLOW KONTROLÜ: Taşan sayfaları otomatik düzelt
    allPages = _fixOverflowingPages(allPages, metrics);

    // Log character lengths for each page
    List<TextSpan> resultPages =
        allPages.map((pageSpans) => TextSpan(children: pageSpans)).toList();
    print('📝 [PAGE LOG] Chapter character lengths:');
    for (int i = 0; i < resultPages.length; i++) {
      int charLength = resultPages[i].toPlainText().length;
      print('   📄 Page ${i + 1}: $charLength characters');
    }

    return resultPages;
  }

  bool _isHeadingSpan(InlineSpan span) {
    if (span is TextSpan) {
      final style = span.style;
      if (style != null) {
        final fontSize = style.fontSize ?? 0;
        final fontWeight = style.fontWeight;
        final baseFontSize = contentStyle.fontSize ?? 14;
        final text = span.text ?? '';
        final trimmedText = text.trim();

        final isBoldWeight = fontWeight == FontWeight.w500 ||
            fontWeight == FontWeight.w600 ||
            fontWeight == FontWeight.w700 ||
            fontWeight == FontWeight.bold;

        return fontSize >= baseFontSize + 3 &&
            isBoldWeight &&
            trimmedText.isNotEmpty;
      }
    }
    return false;
  }

  void _splitLargeTextSpan(
    TextSpan span,
    List<InlineSpan> currentPageList,
    int currentPageChars,
    _PageMetrics metrics,
    List<List<InlineSpan>> allPages,
  ) {
    String remainingText = span.text!;
    TextStyle? style = span.style;
    List<InlineSpan> tempPageList = List.from(currentPageList);
    int tempPageChars = currentPageChars;

    while (remainingText.isNotEmpty) {
      int spaceLeft = metrics.maxCharsPerPage - tempPageChars;

      if (spaceLeft < 100 && tempPageList.isNotEmpty) {
        allPages.add(List.from(tempPageList));
        tempPageList.clear();
        tempPageChars = 0;
        spaceLeft = metrics.maxCharsPerPage;
      }

      if (remainingText.length <= spaceLeft) {
        tempPageList.add(TextSpan(text: remainingText, style: style));
        tempPageChars += remainingText.length;
        remainingText = '';
      } else {
        int splitIndex = remainingText.lastIndexOf(' ', spaceLeft);
        if (splitIndex == -1 || splitIndex < spaceLeft * 0.7) {
          splitIndex = spaceLeft;
        }

        String textPart = remainingText.substring(0, splitIndex);
        remainingText = remainingText.substring(splitIndex);
        if (remainingText.startsWith(' ')) {
          remainingText = remainingText.substring(1);
        }

        tempPageList.add(TextSpan(text: textPart, style: style));
        tempPageChars += textPart.length;

        allPages.add(List.from(tempPageList));
        tempPageList.clear();
        tempPageChars = 0;
      }
    }

    if (tempPageList.isNotEmpty) {
      currentPageList.clear();
      currentPageList.addAll(tempPageList);
    }
  }

  void _handleLargeWidgetSpan(
    InlineSpan span,
    int spanChars,
    List<InlineSpan> currentPageList,
    int currentPageChars,
    List<List<InlineSpan>> allPages,
  ) {
    if (currentPageList.isEmpty) {
      currentPageList.add(span);
      allPages.add(List.from(currentPageList));
      currentPageList.clear();
    } else {
      allPages.add(List.from(currentPageList));
      currentPageList.clear();
      currentPageList.add(span);
    }
  }

  /// Detect subchapters in a list of spans and record their page number
  void _detectSubchaptersInSpans(List<InlineSpan> spans, int pageIndex) {
    for (var span in spans) {
      if (span is TextSpan &&
          span.semanticsLabel != null &&
          span.semanticsLabel!.startsWith('SUBCHAPTER:')) {
        final subchapterTitle =
            span.semanticsLabel!.substring('SUBCHAPTER:'.length);
        if (!subchapterPageMap.containsKey(subchapterTitle)) {
          subchapterPageMap[subchapterTitle] = pageIndex;
          print(
              '📍 Subchapter detected: "$subchapterTitle" at page ${pageIndex + 1}');
        }
      }
    }
  }

  /// Taşan sayfaları tespit edip düzelt - taşan içeriği sonraki sayfaya aktar
  List<List<InlineSpan>> _fixOverflowingPages(
      List<List<InlineSpan>> pages, _PageMetrics metrics) {
    List<List<InlineSpan>> fixedPages = [];

    for (int pageIdx = 0; pageIdx < pages.length; pageIdx++) {
      List<InlineSpan> currentPage = List.from(pages[pageIdx]);

      // Measure actual height
      double actualHeight = _measurePageHeight(currentPage, metrics.maxWidth);

      // If page overflows height, move spans one by one to the next page
      // BUT keep at least one span to avoid infinite loops
      while (actualHeight > metrics.maxHeight && currentPage.length > 1) {
        final lastSpan = currentPage.removeLast();

        // Calculate characters in moved span
        int movedChars = 0;
        if (lastSpan is TextSpan && lastSpan.text != null) {
          movedChars = lastSpan.text!.length;
        }

        if (pageIdx + 1 < pages.length) {
          // Check if next page would become too huge
          int nextPageChars = _calculateTotalChars(pages[pageIdx + 1]);
          if (nextPageChars + movedChars > metrics.maxCharsPerPage * 1.5) {
            // If next page is already full, insert a new page instead
            pages.insert(pageIdx + 1, [lastSpan]);
          } else {
            // Otherwise, push to the beginning of next page
            pages[pageIdx + 1].insert(0, lastSpan);
          }
        } else {
          // If no next page, create one
          pages.add([lastSpan]);
        }

        // Re-measure
        actualHeight = _measurePageHeight(currentPage, metrics.maxWidth);
      }

      fixedPages.add(currentPage);
    }

    return fixedPages;
  }

  int _calculateTotalChars(List<InlineSpan> spans) {
    int total = 0;
    for (var span in spans) {
      if (span is TextSpan && span.text != null) {
        total += span.text!.length;
      }
    }
    return total;
  }

  /// Bir sayfanın gerçek yüksekliğini ölç
  double _measurePageHeight(List<InlineSpan> spans, double maxWidth) {
    if (spans.isEmpty) return 0;

    try {
      TextPainter painter = TextPainter(
        text: TextSpan(children: spans),
        textDirection: TextDirection.ltr,
        textScaleFactor: 1.0,
      );
      painter.layout(maxWidth: maxWidth);
      double height = painter.height;
      painter.dispose();
      return height;
    } catch (e) {
      // Hata durumunda tahmini yükseklik döndür
      return 0;
    }
  }
}

class _PageMetrics {
  final double maxWidth;
  final double maxHeight;
  final int totalChars;
  final double weightedTotalChars;
  final double pageRatio;
  final int minCharsPerPage;
  final int maxCharsPerPage;

  _PageMetrics({
    required this.maxWidth,
    required this.maxHeight,
    required this.totalChars,
    required this.weightedTotalChars,
    required this.pageRatio,
    required this.minCharsPerPage,
    required this.maxCharsPerPage,
  });
}
