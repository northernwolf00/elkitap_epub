import 'dart:developer';
import 'package:get_storage/get_storage.dart';

/// Helper class for managing EPUB page count caching
class EpubCacheHelper {
  final String bookId;
  final GetStorage gs;

  EpubCacheHelper({
    required this.bookId,
    required this.gs,
  });

  /// Load cached page counts from storage
  Map<int, int> loadCachedPageCounts(int totalChapters) {
    final cached = gs.read('book_${bookId}_page_counts');
    Map<int, int> chapterPageCounts = {};

    if (cached != null && cached is Map) {
      // Keys may have been stored as strings; normalize to int keys
      chapterPageCounts = cached.map<int, int>((key, value) {
        final intKey = key is int ? key : int.tryParse(key.toString()) ?? 0;
        return MapEntry(intKey, value as int);
      });

      // Validate cache: if cached chapters don't match current chapter count, clear cache
      if (chapterPageCounts.length != totalChapters) {
        print('⚠️ Cache mismatch: Cached ${chapterPageCounts.length} chapters, book has $totalChapters chapters');
        print('⚠️ Clearing cache and recalculating...');
        chapterPageCounts.clear();
        gs.remove('book_${bookId}_page_counts');
        log('📚 Cache cleared, will recalculate all chapters');
        return {};
      }

      log('📚 Loaded ${chapterPageCounts.length} cached page counts');
    } else {
      log('📚 No cached page counts found, will calculate all chapters');
    }

    return chapterPageCounts;
  }

  /// Save page counts to storage
  void saveCachedPageCounts(Map<int, int> chapterPageCounts) {
    // Store with string keys to keep JSON encoder happy
    final stringKeyed = chapterPageCounts.map<String, int>(
      (key, value) => MapEntry(key.toString(), value),
    );
    gs.write('book_${bookId}_page_counts', stringKeyed);
    log('💾 Saved page counts to cache');
  }

  /// Clear all cached page counts for this book
  void clearCache() {
    gs.remove('book_${bookId}_page_counts');
    log('🗑️ Cleared cache for book $bookId');
  }
}
