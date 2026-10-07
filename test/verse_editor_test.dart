import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dec_docx/docx_builder.dart';
import 'package:dec_docx/main.dart';
import 'package:dec_docx/verse_editor.dart';
import 'package:dec_docx/drafts/draft_repository.dart';

class _MemoryDraftRepository implements DraftRepository {
  _MemoryDraftRepository(Map<String, dynamic> data)
    : revisions = [
        {'id': 'initial', 'savedAt': '2026-10-07T00:00:00Z', 'data': data},
      ];
  final List<Map<String, dynamic>> revisions;
  @override
  Future<List<Map<String, dynamic>>> history() async =>
      revisions.reversed.toList();
  @override
  Future<Map<String, dynamic>> read(String id) async =>
      revisions.firstWhere((revision) => revision['id'] == id);
  @override
  Future<void> save(Map<String, dynamic> revision) async =>
      revisions.add(revision);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => binding.platformDispatcher.localeTestValue = const Locale('fr'));
  tearDown(binding.platformDispatcher.clearLocaleTestValue);

  testWidgets(
    'editing an imported verse reaches the saved draft and generation source',
    (tester) async {
      final repository = _MemoryDraftRepository({
        'title': 'Kacou 1 : Exemple',
        'language': 'francais',
        'text': '1 Texte collé',
        'sources': [
          {'name': 'premier.docx', 'text': '2 Premier fichier\n3 À modifier'},
          {'name': 'second.txt', 'text': '4 Second fichier'},
        ],
      });
      await tester.pumpWidget(
        MaterialApp(home: GeneratorPage(draftRepository: repository)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final importedEditor = find.byWidgetPredicate(
        (widget) =>
            widget is VerseEditor && widget.sourceName == 'premier.docx',
      );
      expect(importedEditor, findsOneWidget);
      final edit = find
          .descendant(of: importedEditor, matching: find.byTooltip('Modifier'))
          .last;
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pump(const Duration(milliseconds: 400));
      final dialog = find.byType(AlertDialog);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        '3 Verset corrigé',
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Enregistrer')),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final saved = repository.revisions.last['data'] as Map<String, dynamic>;
      expect(saved['text'], '1 Texte collé');
      expect((saved['sources'] as List).last['text'], '4 Second fichier');
      expect(
        (saved['sources'] as List).first['text'],
        '2 Premier fichier\n3 Verset corrigé',
      );
      final source = DocumentSource(
        name: (saved['sources'] as List).first['name'] as String,
        text: (saved['sources'] as List).first['text'] as String,
      );
      final validation = DocxBuilder.validateChapter(
        ChapterInput(
          title: saved['title'] as String,
          subtitle: '',
          similarChapters: '',
          sources: [
            DocumentSource(name: 'Texte saisi', text: saved['text'] as String),
            source,
            DocumentSource(
              name: 'second.txt',
              text: (saved['sources'] as List).last['text'] as String,
            ),
          ],
        ),
      );
      expect(validation.errors, isEmpty);
      expect(
        validation.documents.single.blocks
            .where((block) => block.paragraph != null)
            .map((block) => block.paragraph!.text),
        contains('Verset corrigé'),
      );
      expect(
        repository.revisions.first['data']['sources'].first['text'],
        '2 Premier fichier\n3 À modifier',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('date headings stay outside editable verse ranges', () {
    for (final date in ['24 mai 2009', '24/05/2009', '(24 mai 2009)']) {
      final text = '1 Premier\n$date\n2 Deuxième\n';
      final verses = locateSourceVerses(text, language: 'français');
      expect(verses.map((verse) => verse.number), [1, 2]);
      expect(verses.first.textIn(text), '1 Premier');
      expect(verses.last.textIn(text), '2 Deuxième');
    }
  });

  Future<void> mount(
    WidgetTester tester,
    TextEditingController controller, {
    List<String> issues = const [],
    String? sourceName,
    String locale = 'fr',
  }) async {
    final language = TextEditingController(text: 'francais');
    addTearDown(language.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VerseEditor(
              controller: controller,
              languageController: language,
              issues: issues,
              sourceName: sourceName,
              locale: locale,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'only erroneous cards are red and verse text is never truncated',
    (tester) async {
      final controller = TextEditingController(
        text: '1 Premier\n2 Deuxième\n2 Doublon\n3 Troisième\n',
      );
      addTearDown(controller.dispose);
      await mount(tester, controller);
      final verses = locateSourceVerses(controller.text);
      for (var i = 0; i < verses.length; i++) {
        final card = tester.widget<Container>(
          find.byKey(ValueKey('verse-card-${verses[i].start}')),
        );
        final border = (card.decoration! as BoxDecoration).border! as Border;
        expect(
          border.top.color,
          i == 2 ? const Color(0xFFB91C1C) : const Color(0xFF8B4513),
        );
        final text = tester.widget<Text>(
          find.byKey(ValueKey('verse-text-${verses[i].start}')),
        );
        expect(text.maxLines, isNull);
        expect(text.overflow, isNull);
      }
      expect(
        tester.getTopLeft(find.byTooltip('Modifier').first).dx,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('verse-text-0'))).dx,
        ),
      );
    },
  );

  testWidgets('French numbering errors highlight only the matching verse', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1 Premier\n2 Deuxième\n');
    addTearDown(controller.dispose);
    await mount(
      tester,
      controller,
      issues: [
        '[FR-VERSE] verset 2 : ce numéro est absent de la référence française.',
      ],
    );
    final verses = locateSourceVerses(controller.text);
    for (final verse in verses) {
      final card = tester.widget<Container>(
        find.byKey(ValueKey('verse-card-${verse.start}')),
      );
      expect(
        ((card.decoration! as BoxDecoration).border! as Border).top.color,
        verse.number == 2 ? const Color(0xFFB91C1C) : const Color(0xFF8B4513),
      );
    }
    expect(find.textContaining('ce numéro est absent'), findsOneWidget);
  });

  testWidgets(
    'imported source issues are attached to the imported file editor',
    (tester) async {
      final controller = TextEditingController(text: '1 Premier\n2 Deuxième\n');
      addTearDown(controller.dispose);
      await mount(
        tester,
        controller,
        sourceName: 'chapitre.docx',
        issues: ['chapitre.docx, ligne 2 : texte différent de la référence.'],
      );
      final cards = find.byType(Container).evaluate().where((element) {
        final widget = element.widget;
        if (widget is! Container || widget.decoration is! BoxDecoration) {
          return false;
        }
        final border = (widget.decoration! as BoxDecoration).border;
        return border is Border && border.top.color == const Color(0xFFB91C1C);
      });
      expect(cards, isNotEmpty);
      expect(find.textContaining('texte différent'), findsOneWidget);
    },
  );

  testWidgets('a numbering gap highlights its own verse', (tester) async {
    final controller = TextEditingController(
      text: '1 Premier\n3 Numéro incorrect\n',
    );
    addTearDown(controller.dispose);
    await mount(tester, controller);
    final verses = locateSourceVerses(controller.text);
    final card = tester.widget<Container>(
      find.byKey(ValueKey('verse-card-${verses.last.start}')),
    );
    expect(
      ((card.decoration! as BoxDecoration).border! as Border).top.color,
      const Color(0xFFB91C1C),
    );
    expect(find.textContaining('Attendu 2 mais trouve 3'), findsOneWidget);
  });

  for (final locale in ['en', 'es', 'pt']) {
    testWidgets('translated issues retain their verse association in $locale', (
      tester,
    ) async {
      final controller = TextEditingController(
        text: '1 Premier\n3 Numéro incorrect\n',
      );
      addTearDown(controller.dispose);
      await mount(
        tester,
        controller,
        locale: locale,
        sourceName: 'verset trouvé.docx',
      );
      final verses = locateSourceVerses(controller.text);
      final card = tester.widget<Container>(
        find.byKey(ValueKey('verse-card-${verses.last.start}')),
      );
      expect(
        ((card.decoration! as BoxDecoration).border! as Border).top.color,
        const Color(0xFFB91C1C),
      );
      expect(find.textContaining('numero manquant'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(
        tester,
        controller,
        locale: locale,
        sourceName: 'verset trouvé.docx',
        issues: [
          '[FR-VERSE] verset 3 : ce numéro est absent de la référence française.',
          'Other.docx, ligne 1 : ce paragraphe n’a pas de numero -> "Texte". Ajoute "1 " au debut de la ligne, ou transforme cette ligne en sous-titre clair comme "PARTIE ...".',
        ],
      );
      final firstCard = tester.widget<Container>(
        find.byKey(ValueKey('verse-card-${verses.first.start}')),
      );
      expect(
        ((firstCard.decoration! as BoxDecoration).border! as Border).top.color,
        const Color(0xFF8B4513),
      );
    });
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
    expect(find.text('Numéro répété'), findsOneWidget);
    expect(find.byTooltip('Modifier'), findsWidgets);
    expect(find.byTooltip('Supprimer'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty or multiple verses cannot replace one occurrence', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1 Premier\n');
    addTearDown(controller.dispose);
    await mount(tester, controller);
    await tester.tap(find.byTooltip('Modifier'));
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
      expect(find.text('Numéro répété'), findsOneWidget);
      await tester.tap(find.byTooltip('Supprimer').at(1));
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
      await tester.tap(find.byTooltip('Modifier').at(1));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2 Nouveau');
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(controller.text, contains('2 Ancien'));
      await tester.tap(find.byTooltip('Modifier').at(1));
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
    await tester.tap(find.byTooltip('Supprimer').first);
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
    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Supprimer'),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
