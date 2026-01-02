import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:selectable/selectable.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SelectableTextWithCustomToolbar extends StatelessWidget {
  final String text;
  final TextDirection textDirection;
  final TextStyle style;
  final String bookId;
  final bool isFirstPage;
  final String? chapterTitle;
  final int? pageNumber;
  final int? totalPages;

  const SelectableTextWithCustomToolbar({
    super.key,
    required this.text,
    required this.textDirection,
    required this.style,
    required this.bookId,
    this.isFirstPage = false,
    this.chapterTitle,
    this.pageNumber,
    this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    return Selectable(
      selectWordOnLongPress: true,
      selectWordOnDoubleTap: true,
      selectionColor: const Color(0xFFB8B3E9).withValues(alpha: 0.5),
      popupMenuItems: [
        SelectableMenuItem(
          title: CosmosEpubLocalization.t('add_note'),
          isEnabled: (controller) => controller!.isTextSelected,
          handler: (controller) {
            final selectedText = controller!.getSelection()!.text!;
            _handleAddNote(context, selectedText);
            return true;
          },
        ),
        SelectableMenuItem(
          title: CosmosEpubLocalization.t('share'),
          isEnabled: (controller) => controller!.isTextSelected,
          handler: (controller) {
            final selectedText = controller!.getSelection()!.text!;
            _handleShare(context, selectedText);
            return true;
          },
        ),
        SelectableMenuItem(
          type: SelectableMenuItemType.copy,
          title: CosmosEpubLocalization.t('copy'),
        ),
      ],
      child: Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFirstPage && chapterTitle != null) ...[
              SizedBox(height: 20.h),
              Text(
                chapterTitle!,
                textAlign: TextAlign.center,
                style: style.copyWith(
                  fontSize: (style.fontSize ?? 10) + 2,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SFPro',
                  height: 1.3,
                ),
              ),
              SizedBox(height: 16.h),
              // Center(
              //   child: Container(
              //     width: 80.w,
              //     height: 2.h,
              //     decoration: BoxDecoration(
              //       gradient: LinearGradient(
              //         colors: [
              //           (style.color ?? Colors.black).withOpacity(0.1),
              //           (style.color ?? Colors.black).withOpacity(0.5),
              //           (style.color ?? Colors.black).withOpacity(0.1),
              //         ],
              //       ),
              //     ),
              //   ),
              // ),
              SizedBox(height: 30.h),
            ],

            // Main text with paragraph indentation
            _buildFormattedText(text, style),
          ],
        ),
      ),
    );
  }

  String _formatText(String rawText) {
    if (rawText.isEmpty) return rawText;

    String formatted = rawText;

    // Remove all excessive whitespace (tabs, multiple spaces, non-breaking spaces, etc.)
    formatted = formatted.replaceAll('\u00A0', ' '); // Non-breaking space
    formatted = formatted.replaceAll('\u200B', ''); // Zero-width space
    formatted = formatted.replaceAll('\u2009', ' '); // Thin space
    formatted = formatted.replaceAll('\u202F', ' '); // Narrow no-break space
    formatted = formatted.replaceAll(RegExp(r'[ \t\u00A0\u200B\u2009\u202F]+'), ' ');

    // Remove spaces at the beginning and end of lines
    formatted = formatted.replaceAll(RegExp(r'^\s+', multiLine: true), '');
    formatted = formatted.replaceAll(RegExp(r'\s+$', multiLine: true), '');

    // Normalize line breaks (3+ newlines become 2)
    formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Remove extra spaces around punctuation marks
    formatted = formatted.replaceAll(RegExp(r'\s+([.,;:!?\)\]»])'), '\$1');
    formatted = formatted.replaceAll(RegExp(r'([(\[«])\s+'), '\$1');

    // Add space after punctuation if missing (both Latin and Cyrillic)
    formatted = formatted.replaceAll(RegExp(r'\.([a-zA-Zа-яА-ЯёЁ])'), '. \$1');
    formatted = formatted.replaceAll(RegExp(r',([a-zA-Zа-яА-ЯёЁ])'), ', \$1');
    formatted = formatted.replaceAll(RegExp(r';([a-zA-Zа-яА-ЯёЁ])'), '; \$1');
    formatted = formatted.replaceAll(RegExp(r':([a-zA-Zа-яА-ЯёЁ])'), ': \$1');
    formatted = formatted.replaceAll(RegExp(r'!([a-zA-Zа-яА-ЯёЁ])'), '! \$1');
    formatted = formatted.replaceAll(RegExp(r'\?([a-zA-Zа-яА-ЯёЁ])'), '? \$1');

    // Russian quotation marks fixes
    formatted = formatted.replaceAll(RegExp(r'«\s+'), '«');
    formatted = formatted.replaceAll(RegExp(r'\s+»'), '»');

    // Replace multiple hyphens or em-dashes with single em dash
    formatted = formatted.replaceAll(RegExp(r'\s*[-–—]+\s*'), ' — ');

    // Remove any remaining double spaces
    formatted = formatted.replaceAll(RegExp(r' {2,}'), ' ');

    // Add soft hyphens for word breaking (hyphenation)
    formatted = _addSoftHyphens(formatted);

    return formatted.trim();
  }

  // Add soft hyphens to allow proper word breaking with hyphens
  String _addSoftHyphens(String text) {
    // Split into words and add soft hyphens to long words
    return text.replaceAllMapped(RegExp(r'\b[\w\u0400-\u04FF]{8,}\b'), (match) {
      String word = match.group(0)!;
      // Don't hyphenate if word already contains hyphens or soft hyphens
      if (word.contains('-') || word.contains('\u00AD')) return word;

      // Check if word is Russian (Cyrillic) or English
      bool isRussian = RegExp(r'[\u0400-\u04FF]').hasMatch(word);

      StringBuffer result = StringBuffer();
      for (int i = 0; i < word.length; i++) {
        result.write(word[i]);

        // Russian hyphenation rules
        if (isRussian && i > 2 && i < word.length - 2) {
          // Add soft hyphen after consonants before vowels in Russian
          String current = word[i];
          String next = i < word.length - 1 ? word[i + 1] : '';

          bool currentIsConsonant = RegExp(r'[бвгджзклмнпрстфхцчшщБВГДЖЗКЛМНПРСТФХЦЧШЩ]').hasMatch(current);
          bool nextIsVowel = RegExp(r'[аэоуиыяюеёАЭОУИЫЯЮЕЁ]').hasMatch(next);

          if (currentIsConsonant && nextIsVowel && (i % 3 == 0 || i % 4 == 0)) {
            result.write('\u00AD'); // Soft hyphen
          }
        }
        // English hyphenation rules
        else if (!isRussian && i > 3 && i < word.length - 3) {
          // Add soft hyphen after vowels when word is long enough
          if ((i % 4 == 0 || i % 5 == 0) && 'aeiouAEIOU'.contains(word[i])) {
            result.write('\u00AD'); // Soft hyphen
          }
        }
      }
      return result.toString();
    });
  }

  Widget _buildFormattedText(String text, TextStyle style) {
    final formattedText = _formatText(text);
    final paragraphs = formattedText.split('\n\n');

    List<InlineSpan> spans = [];

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i].trim();
      if (paragraph.isEmpty) continue;

      // Add paragraph indent (using em-space for first line)
      spans.add(TextSpan(
        text: '\u2003$paragraph',
        style: style.copyWith(
          fontFamily: 'SFPro',
          height: 1.5,
          letterSpacing: 0,
          wordSpacing: 0,
          fontSize: style.fontSize,
        ),
      ));

      // Add proper paragraph break (except for last paragraph)
      if (i < paragraphs.length - 1) {
        spans.add(TextSpan(text: '\n\n'));
      }
    }

    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        children: spans,
        style: style.copyWith(
          fontFamily: 'SFPro',
          height: 1.5,
          letterSpacing: 0,
          wordSpacing: 0,
        ),
      ),
    );
  }

  void _handleAddNote(BuildContext context, String selectedText) async {
    await CosmosEpub.addNote(
      bookId: bookId,
      selectedText: selectedText,
      context: context,
    );
  }

  void _handleShare(BuildContext context, String selectedText) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.localToGlobal(Offset.zero) & box.size;

    SharePlus.instance.share(
      ShareParams(
        text: selectedText,
        sharePositionOrigin: position,
      ),
    );
  }
}

class BookPageBuilder {
  static Widget buildBookPage({
    required String text,
    required TextStyle style,
    required TextDirection textDirection,
    required String bookId,
    required VoidCallback onTextTap,
    bool isFirstPage = false,
    String? chapterTitle,
    int? pageNumber,
    int? totalPages,
    Color? backgroundColor,
    double bottomNavHeight = 70.0,
  }) {
    return InkWell(
      onTap: onTextTap,
      child: Container(
        color: backgroundColor ?? Colors.white,
        padding: EdgeInsets.only(
          left: 18.w,
          right: 18.w,
          top: 20.h,
          bottom: 20.h,
        ),
        child: SingleChildScrollView(
          child: SelectableTextWithCustomToolbar(
            text: text,
            textDirection: textDirection,
            style: style,
            bookId: bookId,
            isFirstPage: isFirstPage,
            chapterTitle: chapterTitle,
            pageNumber: pageNumber,
            totalPages: totalPages,
          ),
        ),
      ),
    );
  }

  // NEW METHOD: Build page with TextSpan (for mixed text + images)
  static Widget buildBookPageSpan({
    required BuildContext context,
    required TextSpan contentSpan,
    required TextStyle style,
    required TextDirection textDirection,
    required String bookId,
    required VoidCallback onTextTap,
    bool isFirstPage = false,
    String? chapterTitle,
    int? pageNumber,
    int? totalPages,
    Color? backgroundColor,
    double bottomNavHeight = 70.0,
  }) {
    return InkWell(
        onTap: onTextTap,
        child: Container(
          color: backgroundColor ?? Colors.white,
          padding: EdgeInsets.only(
            left: 16.w,
            right: 16.w,
            top: 4.h,  // Reduced from 8h
            bottom: 4.h,  // Reduced from 12h to maximize content area
          ),
          child: Directionality(
            textDirection: textDirection,
            child: LayoutBuilder(
              builder: (context, constraints) {
                print('📐 Page container height: ${constraints.maxHeight}');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Chapter title header on ALL pages
                    if (chapterTitle != null) ...[
                      if (isFirstPage) ...[
                        SizedBox(height: 4.h),  // Reduced from 8h
                        Text(
                          chapterTitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(
                            fontSize: (style.fontSize ?? 16) + 2,  // Smaller title
                            fontWeight: FontWeight.w500,
                            height: 1.1,  // Tighter spacing
                            letterSpacing: 0.1,
                          ),
                        ),
                        SizedBox(height: 6.h),  // Reduced from 10h
                      ] else ...[
                        SizedBox(height: 2.h),  // Reduced from 4h
                        Text(
                          chapterTitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.copyWith(
                            fontSize: (style.fontSize ?? 16) - 2,
                            fontWeight: FontWeight.w400,
                            height: 1.0,  // Tighter spacing
                            color: (style.color ?? Colors.black).withValues(alpha: 0.5),
                          ),
                        ),
                        SizedBox(height: 4.h),  // Reduced from 6h
                      ],
                    ],

                    // Main content - fill remaining space completely
                    Expanded(
                      child: Selectable(
                          selectWordOnLongPress: true,
                          selectWordOnDoubleTap: true,
                          selectionColor: const Color(0xFFB8B3E9).withValues(alpha: 0.5),
                          popupMenuItems: [
                            SelectableMenuItem(
                              title: CosmosEpubLocalization.t('add_note'),
                              isEnabled: (controller) => controller!.isTextSelected,
                              handler: (controller) {
                                final selectedText = controller!.getSelection()!.text!;
                                _handleAddNoteFromSpan(context, bookId, selectedText);
                                return true;
                              },
                            ),
                            SelectableMenuItem(
                              title: CosmosEpubLocalization.t('share'),
                              isEnabled: (controller) => controller!.isTextSelected,
                              handler: (controller) {
                                final selectedText = controller!.getSelection()!.text!;

                                final box = context.findRenderObject() as RenderBox?;
                                if (box == null) return true;

                                final position = box.localToGlobal(Offset.zero) & box.size;

                                SharePlus.instance.share(
                                  ShareParams(
                                    text: selectedText,
                                    sharePositionOrigin: position,
                                  ),
                                );
                                return true;
                              },
                            ),
                            SelectableMenuItem(
                              type: SelectableMenuItemType.copy,
                              title: CosmosEpubLocalization.t('copy'),
                            ),
                          ],
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              print('📝 RichText container height: ${constraints.maxHeight}');
                              return RichText(
                                textAlign: TextAlign.justify,
                                text: contentSpan,
                              );
                            },
                          ),
                        ),
                    ),
                  ],
                );
              },
            ),
          ),
        ));
  }

  static Future<void> _handleAddNoteFromSpan(BuildContext context, String bookId, String selectedText) async {
    await CosmosEpub.addNote(
      bookId: bookId,
      selectedText: selectedText,
      context: context,
    );
  }

  static String cleanBookText(String htmlText) {
    String cleaned = htmlText.replaceAll(RegExp(r'<[^>]*>'), '');

    // HTML entity decoding
    cleaned = cleaned
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&#160;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»');

    // Remove Unicode invisible characters
    cleaned = cleaned.replaceAll('\u00A0', ' '); // Non-breaking space
    cleaned = cleaned.replaceAll('\u200B', ''); // Zero-width space
    cleaned = cleaned.replaceAll('\u2009', ' '); // Thin space
    cleaned = cleaned.replaceAll('\u202F', ' '); // Narrow no-break space
    cleaned = cleaned.replaceAll('\uFEFF', ''); // Zero-width no-break space

    // Remove excessive spaces
    cleaned = cleaned.replaceAll(RegExp(r'[ \t\u00A0\u200B\u2009\u202F]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');

    // Clean up line breaks
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r'^\s+', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+$', multiLine: true), '');

    return cleaned.trim();
  }
}
