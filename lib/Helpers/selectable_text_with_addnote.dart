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
      selectionColor: const Color(0xFFB8B3E9).withOpacity(0.5),
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
              SizedBox(height: 40.h),
              Text(
                chapterTitle!,
                textAlign: TextAlign.center,
                style: style.copyWith(
                  fontSize: (style.fontSize ?? 12),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SFPro',
                  height: 1,
                ),
              ),
              SizedBox(height: 30.h),
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

    // Remove excessive spaces (2 or more spaces become 1)
    formatted = formatted.replaceAll(RegExp(r' {2,}'), ' ');

    // Normalize line breaks (3+ newlines become 2)
    formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Add space after punctuation if missing
    formatted = formatted.replaceAll(RegExp(r'\.(\S)'), '. \$1');
    formatted = formatted.replaceAll(RegExp(r',(\S)'), ', \$1');
    formatted = formatted.replaceAll(RegExp(r';(\S)'), '; \$1');
    formatted = formatted.replaceAll(RegExp(r':(\S)'), ': \$1');
    formatted = formatted.replaceAll(RegExp(r'!(\S)'), '! \$1');
    formatted = formatted.replaceAll(RegExp(r'\?(\S)'), '? \$1');

    // Remove spaces before punctuation
    formatted = formatted.replaceAll(RegExp(r'\s+([.,;:!?])'), '\$1');

    // Replace hyphens with em dash
    formatted = formatted.replaceAll(RegExp(r'\s+-\s+'), ' — ');

    return formatted.trim();
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
          height: 1,
          letterSpacing: 0,
          wordSpacing: 0,
          fontSize: style.fontSize,
        ),
      ));

      // Add single paragraph break (except for last paragraph)
      if (i < paragraphs.length - 1) {
        spans.add(TextSpan(text: '\n'));
      }
    }

    return RichText(
      textAlign: TextAlign.justify,
      text: TextSpan(
        children: spans,
        style: style.copyWith(
          fontFamily: 'SFPro',
          height: 1,
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
          left: 32.w,
          right: 32.w,
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
          left: 24.w,
          right: 24.w,
          top: 16.h,
          bottom: bottomNavHeight + 16.h,
        ),
        child: SingleChildScrollView(
          child: Directionality(
            textDirection: textDirection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chapter title for first page
                if (isFirstPage && chapterTitle != null) ...[
                  SizedBox(height: 40.h),
                  Text(
                    chapterTitle,
                    textAlign: TextAlign.center,
                    style: style.copyWith(
                      fontSize: (style.fontSize ?? 16) + 6,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SFPro',
                      height: 1,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 30.h),
                  Center(
                    child: Container(
                      width: 80.w,
                      height: 2.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (style.color ?? Colors.black).withOpacity(0.1),
                            (style.color ?? Colors.black).withOpacity(0.5),
                            (style.color ?? Colors.black).withOpacity(0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30.h),
                ],

                // Main content with TextSpan (includes text and images) wrapped in Selectable
                Selectable(
                  selectWordOnLongPress: true,
                  selectWordOnDoubleTap: true,
                  selectionColor: const Color(0xFFB8B3E9).withOpacity(0.5),
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

                        final position =
                            box.localToGlobal(Offset.zero) & box.size;

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
                  child: RichText(
                    textAlign: TextAlign.justify,
                    text: contentSpan,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _handleAddNoteFromSpan(
      BuildContext context, String bookId, String selectedText) async {
    await CosmosEpub.addNote(
      bookId: bookId,
      selectedText: selectedText,
      context: context,
    );
  }

  static String cleanBookText(String htmlText) {
    String cleaned = htmlText.replaceAll(RegExp(r'<[^>]*>'), '');
    cleaned = cleaned
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–');
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    return cleaned.trim();
  }
}
