import 'package:flutter/material.dart';
import 'package:selectable/selectable.dart';

class SelectableTextWithCustomToolbar extends StatelessWidget {
  final String text;
  final TextDirection textDirection;
  final TextStyle style;

  const SelectableTextWithCustomToolbar({
    super.key,
    required this.text,
    required this.textDirection,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Selectable(
      selectWordOnLongPress: true,
      selectWordOnDoubleTap: true,
      selectionColor: const Color(0xFFB8B3E9).withOpacity(0.5),

      popupMenuItems: [
        // 🟩 Add Note
        SelectableMenuItem(
          title: 'Add Note',
          isEnabled: (controller) => controller!.isTextSelected,
          handler: (controller) {
            final selectedText = controller!.getSelection()!.text!;
            _handleAddNote(context, selectedText);
            return true;
          },
        ),

        // 🟦 Share
        SelectableMenuItem(
          title: 'Share',
          isEnabled: (controller) => controller!.isTextSelected,
          handler: (controller) {
            final selectedText = controller!.getSelection()!.text!;
            _handleShare(context, selectedText);
            return true;
          },
        ),

        // 🟣 Copy
        const SelectableMenuItem(type: SelectableMenuItemType.copy),
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

  // 🧩 Custom SnackBar actions (color-coded)
  void _handleAddNote(BuildContext context, String selectedText) {
    _showColoredSnackBar(
      context,
      'Note added: "${_truncateText(selectedText)}"',
      Colors.white,
    );
  }

  void _handleShare(BuildContext context, String selectedText) {
    _showColoredSnackBar(
      context,
      'Sharing: "${_truncateText(selectedText)}"',
      Colors.white,
    );
  }

  void _showColoredSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: color,
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
