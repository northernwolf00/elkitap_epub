
// class LocalChapterModel {
//   final String chapter;
//   bool isSubChapter = false;

//   LocalChapterModel({required this.chapter, required this.isSubChapter});
// }

class LocalChapterModel {
  final String chapter;
  bool isSubChapter = false;
  int startPage = 0;
  int endPage = 0;
  int pageCount = 0;

  LocalChapterModel({
    required this.chapter,
    required this.isSubChapter,
    this.startPage = 0,
    this.endPage = 0,
    this.pageCount = 0,
  });
}