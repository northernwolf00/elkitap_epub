import 'package:epubx/epubx.dart';

/// Utilities for fixing and creating chapters in EPUBs with broken structure
class EpubChapterFixer {
  /// Fix for EPUBs where navigation is broken but HTML files exist
  /// Handles PDF-to-EPUB conversions and malformed EPUBs
  static void fixChaptersIfNeeded(EpubBook epubBook) {
    try {
      final chapters = epubBook.Chapters ?? [];
      final htmlFiles = epubBook.Content?.Html ?? {};
      final images = epubBook.Content?.Images ?? {};
      final spine = epubBook.Schema?.Package?.Spine?.Items ?? [];

      print('🔍 EPUB Structure Analysis:');
      print('   Chapters: ${chapters.length}');
      print('   HTML files: ${htmlFiles.length}');
      print('   Images: ${images.length}');
      print('   Spine items: ${spine.length}');

      // Validate basic EPUB structure
      if (htmlFiles.isEmpty && images.isEmpty) {
        print('⚠️ WARNING: EPUB has no HTML or image content!');
        _createDummyChapter(epubBook);
        return;
      }

      // Fix 1: If we have 1 or fewer chapters but multiple content files
      if (chapters.length <= 1 && (htmlFiles.length > 1 || (htmlFiles.isEmpty && images.length > 1))) {
        print('🔧 Fixing EPUB: Found ${chapters.length} chapters but ${htmlFiles.length} HTML + ${images.length} image files');
        print('🔧 Creating virtual chapters from content files...');

        final newChapters = <EpubChapter>[];

        // Try spine order first, then fallback to sorted HTML files
        if (spine.isNotEmpty) {
          _createChaptersFromSpine(epubBook, spine, htmlFiles, newChapters);
        }

        if (newChapters.isEmpty && htmlFiles.isNotEmpty) {
          _createChaptersFromHtmlFiles(htmlFiles, newChapters);
        }

        if (newChapters.isNotEmpty) {
          epubBook.Chapters = newChapters;
          print('🔧 ✅ Created ${newChapters.length} chapters from content files');
        } else {
          print('⚠️ Could not create chapters, using fallback');
          _createFallbackChapter(epubBook, htmlFiles, images);
        }
      }

      // Fix 2: Validate existing chapters have content
      if (chapters.isNotEmpty && _hasInvalidChapters(chapters)) {
        print('🔧 Repairing chapters with missing content...');
        _repairChapterContent(epubBook);
      }
    } catch (e, st) {
      print('❌ Error in fixChaptersIfNeeded: $e');
      print('Stack trace: $st');
    }
  }

  static void _createDummyChapter(EpubBook epubBook) {
    final dummyChapter = EpubChapter();
    dummyChapter.Title = 'Empty Book';
    dummyChapter.HtmlContent = '<html><body><p>This EPUB file appears to be empty or corrupted.</p></body></html>';
    dummyChapter.SubChapters = [];
    epubBook.Chapters = [dummyChapter];
  }

  static void _createChaptersFromSpine(
    EpubBook epubBook,
    List<EpubSpineItemRef> spine,
    Map<String, EpubTextContentFile> htmlFiles,
    List<EpubChapter> newChapters,
  ) {
    print('🔧 Using spine order for chapter creation');
    int index = 0;

    for (var spineItem in spine) {
      final idRef = spineItem.IdRef;
      if (idRef == null) continue;

      final manifestItems = epubBook.Schema?.Package?.Manifest?.Items;
      if (manifestItems == null) continue;

      EpubManifestItem? manifestItem;
      try {
        manifestItem = manifestItems.firstWhere((m) => m.Id == idRef);
      } catch (e) {
        continue;
      }

      if (manifestItem.Href == null) continue;

      final href = manifestItem.Href!;
      final isHtml = href.endsWith('.html') || href.endsWith('.xhtml') || href.endsWith('.htm');

      if (!isHtml) continue;

      final htmlContent = htmlFiles[href];
      if (htmlContent == null) continue;

      // Try to split HTML by chapter markers
      final fallbackTitle = _extractChapterTitle(href, index);
      final splitChapters = _splitHtmlByChapters(htmlContent.Content, fallbackTitle);

      for (var (chapterTitle, chapterContent) in splitChapters) {
        final chapter = EpubChapter();
        chapter.Title = chapterTitle;
        chapter.HtmlContent = chapterContent;
        chapter.ContentFileName = href;
        chapter.Anchor = '$href#${chapterTitle.replaceAll(' ', '_')}';
        chapter.SubChapters = [];

        newChapters.add(chapter);
        index++;

        print('🔧   Created chapter $index: "$chapterTitle" from spine');
      }
    }
  }

  static void _createChaptersFromHtmlFiles(
    Map<String, EpubTextContentFile> htmlFiles,
    List<EpubChapter> newChapters,
  ) {
    print('🔧 Using sorted HTML files for chapter creation');
    final sortedHtmlKeys = htmlFiles.keys.toList()..sort();
    int index = 0;

    for (var htmlKey in sortedHtmlKeys) {
      final htmlContent = htmlFiles[htmlKey];
      if (htmlContent == null) continue;

      final fallbackTitle = _extractChapterTitle(htmlKey, index);
      final splitChapters = _splitHtmlByChapters(htmlContent.Content, fallbackTitle);

      for (var (chapterTitle, chapterContent) in splitChapters) {
        final chapter = EpubChapter();
        chapter.Title = chapterTitle;
        chapter.HtmlContent = chapterContent;
        chapter.ContentFileName = htmlKey;
        chapter.Anchor = '$htmlKey#${chapterTitle.replaceAll(' ', '_')}';
        chapter.SubChapters = [];

        newChapters.add(chapter);
        index++;

        print('🔧   Created chapter $index: "$chapterTitle" from $htmlKey');
      }
    }
  }

  static bool _hasInvalidChapters(List<EpubChapter> chapters) {
    for (var chapter in chapters) {
      if (chapter.HtmlContent == null || chapter.HtmlContent!.isEmpty) {
        return true;
      }
    }
    return false;
  }

  static void _repairChapterContent(EpubBook epubBook) {
    final htmlFiles = epubBook.Content?.Html ?? {};

    for (var chapter in epubBook.Chapters ?? []) {
      if (chapter.HtmlContent == null || chapter.HtmlContent!.isEmpty) {
        if (chapter.ContentFileName != null) {
          final content = htmlFiles[chapter.ContentFileName!];
          if (content != null) {
            chapter.HtmlContent = content.Content;
          }
        }
      }
    }
  }

  static void _createFallbackChapter(
    EpubBook epubBook,
    Map<String, EpubTextContentFile> htmlFiles,
    Map<String, EpubByteContentFile> images,
  ) {
    if (htmlFiles.isNotEmpty) {
      final combinedHtml = StringBuffer('<html><body>');
      final sortedKeys = htmlFiles.keys.toList()..sort();

      for (var key in sortedKeys) {
        final content = htmlFiles[key]?.Content ?? '';
        combinedHtml.write('<div>');
        combinedHtml.write(content);
        combinedHtml.write('</div>');
      }

      combinedHtml.write('</body></html>');

      final chapter = EpubChapter();
      chapter.Title = 'Book Content';
      chapter.HtmlContent = combinedHtml.toString();
      chapter.SubChapters = [];

      epubBook.Chapters = [chapter];
    }
  }

  static String _extractChapterTitle(String filename, int index) {
    String title = filename.split('/').last.replaceAll('.html', '').replaceAll('.xhtml', '').replaceAll('.htm', '').replaceAll('_', ' ').trim();

    if (title.contains('-')) {
      final parts = title.split('-');
      if (parts.length > 1 && parts[0].length <= 4) {
        title = parts.sublist(1).join('-').trim();
      }
    }

    if (title.isEmpty || title.length < 2) {
      return 'Chapter ${index + 1}';
    }

    return title.length > 50 ? 'Chapter ${index + 1}' : title;
  }

  static List<(String title, String content)> _splitHtmlByChapters(
    String? htmlContent,
    String fallbackTitle,
  ) {
    if (htmlContent == null || htmlContent.isEmpty) {
      return [(fallbackTitle, htmlContent ?? '')];
    }

    try {
      final bodyMatch = RegExp(
        r'<body[^>]*>(.*?)</body>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(htmlContent);
      final bodyContent = bodyMatch?.group(1) ?? htmlContent;

      final plainTextPattern = RegExp(
        r'(?:^|\n)\s*([Cc][Hh][Aa][Pp][Tt][Ee][Rr]\s+\d+(?:\s*[-–—:]\s*[^\n]{1,100})?)\s*(?:\n|$)',
        multiLine: true,
      );

      final plainText = bodyContent.replaceAll(RegExp(r'<[^>]+>'), '\n');
      final allMatches = plainTextPattern.allMatches(plainText).toList();

      final chapterMatches = allMatches.where((match) {
        final title = match.group(1)?.trim() ?? '';
        return title.startsWith('C') && !title.contains(';') && !title.contains(',') && !title.toLowerCase().contains('when ') && !title.toLowerCase().contains('where ') && title.length >= 9;
      }).toList();

      if (chapterMatches.length <= 1) {
        return [(fallbackTitle, htmlContent)];
      }

      print('🔧 Found ${chapterMatches.length} valid chapters in single HTML file');

      final chapters = <(String title, String content)>[];

      for (int i = 0; i < chapterMatches.length; i++) {
        final match = chapterMatches[i];
        final chapterTitle = match.group(1)?.trim() ?? 'Chapter ${i + 1}';

        final searchText = chapterTitle.substring(0, chapterTitle.length.clamp(0, 20));
        final startIndex = htmlContent.indexOf(searchText);

        if (startIndex == -1) continue;

        int endIndex;
        if (i < chapterMatches.length - 1) {
          final nextMatch = chapterMatches[i + 1];
          final nextSearchText = (nextMatch.group(1) ?? '').trim().substring(0, (nextMatch.group(1) ?? '').trim().length.clamp(0, 20));
          endIndex = htmlContent.indexOf(nextSearchText, startIndex + searchText.length);
          if (endIndex == -1) endIndex = htmlContent.length;
        } else {
          endIndex = htmlContent.length;
        }

        final chapterContent = htmlContent.substring(startIndex, endIndex);
        final wrappedContent = '''<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body>$chapterContent</body>
</html>''';

        chapters.add((chapterTitle, wrappedContent));
        print('🔧   Split chapter: "$chapterTitle"');
      }

      if (chapters.isEmpty) {
        return [(fallbackTitle, htmlContent)];
      }

      return chapters;
    } catch (e) {
      print('⚠️ Error splitting HTML by chapters: $e');
      return [(fallbackTitle, htmlContent)];
    }
  }
}
