# Audio Progress Synchronization with EPUB Reader

This guide explains how to synchronize audiobook progress with the EPUB reader using the `starterPageInBook` parameter.

## Overview

The `ShowEpub` widget now supports starting from a specific page in the book (not just a specific chapter). This allows you to sync audio playback progress with text reading progress.

## How It Works

1. **Audio progress is stored as a percentage** (e.g., 54.3% = 0.543)
2. **Calculate the target page** based on total pages in the book
3. **Pass the target page** to `ShowEpub` via the `starterPageInBook` parameter
4. **The reader automatically jumps** to the correct chapter and page

## Important Requirements

⚠️ **The book must have been opened at least once before** so that page counts are cached. The audio sync feature requires knowing how many pages are in each chapter.

## Example Usage

### In Your Parent Application

```dart
import 'package:get_storage/get_storage.dart';
import 'package:cosmos_epub/cosmos_epub.dart';

class BookReaderScreen extends StatelessWidget {
  final String bookId;
  final EpubBook epubBook;

  @override
  Widget build(BuildContext context) {
    // 1. Get audio progress from storage (stored as 0.0 to 1.0)
    final gs = GetStorage();
    final audioProgress = gs.read('audio_progress_$bookId') as double?;

    // 2. Get total pages from cache (if available)
    final cachedPageCounts = gs.read('book_${bookId}_page_counts');
    int? totalPages;

    if (cachedPageCounts != null && cachedPageCounts is Map) {
      totalPages = 0;
      cachedPageCounts.forEach((key, value) {
        totalPages = totalPages! + (value as int);
      });
    }

    // 3. Calculate target page in book
    int? starterPageInBook;
    if (audioProgress != null && totalPages != null && totalPages > 0) {
      starterPageInBook = (audioProgress * totalPages).round();
      print('🎵 Audio sync: ${(audioProgress * 100).toStringAsFixed(1)}% → Page $starterPageInBook / $totalPages');
    }

    // 4. Open the book with audio sync
    return ShowEpub(
      epubBook: epubBook,
      bookId: bookId,
      imageUrl: 'https://example.com/cover.jpg',
      accentColor: Colors.blue,
      chapterListTitle: 'Chapters',
      starterPageInBook: starterPageInBook,  // ✅ Audio sync!
      onPageFlip: (currentPage, totalPages) {
        // Save reading progress
        print('📄 Page: $currentPage / $totalPages');

        // Optional: Update audio progress when reading
        final readingProgress = currentPage / totalPages;
        gs.write('audio_progress_$bookId', readingProgress);
      },
    );
  }
}
```

## Example with Your Logs

Based on your logs where audio is at **54.3%** and the book has **30 pages**:

```dart
// Audio progress: 54.3% = 0.543
double audioProgress = 0.543;

// Total pages: 30
int totalPages = 30;

// Calculate target page: 30 * 0.543 = 16.29 ≈ 16
int targetPage = (totalPages * audioProgress).round(); // = 16

// Open book
ShowEpub(
  // ... other parameters ...
  starterPageInBook: targetPage,  // Will open at page 16/30
);
```

## Display Format

The `onPageFlip` callback will receive:
- `currentPage`: Current page in the book (e.g., 16)
- `totalPages`: Total pages in the book (e.g., 30)

You can display this as: **"Page: 16 / 30"**

## Workflow Diagram

```
1. User listens to audiobook → 54.3% complete
   ↓
2. Store audio progress: gs.write('audio_progress_18', 0.543)
   ↓
3. User opens EPUB reader
   ↓
4. Calculate target page: 30 * 0.543 = 16
   ↓
5. Pass to ShowEpub: starterPageInBook = 16
   ↓
6. Reader calculates: "Page 16 is in Chapter X, Page Y"
   ↓
7. Reader loads Chapter X and jumps to Page Y
   ↓
8. Display shows: "Page: 16 / 30"
```

## Error Handling

If the book hasn't been opened before (no cached page counts):
- The `starterPageInBook` parameter will be ignored
- The book will open from the last saved reading position or from the beginning
- Page counts will be calculated and cached for next time

## Best Practices

1. **Always check if cache exists** before calculating `starterPageInBook`
2. **Handle null cases** gracefully
3. **Store both audio and reading progress** for bi-directional sync
4. **Use 0-based page indexing** (page 0 = first page)
5. **Round the calculated page** to the nearest integer

## Bi-Directional Sync (Optional)

To sync reading progress back to audio:

```dart
onPageFlip: (currentPage, totalPages) {
  // Update audio progress when user reads ahead
  final readingProgress = currentPage / totalPages;
  final audioProgress = gs.read('audio_progress_$bookId') as double? ?? 0.0;

  // If reading is ahead of audio, update audio position
  if (readingProgress > audioProgress) {
    gs.write('audio_progress_$bookId', readingProgress);
    print('📖 Updated audio to match reading: ${(readingProgress * 100).toStringAsFixed(1)}%');
  }
},
```

## Troubleshooting

### "Audio sync not working"
- ✅ Ensure the book has been opened at least once
- ✅ Check that `book_${bookId}_page_counts` exists in storage
- ✅ Verify `starterPageInBook` is not null

### "Opens at wrong page"
- ✅ Check your page calculation: `(totalPages * audioProgress).round()`
- ✅ Verify audio progress is between 0.0 and 1.0
- ✅ Check logs for "🎵 AUDIO SYNC REQUESTED"

### "Progress saved as 0.0%"
- ✅ Don't save progress during initialization, only after user interaction
- ✅ Wait for the first `onPageFlip` callback to get the correct page

## API Reference

### ShowEpub Parameters

```dart
ShowEpub({
  required EpubBook epubBook,
  required String bookId,
  required String imageUrl,
  required Color accentColor,
  required String chapterListTitle,
  int starterChapter = 0,               // Chapter to start from
  int? starterPageInBook,               // 🆕 Page in book to start from (audio sync)
  Function(int, int)? onPageFlip,       // Called when page changes
  Function(int)? onLastPage,            // Called on last page
  bool shouldOpenDrawer = false,
})
```

### Priority Order

1. **starterPageInBook** (audio sync) - highest priority
2. **Saved progress** (last reading position)
3. **starterChapter** (explicit chapter)
4. **Chapter 0** (beginning) - lowest priority

---

**Note**: This feature requires cached page counts. On first open, the book will be read normally and page counts will be cached for future audio sync.
