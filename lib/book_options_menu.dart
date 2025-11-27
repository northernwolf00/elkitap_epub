import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookOptionsMenu extends StatelessWidget {
  final Color fontColor;
  final Color backColor;
  final String bookTitle;
  final String bookImage;
  final String bookId;

  const BookOptionsMenu({
    Key? key,
    required this.fontColor,
    required this.backColor,
    required this.bookTitle,
    required this.bookImage,
    required this.bookId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.w,
      height: 34.h,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_horiz,
          color: fontColor,
          size: 16.sp,
        ),
        color: backColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        elevation: 6,
        padding: EdgeInsets.zero,
        offset: Offset(0, 50.h),
        onSelected: (value) {
          switch (value) {
            case 'book_description':
              openBookDescription(context);
              break;
            case 'contents':
              openTableOfContents();
              break;
            case 'add_to_shelf':
              addToShelf();
              break;
            case 'save_to_my_books':
              saveToMyBooks();
              break;
          }
        },
        itemBuilder: (BuildContext context) => [
          _buildMenuItem(
            label: CosmosEpubLocalization.t('book_description'),
            value: 'book_description',
            fontColor: fontColor,
            showDivider: true,
          ),
          // _buildMenuItem(
          //   label: CosmosEpubLocalization.t('contents'),
          //   value: 'contents',
          //   fontColor: fontColor,
          //   showDivider: true,
          // ),
          _buildMenuItem(
            label: CosmosEpubLocalization.t('add_to_shelf'),
            value: 'add_to_shelf',
            fontColor: fontColor,
            showDivider: true,
          ),
          _buildMenuItem(
            label: CosmosEpubLocalization.t('save_to_my_books'),
            value: 'save_to_my_books',
            fontColor: fontColor,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  /// Custom reusable menu item
  PopupMenuEntry<String> _buildMenuItem({
    required String label,
    required String value,
    required Color fontColor,
    bool showDivider = false,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fontColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            Container(
              height: 0.7,
              color: fontColor.withOpacity(0.2),
            ),
        ],
      ),
    );
  }

  void openBookDescription(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: backColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.network(
                          bookImage,
                          width: 80.w,
                          height: 120.h,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80.w,
                              height: 120.h,
                              color: Colors.grey,
                              child: Icon(Icons.book, color: Colors.white),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookTitle,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: fontColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    CosmosEpubLocalization.t('book_description'),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: fontColor,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        CosmosEpub.bookDescription,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: fontColor.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void openTableOfContents() {
   
  }

  void addToShelf() {
    CosmosEpub.onAddToShelf(bookId);
  }

  void saveToMyBooks() {
    CosmosEpub.onSaveToMyBooks(bookId);
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// class BookOptionsMenu extends StatelessWidget {
//   final Color fontColor;
//   final Color backColor;

//   const BookOptionsMenu({
//     Key? key,
//     required this.fontColor,
//     required this.backColor,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 34.w,
//       height: 34.h,
//       decoration: BoxDecoration(
//         color: Colors.grey.withOpacity(0.2),
//         shape: BoxShape.circle,
//       ),
//       child: PopupMenuButton<String>(
//         icon: Icon(
//           Icons.more_horiz,
//           color: fontColor,
//           size: 16.sp,
//         ),
//         color: backColor,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(14.r),
//         ),
//         elevation: 6,
//         padding: EdgeInsets.zero,
//         offset: Offset(0, 50.h),
//         onSelected: (value) {
//           switch (value) {
//             case 'description':
//               openBookDescription();
//               break;
//             case 'contents':
//               openTableOfContents();
//               break;
//             case 'shelf':
//               addToShelf();
//               break;
//             case 'save':
//               saveToMyBooks();
//               break;
//           }
//         },
//         itemBuilder: (BuildContext context) => [
//           _buildMenuItem(
//             label: 'Book description',
//             iconPath: 'packages/cosmos_epub/assets/icons/rider.svg',
//             fontColor: fontColor,
//             showDivider: true,
//           ),
//           _buildMenuItem(
//             label: 'Contents',
//             iconPath: 'packages/cosmos_epub/assets/icons/r2.svg',
//             fontColor: fontColor,
//             showDivider: true,
//           ),
//           _buildMenuItem(
//             label: 'Add to shelf',
//             iconPath: 'packages/cosmos_epub/assets/icons/r3.svg',
//             fontColor: fontColor,
//             showDivider: true,
//           ),
//           _buildMenuItem(
//             label: 'Save to My Books',
//             iconPath: 'packages/cosmos_epub/assets/icons/r4.svg',
//             fontColor: fontColor,
//             showDivider: false,
//           ),
//         ],
//       ),
//     );
//   }

//   /// Custom reusable menu item with optional divider
//   PopupMenuEntry<String> _buildMenuItem({
//     required String label,
//     required String iconPath,
//     required Color fontColor,
//     bool showDivider = false,
//   }) {
//     return PopupMenuItem<String>(
//       value: label.toLowerCase().replaceAll(' ', '_'),
//       child: Column(
//         children: [
//           Padding(
//             padding: EdgeInsets.symmetric(vertical: 10.h),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Expanded(
//                   child: Text(
//                     label,
//                     style: TextStyle(
//                       color: fontColor,
//                       fontSize: 14.sp,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//                 SvgPicture.asset(
//                   iconPath,
//                   color: fontColor,
//                   width: 20.w,
//                 ),
//               ],
//             ),
//           ),
//           if (showDivider) ...[
//             SizedBox(height: 10.h),
//             Container(
//               height: 0.7,
//               color: fontColor.withOpacity(0.2),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   void openBookDescription() {
//     // TODO: Implement book description action
//   }

//   void openTableOfContents() {
//     // TODO: Implement table of contents action
//   }

//   void addToShelf() {
//     // TODO: Implement add to shelf action
//   }

//   void saveToMyBooks() {
//     // TODO: Implement save to My Books action
//   }
// }
