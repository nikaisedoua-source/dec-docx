import 'package:dec_docx/docx_builder.dart';
import 'package:dec_docx/localized_issues.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('date diagnostics are complete in each interface language', () {
    const issue =
        '[FR-DATE] Sous-titre initial : date(s) attendue(s) 2002-12-15 ; trouvée(s) aucune date reconnue. Vérifie le jour, le mois, l’année et la position du sous-titre.';
    for (final locale in ['en', 'es', 'pt']) {
      final translated = localizeIssue(issue, locale);
      expect(translated, startsWith('[FR-DATE] '));
      expect(translated, contains('2002-12-15'));
      expect(translated, isNot(contains('Vérifie')));
      expect(translated, isNot(contains('trouvée')));
      expect(translated, isNot(contains('Sous-titre')));
    }
    expect(localizeIssue(issue, 'fr'), issue);
    expect(localizeIssue(issue, 'unknown'), issue);
  });

  test('source names and quoted excerpts remain verbatim', () {
    const name = 'Ajoute verset trouvé, ligne 9.docx';
    const excerpt = 'Ajoute le numero au debut de la ligne';
    const issue =
        '$name, ligne 2 : ce paragraphe n’a pas de numero -> "$excerpt". Ajoute "2 " au debut de la ligne, ou transforme cette ligne en sous-titre clair comme "PARTIE ...".';
    for (final locale in ['en', 'es', 'pt']) {
      final translated = localizeIssue(issue, locale);
      expect(translated, startsWith('$name, '));
      expect(translated, contains('"$excerpt"'));
      expect(translated, contains('"2 "'));
      expect(translated, isNot(issue));
    }
    expect(
      localizeIssue('$name : unknown user content', 'en'),
      '$name : unknown user content',
    );
  });

  test('all parser error categories receive complete translations', () {
    final errors = <String>[
      ...DocxBuilder.validateChapter(
        const ChapterInput(
          title: '',
          subtitle: '',
          similarChapters: '',
          sources: [],
        ),
      ).errors,
      ...DocxBuilder.validateChapter(
        const ChapterInput(
          title: 'Kacou 1 : TITRE MAJUSCULE',
          subtitle: '',
          similarChapters: '',
          sources: [],
        ),
      ).errors,
      ...DocxBuilder.validateChapter(
        const ChapterInput(
          title: 'Kacou 1 : Texte',
          subtitle: 'Texte',
          similarChapters: '',
          sources: [
            DocumentSource(
              name: 'source.docx',
              text: '1 Premier\n3 Troisième\n4',
            ),
          ],
        ),
      ).errors,
      'source.docx, ligne 2 : le numero 2 est seul et ne peut pas etre rattache a un texte.',
      'source.docx : aucun paragraphe numerote trouve. Ajoute des paragraphes commencant par 1, 2, 3...',
      'source.docx, ligne 2 : [ZH-PINYIN-MISSING] verset 2 : transcription pinyin manquante.',
      'source.docx, ligne 2 : [ZH-PINYIN-DUPLICATE] verset 2 : transcription pinyin répétée.',
      'source.docx, ligne 2 : [ZH-PINYIN-NUMBER] verset 2 : numéro pinyin attendu 2, trouvé illisible.',
      'source.docx, ligne 2 : [ZH-PINYIN-ORPHAN] pinyin sans verset chinois précédent.',
      '[FR-INCOMPLETE] Référence française incomplète : les dates des sous-titres ne peuvent pas être vérifiées. Réessaie la comparaison avant de générer.',
      '[FR-MONTH-UNVERIFIED] Sous-titre après le verset 2 : jour et année concordent avec le français, mais le nom du mois n’a pas pu être vérifié dans cette langue. Vérifie le mois avant de partager le document.',
    ];
    for (final locale in ['en', 'es', 'pt']) {
      for (final issue in errors) {
        final translated = localizeIssue(issue, locale);
        expect(translated, isNot(issue), reason: '$locale: $issue');
        expect(translated, isNot(contains('Ajoute')));
        expect(translated, isNot(contains('Sous-titre')));
        expect(translated, isNot(contains('numero manquant')));
      }
    }
  });
}
