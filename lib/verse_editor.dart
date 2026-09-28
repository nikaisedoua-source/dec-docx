import 'package:flutter/material.dart';

import 'docx_builder.dart';

/// An occurrence in the original text. Offsets, rather than verse numbers,
/// distinguish repeated verses and preserve everything outside the selection.
class SourceVerse {
  const SourceVerse(this.number, this.start, this.end);
  final int number;
  final int start;
  final int end;

  String textIn(String source) => source.substring(start, end).trimRight();
}

List<SourceVerse> locateSourceVerses(String source, {String language = ''}) {
  final numbered = RegExp(
    r'^[^\p{L}\p{N}\r\n]{0,8}\s*(\d{1,3})[\s.)-]+(.+)$',
    unicode: true,
  );
  final standalone = RegExp(
    r'^[^\p{L}\p{N}\r\n]{0,8}\s*(\d{1,3})[^\p{L}\p{N}\r\n]{0,8}$',
    unicode: true,
  );
  final chinese = RegExp(
    'chinois|chinese|zh',
    caseSensitive: false,
  ).hasMatch(language);
  final verses = <SourceVerse>[];
  int? number;
  var start = 0;
  void finish(int end) {
    if (number != null) verses.add(SourceVerse(number!, start, end));
    number = null;
  }

  for (final line in RegExp(
    r'[^\r\n]+(?:\r\n|\r|\n)?|[\r\n]+',
  ).allMatches(source)) {
    final value = line.group(0)!.trim();
    if (value.isEmpty) continue;
    // A parenthesized date and Chinese date continuations are not verses.
    final date = RegExp(
      r'^\(\s*\d{1,2}\s+\p{L}',
      unicode: true,
    ).hasMatch(value);
    final match = date ? null : numbered.firstMatch(value);
    final isolated = date ? null : standalone.firstMatch(value);
    final dateContinuation =
        chinese &&
        number != null &&
        match != null &&
        RegExp(
          r'^(?:(?:rì|yuè|nián)(?=[\s.,;:!?]|$)|[日⽇月⽉年])',
          caseSensitive: false,
        ).hasMatch(match.group(2)!);
    if ((match != null || isolated != null) && !dateContinuation) {
      finish(line.start);
      number = int.parse((match ?? isolated)!.group(1)!);
      start = line.start;
    } else if (number != null && !dateContinuation) {
      // Ask the existing parser which lines are headings or concordances.
      // This does not normalize or rewrite the original source.
      final probe = DocxBuilder.validateChapter(
        ChapterInput(
          title: 'Kacou 1 : Texte',
          subtitle: '',
          similarChapters: '',
          language: language,
          sources: [
            DocumentSource(name: 'Texte saisi', text: '1 Texte\n$value'),
          ],
        ),
      );
      final document = probe.documents.first;
      if (document.blocks.skip(1).any((block) => block.paragraph == null) ||
          document.similarChapters != null ||
          RegExp(r'^KACOU\b.*:', caseSensitive: false).hasMatch(value)) {
        finish(line.start);
      }
    }
  }
  finish(source.length);
  return verses;
}

class VerseEditor extends StatefulWidget {
  const VerseEditor({
    super.key,
    required this.controller,
    required this.languageController,
    this.locale = 'fr',
    this.enabled = true,
    this.issues = const [],
  });
  final TextEditingController controller;
  final TextEditingController languageController;
  final String locale;
  final bool enabled;
  final List<String> issues;

  @override
  State<VerseEditor> createState() => _VerseEditorState();
}

class _VerseEditorState extends State<VerseEditor> {
  String? _beforeDelete;
  String? _afterDelete;

  String label(String fr, String en, String es, String pt) =>
      switch (widget.locale) {
        'en' => en,
        'es' => es,
        'pt' => pt,
        _ => fr,
      };

  DocumentValidationResult validate(String text) => DocxBuilder.validateChapter(
    ChapterInput(
      title: 'Kacou 1 : Texte',
      subtitle: '',
      similarChapters: '',
      language: widget.languageController.text,
      sources: [DocumentSource(name: 'Texte saisi', text: text)],
    ),
  );

  bool canSelect(SourceVerse verse, String source) {
    // Some pasted formats contain several numbered paragraphs on one line.
    // Keep them editable in the original text rather than deleting a group.
    return validate(verse.textIn(source)).documents.first.paragraphs.length <=
        1;
  }

  Future<void> edit(SourceVerse verse, String source) async {
    final editor = TextEditingController(text: verse.textIn(source));
    String? error;
    final replacement = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text(
            '${label('Modifier le verset', 'Edit verse', 'Editar versículo', 'Editar versículo')} ${verse.number}',
          ),
          content: SizedBox(
            width: 560,
            child: TextField(
              controller: editor,
              autofocus: true,
              minLines: 4,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: label(
                  'Numéro et texte',
                  'Number and text',
                  'Número y texto',
                  'Número e texto',
                ),
                errorText: error,
                errorMaxLines: 3,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(label('Annuler', 'Cancel', 'Cancelar', 'Cancelar')),
            ),
            FilledButton(
              onPressed: () {
                final value = editor.text.trimRight();
                final entries = locateSourceVerses(
                  value,
                  language: widget.languageController.text,
                );
                final parsed = validate(value).documents.first;
                if (entries.length != 1 ||
                    entries.first.start != 0 ||
                    entries.first.end != value.length ||
                    entries.first.number < 1 ||
                    parsed.paragraphs.length != 1 ||
                    parsed.paragraphs.first.text.trim().isEmpty) {
                  refresh(
                    () => error = label(
                      'Conserve un seul verset avec son numéro (1 à 999) et son texte.',
                      'Keep one verse with its number (1–999) and text.',
                      'Conserva un versículo con su número (1–999) y texto.',
                      'Mantenha um versículo com número (1–999) e texto.',
                    ),
                  );
                  return;
                }
                Navigator.pop(context, value);
              },
              child: Text(label('Enregistrer', 'Save', 'Guardar', 'Salvar')),
            ),
          ],
        ),
      ),
    );
    // The closing dialog still uses its controller during the exit animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    editor.dispose();
    if (!mounted || replacement == null || !widget.enabled) return;
    if (widget.controller.text != source) return;
    final original = source.substring(verse.start, verse.end);
    final suffix = original.substring(original.trimRight().length);
    final newline = source.contains('\r\n') ? '\r\n' : '\n';
    final normalized = replacement
        .replaceAll('\r\n', '\n')
        .replaceAll('\n', newline);
    _beforeDelete = null;
    _afterDelete = null;
    widget.controller.value = TextEditingValue(
      text: source.replaceRange(verse.start, verse.end, '$normalized$suffix'),
      selection: TextSelection.collapsed(offset: verse.start),
    );
  }

  Widget _verseCard(
    BuildContext context,
    SourceVerse verse,
    String source,
    List<String> issues,
  ) {
    final selectable = canSelect(verse, source);
    const normal = Color(0xFF8B4513);
    const errorColor = Color(0xFFB91C1C);
    final color = issues.isEmpty ? normal : errorColor;
    final display = verse
        .textIn(source)
        .replaceFirst(
          RegExp(r'^[^\p{L}\p{N}\r\n]{0,8}\s*\d{1,3}[\s.)-]*', unicode: true),
          '${verse.number}. ',
        );
    return Container(
      key: ValueKey('verse-card-${verse.start}'),
      margin: const EdgeInsets.only(bottom: 16),
      constraints: const BoxConstraints(minHeight: 120),
      decoration: BoxDecoration(
        color: issues.isEmpty ? Colors.white : const Color(0xFFFFF7F7),
        border: Border.all(color: color, width: 1.3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display,
                  key: ValueKey('verse-text-${verse.start}'),
                  style: TextStyle(
                    color: issues.isEmpty
                        ? const Color(0xFF171717)
                        : errorColor,
                    fontSize: MediaQuery.sizeOf(context).width < 600 ? 15 : 17,
                    height: 1.65,
                  ),
                ),
                for (final issue in issues)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      issue,
                      style: const TextStyle(color: errorColor, fontSize: 13),
                    ),
                  ),
                if (!selectable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label(
                        'Plusieurs versets sur une ligne : corrige la zone de texte ci-dessus.',
                        'Several verses on one line: edit the text box above.',
                        'Varios versículos en una línea: edita el texto de arriba.',
                        'Vários versículos na mesma linha: edite o texto acima.',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF595959),
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: label('Supprimer', 'Delete', 'Eliminar', 'Excluir'),
                icon: Icon(
                  Icons.delete_outline,
                  color: widget.enabled && selectable ? color : Colors.grey,
                ),
                onPressed: !widget.enabled || !selectable
                    ? null
                    : () {
                        if (widget.controller.text != source) return;
                        _beforeDelete = source;
                        _afterDelete = source.replaceRange(
                          verse.start,
                          verse.end,
                          '',
                        );
                        widget.controller.value = TextEditingValue(
                          text: _afterDelete!,
                          selection: TextSelection.collapsed(
                            offset: verse.start,
                          ),
                        );
                      },
              ),
              IconButton(
                tooltip: label('Modifier', 'Edit', 'Editar', 'Editar'),
                icon: Icon(
                  Icons.edit_outlined,
                  color: widget.enabled && selectable ? color : Colors.grey,
                ),
                onPressed: widget.enabled && selectable
                    ? () => edit(verse, source)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.controller, widget.languageController]),
    builder: (context, _) {
      final source = widget.controller.text;
      final verses = locateSourceVerses(
        source,
        language: widget.languageController.text,
      );
      final canUndo = _beforeDelete != null && source == _afterDelete;
      if (verses.isEmpty && !canUndo) return const SizedBox.shrink();
      final errors = source.trim().isEmpty
          ? <String>[]
          : validate(source).errors;
      final localIssues = {
        ...errors,
        ...widget.issues.where(
          (issue) =>
              issue.startsWith('Texte saisi,') || issue.startsWith('[FR-KC]'),
        ),
      };
      final issuesByVerse = <int, List<String>>{};
      final seen = <int>{};
      for (final verse in verses) {
        final messages = <String>[];
        if (!seen.add(verse.number)) {
          messages.add(
            label(
              'Numéro répété',
              'Repeated number',
              'Número repetido',
              'Número repetido',
            ),
          );
        }
        final firstLine = source.substring(0, verse.start).split('\n').length;
        final lastLine =
            firstLine +
            source
                .substring(verse.start, verse.end)
                .trimRight()
                .split('\n')
                .length -
            1;
        for (final issue in localIssues) {
          final referenceVerse = RegExp(
            r'^\[FR-KC\] verset (\d+) :',
          ).firstMatch(issue);
          if (referenceVerse != null &&
              int.parse(referenceVerse[1]!) == verse.number) {
            messages.add(issue);
          }
          final match = RegExp(r'ligne (\d+) :').firstMatch(issue);
          final line = match == null ? null : int.tryParse(match.group(1)!);
          if (line != null && line >= firstLine && line <= lastLine) {
            messages.add(issue.substring(issue.indexOf(' :') + 2).trim());
          }
        }
        issuesByVerse[verse.start] = messages;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canUndo)
            TextButton.icon(
              icon: const Icon(Icons.undo),
              label: Text(
                label(
                  'Annuler la suppression',
                  'Undo deletion',
                  'Deshacer eliminación',
                  'Desfazer exclusão',
                ),
              ),
              onPressed: !widget.enabled
                  ? null
                  : () {
                      final previous = _beforeDelete!;
                      _beforeDelete = null;
                      _afterDelete = null;
                      widget.controller.value = TextEditingValue(
                        text: previous,
                        selection: TextSelection.collapsed(
                          offset: previous.length,
                        ),
                      );
                    },
            ),
          if (verses.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '${label('Versets', 'Verses', 'Versículos', 'Versículos')} (${verses.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final verse in verses)
              _verseCard(context, verse, source, issuesByVerse[verse.start]!),
          ],
          if (errors.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '${label('Contrôles du texte', 'Text checks', 'Controles del texto', 'Verificações do texto')} (${errors.length})',
              ),
              children: errors
                  .map(
                    (error) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error),
                    ),
                  )
                  .toList(),
            ),
        ],
      );
    },
  );
}
