import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class DocumentSource {
  const DocumentSource({required this.name, required this.text});

  final String name;
  final String text;
}

class ChapterInput {
  const ChapterInput({
    required this.title,
    required this.subtitle,
    required this.similarChapters,
    required this.sources,
    this.language = '',
  });

  final String title;
  final String subtitle;
  final String similarChapters;
  final List<DocumentSource> sources;
  final String language;
}

class ParsedDocument {
  const ParsedDocument({
    required this.title,
    required this.similarChapters,
    required this.blocks,
  });

  final String title;
  final String? similarChapters;
  final List<DocumentBlock> blocks;

  List<NumberedParagraph> get paragraphs => blocks
      .where((block) => block.paragraph != null)
      .map((block) => block.paragraph!)
      .toList();
}

class NumberedParagraph {
  const NumberedParagraph({required this.number, required this.text});

  final int number;
  final String text;
}

class DocumentBlock {
  const DocumentBlock.subtitle(String text)
    : subtitle = text,
      paragraph = null,
      concordance = null;

  const DocumentBlock.concordance(String text)
    : concordance = text,
      subtitle = null,
      paragraph = null;

  const DocumentBlock.paragraph(NumberedParagraph value)
    : paragraph = value,
      subtitle = null,
      concordance = null;

  final String? subtitle;
  final NumberedParagraph? paragraph;
  final String? concordance;
}

class DocumentValidationResult {
  const DocumentValidationResult({
    required this.documents,
    required this.errors,
  });

  final List<ParsedDocument> documents;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;
}

class DocxBuilder {
  static Uint8List buildChapter(ChapterInput input) {
    final validation = validateChapter(input);
    if (validation.hasErrors) {
      throw FormatException(validation.errors.join('\n'));
    }

    final document = validation.documents.firstOrNull;
    if (document == null) {
      throw ArgumentError('Aucun texte exploitable pour générer le document.');
    }

    return _buildArchive([document]);
  }

  static DocumentValidationResult validateChapter(ChapterInput input) {
    final errors = <String>[];
    final title = input.title.trim();
    final subtitle = input.subtitle.trim();
    var similarChapters = _normalizeSimilarChapters(input.similarChapters);

    if (title.isEmpty) {
      errors.add(
        'Titre du chapitre : ce champ est obligatoire. Mets un titre comme "KACOU 1 : C’est ici la voix de Matthieu 25 :6".',
      );
    } else if (_isAllCapsTitle(title)) {
      errors.add(
        'Titre du chapitre : ne l’écris pas entièrement en majuscules. Écris-le normalement, par exemple "KACOU 1 : C’est ici la voix de Matthieu 25 :6". Les débuts de phrase et les noms propres peuvent garder leur majuscule.',
      );
    }

    final blocks = <DocumentBlock>[
      if (subtitle.isNotEmpty) DocumentBlock.subtitle(subtitle),
    ];

    var hasAnyText = false;
    for (final source in input.sources) {
      if (source.text.trim().isEmpty) {
        continue;
      }

      hasAnyText = true;
      final result = _parseContent(source.name, source.text);
      blocks.addAll(result.blocks);
      errors.addAll(result.errors);
      similarChapters ??= result.similarChapters;
    }

    if (!hasAnyText) {
      errors.add(
        'Paragraphes : colle ou importe le texte du chapitre. Les paragraphes doivent commencer par 1, 2, 3...',
      );
    }

    if (blocks.every((block) => block.paragraph == null)) {
      errors.add(
        'Paragraphes : aucun paragraphe numerote trouve. Ajoute des paragraphes qui commencent par leur numero.',
      );
    }

    return DocumentValidationResult(
      documents: [
        ParsedDocument(
          title: title,
          similarChapters: similarChapters,
          blocks: blocks,
        ),
      ],
      errors: errors,
    );
  }

  static bool _isAllCapsTitle(String title) {
    final separatorIndex = title.indexOf(':');
    final descriptiveTitle =
        (separatorIndex >= 0
                ? title.substring(separatorIndex + 1)
                : title.replaceFirst(
                    RegExp(
                      r'^kacou\s*(?:n[°ºo]?\s*)?\d+\s*',
                      caseSensitive: false,
                    ),
                    '',
                  ))
            .trim();
    return descriptiveTitle.isNotEmpty &&
        descriptiveTitle == descriptiveTitle.toUpperCase() &&
        descriptiveTitle != descriptiveTitle.toLowerCase();
  }

  static int? extractKacouChapterNumber(String value) {
    final patterns = [
      RegExp(
        r'\bKACOU\s*(?:N[°O.]?\s*)?[-_ ]*(\d{1,3})\b',
        caseSensitive: false,
      ),
      RegExp(r'\bKACOU\s*:\s*(\d{1,3})\b', caseSensitive: false),
      RegExp(r'\bKC\.?\s*[-_ ]*(\d{1,3})\b', caseSensitive: false),
      RegExp(r'^\s*(\d{1,3})\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(value);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }

    return null;
  }

  static int paragraphCount(ParsedDocument document) {
    return document.paragraphs.length;
  }

  static Uint8List build(List<DocumentSource> sources) {
    final validation = validate(sources);
    if (validation.hasErrors) {
      throw FormatException(validation.errors.join('\n'));
    }

    final documents = validation.documents;
    if (documents.isEmpty) {
      throw ArgumentError('Aucun texte exploitable pour générer le document.');
    }

    return _buildArchive(documents);
  }

  static DocumentValidationResult validate(List<DocumentSource> sources) {
    final documents = <ParsedDocument>[];
    final errors = <String>[];

    for (final source in sources) {
      final result = _parseSource(source.name, source.text);
      if (result.document.title.trim().isNotEmpty ||
          result.document.paragraphs.isNotEmpty) {
        documents.add(result.document);
      }
      errors.addAll(result.errors);
    }

    return DocumentValidationResult(documents: documents, errors: errors);
  }

  static String extractTextFromDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final file = archive.findFile('word/document.xml');
    if (file == null) {
      throw FormatException(
        'Le fichier DOCX ne contient pas word/document.xml.',
      );
    }

    final xmlText = utf8.decode(file.content as List<int>);
    final document = XmlDocument.parse(xmlText);
    final buffer = StringBuffer();

    for (final paragraph in document.findAllElements('w:p')) {
      for (final line in _extractParagraphLines(paragraph)) {
        buffer.writeln(line);
      }
    }

    return buffer.toString().trim();
  }

  static List<String> _extractParagraphLines(XmlElement paragraph) {
    final lines = <String>[];
    var lineBuffer = StringBuffer();

    void flushLine() {
      final line = lineBuffer.toString().trim();
      if (line.isNotEmpty) {
        lines.add(line);
      }
      lineBuffer = StringBuffer();
    }

    void visit(XmlNode node) {
      if (node is! XmlElement) {
        return;
      }

      final localName = node.name.local;
      if (localName == 't') {
        lineBuffer.write(node.innerText);
        return;
      }
      if (localName == 'tab') {
        lineBuffer.write('\t');
        return;
      }
      if (localName == 'br' || localName == 'cr') {
        flushLine();
        return;
      }

      for (final child in node.children) {
        visit(child);
      }
    }

    for (final child in paragraph.children) {
      visit(child);
    }
    flushLine();

    return lines;
  }

  static Uint8List _buildArchive(List<ParsedDocument> documents) {
    final archive = Archive();
    _addText(archive, '[Content_Types].xml', _contentTypesXml);
    _addText(archive, '_rels/.rels', _relsXml);
    _addText(archive, 'docProps/app.xml', _appXml);
    _addText(archive, 'docProps/core.xml', _coreXml());
    _addText(archive, 'word/_rels/document.xml.rels', _documentRelsXml);
    _addText(archive, 'word/settings.xml', _settingsXml);
    _addText(archive, 'word/styles.xml', _stylesXml);
    _addText(archive, 'word/document.xml', _documentXml(documents));

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static _ParseResult _parseSource(String fallbackTitle, String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return _ParseResult(
        document: ParsedDocument(
          title: fallbackTitle,
          similarChapters: null,
          blocks: const [],
        ),
        errors: const [],
      );
    }

    final titleIndex = lines.indexWhere(_isKacouTitle);
    final title = titleIndex >= 0 ? lines[titleIndex] : lines.first;
    final contentStart = titleIndex >= 0 ? titleIndex + 1 : 1;
    final result = _parseContent(
      fallbackTitle,
      lines.skip(contentStart).join('\n'),
    );

    return _ParseResult(
      document: ParsedDocument(
        title: title,
        similarChapters: result.similarChapters,
        blocks: result.blocks,
      ),
      errors: result.errors,
    );
  }

  static bool _startsWithNumber(String value) {
    return _numberedParagraphPattern.hasMatch(value);
  }

  static NumberedParagraph? _parseNumberedParagraph(String value) {
    final match = _numberedParagraphPattern.firstMatch(value);
    if (match == null) {
      return null;
    }

    return NumberedParagraph(
      number: int.parse(match.group(1)!),
      text: match.group(2)!.trim(),
    );
  }

  static bool _isKacouTitle(String value) {
    return RegExp(
      r'^KACOU(?:\s*(?:N[°O.]?\s*)?\d{1,3})?\s*:',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  static _ContentParseResult _parseContent(String sourceName, String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .toList();
    final contentLines = <_ContentLine>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.isEmpty) {
        continue;
      }
      final nextLine = index + 1 < lines.length ? lines[index + 1] : null;
      if (!_isConversationNoise(line, nextLine)) {
        contentLines.add(_ContentLine(text: line, number: index + 1));
      }
    }

    final blocks = <DocumentBlock>[];
    final errors = <String>[];
    int? expectedNumber;
    var sawNumberedParagraph = false;
    final normalizedLines = _splitEmbeddedNumberedParagraphs(
      _attachStandaloneNumbers(contentLines, sourceName),
    );
    final similarChapters = _extractTrailingSimilarChapters(normalizedLines);

    for (final contentLine in similarChapters.lines) {
      final line = contentLine.text;
      if (_isConcordanceLine(line)) {
        blocks.add(DocumentBlock.concordance(line));
        continue;
      }

      final paragraph = _parseNumberedParagraph(line);
      if (paragraph == null) {
        if (!sawNumberedParagraph || _looksLikeSectionSubtitle(line)) {
          blocks.add(DocumentBlock.subtitle(line));
        } else {
          final expected = expectedNumber ?? 1;
          errors.add(
            '$sourceName, ligne ${contentLine.number} : ce paragraphe n’a pas de numero -> "$line". Ajoute "$expected " au debut de la ligne, ou transforme cette ligne en sous-titre clair comme "PARTIE ...".',
          );
        }
        continue;
      }

      if (expectedNumber != null && paragraph.number != expectedNumber) {
        errors.add(
          '$sourceName, ligne ${contentLine.number} : numero manquant ou incorrect. Attendu $expectedNumber mais trouve ${paragraph.number}. Ajoute le paragraphe $expectedNumber manquant ou corrige le numero ${paragraph.number}.',
        );
      }
      expectedNumber = paragraph.number + 1;
      sawNumberedParagraph = true;
      blocks.add(DocumentBlock.paragraph(paragraph));
    }
    errors.addAll(normalizedLines.errors);

    if (blocks.every((block) => block.paragraph == null) &&
        contentLines.isNotEmpty) {
      errors.add(
        '$sourceName : aucun paragraphe numerote trouve. Ajoute des paragraphes commencant par 1, 2, 3...',
      );
    }

    return _ContentParseResult(
      blocks: blocks,
      errors: errors,
      similarChapters: similarChapters.similarChapters,
    );
  }

  static _SimilarChaptersExtraction _extractTrailingSimilarChapters(
    _NormalizedLines input,
  ) {
    final lines = input.lines.toList();
    final similarLines = <String>[];

    while (lines.isNotEmpty) {
      final text = lines.last.text.trim();
      if (!_looksLikeSimilarChaptersLine(text)) {
        break;
      }
      similarLines.insert(0, text);
      lines.removeLast();
    }

    final similarChapters = similarLines.isEmpty
        ? null
        : _normalizeSimilarChapters(similarLines.join('\n'));

    return _SimilarChaptersExtraction(
      lines: lines,
      similarChapters: similarChapters,
    );
  }

  static _NormalizedLines _attachStandaloneNumbers(
    List<_ContentLine> lines,
    String sourceName,
  ) {
    final normalized = <_ContentLine>[];
    final errors = <String>[];

    for (var index = 0; index < lines.length; index++) {
      final current = lines[index];
      final numberMatch = _standaloneNumberPattern.firstMatch(current.text);
      if (numberMatch == null) {
        normalized.add(current);
        continue;
      }

      if (index + 1 >= lines.length) {
        errors.add(
          '$sourceName, ligne ${current.number} : le numero ${numberMatch.group(1)} existe mais aucun texte ne le suit.',
        );
        normalized.add(current);
        continue;
      }

      final next = lines[index + 1];
      if (_parseNumberedParagraph(next.text) != null ||
          _standaloneNumberPattern.hasMatch(next.text)) {
        errors.add(
          '$sourceName, ligne ${current.number} : le numero ${numberMatch.group(1)} est seul et ne peut pas etre rattache a un texte.',
        );
        normalized.add(current);
        continue;
      }

      normalized.add(
        _ContentLine(
          text: '${current.text} ${next.text}',
          number: current.number,
        ),
      );
      index++;
    }

    return _NormalizedLines(lines: normalized, errors: errors);
  }

  static _NormalizedLines _splitEmbeddedNumberedParagraphs(
    _NormalizedLines input,
  ) {
    final normalized = <_ContentLine>[];

    for (final line in input.lines) {
      normalized.addAll(_splitEmbeddedNumberedParagraphLine(line));
    }

    return _NormalizedLines(lines: normalized, errors: input.errors);
  }

  static List<_ContentLine> _splitEmbeddedNumberedParagraphLine(
    _ContentLine line,
  ) {
    final matches = RegExp(
      r'(^|\s)[^\p{L}\p{N}\r\n]{0,8}\s*(\d{1,3})[\s.)-]+(?=\S)',
      unicode: true,
    ).allMatches(line.text).toList();

    if (matches.length <= 1 || matches.first.start != 0) {
      return [line];
    }

    final numbers = matches
        .map((match) => int.parse(match.group(2)!))
        .toList(growable: false);
    for (var index = 1; index < numbers.length; index++) {
      if (numbers[index] != numbers[index - 1] + 1) {
        return [line];
      }
    }

    final parts = <_ContentLine>[];
    for (var index = 0; index < matches.length; index++) {
      final start = matches[index].start;
      final end = index + 1 < matches.length
          ? matches[index + 1].start
          : line.text.length;
      final text = line.text.substring(start, end).trim();
      if (text.isNotEmpty) {
        parts.add(_ContentLine(text: text, number: line.number));
      }
    }

    return parts.length <= 1 ? [line] : parts;
  }

  static bool _looksLikeSectionSubtitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || _startsWithNumber(trimmed)) {
      return false;
    }
    if (RegExp(
      r'^(PARTIE|CHAPITRE|SECTION)\b',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return true;
    }
    final letters = RegExp(r'[A-Za-zÀ-ÿ]').allMatches(trimmed).length;
    final uppercase = RegExp(r'[A-ZÀ-Þ]').allMatches(trimmed).length;
    return letters > 0 && uppercase / letters >= 0.7;
  }

  static bool _looksLikeSimilarChaptersLine(String value) {
    return RegExp(
      r'^(?:chapitres?(?:\s+similaires)?|cap[ií]tulos?(?:\s+similares)?|similar\s+chapters|similar\s+chapter|ähnliche\s+kapitel|capitoli\s+simili|cap[ií]tulos?\s+semelhantes|ikapitulu\s+solikanana|chương\s+tương\s+tự)[\s\u00a0]*:',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(value.trim());
  }

  static bool _isConcordanceLine(String value) {
    return RegExp(
      r'^(?:\[\s*Kc\.\s*\d{1,3}\s*v\s*\d{1,3}\s*\])+$',
      caseSensitive: false,
    ).hasMatch(value.trim().replaceAll(RegExp(r'\s+'), ''));
  }

  static bool _isConversationNoise(String line, String? nextLine) {
    final value = line.trim();
    if (value.isEmpty || _isKacouTitle(value)) {
      return true;
    }

    final noisePatterns = [
      RegExp(r'^\d{1,2}:\d{2}(\s?[AP]M)?$', caseSensitive: false),
      RegExp(r'^\d{1,2}/\d{1,2}/\d{2,4}$'),
      RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$'),
      RegExp(r'^(aujourd.?hui|hier|today|yesterday)$', caseSensitive: false),
      RegExp(r'^(edited|modifie|transfere|forwarded)', caseSensitive: false),
      RegExp(r'^[-_]{3,}$'),
    ];

    if (noisePatterns.any((pattern) => pattern.hasMatch(value))) {
      return true;
    }

    if (nextLine != null &&
        _startsWithNumber(nextLine) &&
        _looksLikeSenderName(value)) {
      return true;
    }

    return false;
  }

  static bool _looksLikeSenderName(String value) {
    if (_startsWithNumber(value) || value.length > 60) {
      return false;
    }

    final words = value.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    if (words.length > 5) {
      return false;
    }

    final hasNameShape = words.every((word) {
      if (word.startsWith('@')) {
        return true;
      }
      return RegExp(r'^[A-Z][A-Za-z0-9._-]*$').hasMatch(word);
    });

    return hasNameShape && !RegExp(r'[.!?;]$').hasMatch(value);
  }

  static String? _normalizeSimilarChapters(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  static void _addText(Archive archive, String name, String content) {
    final data = utf8.encode(content);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  static String _documentXml(List<ParsedDocument> documents) {
    final body = StringBuffer();

    for (var docIndex = 0; docIndex < documents.length; docIndex++) {
      final document = documents[docIndex];
      body.write(_titleParagraph(document.title));

      for (final block in document.blocks) {
        final subtitle = block.subtitle;
        final paragraph = block.paragraph;
        final concordance = block.concordance;
        if (subtitle != null && subtitle.isNotEmpty) {
          body.write(_subtitleParagraph(subtitle));
        } else if (concordance != null && concordance.isNotEmpty) {
          body.write(_concordanceParagraph(concordance));
        } else if (paragraph != null) {
          body.write(_numberedParagraph(paragraph.number, paragraph.text));
        }
      }

      final similarChapters = document.similarChapters;
      if (similarChapters != null) {
        body.write(_similarChaptersParagraph(similarChapters));
      }

      if (docIndex < documents.length - 1) {
        body.write(_pageBreakParagraph());
      }
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:w10="urn:schemas-microsoft-com:office:word" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk" xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" mc:Ignorable="w14 wp14">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
      <w:cols w:space="708"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>''';
  }

  static String _titleParagraph(String text) {
    return '''<w:p>
      <w:pPr><w:spacing w:after="160"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t>${_escape(text.toUpperCase())}</w:t></w:r>
    </w:p>''';
  }

  static String _subtitleParagraph(String text) {
    return '''<w:p>
      <w:pPr><w:spacing w:after="160"/></w:pPr>
      <w:r><w:rPr><w:i/><w:sz w:val="24"/></w:rPr><w:t>${_escape(text)}</w:t></w:r>
    </w:p>''';
  }

  static String _numberedParagraph(int number, String text) {
    return '''<w:p>
      <w:pPr><w:spacing w:after="240"/></w:pPr>
      <w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t xml:space="preserve">$number </w:t></w:r>
      ${_runsWithConcordances(text)}
    </w:p>''';
  }

  static String _similarChaptersParagraph(String text) {
    return '''<w:p>
      <w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="240"/></w:pPr>
      <w:r><w:rPr><w:i/><w:color w:val="0000FF"/><w:sz w:val="24"/></w:rPr><w:t>${_escape(text)}</w:t></w:r>
    </w:p>''';
  }

  static String _concordanceParagraph(String text) {
    return '''<w:p>
      <w:pPr><w:spacing w:after="120"/></w:pPr>
      <w:r><w:rPr><w:i/><w:color w:val="008000"/><w:sz w:val="24"/></w:rPr><w:t>${_escape(text)}</w:t></w:r>
    </w:p>''';
  }

  static String _runsWithConcordances(String text) {
    final buffer = StringBuffer();
    final matches = RegExp(
      r'\[\s*Kc\.\s*\d{1,3}\s*v\s*\d{1,3}\s*\]',
      caseSensitive: false,
    ).allMatches(text).toList();

    if (matches.isEmpty) {
      return '<w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t>${_escape(text)}</w:t></w:r>';
    }

    var index = 0;
    for (final match in matches) {
      if (match.start > index) {
        final plain = text.substring(index, match.start);
        buffer.write(
          '<w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t>${_escape(plain)}</w:t></w:r>',
        );
      }
      final concordance = text.substring(match.start, match.end);
      buffer.write(
        '<w:r><w:rPr><w:i/><w:color w:val="008000"/><w:sz w:val="24"/></w:rPr><w:t>${_escape(concordance)}</w:t></w:r>',
      );
      index = match.end;
    }

    if (index < text.length) {
      final plain = text.substring(index);
      buffer.write(
        '<w:r><w:rPr><w:sz w:val="24"/></w:rPr><w:t>${_escape(plain)}</w:t></w:r>',
      );
    }

    return buffer.toString();
  }

  static String _pageBreakParagraph() {
    return '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
  }

  static String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static const _contentTypesXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

  static const _relsXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';

  static const _documentRelsXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>''';

  static const _appXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>DEC DOCX</Application>
  <DocSecurity>0</DocSecurity>
  <ScaleCrop>false</ScaleCrop>
  <Company></Company>
  <LinksUpToDate>false</LinksUpToDate>
  <SharedDoc>false</SharedDoc>
  <HyperlinksChanged>false</HyperlinksChanged>
  <AppVersion>1.0</AppVersion>
</Properties>''';

  static String _coreXml() {
    final now = DateTime.now().toUtc().toIso8601String();
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Document généré</dc:title>
  <dc:creator>DEC DOCX</dc:creator>
  <cp:lastModifiedBy>DEC DOCX</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>''';
  }

  static const _settingsXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:zoom w:percent="100"/>
  <w:defaultTabStop w:val="708"/>
</w:settings>''';

  static const _stylesXml =
      '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/>
        <w:sz w:val="24"/>
        <w:szCs w:val="24"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="240"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:qFormat/>
  </w:style>
</w:styles>''';

  static final RegExp _numberedParagraphPattern = RegExp(
    r'^[^\p{L}\p{N}\r\n]{0,8}\s*(\d{1,3})[\s.)-]+(.+)$',
    unicode: true,
  );

  static final RegExp _standaloneNumberPattern = RegExp(
    r'^[^\p{L}\p{N}\r\n]{0,8}\s*(\d{1,3})[^\p{L}\p{N}\r\n]{0,8}$',
    unicode: true,
  );
}

class _ParseResult {
  const _ParseResult({required this.document, required this.errors});

  final ParsedDocument document;
  final List<String> errors;
}

class _ContentParseResult {
  const _ContentParseResult({
    required this.blocks,
    required this.errors,
    required this.similarChapters,
  });

  final List<DocumentBlock> blocks;
  final List<String> errors;
  final String? similarChapters;
}

class _SimilarChaptersExtraction {
  const _SimilarChaptersExtraction({
    required this.lines,
    required this.similarChapters,
  });

  final List<_ContentLine> lines;
  final String? similarChapters;
}

class _NormalizedLines {
  const _NormalizedLines({required this.lines, required this.errors});

  final List<_ContentLine> lines;
  final List<String> errors;
}

class _ContentLine {
  const _ContentLine({required this.text, required this.number});

  final String text;
  final int number;
}
