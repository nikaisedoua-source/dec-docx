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
  });
  final TextEditingController controller;
  final TextEditingController languageController;
  final String locale;
  final bool enabled;

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
      final counts = <int, int>{};
      for (final verse in verses) {
        counts.update(verse.number, (count) => count + 1, ifAbsent: () => 1);
      }
      final errors = source.trim().isEmpty
          ? <String>[]
          : validate(source).errors;
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
          if (verses.isNotEmpty)
            ExpansionTile(
              key: const PageStorageKey('verse-editor'),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              title: Text(
                '${label('Versets', 'Verses', 'Versículos', 'Versículos')} (${verses.length})',
              ),
              children: [
                SizedBox(
                  height: verses.length == 1 ? 230 : 420,
                  child: ListView.builder(
                    primary: false,
                    itemCount: verses.length,
                    itemBuilder: (context, index) {
                      final verse = verses[index];
                      final selectable = canSelect(verse, source);
                      final repeated = counts[verse.number]! > 1;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${label('Verset', 'Verse', 'Versículo', 'Versículo')} ${verse.number}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (repeated)
                                Text(
                                  label(
                                    'Numéro répété',
                                    'Repeated number',
                                    'Número repetido',
                                    'Número repetido',
                                  ),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                verse.textIn(source),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!selectable)
                                Text(
                                  label(
                                    'Plusieurs versets sur une ligne : corrige la zone de texte ci-dessus.',
                                    'Several verses on one line: edit the text box above.',
                                    'Varios versículos en una línea: edita el texto de arriba.',
                                    'Vários versículos na mesma linha: edite o texto acima.',
                                  ),
                                ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      label(
                                        'Modifier',
                                        'Edit',
                                        'Editar',
                                        'Editar',
                                      ),
                                    ),
                                    onPressed: widget.enabled && selectable
                                        ? () => edit(verse, source)
                                        : null,
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: Text(
                                      label(
                                        'Supprimer',
                                        'Delete',
                                        'Eliminar',
                                        'Excluir',
                                      ),
                                    ),
                                    onPressed: !widget.enabled || !selectable
                                        ? null
                                        : () {
                                            if (widget.controller.text !=
                                                source) {
                                              return;
                                            }
                                            _beforeDelete = source;
                                            _afterDelete = source.replaceRange(
                                              verse.start,
                                              verse.end,
                                              '',
                                            );
                                            widget.controller.value =
                                                TextEditingValue(
                                                  text: _afterDelete!,
                                                  selection:
                                                      TextSelection.collapsed(
                                                        offset: verse.start,
                                                      ),
                                                );
                                          },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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
