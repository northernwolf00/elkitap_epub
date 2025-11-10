import 'package:cosmos_epub/translations/epub_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BookOptionsMenu extends StatelessWidget {
  final Color fontColor;
  final Color backColor;

  const BookOptionsMenu({
    Key? key,
    required this.fontColor,
    required this.backColor,
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
              openBookDescription();
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
          _buildMenuItem(
            label: CosmosEpubLocalization.t('contents'),
            value: 'contents',
            fontColor: fontColor,
            showDivider: true,
          ),
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

  void openBookDescription() {
    // TODO: Implement book description action
  }

  void openTableOfContents() {
    // TODO: Implement table of contents action
  }

  void addToShelf() {
    // TODO: Implement add to shelf action
  }

  void saveToMyBooks() {
    // TODO: Implement save to My Books action
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
