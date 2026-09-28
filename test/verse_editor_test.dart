import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dec_docx/docx_builder.dart';
import 'package:dec_docx/main.dart';
import 'package:dec_docx/verse_editor.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    TextEditingController controller,
  ) async {
    final language = TextEditingController(text: 'francais');
    addTearDown(language.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VerseEditor(
              controller: controller,
              languageController: language,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pasting into the app shows verse actions on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 710);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DocxGeneratorApp(skipStorageSetup: true));
    final input = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == AppStrings(AppLanguage.fr).inputHint,
    );
    await tester.enterText(input, '1 Premier\n1 Doublon\n2 Deuxième\n');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byType(VerseEditor));
    await tester.pump();
    expect(find.text('Numéro répété'), findsNWidgets(2));
    expect(find.text('Modifier'), findsWidgets);
    expect(find.text('Supprimer'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty or multiple verses cannot replace one occurrence', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1 Premier\n');
    addTearDown(controller.dispose);
    await mount(tester, controller);
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(controller.text, '1 Premier\n');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1 Premier\n2 Autre');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(controller.text, '1 Premier\n');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
  });

  test(
    'ranges preserve titles, line endings and distinct duplicate occurrences',
    () {
      const source =
          'Titre\r\n1 Premier\r\n2 Deuxième\r\n2 Doublon\r\nPARTIE II\r\n3 Troisième\r\nChapitres similaires : 4\r\n';
      final verses = locateSourceVerses(source);
      expect(verses.map((v) => v.number), [1, 2, 2, 3]);
      final selected = verses[2];
      final corrected = source.replaceRange(selected.start, selected.end, '');
      expect(
        corrected,
        'Titre\r\n1 Premier\r\n2 Deuxième\r\nPARTIE II\r\n3 Troisième\r\nChapitres similaires : 4\r\n',
      );
      final validation = DocxBuilder.validateChapter(
        ChapterInput(
          title: 'Kacou 1 : Texte',
          subtitle: '',
          similarChapters: '',
          sources: [DocumentSource(name: 'Texte saisi', text: corrected)],
        ),
      );
      expect(validation.errors, isEmpty);
    },
  );

  test('standalone numbers, multiline text and Chinese pinyin stay together', () {
    const source = '1\nPremier\nsuite du texte\n2 Deuxième\n';
    expect(
      locateSourceVerses(source).first.textIn(source),
      '1\nPremier\nsuite du texte',
    );
    const chinese =
        '1 中文\nPinyin 1: zhōng wén\n27 rì continuation\n第二部分\n2 中文二\nPinyin 2: èr\n';
    final verses = locateSourceVerses(chinese, language: 'chinois');
    expect(verses.map((v) => v.number), [1, 2]);
    expect(
      verses.first.textIn(chinese),
      '1 中文\nPinyin 1: zhōng wén\n27 rì continuation',
    );
    expect(verses.last.textIn(chinese), '2 中文二\nPinyin 2: èr');
  });

  testWidgets(
    'deletes one duplicate, updates checks, and restores exact text',
    (tester) async {
      const original = '1 Premier\n1 Doublon\n2 Deuxième\n';
      final controller = TextEditingController(text: original);
      addTearDown(controller.dispose);
      await mount(tester, controller);
      expect(find.text('Numéro répété'), findsNWidgets(2));
      await tester.tap(find.text('Supprimer').at(1));
      await tester.pumpAndSettle();
      expect(controller.text, '1 Premier\n2 Deuxième\n');
      expect(find.text('Numéro répété'), findsNothing);
      expect(find.textContaining('Contrôles du texte'), findsNothing);
      await tester.tap(find.text('Annuler la suppression'));
      await tester.pumpAndSettle();
      expect(controller.text, original);
    },
  );

  testWidgets(
    'edit and cancel preserve neighbors, save reaches generation input',
    (tester) async {
      final controller = TextEditingController(
        text: '1 Premier\r\n2 Ancien\r\nPARTIE II\r\n3 Troisième\r\n',
      );
      addTearDown(controller.dispose);
      await mount(tester, controller);
      await tester.tap(find.text('Modifier').at(1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2 Nouveau');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(controller.text, contains('2 Ancien'));
      await tester.tap(find.text('Modifier').at(1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2 Nouveau');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(
        controller.text,
        '1 Premier\r\n2 Nouveau\r\nPARTIE II\r\n3 Troisième\r\n',
      );
      final input = ChapterInput(
        title: 'Kacou 1 : Texte',
        subtitle: '',
        similarChapters: '',
        sources: [DocumentSource(name: 'Texte saisi', text: controller.text)],
      );
      expect(
        DocxBuilder.validateChapter(input).documents.first.paragraphs[1].text,
        'Nouveau',
      );
      expect(DocxBuilder.buildChapter(input), isNotEmpty);
    },
  );

  testWidgets('undo never overwrites subsequent manual changes', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1 Premier\n2 Deuxième\n');
    addTearDown(controller.dispose);
    await mount(tester, controller);
    await tester.tap(find.text('Supprimer').first);
    await tester.pumpAndSettle();
    controller.text = '1 Nouveau collage\n';
    await tester.pumpAndSettle();
    expect(find.text('Annuler la suppression'), findsNothing);
    expect(controller.text, '1 Nouveau collage\n');
  });

  testWidgets('one-line groups cannot be accidentally deleted', (tester) async {
    final controller = TextEditingController(text: '1 Premier 2 Deuxième\n');
    addTearDown(controller.dispose);
    await mount(tester, controller);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Supprimer'),
    );
    expect(button.onPressed, isNull);
  });
}
