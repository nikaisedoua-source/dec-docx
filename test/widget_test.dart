import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dec_docx/docx_builder.dart';
import 'package:dec_docx/main.dart';
import 'package:dec_docx/iphone_install_guide.dart';
import 'package:dec_docx/sermon_reference.dart';
import 'package:dec_docx/app_release_tools.dart';

void main() {
  testWidgets('compact install button opens the matching platform download', (tester) async {
    for (final (platform, label, asset) in [
      (TargetPlatform.android, 'Android', 'DEC-DOCX-Android-preview.apk'),
      (TargetPlatform.macOS, 'Mac', 'DEC-DOCX-macOS-preview.zip'),
      (TargetPlatform.windows, 'Windows', 'DEC-DOCX-Windows-preview.zip'),
    ]) {
      Uri? opened;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: InstallAppButton(
        version: '1.9.14', platform: platform,
        openUrl: (uri) async { opened = uri; return true; },
      ))));
      await tester.tap(find.byTooltip('Installer sur $label'));
      await tester.pump();
      expect(opened?.path, '/nikaisedoua-source/dec-docx/releases/download/v1.9.14-preview/$asset');
    }
  });

  testWidgets('iPhone install button opens the installation guide', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: InstallAppButton(
      version: '1.9.14', platform: TargetPlatform.iOS,
    ))));
    await tester.tap(find.byTooltip('Installer sur iPhone'));
    await tester.pumpAndSettle();
    expect(find.text('Installer DEC DOCX sur iPhone'), findsOneWidget);
  });

  testWidgets('release notice respects reduced motion and disappears after eight seconds', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: ReleaseNotice(version: '1.9.14', onDismiss: () => dismissed = true)),
    )));
    await tester.pump();
    expect(find.text('Nouveautés disponibles · v1.9.14'), findsOneWidget);
    expect(tester.widget<Opacity>(find.byType(Opacity).last).opacity, 1);
    await tester.pump(const Duration(seconds: 8));
    expect(dismissed, isTrue);
  });

  testWidgets('iPhone guide scrolls on a small screen and can be closed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const IphoneInstallGuide(),
              ),
              child: const Text('Guide iPhone'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Guide iPhone'));
    await tester.pumpAndSettle();
    expect(find.text('Installer DEC DOCX sur iPhone'), findsOneWidget);
    expect(find.text('1. Ouvrez le lien dans Safari'), findsOneWidget);
    await tester.ensureVisible(find.text('4. Confirmez avec Ajouter'));
    await tester.pumpAndSettle();
    expect(
      find.text('4. Confirmez avec Ajouter').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Compris'));
    await tester.pumpAndSettle();
    expect(find.byType(IphoneInstallGuide), findsNothing);
  });

  testWidgets('shows the generator screen', (tester) async {
    await tester.pumpWidget(const DocxGeneratorApp(skipStorageSetup: true));

    expect(find.text('DEC DOCX'), findsWidgets);
    expect(find.text('Version 1.9.14'), findsOneWidget);
    expect(find.text('Titre du chapitre'), findsOneWidget);
    expect(
      find.byTooltip(AppStrings(AppLanguage.fr).chapterTitleLowercaseHelp),
      findsOneWidget,
    );
    expect(find.text('Langue du document'), findsOneWidget);
    expect(find.text('Langue du site'), findsNothing);
    expect(find.text('Sous-titre optionnel'), findsNothing);
    expect(find.text('Chapitres similaires finaux'), findsNothing);
    expect(find.text('Corriger et générer'), findsOneWidget);
    expect(find.text('Partager & Microsoft Word'), findsOneWidget);
    expect(find.text('Complément Microsoft Word'), findsOneWidget);
    expect(find.text('Extension pour navigateurs'), findsOneWidget);
  });

  testWidgets('retains optional chapter details after collapsing the section', (
    tester,
  ) async {
    await tester.pumpWidget(const DocxGeneratorApp(skipStorageSetup: true));
    final options = find.text('Sous-titre et chapitres similaires');
    await tester.ensureVisible(options);
    await tester.pump();
    await tester.tap(options);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.widgetWithText(TextField, 'Sous-titre optionnel'),
      'Sous-titre conservé',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Chapitres similaires finaux'),
      'Kacou 2, 3',
    );
    await tester.ensureVisible(options);
    await tester.pump();
    await tester.tap(options);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sous-titre optionnel'), findsNothing);
    await tester.ensureVisible(options);
    await tester.pump();
    await tester.tap(options);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sous-titre conservé'), findsOneWidget);
    expect(find.text('Kacou 2, 3'), findsOneWidget);
  });

  testWidgets(
    'uses a suggested or custom document language in the output name',
    (tester) async {
      await tester.pumpWidget(const DocxGeneratorApp(skipStorageSetup: true));
      await tester.enterText(
        find.widgetWithText(TextField, 'Titre du chapitre'),
        'KACOU 181 : Har Meguiddo',
      );
      await tester.tap(find.byTooltip('Choisir une langue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('francais'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final nameField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Nom du fichier'),
      );
      expect(nameField.controller!.text, 'KACOU 181 francais.docx');
      await tester.enterText(
        find.widgetWithText(TextField, 'Langue du document'),
        'swahili RDC',
      );
      expect(nameField.controller!.text, 'KACOU 181 swahili rdc.docx');
      await tester.tap(find.byTooltip('Vider'));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Langue du document'),
            )
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  for (final size in [const Size(320, 710), const Size(1280, 900)]) {
    testWidgets('keeps generation accessible at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const DocxGeneratorApp(skipStorageSetup: true));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Corriger et générer').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final mode in [
        'Édition · Papier éditorial',
        'Nocturne · Studio sombre',
      ]) {
        await tester.tap(find.byTooltip('Changer de style'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text(mode));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        expect(find.text('Corriger et générer').hitTestable(), findsOneWidget);
      }
    });
  }

  testWidgets('preserves normal capitals in the chapter title', (tester) async {
    await tester.pumpWidget(const DocxGeneratorApp(skipStorageSetup: true));

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

  test('accepts Urdu section headings between numbered paragraphs', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'KACOU 173 : معجزات اور شفا یابی کی شہادتیں',
        subtitle: '',
        similarChapters: '',
        language: 'Urdu',
        sources: [
          DocumentSource(
            name: 'KACOU 173 ourdou',
            text: '''
حصہ 1: تعارف
1 پہلا پیراگراف
حصہ 2: موزمبیق میں معجزات اور شفا یابیاں
2 دوسرا پیراگراف
قسم 3: شہادتیں
3 تیسرا پیراگراف
''',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(validation.documents.single.paragraphs, hasLength(3));
    expect(
      validation.documents.single.blocks
          .where((block) => block.sectionTitle != null)
          .map((block) => block.sectionTitle),
      containsAll(<String>[
        'حصہ 1: تعارف',
        'حصہ 2: موزمبیق میں معجزات اور شفا یابیاں',
        'قسم 3: شہادتیں',
      ]),
    );
  });

  test('renders chapter section headings in bold', () {
    final bytes = DocxBuilder.build(const [
      DocumentSource(
        name: 'Kacou 169',
        text: '''
KACOU : Titre du document
PARTIE 1 : INTRODUCTION
1 Premier paragraphe
AVEUGLE D’UN ŒIL GUÉRIE
2 Deuxieme paragraphe
''',
      ),
    ]);

    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );

    expect(
      documentXml,
      contains(
        '<w:b/><w:bCs/><w:sz w:val="24"/></w:rPr><w:t>PARTIE 1 : INTRODUCTION',
      ),
    );
    expect(
      documentXml,
      contains(
        '<w:b/><w:bCs/><w:sz w:val="24"/></w:rPr><w:t>AVEUGLE D’UN ŒIL GUÉRIE',
      ),
    );
  });

  test('keeps consecutive Chinese lines inside one numbered verse', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'KACOU 169 : 中文章节',
        subtitle: '',
        similarChapters: '',
        language: 'chinois',
        sources: [
          DocumentSource(
            name: 'Kacou 169 chinois',
            text: '''
KACOU 169 : 中文章节
1 第一行经文
第二行经文仍属于同一节
2 第二节经文
''',
          ),
        ],
      ),
    );

    expect(validation.hasErrors, isFalse);
    expect(validation.documents.first.paragraphs, hasLength(2));
    expect(
      validation.documents.first.paragraphs.first.text,
      '第一行经文\n第二行经文仍属于同一节',
    );
  });

  group('Chinese and pinyin pairs', () {
    ChapterInput chinese(String text) => ChapterInput(
      title: 'Kacou 182 : 中文 (Zhōngwén)',
      subtitle: '',
      similarChapters: '',
      language: 'chinois',
      sources: [DocumentSource(name: 'Chinese source', text: text)],
    );

    test('accepts both label styles and dates wrapped across lines', () {
      final input = chinese(
        '1 中文\n27 日仍是同一节。\nPinyin : 1 Zhōngwén\n27 rì.\n2 第二节\nPinyin 2 : Dì èr jié.',
      );
      final result = DocxBuilder.validateChapter(input);
      expect(result.errors, isEmpty);
      expect(result.documents.single.paragraphs, hasLength(2));
      final archive = ZipDecoder().decodeBytes(DocxBuilder.buildChapter(input));
      final xml = utf8.decode(
        archive.findFile('word/document.xml')!.content as List<int>,
      );
      expect('<w:keepNext/>'.allMatches(xml), hasLength(2));
      expect(xml, contains('Pinyin : 1'));
      expect(xml, contains('Pinyin 2 :'));
      expect(xml, contains('Zhōngwén'));
    });

    test('indexes a mismatched pinyin at its original source line', () {
      final result = DocxBuilder.validateChapter(
        chinese('1 中文\n续文\n\nPinyin : 2 Zhōngwén'),
      );
      expect(result.errors, contains(contains('ligne 4 : [ZH-PINYIN-NUMBER]')));
      expect(
        () => DocxBuilder.buildChapter(chinese('1 中文\nPinyin : 2 Zhōngwén')),
        throwsFormatException,
      );
    });

    test('reports missing, duplicated and orphan transcriptions', () {
      expect(
        DocxBuilder.validateChapter(
          chinese('1 中文\n2 中文\nPinyin 2 : Èr'),
        ).errors,
        contains(contains('[ZH-PINYIN-MISSING]')),
      );
      expect(
        DocxBuilder.validateChapter(
          chinese('1 中文\nPinyin 1 : Yī\nPinyin : 1 Yī'),
        ).errors,
        contains(contains('[ZH-PINYIN-DUPLICATE]')),
      );
      expect(
        DocxBuilder.validateChapter(chinese('Pinyin : 1 Yī\n1 中文')).errors,
        contains(contains('[ZH-PINYIN-ORPHAN]')),
      );
    });

    test('recovers a Chinese verse number replaced by a PDF bullet', () {
      final result = DocxBuilder.validateChapter(
        chinese(
          '201 第一段\nPinyin 201 : Dì yī duàn\n'
          '• 凡接受过按手的人都证实发生了变化。\n'
          'Pinyin 202 : Fán jiēshòu guò ànshǒu de rén.\n'
          '203 第三段\nPinyin 203 : Dì sān duàn',
        ),
      );
      expect(result.errors, isEmpty);
      expect(result.documents.single.paragraphs.map((p) => p.number), [
        201,
        202,
        203,
      ]);
      expect(result.documents.single.paragraphs[1].text, startsWith('凡接受过'));
    });
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

  test('keeps Czech biblical range numbers inside their verse', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'Kacou 99: Lodě z Tarsisu',
        subtitle: '',
        similarChapters: '',
        language: 'Tchèque',
        sources: [
          DocumentSource(
            name: 'Texte saisi',
            text: '''
9 Předně Matouš 25:6 je služba jednoho muže a tato služba se řadí za Zjevení 10:7. Zjevení 10:8 je Daniel 12:8 až 10. Vidíte? Otevřená svitková knížka z Daniela 12:4 je ta ze Zjevení 10:1 až 2.
10 Další skutečný verš.
''',
          ),
        ],
      ),
    );
    expect(validation.errors, isEmpty);
    expect(
      validation.documents.single.paragraphs.map((paragraph) => paragraph.number),
      [9, 10],
    );
    expect(
      validation.documents.single.paragraphs.first.text,
      contains('Daniel 12:8 až 10. Vidíte?'),
    );
  });

  test('keeps source-style spaces around Bible colons inside a verse', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'Kacou 66 : Odmítání pokroku',
        subtitle: '',
        similarChapters: '',
        language: 'Tchèque',
        sources: [
          DocumentSource(
            name: 'Texte saisi',
            text: '9 Zjevení 10\u00a0:8 je Daniel 12\u00a0:8 až 10. Vidíte?\n'
                '10 Nyní si přečtěme další verš.',
          ),
        ],
      ),
    );
    expect(validation.errors, isEmpty);
    expect(
      validation.documents.single.paragraphs.map((paragraph) => paragraph.number),
      [9, 10],
    );
    expect(
      validation.documents.single.paragraphs.first.text,
      contains('Daniel 12\u00a0:8 až 10. Vidíte?'),
    );
  });

  test('does not read a spaced Bible chapter or dotted date as a new verse', () {
    for (final (first, second, content) in [
      (9, 10, 'Zjevení 10\u00a0:8 je zmíněno.'),
      (21, 22, 'Tato událost byla 22. Listopadu 2007.'),
    ]) {
      final validation = DocxBuilder.validateChapter(
        ChapterInput(
          title: 'Kacou 66 : Odmítání pokroku',
          subtitle: '',
          similarChapters: '',
          language: 'Tchèque',
          sources: [
            DocumentSource(
              name: 'Texte saisi',
              text: '$first $content\n$second Skutečný další verš.',
            ),
          ],
        ),
      );
      expect(validation.errors, isEmpty, reason: content);
      expect(
        validation.documents.single.paragraphs
            .map((paragraph) => paragraph.number),
        [first, second],
        reason: content,
      );
    }
  });

  test('keeps biblical range numbers inside verses in other languages', () {
    for (final (language, range) in [
      ('français', 'Jean 12:8 à 10. Regardez?'),
      ('anglais', 'John 12:8 to 10. See?'),
      ('espagnol', 'Juan 12:8 hasta el 10. Miren?'),
      ('portugais', 'João 12:8 até o 10. Vejam?'),
      ('allemand', 'Johannes 12:8 bis 10. Seht?'),
    ]) {
      final validation = DocxBuilder.validateChapter(
        ChapterInput(
          title: 'Kacou 99 : Exemple',
          subtitle: '',
          similarChapters: '',
          language: language,
          sources: [
            DocumentSource(
              name: 'Texte saisi',
              text: '9 Texte. $range\n10 Verset suivant.',
            ),
          ],
        ),
      );
      expect(validation.errors, isEmpty, reason: language);
      expect(
        validation.documents.single.paragraphs.map((paragraph) => paragraph.number),
        [9, 10],
        reason: language,
      );
      expect(validation.documents.single.paragraphs.first.text, contains(range));
    }
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

  test('extracts translated trailing chapter labels without creating verse 71', () {
    for (final label in [
      'Podobná kapitola : Kc. 109',
      'Podobné kapitoly\u00a0: Kc. 109, Kc. 101',
      'Chapitres similaires : Kc. 109',
      'Similar chapters: Kc. 109',
      'Ähnliche Kapitel: Kc. 109',
      'Benzer bölümler: Kc. 109',
      'Похожие главы: Kc. 109',
      '相似章节：Kc. 109',
    ]) {
      final validation = DocxBuilder.validateChapter(
        ChapterInput(
          title: 'Kacou 66 : Exemple',
          subtitle: '',
          similarChapters: '',
          language: 'Tchèque',
          sources: [
            DocumentSource(
              name: 'Kacou 66',
              text: '${List.generate(70, (i) => '${i + 1} Texte.').join('\n')}\n$label',
            ),
          ],
        ),
      );
      expect(validation.errors, isEmpty, reason: label);
      expect(validation.documents.single.paragraphs, hasLength(70));
      expect(validation.documents.single.similarChapters, label);
    }
  });

  test('does not hide trailing unnumbered prose containing a Kc reference', () {
    final validation = DocxBuilder.validateChapter(
      const ChapterInput(
        title: 'Kacou 66 : Exemple',
        subtitle: '',
        similarChapters: '',
        sources: [DocumentSource(
          name: 'Texte',
          text: '1 Texte.\nNote : Kc. 109 explique ce passage.',
        )],
      ),
    );
    expect(validation.errors, isNotEmpty);
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
                '1 Premier paragraphe [Kc.104v28]\n[Kc.2v11][Kc.31v18]\n2 Deuxieme paragraphe\n[Kc.6v17][Kc.15v14-16]\n3 Troisieme paragraphe',
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
    expect(extracted, contains('[Kc.6v17][Kc.15v14-16]'));

    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );
    expect(documentXml, contains('<w:color w:val="008000"/>'));
    expect(documentXml, contains('[Kc.15v14-16]'));
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
