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
  test(
    'compares all Kc references by verse including standalone lines and repetitions',
    () {
      final fr = reference(
        html(
          '1 Texte [Kc.104v28]\n[Kc.2v11][Kc.31v18]\n2 Suite.',
          subtitle: '',
        ),
      );
      expect(
        compareFrenchConsistency(
          document('1 Text [Kc.104v28]\n[Kc.2v11][Kc.31v18]\n2 Next.'),
          fr,
        ),
        isEmpty,
      );
      for (final text in [
        '1 Text [Kc.104v29]\n[Kc.2v11][Kc.31v18]\n2 Next.',
        '1 Text.\n2 Next [Kc.104v28][Kc.2v11][Kc.31v18]',
        '1 Text [Kc.104v28][Kc.104v28][Kc.2v11][Kc.31v18]\n2 Next.',
      ]) {
        expect(
          compareFrenchConsistency(document(text), fr).join('\n'),
          contains('[FR-KC] verset 1'),
        );
      }
    },
  );
  test('detects references added where French contains none', () {
    final fr = reference(html('1 Texte.\n2 Suite.', subtitle: ''));
    expect(
      compareFrenchConsistency(document('1 Text [Kc.1v2]\n2 Next.'), fr).single,
      contains('attendues aucune'),
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
