// lib/translations/epub_translations.dart

import 'package:cosmos_epub/cosmos_epub.dart';
import 'package:get/get.dart';


class CosmosEpubLocalization {
  static const _texts = {
    'tr': {
      'themes': 'Tema sazlamalary',
      'bold': 'Galyň',
      'quiet': 'Sessiz',
      'paper': 'Kagyz',
      'calm': 'Asuda',
      'focus': 'Üns',
        'page': 'Sahypa',
    'of': 'dan',
      'book_description': 'Kitap beýany',
    'contents': 'Mazmuny',
    'add_to_shelf': 'Tekjä goş',
    'save_to_my_books': 'Kitaplaryma goş',
    },
    'en': {
      'themes': 'Themes',
      'bold': 'Bold',
      'quiet': 'Quiet',
      'paper': 'Paper',
      'calm': 'Calm',
      'focus': 'Focus',
       'page': 'Page',
    'of': 'of',
    'book_description': 'Book description',
    'contents': 'Contents',
    'add_to_shelf': 'Add to shelf',
    'save_to_my_books': 'Save to My Books',
    },
    'ru': {
      'themes': 'Темы',
      'bold': 'Жирный',
      'quiet': 'Тихий',
      'paper': 'Бумага',
      'calm': 'Спокойный',
      'focus': 'Фокус',
       'page': 'Страница',
    'of': 'из',
    'book_description': 'Описание книги',
    'contents': 'Содержание',
    'add_to_shelf': 'Добавить на полку',
    'save_to_my_books': 'Сохранить в Мои книги',
    },
  };

  static String t(String key) {
    final lang = CosmosEpub.currentLocale.languageCode;
    return _texts[lang]?[key] ?? _texts['tr']![key]!;
  }
}
