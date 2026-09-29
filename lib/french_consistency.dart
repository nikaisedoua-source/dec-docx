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
}) {
  final content = reference.content;
  if (content == null || !content.isComplete(reference.paragraphCount)) {
    return [
      '[FR-INCOMPLETE] Référence française incomplète : les dates des sous-titres ne peuvent pas être vérifiées. Réessaie la comparaison avant de générer.',
    ];
  }
  final errors = <String>[];
  final localDates = <int, List<String>>{};
  var previous = 0;
  for (final block in document.blocks) {
    if (block.paragraph != null) {
      previous = block.paragraph!.number;
    } else if (block.concordance == null) {
      final heading = block.subtitle ?? block.sectionTitle ?? '';
      final dates = SermonRules.dates(heading, language: language);
      if (dates.isNotEmpty) {
        localDates.putIfAbsent(previous, () => []).addAll(dates);
      }
    }
  }
  for (final position in {
    ...content.subtitleDates.keys,
    ...localDates.keys,
  }.toList()..sort()) {
    final expected = content.subtitleDates[position] ?? const <String>[];
    final actual = localDates[position] ?? const <String>[];
    if (expected.join('|') != actual.join('|')) {
      final location = position == 0
          ? 'Sous-titre initial'
          : 'Sous-titre après le verset $position';
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
