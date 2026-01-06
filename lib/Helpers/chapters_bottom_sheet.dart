import 'package:cached_network_image/cached_network_image.dart';
import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:cosmos_epub/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChaptersBottomSheet extends StatefulWidget {
  final String title;
  final List<LocalChapterModel> chapters;
  final String bookId;
  final String imageUrl;
  final Color accentColor;
  final String chapterListTitle;
  final int currentPage;
  final int totalPages;
  final int
      currentPageInChapter; // New parameter for current page within chapter

  const ChaptersBottomSheet({
    super.key,
    required this.title,
    required this.chapters,
    required this.bookId,
    required this.imageUrl,
    required this.accentColor,
    required this.chapterListTitle,
    required this.currentPage,
    required this.totalPages,
    this.currentPageInChapter = 0, // Default to 0
  });

  @override
  State<ChaptersBottomSheet> createState() => _ChaptersBottomSheetState();
}

class _ChaptersBottomSheetState extends State<ChaptersBottomSheet> {
  @override
  Widget build(BuildContext context) {
    String allChapterText = widget.chapters.map((c) => c.chapter).join(' ');
    TextDirection textDirection = RTLHelper.getTextDirection(allChapterText);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Directionality(
          textDirection: textDirection,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Column(
                    children: [
                      // Drag handle
                      // Center(
                      //   child: Container(
                      //     width: 40.w,
                      //     height: 4.h,
                      //     margin: EdgeInsets.only(bottom: 16.h),
                      //     decoration: BoxDecoration(
                      //       color: Colors.grey.withOpacity(0.3),
                      //       borderRadius: BorderRadius.circular(2),
                      //     ),
                      //   ),
                      // ),
                      // Title row
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 80,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors
                                  .red, // fallback background while loading
                              borderRadius:
                                  BorderRadius.circular(8), // optional
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: CachedNetworkImage(
                              imageUrl: widget.imageUrl, // << put your URL here
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const LoadingWidget(
                                height: 80,
                                animationWidth: 40,
                                animationHeight: 40,
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  textDirection: textDirection,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                if (widget.totalPages > 0) ...[
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      Text(
                                        '${CosmosEpubLocalization.t('page')} ',
                                        style: TextStyle(
                                          color: Colors.black.withOpacity(0.6),
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${widget.currentPageInChapter + 1} ${CosmosEpubLocalization.t('of')} ${widget.totalPages}',
                                        style: TextStyle(
                                          color: Colors.black.withOpacity(0.6),
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(null),
                            child: CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              child: Icon(
                                Icons.close,
                                color: fontColor,
                                size: 20.h,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.withOpacity(0.2)),
                // Chapters list
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    itemCount: widget.chapters.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.grey,
                      indent: 16.w,
                      endIndent: 16.w,
                    ),
                    itemBuilder: (context, i) {
                      final chapter = widget.chapters[i];
                      final currentChapterIndex = bookProgress
                              .getBookProgress(widget.bookId)
                              .currentChapterIndex ??
                          0;

                      // Check if this item is currently selected
                      bool isCurrentChapter = false;
                      if (chapter.isSubChapter &&
                          chapter.parentChapterIndex >= 0) {
                        // Sub-chapter: selected if parent chapter matches AND page matches
                        isCurrentChapter = (currentChapterIndex ==
                                chapter.parentChapterIndex &&
                            widget.currentPageInChapter ==
                                chapter.pageInChapter);
                      } else {
                        // Regular chapter: selected if chapter index matches
                        isCurrentChapter = (currentChapterIndex == i);
                      }

                      return InkWell(
                        onTap: () async {
                          print(
                              '📌 Chapter tapped: $i, isSubChapter: ${chapter.isSubChapter}, parentChapterIndex: ${chapter.parentChapterIndex}, pageInChapter: ${chapter.pageInChapter}');

                          // Handle sub-chapter navigation - return Map with navigation info
                          if (chapter.isSubChapter &&
                              chapter.parentChapterIndex >= 0) {
                            print(
                                '📖 Sub-chapter tapped, navigating to parent chapter ${chapter.parentChapterIndex}, page ${chapter.pageInChapter}');

                            Navigator.of(context).pop({
                              'isSubChapter': true,
                              'chapterIndex': chapter.parentChapterIndex,
                              'pageIndex': chapter.pageInChapter,
                              'subchapterIndex':
                                  i, // Include the subchapter's own index
                              'subchapterTitle': chapter
                                  .chapter, // Include the subchapter's title
                            });
                            return;
                          }

                          // If tapping the current chapter, navigate to first page of chapter
                          if (i ==
                              bookProgress
                                  .getBookProgress(widget.bookId)
                                  .currentChapterIndex) {
                            print(
                                '📄 Same chapter tapped, navigating to first page');
                            Navigator.of(context).pop({
                              'isSubChapter': false,
                              'chapterIndex': i,
                              'pageIndex': 0, // Go to first page of chapter
                            });
                            return;
                          }

                          print('✅ Changing to chapter $i');
                          Navigator.of(context).pop({
                            'isSubChapter': false,
                            'chapterIndex': i,
                            'pageIndex': 0,
                          });
                        },
                        child: Container(
                          color: isCurrentChapter
                              ? Colors.grey[400]
                              : Colors.grey[200],
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 20.h,
                          ),
                          child: Row(
                            children: [
                              // Chapter content
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: widget.chapters[i].isSubChapter &&
                                            textDirection == TextDirection.ltr
                                        ? 20.w
                                        : 0,
                                    right: widget.chapters[i].isSubChapter &&
                                            textDirection == TextDirection.rtl
                                        ? 20.w
                                        : 0,
                                  ),
                                  child: Text(
                                    widget.chapters[i].chapter,
                                    textDirection: RTLHelper.getTextDirection(
                                        widget.chapters[i].chapter),
                                    style: TextStyle(
                                      color: isCurrentChapter
                                          ? Colors.black54
                                          : Colors.black54,
                                      fontSize: 14.sp,
                                      fontWeight:
                                          widget.chapters[i].isSubChapter
                                              ? FontWeight.w400
                                              : FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // Show page number if available
                              if (widget.chapters[i].startPage > 0)
                                Text(
                                  widget.chapters[i].isSubChapter
                                      ? '${widget.chapters[i].startPage - 1}' // Sub-chapter: use startPage directly
                                      : '${widget.chapters[i].startPage - 1}', // Main chapter: -1 for display
                                  style: TextStyle(
                                    color: Colors.grey,
                                    // fontFamily: 'Gilroy',
                                    fontSize: 13.sp,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
