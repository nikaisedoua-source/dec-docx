import 'docx_builder.dart';
import 'sermon_reference.dart';
import 'sermon_rules.dart';

/// Check subtitle dates and verse numbering against French.
/// The public site omits Kc annotations, so they must never be compared or
/// removed here. The document builder retains the user's concordances.
List<String> compareFrenchConsistency(
  ParsedDocument document,
  SermonReferenceResult reference, {
  String language = '',
  List<String>? notices,
}) {
  final content = reference.content;
  if (content == null || !content.isComplete(reference.paragraphCount)) {
    return [
      '[FR-INCOMPLETE] Référence française incomplète : les dates des sous-titres ne peuvent pas être vérifiées. Réessaie la comparaison avant de générer.',
    ];
  }
  final errors = <String>[];
  final localDates = <int, List<String>>{};
  final unrecognizedDates = <int, List<(int, int)>>{};
  var previous = 0;
  for (final block in document.blocks) {
    if (block.paragraph != null) {
      previous = block.paragraph!.number;
    } else if (block.concordance == null) {
      final heading = block.subtitle ?? block.sectionTitle ?? '';
      final dates = SermonRules.dates(heading, language: language);
      if (dates.isNotEmpty) {
        localDates.putIfAbsent(previous, () => []).addAll(dates);
      } else {
        unrecognizedDates
            .putIfAbsent(previous, () => [])
            .addAll(_dateLikeDayYears(heading));
      }
    }
  }
  final positions = {
    ...content.subtitleDates.keys,
    ...localDates.keys,
  }.toList()..sort();
  for (final position in positions) {
    final expected = content.subtitleDates[position] ?? const <String>[];
    final actual = localDates[position] ?? const <String>[];
    if (expected.join('|') != actual.join('|')) {
      final location = position == 0
          ? 'Sous-titre initial'
          : 'Sous-titre après le verset $position';
      final possible = unrecognizedDates[position] ?? const <(int, int)>[];
      if (actual.isEmpty &&
          expected.isNotEmpty &&
          possible.length == expected.length &&
          List.generate(expected.length, (index) {
            final date = expected[index];
            return possible[index].$1 == int.parse(date.substring(8, 10)) &&
                possible[index].$2 == int.parse(date.substring(0, 4));
          }).every((matches) => matches)) {
        notices?.add(
          '[FR-MONTH-UNVERIFIED] $location : jour et année concordent avec le français, mais le nom du mois n’a pas pu être vérifié dans cette langue. Vérifie le mois avant de partager le document.',
        );
        continue;
      }
      errors.add(
        '[FR-DATE] $location : date(s) attendue(s) ${expected.isEmpty ? "aucune" : expected.join(", ")} ; trouvée(s) ${actual.isEmpty ? "aucune date reconnue" : actual.join(", ")}. Vérifie le jour, le mois, l’année et la position du sous-titre.',
      );
    }
  }
  for (final verse in document.paragraphs) {
    final expectedText = content.paragraphs[verse.number];
    if (expectedText == null) {
      errors.add(
        '[FR-VERSE] verset ${verse.number} : ce numéro est absent de la référence française.',
      );
      continue;
    }
  }
  return errors;
}

List<(int, int)> _dateLikeDayYears(String heading) {
  final value = SermonRules.normalize(heading);
  final matches = <(int, int, int)>[];
  for (final match in RegExp(
    r'(?<!\d)(\d{1,2})(?:er|st|nd|rd|th)?\.?\s+(?:de\s+)?\p{L}+\s+(?:de\s+)?(\d{4})(?!\d)',
    unicode: true,
  ).allMatches(value)) {
    matches.add((match.start, int.parse(match[1]!), int.parse(match[2]!)));
  }
  for (final match in RegExp(
    r'\p{L}+\s+(\d{1,2})(?:st|nd|rd|th)?[,]?\s+(\d{4})(?!\d)',
    unicode: true,
  ).allMatches(value)) {
    matches.add((match.start, int.parse(match[1]!), int.parse(match[2]!)));
  }
  matches.sort((a, b) => a.$1.compareTo(b.$1));
  return matches.map((match) => (match.$2, match.$3)).toList();
}
