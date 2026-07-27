import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SermonReferenceResult {
  const SermonReferenceResult({
    required this.chapterNumber,
    required this.paragraphCount,
    required this.url,
    required this.similarChapters,
  });

  final int chapterNumber;
  final int paragraphCount;
  final Uri url;
  final String? similarChapters;
}

class SermonReferenceService {
  const SermonReferenceService();

  Future<SermonReferenceResult> fetchFrenchParagraphCount(
    int chapterNumber,
  ) async {
    return fetchReference(chapterNumber, locale: 'fr-fr');
  }

  Future<SermonReferenceResult> fetchReference(
    int chapterNumber, {
    required String locale,
  }) async {
    final url = Uri.https(
      'www.philippekacou.org',
      '/$locale/sermons/$chapterNumber',
    );
    final requestUrl = kIsWeb
        ? Uri.parse('https://r.jina.ai/http://${url.host}${url.path}')
        : url;
    final response = await http.get(requestUrl).timeout(
      const Duration(seconds: 25),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'HTTP ${response.statusCode}',
        requestUrl,
      );
    }

    final content = utf8.decode(response.bodyBytes, allowMalformed: true);
    final count = parseParagraphCount(content);
    if (count == null || count == 0) {
      throw const FormatException(
        'Impossible de trouver les paragraphes du chapitre sur la page.',
      );
    }

    return SermonReferenceResult(
      chapterNumber: chapterNumber,
      paragraphCount: count,
      url: url,
      similarChapters: parseSimilarChapters(content),
    );
  }

  static String? parseSimilarChapters(String html) {
    final text = _htmlToText(html);
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (var index = lines.length - 1; index >= 0; index--) {
      final line = lines[index];
      if (_looksLikeSimilarChaptersLine(line)) {
        return line;
      }
    }

    return null;
  }

  static int? parseParagraphCount(String html) {
    final matches = RegExp(r'"number"\s*:\s*(\d+)').allMatches(html);
    var maxNumber = 0;

    for (final match in matches) {
      maxNumber = max(maxNumber, int.parse(match.group(1)!));
    }

    if (maxNumber > 0) {
      return maxNumber;
    }

    final sequentialCount = _parseSequentialPlainTextParagraphs(html);
    if (sequentialCount != null) {
      return sequentialCount;
    }

    final strongMatches = RegExp(
      r'<strong>\s*(\d+)\s*</strong>',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in strongMatches) {
      maxNumber = max(maxNumber, int.parse(match.group(1)!));
    }

    if (maxNumber > 0) {
      return maxNumber;
    }

    final articleBody = RegExp(
      r'"articleBody"\s*:\s*"(.+?)"\s*,\s*"image"',
      dotAll: true,
    ).firstMatch(html);
    if (articleBody == null) {
      return null;
    }

    final decoded = _decodeJsonString(articleBody.group(1)!);
    final paragraphNumbers = RegExp(
      r'(?:^|\\n\s*|\n\s*)(\d+)\s+',
    ).allMatches(decoded);

    for (final match in paragraphNumbers) {
      maxNumber = max(maxNumber, int.parse(match.group(1)!));
    }

    return maxNumber == 0 ? null : maxNumber;
  }

  static int? _parseSequentialPlainTextParagraphs(String content) {
    final numbers = content
        .split('\n')
        .map(
          (line) => RegExp(
            r'^\s*(\d{1,3})[.)-]?\s+\p{L}',
            unicode: true,
          ).firstMatch(line),
        )
        .whereType<RegExpMatch>()
        .map((match) => int.parse(match.group(1)!))
        .toList();

    var expected = 1;
    var highest = 0;
    for (final number in numbers) {
      if (number == expected) {
        highest = number;
        expected++;
      }
    }
    return highest == 0 ? null : highest;
  }

  static String _decodeJsonString(String value) {
    try {
      return jsonDecode('"$value"') as String;
    } catch (_) {
      return value;
    }
  }

  static String _htmlToText(String html) {
    final withoutScripts = html
        .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>', dotAll: true), '\n')
        .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true), '\n');
    return withoutScripts
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(?:p|div|h\d|li)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s+'), '\n')
        .trim();
  }

  static bool _looksLikeSimilarChaptersLine(String value) {
    return RegExp(
      r'^(?:chapitres?(?:\s+similaires)?|cap[ií]tulos?(?:\s+similares)?|similar\s+chapters|similar\s+chapter|ähnliche\s+kapitel|capitoli\s+simili|cap[ií]tulos?\s+semelhantes|ikapitulu\s+solikanana|chương\s+tương\s+tự)[\s\u00a0]*:',
      caseSensitive: false,
      unicode: true,
    ).hasMatch(value.trim());
  }
}
