import 'package:cosmos_epub/Helpers/functions.dart';
import 'package:cosmos_epub/Model/chapter_model.dart';
import 'package:cosmos_epub/show_epub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ChaptersBottomSheet extends StatelessWidget {
  final String title;
  final List<LocalChapterModel> chapters;
  final String bookId;
  final Color accentColor;
  final String chapterListTitle;
  final int currentPage;
  final int totalPages;

  const ChaptersBottomSheet({
    super.key,
    required this.title,
    required this.chapters,
    required this.bookId,
    required this.accentColor,
    required this.chapterListTitle,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    String allChapterText = chapters.map((c) => c.chapter).join(' ');
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
              color: backColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
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
                      Center(
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          margin: EdgeInsets.only(bottom: 16.h),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Title row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 80,
                            width: 60,
                            decoration: BoxDecoration(color: Colors.red),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  textDirection: textDirection,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                if (totalPages > 0) ...[
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      Text(
                                        'Page ',
                                        style: TextStyle(
                                          color: Colors.black.withOpacity(0.6),
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                      Text(
                                        '$currentPage of $totalPages',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(false),
                            child: CircleAvatar(
                              backgroundColor: Colors.grey[200],
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
                    itemCount: chapters.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.grey.withOpacity(0.2),
                      indent: 16.w,
                      endIndent: 16.w,
                    ),
                    itemBuilder: (context, i) {
                      final isCurrentChapter = bookProgress
                              .getBookProgress(bookId)
                              .currentChapterIndex ==
                          i;

                      return InkWell(
                        onTap: () async {
                          await bookProgress.setCurrentChapterIndex(bookId, i);
                          Navigator.of(context).pop(true);
                        },
                        child: Container(
                          color: isCurrentChapter
                              ? Colors.grey[300]
                              : Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          child: Row(
                            children: [
                              // Chapter content
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: chapters[i].isSubChapter &&
                                            textDirection == TextDirection.ltr
                                        ? 20.w
                                        : 0,
                                    right: chapters[i].isSubChapter &&
                                            textDirection == TextDirection.rtl
                                        ? 20.w
                                        : 0,
                                  ),
                                  child: Text(
                                    chapters[i].chapter,
                                    textDirection: RTLHelper.getTextDirection(
                                        chapters[i].chapter),
                                    style: TextStyle(
                                      color: isCurrentChapter
                                          ? Colors.grey
                                          : Colors.grey,
                                      fontFamily: fontNames
                                          .where((element) =>
                                              element == selectedFont)
                                          .first,
                                      package: 'cosmos_epub',
                                      fontSize: 14.sp,
                                      fontWeight: chapters[i].isSubChapter
                                          ? FontWeight.w400
                                          : FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // Show page number if available
                              if (chapters[i].startPage > 0)
                                Text(
                                  '${chapters[i].startPage}',
                                  style: TextStyle(
                                    color: fontColor.withOpacity(0.5),
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
