import 'docx_builder.dart';
import 'sermon_reference.dart';
import 'sermon_rules.dart';

/// Blocking differences; text and translations are never silently rewritten.
List<String> compareFrenchConsistency(
  ParsedDocument document,
  SermonReferenceResult reference, {
  String language = '',
}) {
  final content = reference.content;
  if (content == null || !content.isComplete(reference.paragraphCount)) {
    return [
      '[FR-INCOMPLETE] Référence française incomplète : les dates et les références [Kc…] ne peuvent pas être vérifiées. Réessaie la comparaison avant de générer.',
    ];
  }
  final errors = <String>[];
  final localDates = <int, List<String>>{};
  final texts = <int, String>{};
  var previous = 0;
  for (final block in document.blocks) {
    if (block.paragraph != null) {
      previous = block.paragraph!.number;
      texts[previous] = '${texts[previous] ?? ''}\n${block.paragraph!.text}';
    } else if (block.concordance != null) {
      texts[previous] = '${texts[previous] ?? ''}\n${block.concordance}';
    } else {
      final heading = block.subtitle ?? block.sectionTitle ?? '';
      final dates = SermonRules.dates(heading, language: language);
      if (dates.isNotEmpty) {
        localDates.putIfAbsent(previous, () => []).addAll(dates);
      }
    }
  }
  if (SermonRules.concordances(texts[0] ?? '').isNotEmpty) {
    errors.add(
      '[FR-KC] Référence [Kc…] sans verset précédent : rattache-la au verset correspondant au français.',
    );
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
        '[FR-KC] verset ${verse.number} : ce numéro est absent de la référence française.',
      );
      continue;
    }
    final actualText = texts[verse.number] ?? '';
    if (SermonRules.concordances(expectedText).join('|') !=
        SermonRules.concordances(actualText).join('|')) {
      final expected = SermonRules.concordanceDisplay(expectedText);
      final actual = SermonRules.concordanceDisplay(actualText);
      errors.add(
        '[FR-KC] verset ${verse.number} : références françaises attendues ${expected.isEmpty ? "aucune" : expected} ; trouvées ${actual.isEmpty ? "aucune" : actual}. Conserve les mêmes références, dans le même ordre et au même verset.',
      );
    }
  }
  return errors;
}
