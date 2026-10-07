/// Language-independent values used to compare subtitles and concordances.
class SermonRules {
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[éèêëě]'), 'e')
      .replaceAll(RegExp(r'[áàâäã]'), 'a')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòôöõ]'), 'o')
      .replaceAll(RegExp(r'[úùûüů]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('č', 'c')
      .replaceAll('ď', 'd')
      .replaceAll('ň', 'n')
      .replaceAll('ř', 'r')
      .replaceAll('š', 's')
      .replaceAll('ť', 't')
      .replaceAll('ž', 'z')
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll(RegExp(r'[*_#]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String titleKey(String text) =>
      normalize(text).replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  static bool isSermonTitle(String text) => RegExp(
    r'^\s*KACOU\s*(?:N[°ºO.]?\s*)?\d{1,3}\s*(?:\(\s*Kc\.?\s*\d+\s*\))?\s*[:：-]',
    caseSensitive: false,
  ).hasMatch(text);

  static final _months = <String, int>{
    for (final entry in {
      1: 'janvier january enero janeiro gennaio januar ocak leden ledna',
      2: 'fevrier february febrero fevereiro febbraio februar subat unor unora',
      3: 'mars march marzo marco marz mart brezen brezna',
      4: 'avril april abril aprile nisan duben dubna',
      5: 'mai may mayo maio maggio mayis kveten kvetna',
      6: 'juin june junio junho giugno juni haziran cerven cervna',
      7: 'juillet july julio julho luglio juli temmuz cervenec cervence',
      8: 'aout august agosto agustos srpen srpna',
      9: 'septembre september septiembre setembro settembre eylul zari',
      10: 'octobre october octubre outubro ottobre oktober ekim rijen rijna',
      11: 'novembre november noviembre novembro kasim listopad listopadu',
      12: 'decembre december diciembre dezembro dicembre dezember aralik prosinec prosince',
    }.entries)
      for (final word in entry.value.split(' ')) word: entry.key,
  };

  /// Returns ISO dates, retaining order and repetitions. A translated month
  /// name does not change the date. Ambiguous numeric dates default to D/M/Y.
  static List<String> dates(String text, {String language = ''}) {
    final value = normalize(text);
    final matches = <(int, String)>[];
    void add(int offset, int year, int month, int day) {
      final date = DateTime.utc(year, month, day);
      if (date.year != year || date.month != month || date.day != day) return;
      matches.add((
        offset,
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      ));
    }

    final months = _months.keys.join('|');
    for (final m in RegExp(
      '(?<![0-9])([0-9]{1,2})(?:er|st|nd|rd|th)?\\.?\\s+(?:de\\s+)?($months)[,]?\\s+(?:de\\s+)?([0-9]{4})(?![0-9])',
    ).allMatches(value)) {
      add(m.start, int.parse(m[3]!), _months[m[2]]!, int.parse(m[1]!));
    }
    for (final m in RegExp(
      '\\b($months)\\s+([0-9]{1,2})(?:st|nd|rd|th)?[, ]+([0-9]{4})(?![0-9])',
    ).allMatches(value)) {
      add(m.start, int.parse(m[3]!), _months[m[1]]!, int.parse(m[2]!));
    }
    for (final m in RegExp(
      r'(?<!\d)(\d{4})\s*(?:[-/.]|年|nian)\s*(\d{1,2})\s*(?:[-/.]|月|yue)\s*(\d{1,2})(?:\s*(?:日|ri))?(?!\d)',
    ).allMatches(value)) {
      add(m.start, int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    }
    for (final m in RegExp(
      r'(?<!\d)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})(?!\d)',
    ).allMatches(value)) {
      final first = int.parse(m[1]!);
      final second = int.parse(m[2]!);
      final monthFirst =
          normalize(language).contains('en-us') || (first <= 12 && second > 12);
      add(
        m.start,
        int.parse(m[3]!),
        monthFirst ? first : second,
        monthFirst ? second : first,
      );
    }
    matches.sort((a, b) => a.$1.compareTo(b.$1));
    return matches.map((m) => m.$2).toList();
  }

  static bool isDateHeading(String text, {String language = ''}) {
    final value = normalize(text).replaceAll(RegExp(r'[()\[\],]'), '').trim();
    if (dates(value, language: language).isEmpty) return false;
    return RegExp(
      r'^(?:\d{1,2}(?:er)?\.?\s+(?:de\s+)?\p{L}+\s+(?:de\s+)?\d{4}|\p{L}+\s+\d{1,2}\s+\d{4}|\d{1,2}[/.\-]\d{1,2}[/.\-]\d{4}|\d{4}[-/.年]\s*\d{1,2}[-/.月]\s*\d{1,2}日?)$',
      unicode: true,
    ).hasMatch(value);
  }

  static final _kc = RegExp(
    r'\[\s*kc(?=\.|\s|\d|\])[^\]\r\n]*\]',
    caseSensitive: false,
  );
  static List<String> concordances(String text) => _kc
      .allMatches(text)
      .map((m) => m[0]!.replaceAll(RegExp(r'\s+'), '').toLowerCase())
      .toList();
  static String concordanceDisplay(String text) =>
      _kc.allMatches(text).map((m) => m[0]!).join(' ');
}
