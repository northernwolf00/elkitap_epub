import 'package:hyphenatorx/hyphenatorx.dart';
import 'package:hyphenatorx/languages/language_en_us.dart';
import 'package:hyphenatorx/languages/language_ru.dart';
import 'package:hyphenatorx/languages/language_tr.dart';
import 'package:hyphenatorx/languages/language_tk.dart';

/// Helper class for hyphenating text in multiple languages
/// Supports: Russian (ru), English (en_us), Turkish (tr), Turkmen (tk)
class HyphenatorHelper {
  static HyphenatorHelper? _instance;

  Hyphenator? _russianHyphenator;
  Hyphenator? _englishHyphenator;
  Hyphenator? _turkishHyphenator;
  Hyphenator? _turkmenHyphenator;

  bool _isInitialized = false;

  // Zero-width space - satır bölünmesine izin verir ama görünmez
  static const String zwsp = '\u200B';

  // Soft hyphen - satır sonunda tire gösterir
  static const String softHyphen = '\u00AD';

  // Kombinasyon: Soft hyphen + ZWSP - Flutter'da daha iyi çalışır
  static const String hybridHyphen = '\u00AD\u200B';

  HyphenatorHelper._();

  static HyphenatorHelper get instance {
    _instance ??= HyphenatorHelper._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;

  /// Initialize all hyphenators synchronously
  void initialize() {
    if (_isInitialized) return;

    final startTime = DateTime.now();

    try {
      // Hybrid hyphen kullan - soft hyphen + ZWSP

      // Russian hyphenator
      _russianHyphenator = Hyphenator(
        Language_ru(),
        symbol: hybridHyphen,
      );

      // English hyphenator
      _englishHyphenator = Hyphenator(
        Language_en_us(),
        symbol: hybridHyphen,
      );

      // Turkish hyphenator
      _turkishHyphenator = Hyphenator(
        Language_tr(),
        symbol: hybridHyphen,
      );

      // Turkmen hyphenator
      _turkmenHyphenator = Hyphenator(
        Language_tk(),
        symbol: hybridHyphen,
      );

      _isInitialized = true;
      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;
      final durationSec = (durationMs / 1000).toStringAsFixed(2);
      print(
          '📝 HyphenatorHelper initialized for RU, EN, TR, TK languages (soft hyphen+ZWSP mode) - took ${durationMs}ms ($durationSec seconds)');
    } catch (e) {
      print('⚠️ HyphenatorHelper initialization failed: $e');
      _isInitialized = false;
    }
  }

  /// Detect language from text content
  Language detectLanguage(String text) {
    if (text.isEmpty) return Language.english;

    // Count character types
    int cyrillicCount = 0;
    int latinCount = 0;
    int turkmenSpecificCount = 0;

    for (int i = 0; i < text.length && i < 500; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);

      // Cyrillic range: 0x0400-0x04FF
      if (code >= 0x0400 && code <= 0x04FF) {
        cyrillicCount++;
      }
      // Basic Latin range: 0x0041-0x007A
      else if ((code >= 0x0041 && code <= 0x005A) ||
          (code >= 0x0061 && code <= 0x007A)) {
        latinCount++;
      }

      // Turkmen specific characters: ä, ň, ö, ü, ý, ž, ş
      if ('äňöüýžşÄŇÖÜÝŽŞ'.contains(char)) {
        turkmenSpecificCount++;
      }
    }

    // Determine language
    if (cyrillicCount > latinCount) {
      return Language.russian;
    } else if (turkmenSpecificCount > 3) {
      return Language.turkmen;
    } else {
      return Language.english;
    }
  }

  /// Hyphenate text based on detected or specified language
  /// Soft hyphen kullanır - satır sonunda tire gösterir
  String hyphenate(String text, {Language? language}) {
    if (!_isInitialized || text.isEmpty) return text;

    // Don't hyphenate very short text
    if (text.length < 8) return text;

    final lang = language ?? detectLanguage(text);

    try {
      String result;
      switch (lang) {
        case Language.russian:
          result = _russianHyphenator?.hyphenateText(text) ?? text;
          break;
        case Language.english:
          result = _englishHyphenator?.hyphenateText(text) ?? text;
          break;
        case Language.turkmen:
          result = _turkmenHyphenator?.hyphenateText(text) ?? text;
          break;
        case Language.turkish:
          result = _turkishHyphenator?.hyphenateText(text) ?? text;
          break;
      }

      return result;
    } catch (e) {
      // If hyphenation fails, return original text
      return text;
    }
  }

  /// Hyphenate a single word
  String hyphenateWord(String word, {Language? language}) {
    if (!_isInitialized || word.isEmpty || word.length < 4) return word;

    final lang = language ?? detectLanguage(word);

    try {
      String result;
      switch (lang) {
        case Language.russian:
          result = _russianHyphenator?.hyphenateWord(word) ?? word;
          break;
        case Language.english:
          result = _englishHyphenator?.hyphenateWord(word) ?? word;
          break;
        case Language.turkmen:
          result = _turkmenHyphenator?.hyphenateWord(word) ?? word;
          break;
        case Language.turkish:
          result = _turkishHyphenator?.hyphenateWord(word) ?? word;
          break;
      }

      // ZWSP zaten eklendi
      return result;
    } catch (e) {
      return word;
    }
  }

  /// Satır sonlarında ZWSP varsa tire ekle
  /// TextPainter ile satır sonlarını tespit edip, ZWSP'de bölünenlere tire ekler
  static String addHyphensAtLineBreaks(
      String text, List<int> lineBreakPositions) {
    if (lineBreakPositions.isEmpty) return text;

    final buffer = StringBuffer();
    int lastPos = 0;

    for (int breakPos in lineBreakPositions) {
      if (breakPos > 0 && breakPos <= text.length) {
        // Satır sonu karakterini kontrol et
        final charAtBreak = breakPos < text.length ? text[breakPos] : '';
        final charBeforeBreak = breakPos > 0 ? text[breakPos - 1] : '';

        // Eğer satır sonu ZWSP ile bitiyorsa, tire ekle
        if (charBeforeBreak == zwsp || charAtBreak == zwsp) {
          buffer.write(text.substring(lastPos, breakPos));
          // ZWSP'nin yerine tire koy
          if (charBeforeBreak == zwsp) {
            buffer.write('-');
            lastPos = breakPos; // ZWSP'yi atla
          } else {
            buffer.write('-');
            lastPos = breakPos + 1; // ZWSP'yi atla
          }
        } else {
          buffer.write(text.substring(lastPos, breakPos));
          lastPos = breakPos;
        }
      }
    }

    // Kalan metni ekle
    if (lastPos < text.length) {
      buffer.write(text.substring(lastPos));
    }

    return buffer.toString();
  }
}

enum Language {
  russian,
  english,
  turkish,
  turkmen,
}
