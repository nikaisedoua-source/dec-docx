import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dec_docx/docx_builder.dart';
import 'package:dec_docx/french_consistency.dart';
import 'package:dec_docx/sermon_reference.dart';
import 'package:dec_docx/sermon_rules.dart';

ParsedDocument document(
  String text, {
  String subtitle = '',
  String language = 'en',
}) => DocxBuilder.validateChapter(
  ChapterInput(
    title: 'Kacou 154 : The current stage of my mission',
    subtitle: subtitle,
    similarChapters: '',
    language: language,
    sources: [DocumentSource(name: 'Texte saisi', text: text)],
  ),
).documents.first;
SermonReferenceResult reference(String source, {int count = 2}) =>
    SermonReferenceResult(
      chapterNumber: 154,
      paragraphCount: count,
      url: Uri.parse('https://www.philippekacou.org/fr-fr/sermons/154'),
      similarChapters: null,
      content: SermonReferenceService.parseReferenceContent(source),
    );
String html(
  String body, {
  String subtitle = 'Révélation donnée le 18 décembre 2022',
}) =>
    '<script type="application/ld+json">${jsonEncode({'headline': 'Kacou 154 : Titre', 'alternativeHeadline': subtitle, 'articleBody': body})}</script>';

void main() {
  test('same calendar date across translations and numeric formats', () {
    for (final value in [
      '18 décembre 2022',
      'December 18, 2022',
      '18 de diciembre de 2022',
      '18 de dezembro de 2022',
      '2022年12月18日',
      '18/12/2022',
      '18.12.2022',
      '12/18/2022',
      '2022-12-18',
    ]) {
      expect(SermonRules.dates(value), ['2022-12-18'], reason: value);
    }
    expect(SermonRules.dates('31 février 2022'), isEmpty);
    expect(SermonRules.concordances('[Kc.] [Kc ]'), hasLength(2));
    expect(SermonRules.dates('03/04/2022', language: 'en-US'), ['2022-03-04']);
  });
  test('accepts a comma after a day-first English month in a subtitle', () {
    const subtitle =
        '(Ɔkaa asɛm no Kwasiada anɔpa, 15 December, 2002 wɔ Locodjro, Abidjan-Ivory Coast)';
    expect(SermonRules.dates(subtitle, language: 'Twi'), ['2002-12-15']);

    final fr = reference(
      html('1 Texte.\n2 Suite.', subtitle: '15 décembre 2002'),
    );
    expect(
      compareFrenchConsistency(
        document('1 Text.\n2 Next.', subtitle: subtitle, language: 'Twi'),
        fr,
        language: 'Twi',
      ),
      isEmpty,
    );
  });
  test('recognizes Czech ordinal dates in the full subtitle', () {
    const subtitle =
        'Kázáno v neděli ráno 12. září 2010 v Anyamě poblíž Abidjanu – Pobřeží slonoviny';
    expect(SermonRules.dates(subtitle, language: 'Tchèque'), ['2010-09-12']);
    expect(SermonRules.dates('12. října 2010', language: 'Tchèque'), [
      '2010-10-12',
    ]);
    final fr = reference(html('1 Texte.\n2 Suite.', subtitle: '12 septembre 2010'));
    expect(
      compareFrenchConsistency(
        document('1 Text.\n2 Next.', subtitle: subtitle, language: 'Tchèque'),
        fr,
        language: 'Tchèque',
      ),
      isEmpty,
    );
    final notices = <String>[];
    expect(
      compareFrenchConsistency(
        document(
          '1 Text.\n2 Next.',
          subtitle: 'Kázáno 12. neznámý 2010',
          language: 'Tchèque',
        ),
        fr,
        language: 'Tchèque',
        notices: notices,
      ),
      isEmpty,
    );
    expect(notices.single, contains('[FR-MONTH-UNVERIFIED]'));
    final monthFirstNotices = <String>[];
    expect(
      compareFrenchConsistency(
        document(
          '1 Text.\n2 Next.',
          subtitle: 'Sermon given on Unknownmonth 12, 2010',
          language: 'unlisted language',
        ),
        fr,
        language: 'unlisted language',
        notices: monthFirstNotices,
      ),
      isEmpty,
    );
    expect(monthFirstNotices.single, contains('[FR-MONTH-UNVERIFIED]'));
    final knownWrongMonthNotices = <String>[];
    expect(
      compareFrenchConsistency(
        document(
          '1 Text.\n2 Next.',
          subtitle: 'Kázáno 12. října 2010',
          language: 'Tchèque',
        ),
        fr,
        language: 'Tchèque',
        notices: knownWrongMonthNotices,
      ).single,
      contains('[FR-DATE]'),
    );
    expect(knownWrongMonthNotices, isEmpty);
    expect(
      compareFrenchConsistency(
        document(
          '1 Text.\n2 Next.',
          subtitle: 'Kázáno 13. neznámý 2010',
          language: 'Tchèque',
        ),
        fr,
        language: 'Tchèque',
      ).single,
      contains('[FR-DATE]'),
    );
  });
  test('recognizes a dotted day with known month names across languages', () {
    for (final subtitle in [
      '12. septembre 2010',
      '12. September 2010',
      '12. septiembre 2010',
      '12. settembre 2010',
      '12. setembro 2010',
      '12. září 2010',
      '22. Listopadu 2007',
      '12. Eylül 2010',
    ]) {
      final expected = subtitle.contains('Listopadu')
          ? ['2007-11-22']
          : ['2010-09-12'];
      expect(SermonRules.dates(subtitle), expected, reason: subtitle);
      expect(SermonRules.isDateHeading(subtitle), isTrue, reason: subtitle);
    }
    expect(
      SermonRules.dates(
        '(Kázáno ve čtvrtek večer 22. Listopadu 2007 v Adjamé, Abidjanu – Pobřeží slonoviny)',
      ),
      ['2007-11-22'],
    );
    expect(SermonRules.dates('12. moisInconnu 2010'), isEmpty);
  });
  test('compares subtitles without using dates mentioned in verse prose', () {
    final fr = reference(html('1 Texte du 20 janvier 2020.\n2 Suite.'));
    expect(
      compareFrenchConsistency(
        document(
          '1 Translation mentioning March 20, 2023.\n2 Next.',
          subtitle: 'Given December 18, 2022',
        ),
        fr,
      ),
      isEmpty,
    );
    final errors = compareFrenchConsistency(
      document('1 Text.\n2 Next.', subtitle: 'Given December 19, 2022'),
      fr,
    );
    expect(errors.single, contains('[FR-DATE]'));
    expect(errors.single, contains('2022-12-18'));
    expect(
      compareFrenchConsistency(document('1 Text.\n2 Next.'), fr).single,
      contains('aucune date reconnue'),
    );
  });
  test('does not restrict Kc references, their order or verse placement', () {
    final fr = reference(
      html('1 Texte [Kc.104v28]\n[Kc.2v11][Kc.31v18]\n2 Suite.', subtitle: ''),
    );
    expect(
      compareFrenchConsistency(
        document('1 Text [Kc.104v28]\n[Kc.2v11][Kc.31v18]\n2 Next.'),
        fr,
      ),
      isEmpty,
    );
    for (final text in [
      '1 Text.\n2 Next.',
      '[Kc.1v2]\n1 Text.\n2 Next.',
      '1 Text [Kc.104v29]\n[Kc.2v11][Kc.31v18]\n2 Next.',
      '1 Text.\n2 Next [Kc.104v28][Kc.2v11][Kc.31v18]',
      '1 Text [Kc.104v28][Kc.104v28][Kc.2v11][Kc.31v18]\n2 Next.',
    ]) {
      expect(compareFrenchConsistency(document(text), fr), isEmpty);
    }
  });
  test('accepts Kc annotations omitted by the French site', () {
    final fr = reference(html('1 Texte.\n2 Suite.', subtitle: ''));
    expect(
      compareFrenchConsistency(document('1 Text [Kc.1v2]\n2 Next.'), fr),
      isEmpty,
    );
  });
  test('Kacou 29 annotations do not block and survive Word export', () {
    final french = List.generate(26, (i) => '${i + 1} Texte.').join('\n');
    final text = List.generate(26, (i) {
      final suffix = switch (i + 1) {
        11 => ' [Kc.59v11]',
        15 => ' [Kc.1v13]\n[Kc.23v5]',
        _ => '',
      };
      return '${i + 1} Maandishi$suffix';
    }).join('\n');
    final input = ChapterInput(
      title: 'Kacou 29 : Les voix de discorde',
      subtitle: '19 janvier 2003',
      similarChapters: '',
      language: 'sw',
      sources: [DocumentSource(name: 'Kacou 29', text: text)],
    );
    final parsed = DocxBuilder.validateChapter(input).documents.first;
    final fr = SermonReferenceResult(
      chapterNumber: 29,
      paragraphCount: 26,
      url: Uri.parse('https://www.philippekacou.org/fr-fr/sermons/29'),
      similarChapters: null,
      content: SermonReferenceService.parseReferenceContent(
        html(french, subtitle: '19 janvier 2003'),
      ),
    );
    expect(compareFrenchConsistency(parsed, fr, language: 'sw'), isEmpty);
    final exported = DocxBuilder.extractTextFromDocx(
      DocxBuilder.buildChapter(input),
    );
    for (final annotation in ['[Kc.59v11]', '[Kc.1v13]', '[Kc.23v5]']) {
      expect(exported, contains(annotation));
    }
    expect(
      exported.indexOf('[Kc.1v13]'),
      lessThan(exported.indexOf('[Kc.23v5]')),
    );
  });
  test('verse numbers absent from French still block', () {
    final fr = reference(html('1 Texte.\n2 Suite.', subtitle: ''));
    expect(
      compareFrenchConsistency(document('1 Text.\n2 Next.\n3 Extra.'), fr),
      contains(
        '[FR-VERSE] verset 3 : ce numéro est absent de la référence française.',
      ),
    );
  });
  test('retains inter-verse date subtitles and checks their positions', () {
    final source =
        '${html('1 Texte.\n2 Suite.')}<div><strong>1</strong> Texte.</div><div>(24 mai 2009)</div><div><strong>2</strong> Suite.</div>';
    final fr = reference(source);
    expect(fr.content!.subtitleDates[1], ['2009-05-24']);
    final local = document(
      '1 Text.\n(24 May 2009)\n2 Next.',
      subtitle: 'December 18, 2022',
    );
    expect(local.paragraphs.length, 2);
    expect(compareFrenchConsistency(local, fr), isEmpty);
    expect(
      compareFrenchConsistency(
        document(
          '1 Text.\n2 Next.\n(24 May 2009)',
          subtitle: 'December 18, 2022',
        ),
        fr,
      ).join('\n'),
      contains('après le verset 1'),
    );
  });
  test('multiple date headings at one position retain their order', () {
    final fr = reference(
      '${html('1 Texte.\n2 Suite.', subtitle: '')}<div><strong>1</strong> Texte.</div><div>24 mai 2009</div><div>25 mai 2009</div><div><strong>2</strong> Suite.</div>',
    );
    expect(fr.content!.subtitleDates[1], ['2009-05-24', '2009-05-25']);
    expect(
      compareFrenchConsistency(
        document('1 Text.\n24 May 2009\n25 May 2009\n2 Next.'),
        fr,
      ),
      isEmpty,
    );
  });

  test('incomplete French text never reports a successful verification', () {
    final fr = reference(html('1 Texte.', subtitle: ''));
    expect(
      compareFrenchConsistency(document('1 Text.\n2 Next.'), fr).single,
      contains('[FR-INCOMPLETE]'),
    );
  });
  test('parses a Jina Markdown chapter with dates and references', () {
    final fr = reference(
      'Title: Sermon\n# Kacou 154 : Titre\nRévélation donnée le 18 décembre 2022\n**1**Texte [Kc.1v2]\n(24 mai 2009)\n**2**Suite.',
    );
    expect(fr.content!.isComplete(2), isTrue);
    expect(fr.content!.subtitleDates, {
      0: ['2022-12-18'],
      1: ['2009-05-24'],
    });
    expect(
      compareFrenchConsistency(
        document(
          '1 Text [Kc.1v2]\n(24 May 2009)\n2 Next.',
          subtitle: 'December 18, 2022',
        ),
        fr,
      ),
      isEmpty,
    );
  });
  test(
    'rejects sermon title in explicit subtitle and removes pasted title duplicates',
    () {
      for (final subtitle in [
        'Kacou 154 (Kc.154): The current stage of my mission',
        'The current stage of my mission',
        'The current stage of my mission\nGiven December 18, 2022',
      ]) {
        final validation = DocxBuilder.validateChapter(
          ChapterInput(
            title: 'Kacou 154 : The current stage of my mission',
            subtitle: subtitle,
            similarChapters: '',
            sources: const [DocumentSource(name: 'Paste', text: '1 Text')],
            language: 'en',
          ),
        );
        expect(validation.errors.join('\n'), contains('[TITLE-IN-SUBTITLE]'));
      }
      final parsed = document(
        'Kacou 154 (Kc.154): The current stage of my mission\nThe current stage of my mission\nGiven December 18, 2022\n1 Text\n2 Next.',
      );
      expect(
        parsed.blocks.where((b) => b.subtitle != null).map((b) => b.subtitle),
        ['Given December 18, 2022'],
      );
    },
  );
  test('numeric date headings are retained without creating a verse', () {
    final local = document('1 Text.\n24/05/2009\n2 Next.');
    expect(local.blocks.any((b) => b.subtitle == '24/05/2009'), isTrue);
    expect(local.paragraphs.map((p) => p.number), [1, 2]);
    expect(SermonRules.isDateHeading('24.05.2009'), isTrue);
  });
  test(
    'a web-reader result that omits the subtitle cannot pass verification',
    () {
      final fr = reference(
        'Title: Kacou 154 : Titre\nMarkdown Content:\n**1**Texte\n**2**Suite',
      );
      expect(
        compareFrenchConsistency(document('1 Text.\n2 Next.'), fr).single,
        contains('[FR-INCOMPLETE]'),
      );
    },
  );

  test('live source snapshots produce a complete reference when supplied', () {
    for (final suffix in [
      '1.html',
      '119.html',
      '154.html',
      '154-jina-html.txt',
    ]) {
      final path = File('/private/tmp/sermon$suffix');
      if (!path.existsSync()) continue;
      final source = path.readAsStringSync();
      final count = SermonReferenceService.parseParagraphCount(source)!;
      final parsed = SermonReferenceService.parseReferenceContent(source);
      expect(parsed.isComplete(count), isTrue, reason: 'source $suffix');
    }
  });
}
