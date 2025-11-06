import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: Colors.amber.withOpacity(0.5),
          cursorColor: Colors.blue,
          selectionHandleColor: Colors.blue,
        ),
      ),
      child: SelectableText(
        text,
        textAlign: TextAlign.justify,
        textDirection: textDirection,
        style: style,
        contextMenuBuilder: (context, editableTextState) {
          final TextEditingValue value = editableTextState.textEditingValue;

          // Get the selected text
          final String selectedText = value.selection.textInside(value.text);

          // Don't show menu if no text is selected
          if (selectedText.isEmpty) {
            return const SizedBox.shrink();
          }

          // Create custom button items
          final List<ContextMenuButtonItem> buttonItems = [
            // Add Note button
            ContextMenuButtonItem(
              label: 'Add Note',
              onPressed: () {
                ContextMenuController.removeAny();
                _handleAddNote(context, selectedText);
              },
            ),
            // Share button
            ContextMenuButtonItem(
              label: 'Share',
              onPressed: () {
                ContextMenuController.removeAny();
                _handleShare(context, selectedText);
              },
            ),
            // Copy button
            ContextMenuButtonItem(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: selectedText));
                ContextMenuController.removeAny();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ];

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: buttonItems,
          );
        },
      ),
    );
  }

  void _handleAddNote(BuildContext context, String selectedText) {
    // TODO: Implement your note-adding logic here
    // You can save to database, show dialog, etc.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Note added: "${_truncateText(selectedText)}"'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleShare(BuildContext context, String selectedText) {
    // TODO: Implement your sharing logic here
    // You can use share_plus package or other sharing methods
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing: "${_truncateText(selectedText)}"'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
  }

  String _truncateText(String text, {int maxLength = 50}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
