# Your Specific Use Case: Audio at 54% → Open at Page 16/30

Based on your logs, here's exactly what you need to do:

## Your Scenario
- 📻 Audio progress: **54.3%** (stored as `0.543`)
- 📖 Book total pages: **30**
- 🎯 Target page: **16** (because 30 × 0.543 = 16.29 ≈ 16)
- ✅ Expected display: **"Page: 16 / 30"**

## Solution Code

### In Your Parent App (where you open ShowEpub):

```dart
import 'package:get_storage/get_storage.dart';
import 'package:cosmos_epub/cosmos_epub.dart';

// When opening the book reader
void openBookWithAudioSync(String bookId, EpubBook epubBook) {
  final gs = GetStorage();

  // 1️⃣ Get audio progress (0.0 to 1.0)
  final audioProgress = gs.read('audio_progress_$bookId') as double?;
  print('📻 Raw audio progress: $audioProgress');

  // 2️⃣ Get cached total pages
  final cachedPageCounts = gs.read('book_${bookId}_page_counts');
  int? totalPagesInBook;

  if (cachedPageCounts != null && cachedPageCounts is Map) {
    totalPagesInBook = 0;
    cachedPageCounts.forEach((key, value) {
      totalPagesInBook = totalPagesInBook! + (value as int);
    });
    print('💾 Cached total pages: $totalPagesInBook');
  }

  // 3️⃣ Calculate target page
  int? targetPageInBook;
  if (audioProgress != null &&
      audioProgress > 0 &&
      totalPagesInBook != null &&
      totalPagesInBook > 0) {

    targetPageInBook = (audioProgress * totalPagesInBook).round();

    print('');
    print('🎯 ═══════════════════════════════════════════');
    print('🎯 AUDIO SYNC CALCULATION');
    print('🎯 Audio progress: ${(audioProgress * 100).toStringAsFixed(1)}%');
    print('🎯 Total pages: $totalPagesInBook');
    print('🎯 Target page: $targetPageInBook');
    print('🎯 Will display as: Page $targetPageInBook / $totalPagesInBook');
    print('🎯 ═══════════════════════════════════════════');
    print('');
  } else {
    print('⚠️ Cannot sync audio - missing data:');
    print('   Audio progress: $audioProgress');
    print('   Total pages: $totalPagesInBook');
  }

  // 4️⃣ Open the book with audio sync
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ShowEpub(
        epubBook: epubBook,
        bookId: bookId,
        imageUrl: 'https://example.com/cover.jpg',
        accentColor: Colors.blue,
        chapterListTitle: 'Chapters',

        // ✅ This is the key parameter!
        starterPageInBook: targetPageInBook,

        onPageFlip: (currentPage, totalPages) {
          // This will be called with currentPage=16, totalPages=30 on first flip
          print('📄 Page: $currentPage / $totalPages');

          // Optionally save reading progress back to audio
          final newProgress = currentPage / totalPages;
          gs.write('audio_progress_$bookId', newProgress);
        },
      ),
    ),
  );
}
```

## What Happens Step-by-Step

### Before (Your Old Logs)
```
[log] 📄 Page flip: 0 / 30                        ❌ Wrong!
[log] 🔍 Looking for audio progress...
[log] ✅ Audio progress found: 54.3%
[log] 🎯 Applying audio progress: jumping to page 16
[log] 💾 Saved progress: 0.0%                     ❌ Wrong!
```

### After (With This Update)
```
🎯 AUDIO SYNC CALCULATION
🎯 Audio progress: 54.3%
🎯 Total pages: 30
🎯 Target page: 16
🎯 Will display as: Page 16 / 30

🎵 AUDIO SYNC REQUESTED
🎵 Target page in book: 16

🎯 CALCULATING CHAPTER AND PAGE FROM BOOK PAGE
🎯 Target page in book: 16
📖 Chapter 0: pages 0-29 (30 pages)
✅ Found: Chapter 0, Page 16

🎵 Will start at Chapter 0, Page 16
🎵 Starting at audio sync page: 16 in chapter 0

📄 Page flip: 16 / 30                             ✅ Correct!
💾 Saved progress: 16 / 30 (53.3%)               ✅ Correct!
```

## Quick Start Code (Copy-Paste Ready)

Replace your book opening code with this:

```dart
// Get audio and page data
final gs = GetStorage();
final audioProgress = gs.read('audio_progress_$bookId') as double?;
final pageCountsCache = gs.read('book_${bookId}_page_counts');

// Calculate total pages
int? totalPages;
if (pageCountsCache is Map) {
  totalPages = 0;
  pageCountsCache.forEach((k, v) => totalPages = totalPages! + (v as int));
}

// Calculate target page
int? startPage;
if (audioProgress != null && totalPages != null && totalPages > 0) {
  startPage = (audioProgress * totalPages).round();
}

// Open book
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ShowEpub(
    epubBook: epubBook,
    bookId: bookId,
    imageUrl: imageUrl,
    accentColor: accentColor,
    chapterListTitle: 'Chapters',
    starterPageInBook: startPage,  // 🎯 Magic happens here!
    onPageFlip: (page, total) {
      print('📄 Page: $page / $total');
      gs.write('audio_progress_$bookId', page / total);
    },
  ),
));
```

## Testing

1. **Store audio progress** (e.g., 54.3%):
   ```dart
   gs.write('audio_progress_18', 0.543);
   ```

2. **Ensure book has been opened once** so pages are cached

3. **Open the book** - it should automatically jump to page 16

4. **Check the display** - should show "Page: 16 / 30"

## Common Issues

### ❌ "Still opens at page 0"
**Solution**: Make sure you're passing `starterPageInBook` (not `starterChapter`)

### ❌ "Page counts not found"
**Solution**: Open the book once normally to cache page counts, then audio sync will work

### ❌ "Wrong page calculation"
**Solution**: Verify your math:
```dart
double progress = 0.543;  // 54.3%
int total = 30;
int target = (progress * total).round();  // = 16 ✅
```

## Display Format

To show "Page: 15 / 30" format in your UI:

```dart
onPageFlip: (currentPage, totalPages) {
  setState(() {
    // Note: currentPage is 0-indexed
    // Add 1 if you want 1-indexed display
    pageDisplay = 'Page: ${currentPage + 1} / $totalPages';
  });
}
```

If your pages are already 1-indexed (first page = 1), use:
```dart
pageDisplay = 'Page: $currentPage / $totalPages';
```

---

**You're all set!** 🎉 The epub reader now supports audio synchronization.
