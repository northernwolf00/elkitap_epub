import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:selectable/selectable.dart';

class SelectableTextWithCustomToolbar extends StatelessWidget {
  final String text;
  final TextDirection textDirection;
  final TextStyle style;
  final String bookId; // 🆕 Add this line

  const SelectableTextWithCustomToolbar({
    super.key,
    required this.text,
    required this.textDirection,
    required this.style,
    required this.bookId, // 🆕 Required parameter
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
            title: CosmosEpubLocalization.t('copy')),
      ],
      child: Directionality(
        textDirection: textDirection,
        child: Text(
          text,
          textAlign: TextAlign.justify,
          style: style,
        ),
      ),
    );
  }

  // 🧩 SnackBar feedback
  // void _handleAddNote(BuildContext context, String selectedText) {
  //   _showColoredSnackBar(
  //     context,
  //     '${CosmosEpubLocalization.t('note_added')}: "${_truncateText(selectedText)}"',
  //     Colors.white,
  //   );
  // }
  void _handleAddNote(BuildContext context, String selectedText) async {
    await CosmosEpub.addNote(
      bookId: bookId,
      selectedText: selectedText,
      context: context,
    );
  }

  void _handleShare(BuildContext context, String selectedText) {
    _showColoredSnackBar(
      context,
      '${CosmosEpubLocalization.t('sharing')}: "${_truncateText(selectedText)}"',
      Colors.white,
    );
  }

  void _showColoredSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _truncateText(String text, {int maxLength = 50}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
