import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dec_docx/docx_builder.dart';
import 'package:dec_docx/main.dart';
import 'package:dec_docx/sermon_reference.dart';

void main() {
  testWidgets('shows the generator screen', (tester) async {
    await tester.pumpWidget(const DocxGeneratorApp());

    expect(find.text('DEC DOCX'), findsWidgets);
    expect(find.text('Version 1.8.4'), findsOneWidget);
    expect(find.text('Titre du chapitre'), findsOneWidget);
    expect(
      find.text(
        'Écris le titre normalement, pas tout en majuscules. Les débuts de phrase et les noms propres peuvent avoir une majuscule.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sous-titre optionnel'), findsOneWidget);
    expect(find.text('Chapitres similaires finaux'), findsOneWidget);
  });

  testWidgets('preserves normal capitals in the chapter title', (tester) async {
    await tester.pumpWidget(const DocxGeneratorApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Titre du chapitre'),
      'KACOU 1 : Jésus parle à Matthieu',
    );

    final field = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Titre du chapitre'),
    );
    expect(field.controller!.text, 'KACOU 1 : Jésus parle à Matthieu');
  });

  test('rejects a chapter title written entirely in uppercase', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'KACOU 1 : TITRE EN MAJUSCULES',
        subtitle: '',
        similarChapters: '',
        sources: [DocumentSource(name: 'Test', text: '1 Premier paragraphe')],
      ),
    );

    expect(validation.hasErrors, isTrue);
    expect(
      validation.errors,
      contains(
        'Titre du chapitre : ne l’écris pas entièrement en majuscules. Écris-le normalement, par exemple "KACOU 1 : C’est ici la voix de Matthieu 25 :6". Les débuts de phrase et les noms propres peuvent garder leur majuscule.',
      ),
    );
  });

  test('accepts capitals at the beginning and in proper names', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'KACOU 1 : Jésus parle à Matthieu',
        subtitle: '',
        similarChapters: '',
        sources: [DocumentSource(name: 'Test', text: '1 Premier paragraphe')],
      ),
    );

    expect(validation.hasErrors, isFalse);
  });

  test('builds a valid docx archive with separated paragraph numbers', () {
    final bytes = DocxBuilder.build(const [
      DocumentSource(
        name: 'Kacou test',
        text:
            'KACOU : Titre du document\n1 Premier paragraphe\n2 Deuxieme paragraphe',
      ),
    ]);

    final extracted = DocxBuilder.extractTextFromDocx(bytes);

    expect(extracted, contains('KACOU : TITRE DU DOCUMENT'));
    expect(extracted, contains('1 Premier paragraphe'));
    expect(extracted, contains('2 Deuxieme paragraphe'));
  });

  test('keeps a subtitle between title and first paragraph', () {
    final bytes = DocxBuilder.buildChapter(
      const ChapterInput(
        title: 'kacou 1 : titre du document',
        subtitle: 'Sous titre du document',
        similarChapters: '',
        sources: [
          DocumentSource(name: 'Kacou subtitle', text: '1 Premier paragraphe'),
        ],
      ),
    );

    final extracted = DocxBuilder.extractTextFromDocx(bytes);

    expect(extracted, contains('KACOU 1 : TITRE DU DOCUMENT'));
    expect(extracted, contains('Sous titre du document'));
    expect(extracted, contains('1 Premier paragraphe'));
  });

  test('extracts docx line breaks inside a malformed Word paragraph', () {
    final bytes = _minimalDocx('''
<w:p>
  <w:r><w:t>KACOU 112 : Exemple</w:t></w:r>
  <w:r><w:br/></w:r>
  <w:r><w:t>Sous titre</w:t></w:r>
  <w:r><w:br/></w:r>
  <w:r><w:t>1</w:t></w:r>
  <w:r><w:t xml:space="preserve"> Premier paragraphe</w:t></w:r>
  <w:r><w:br/></w:r>
  <w:r><w:t>2</w:t></w:r>
  <w:r><w:t xml:space="preserve"> Deuxieme paragraphe</w:t></w:r>
</w:p>
''');

    final extracted = DocxBuilder.extractTextFromDocx(bytes);

    expect(
      extracted,
      'KACOU 112 : Exemple\nSous titre\n1 Premier paragraphe\n2 Deuxieme paragraphe',
    );
  });

  test('ignores invisible Word spacer paragraphs when importing a docx', () {
    final bytes = _minimalDocx('''
<w:p><w:r><w:t>KACOU 181 : Har Meguiddo</w:t></w:r></w:p>
<w:p><w:r><w:t>\u200B1 Premier paragraphe</w:t></w:r></w:p>
<w:p><w:r><w:t>\u200B</w:t></w:r></w:p>
<w:p><w:r><w:t>2 Deuxieme paragraphe</w:t></w:r></w:p>
''');

    final extracted = DocxBuilder.extractTextFromDocx(bytes);
    final validation = DocxBuilder.validateChapter(
      ChapterInput(
        title: 'KACOU 181 : Har Meguiddo',
        subtitle: '',
        similarChapters: '',
        sources: [DocumentSource(name: 'Kacou 181', text: extracted)],
      ),
    );

    expect(
      extracted,
      'KACOU 181 : Har Meguiddo\n1 Premier paragraphe\n2 Deuxieme paragraphe',
    );
    expect(validation.hasErrors, isFalse);
    expect(validation.documents.first.paragraphs, hasLength(2));
  });

  test(
    'repairs existing standalone paragraph numbers without adding missing ones',
    () {
      final validation = DocxBuilder.validateChapter(
        const ChapterInput(
          title: 'kacou 112 : exemple',
          subtitle: '',
          similarChapters: '',
          sources: [
            DocumentSource(
              name: 'Bad format',
              text: '''
1
Premier paragraphe
3
Troisieme paragraphe
''',
            ),
          ],
        ),
      );

      expect(validation.hasErrors, isTrue);
      expect(validation.documents.first.paragraphs, hasLength(2));
      expect(validation.documents.first.paragraphs.first.number, 1);
      expect(
        validation.documents.first.paragraphs.first.text,
        'Premier paragraphe',
      );
      expect(validation.errors.join('\n'), contains('Attendu 2'));
    },
  );

  test('ignores a pasted KACOU numbered title inside chapter content', () {
    final bytes = DocxBuilder.buildChapter(
      const ChapterInput(
        title: 'kacou 1 : titre du document',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Kacou pasted title',
            text:
                'KACOU 1 : Titre du document\n1 Premier paragraphe\n2 Deuxieme paragraphe',
          ),
        ],
      ),
    );

    final extracted = DocxBuilder.extractTextFromDocx(bytes);

    expect('KACOU 1 :'.allMatches(extracted).length, 1);
    expect(extracted, contains('1 Premier paragraphe'));
    expect(extracted, contains('2 Deuxieme paragraphe'));
  });

  test('extracts Kacou chapter numbers from common title formats', () {
    expect(
      DocxBuilder.extractKacouChapterNumber(
        'KACOU 1 : CEST ICI LA VOIX DE MATTHIEU 25:6',
      ),
      1,
    );
    expect(DocxBuilder.extractKacouChapterNumber('KACOU N 36 : Titre'), 36);
    expect(DocxBuilder.extractKacouChapterNumber('Kc.130'), 130);
  });

  test('adds similar chapters centered after the last paragraph', () {
    final bytes = DocxBuilder.buildChapter(
      const ChapterInput(
        title: 'kacou 1 : titre',
        subtitle: '',
        similarChapters: 'Kc.36, Kc.64',
        sources: [
          DocumentSource(
            name: 'Kacou similar',
            text: '1 Premier paragraphe\n2 Dernier paragraphe',
          ),
        ],
      ),
    );

    final extracted = DocxBuilder.extractTextFromDocx(bytes);

    expect(extracted, contains('2 Dernier paragraphe\nKc.36, Kc.64'));

    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );
    expect(documentXml, contains('<w:color w:val="0000FF"/>'));
    expect(documentXml, contains('<w:jc w:val="center"/>'));
  });

  test('keeps section subtitles between numbered paragraphs', () {
    final bytes = DocxBuilder.build(const [
      DocumentSource(
        name: 'Kacou sections',
        text: '''
KACOU : Titre du document
PARTIE 1 : INTRODUCTION
1 Premier paragraphe
PARTIE 2 : SUITE
2 Deuxieme paragraphe
''',
      ),
    ]);

    final extracted = DocxBuilder.extractTextFromDocx(bytes);

    expect(extracted, contains('PARTIE 1 : INTRODUCTION'));
    expect(extracted, contains('1 Premier paragraphe'));
    expect(extracted, contains('PARTIE 2 : SUITE'));
    expect(extracted, contains('2 Deuxieme paragraphe'));
  });

  test('repairs numbered paragraphs pasted on one line', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'kacou 180 : exemple',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'One line',
            text: '1 Premier paragraphe 2 Deuxieme paragraphe 3 Troisieme',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(validation.documents.first.paragraphs, hasLength(3));
    expect(validation.documents.first.paragraphs[1].number, 2);
    expect(
      validation.documents.first.paragraphs[1].text,
      'Deuxieme paragraphe',
    );
  });

  test('detects paragraph numbers with leading special symbols', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'kacou 181 : exemple',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Bad symbols',
            text: '''
*1 Premier paragraphe
• 2 Deuxieme paragraphe
(3) Troisieme paragraphe
#4 Quatrieme paragraphe
''',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(
      validation.documents.first.paragraphs.map(
        (paragraph) => paragraph.number,
      ),
      [1, 2, 3, 4],
    );
    expect(
      validation.documents.first.paragraphs.first.text,
      'Premier paragraphe',
    );
  });

  test('splits one-line paragraphs with leading special symbols', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'kacou 182 : exemple',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'One line symbols',
            text: '*1 Premier paragraphe • 2 Deuxieme paragraphe #3 Troisieme',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(validation.documents.first.paragraphs, hasLength(3));
    expect(validation.documents.first.paragraphs[1].number, 2);
    expect(
      validation.documents.first.paragraphs[1].text,
      'Deuxieme paragraphe',
    );
  });

  test('does not split dates inside a numbered paragraph', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'kacou 139 : exemple',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Date text',
            text:
                '1 Oraculo miyo, namaxexe, 07 na Novembro ya 2019, mwaha wa idini.\n2 Omwene wa Wirimu.',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(validation.documents.first.paragraphs, hasLength(2));
    expect(validation.documents.first.paragraphs.first.number, 1);
    expect(
      validation.documents.first.paragraphs.first.text,
      contains('07 na Novembro ya 2019'),
    );
  });

  test('does not split a sequential Turkish date inside a paragraph', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'Kacou 86: Piramidin Tepesinde',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Kacou 86 Turqu.',
            text: '''
23 Tüm zamanların seçilmişleri, 24 Nisan 1993'teki gibi Kurtuluş eylemlerinden asla uzak olmadılar.
24 Ve o 24 Nisan 1993'te, Gökteki tüm tapınma durdu.
25 Sonraki paragraf.
''',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(
      validation.documents.single.paragraphs.map(
        (paragraph) => paragraph.number,
      ),
      [23, 24, 25],
    );
  });

  test('does not split Turkish verse references into fake paragraphs', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'Kacou 119: Israil ve Amerika uzerine peygamberlik',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Kc. 119 turcq.',
            text: '''
25 Simdi fark edin ki bunlar iki farkli gruptur. Daniel'in 26 ve 27. ayetlerde gordugu iste budur.
26 Insanlik bir Gece Yarisi Bagirisi olacagini kabul etmelidir.
27 Branhamci bir pastorun vaazini dinliyordum.
28 Bu Bagiris gelecek olan sekizinci bir elci peygamber mi olacaktir?
''',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(
      validation.documents.single.paragraphs.map(
        (paragraph) => paragraph.number,
      ),
      [25, 26, 27, 28],
    );
    expect(
      validation.documents.single.paragraphs.first.text,
      contains("Daniel'in 26 ve 27. ayetlerde"),
    );
  });

  test('accepts a Turkish parenthesized date and similar chapter label', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'Kacou 86: Piramidin Tepesinde',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Kacou 86 Turqu.',
            text: '''
(24 Mayıs 2009 Pazar günü Adjamé'de vaaz edilmiştir)
1 Birinci paragraf
2 İkinci paragraf
Benzer bölüm: Kc. 118
''',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(
      validation.documents.single.paragraphs.map(
        (paragraph) => paragraph.number,
      ),
      [1, 2],
    );
    expect(
      validation.documents.single.similarChapters,
      'Benzer bölüm: Kc. 118',
    );
  });

  test('accepts similar chapters line after the last numbered paragraph', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'kacou 139 : exemple',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Similar chapters',
            text:
                '1 Premier paragraphe\n2 Dernier paragraphe\nIkapitulu solikanana: Kc.140, Kc.131',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(validation.documents.first.paragraphs, hasLength(2));
    expect(validation.documents.first.similarChapters, contains('Kc.140'));
  });

  test('accepts Vietnamese similar chapters after numbered paragraphs', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'kacou 34 : ví dụ',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Vietnamese chapter',
            text:
                '\u200b1 Đoạn thứ nhất\n\u200b2 Đoạn thứ hai\nChương tương tự\u00a0: Kc.45',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(validation.documents.first.paragraphs, hasLength(2));
    expect(validation.documents.first.similarChapters, contains('Kc.45'));
  });

  test('keeps concordances in place and renders them in green', () {
    final bytes = DocxBuilder.buildChapter(
      const ChapterInput(
        title: 'kacou 3 : exemple',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Concordances',
            text:
                '1 Premier paragraphe [Kc.104v28]\n[Kc.2v11][Kc.31v18]\n2 Deuxieme paragraphe',
          ),
        ],
      ),
    );

    final extracted = DocxBuilder.extractTextFromDocx(bytes);

    expect(
      extracted.indexOf('[Kc.104v28]'),
      greaterThan(extracted.indexOf('1 Premier paragraphe')),
    );
    expect(
      extracted.indexOf('[Kc.2v11][Kc.31v18]'),
      lessThan(extracted.indexOf('2 Deuxieme paragraphe')),
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );
    expect(documentXml, contains('<w:color w:val="008000"/>'));
  });

  test('adds explicit spacing after each numbered paragraph', () {
    final bytes = DocxBuilder.buildChapter(
      const ChapterInput(
        title: 'kacou 183 : exemple',
        subtitle: '',
        similarChapters: '',
        sources: [
          DocumentSource(
            name: 'Spacing',
            text: '1 Premier paragraphe\n2 Deuxieme paragraphe',
          ),
        ],
      ),
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );

    expect(
      RegExp(r'<w:spacing w:after="240"/>').allMatches(documentXml),
      hasLength(2),
    );
  });

  test('cleans telegram names before numbered paragraphs', () {
    final bytes = DocxBuilder.build(const [
      DocumentSource(
        name: 'Telegram',
        text: '''
Jean Dupont
15:42
KACOU : Exemple
Jean Dupont
1 Premier texte
Jean Dupont
2 Deuxieme texte
''',
      ),
    ]);

    final extracted = DocxBuilder.extractTextFromDocx(bytes);

    expect(extracted, contains('KACOU : EXEMPLE'));
    expect(extracted, contains('1 Premier texte'));
    expect(extracted, contains('2 Deuxieme texte'));
    expect(extracted, isNot(contains('Jean Dupont')));
  });

  test('reports missing paragraph numbers and skipped numbers', () {
    final validation = DocxBuilder.validate(const [
      DocumentSource(
        name: 'Bad text',
        text: '''
KACOU : Exemple
Sous titre
1 Premier texte
Texte sans numero
3 Troisieme texte
''',
      ),
    ]);

    expect(validation.hasErrors, isTrue);
    expect(validation.errors.join('\n'), contains('n’a pas de numero'));
    expect(validation.errors.join('\n'), contains('Attendu 2'));
  });

  test('parses paragraph count from sermon page html', () {
    const html = '''
<script>{"verses":[{"number":1,"content":"A"},{"number":2,"content":"B"},{"number":41,"content":"C"}]}</script>
''';

    expect(SermonReferenceService.parseParagraphCount(html), 41);
  });

  test('parses paragraph count from rendered sermon html', () {
    const html = '''
<div class="m-0 text-justify font-serif"><strong>1</strong> Premier</div>
<div class="m-0 text-justify font-serif"><strong>2</strong> Deuxieme</div>
<div class="m-0 text-justify font-serif"><strong>24</strong> Dernier</div>
''';

    expect(SermonReferenceService.parseParagraphCount(html), 24);
  });

  test('parses paragraph count from web reader plain text', () {
    const text = '''
Title: Kacou 86

1 Premier paragraphe
2 Deuxième paragraphe
24 Mai 2009
3 Troisième paragraphe
''';

    expect(SermonReferenceService.parseParagraphCount(text), 3);
  });

  test('parses paragraph count from Jina markdown with bold numbers', () {
    const text = '''
Title: Kacou 119

**1**Ce matin, je desire parler du sujet.

**2**La premiere question est la suivante.

**3**Et parlant de la Bible, les Juifs ont rassemble des livres.
''';

    expect(SermonReferenceService.parseParagraphCount(text), 3);
  });

  test('parses Jina paragraphs whose text starts with markdown emphasis', () {
    const text = '''
Title: Kacou 181

**1**Premier paragraphe.

**2**_Deuxieme paragraphe en italique._

**3**Troisieme paragraphe.
''';

    expect(SermonReferenceService.parseParagraphCount(text), 3);
  });

  test('parses Jina paragraphs whose text starts with a markdown link', () {
    const text = '''
Title: Kacou 181

**1**Premier paragraphe.

**2**[](https://example.com)Deuxieme paragraphe avec un lien.

**3**Troisieme paragraphe.
''';

    expect(SermonReferenceService.parseParagraphCount(text), 3);
  });

  test('selects the complete count when one proxy response is truncated', () {
    final truncated = List.generate(
      48,
      (index) => '**${index + 1}**Paragraphe',
    ).join('\n');
    final complete = List.generate(
      66,
      (index) => '**${index + 1}**Paragraphe',
    ).join('\n');

    final counts = [
      truncated,
      complete,
    ].map(SermonReferenceService.parseParagraphCount).whereType<int>();

    expect(counts.reduce(max), 66);
  });

  test('keeps the verified Kacou 119 count when every proxy is truncated', () {
    expect(SermonReferenceService.applyVerifiedParagraphMinimum(119, 48), 66);
    expect(SermonReferenceService.applyVerifiedParagraphMinimum(120, 48), 48);
  });
}

Uint8List _minimalDocx(String bodyXml) {
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        '[Content_Types].xml',
        utf8.encode(_minimalContentTypes).length,
        utf8.encode(_minimalContentTypes),
      ),
    )
    ..addFile(
      ArchiveFile(
        'word/document.xml',
        utf8.encode(_minimalDocumentXml(bodyXml)).length,
        utf8.encode(_minimalDocumentXml(bodyXml)),
      ),
    );

  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _minimalDocumentXml(String bodyXml) =>
    '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $bodyXml
  </w:body>
</w:document>
''';

const _minimalContentTypes = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
''';
