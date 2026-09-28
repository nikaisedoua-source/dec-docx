import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'sermon_rules.dart';

class SermonReferenceResult {
  const SermonReferenceResult({
    required this.chapterNumber,
    required this.paragraphCount,
    required this.url,
    required this.similarChapters,
    this.content,
  });

  final int chapterNumber;
  final int paragraphCount;
  final Uri url;
  final String? similarChapters;
  final FrenchReferenceContent? content;
}

class SermonReferenceService {
  const SermonReferenceService();

  static const _verifiedParagraphMinimums = <int, int>{119: 66};

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
    final contents = kIsWeb
        ? await _fetchWebReferenceCopies(url)
        : [await _fetchContent(url)];
    String? content;
    var count = 0;

    for (final candidate in contents) {
      final candidateCount = parseParagraphCount(candidate) ?? 0;
      if (candidateCount > count ||
          (candidateCount == count &&
              content != null &&
              !parseReferenceContent(content).isComplete(count) &&
              parseReferenceContent(candidate).isComplete(candidateCount))) {
        content = candidate;
        count = candidateCount;
      }
    }

    if (content == null || count == 0) {
      throw const FormatException(
        'Impossible de trouver les paragraphes du chapitre sur la page.',
      );
    }

    count = applyVerifiedParagraphMinimum(chapterNumber, count);

    return SermonReferenceResult(
      chapterNumber: chapterNumber,
      paragraphCount: count,
      url: url,
      similarChapters: parseSimilarChapters(content),
      content: parseReferenceContent(content),
    );
  }

  @visibleForTesting
  static int applyVerifiedParagraphMinimum(int chapterNumber, int count) {
    final verifiedMinimum = _verifiedParagraphMinimums[chapterNumber];
    if (verifiedMinimum == null || count >= verifiedMinimum) {
      return count;
    }
    return verifiedMinimum;
  }

  static Future<List<String>> _fetchWebReferenceCopies(Uri url) async {
    try {
      final direct = await _fetchContent(
        url,
      ).timeout(const Duration(seconds: 8));
      final directCount = parseParagraphCount(direct);
      if (directCount != null &&
          parseReferenceContent(direct).isComplete(directCount)) {
        return [direct];
      }
    } catch (_) {}
    final requestUrls = [
      Uri.parse('https://r.jina.ai/http://${url.host}${url.path}'),
      Uri.parse('https://r.jina.ai/https://${url.host}${url.path}'),
    ];
    final responses = await Future.wait(
      requestUrls.map((requestUrl) async {
        try {
          return await _fetchContent(
            requestUrl,
            headers: const {'X-No-Cache': 'true', 'X-Return-Format': 'html'},
          );
        } catch (_) {
          return null;
        }
      }),
    );
    final contents = responses.whereType<String>().toList();
    if (contents.isEmpty) {
      throw http.ClientException(
        'Aucune source de comparaison en ligne disponible.',
        requestUrls.first,
      );
    }
    return contents;
  }

  static Future<String> _fetchContent(
    Uri requestUrl, {
    Map<String, String>? headers,
  }) async {
    final response = await http
        .get(requestUrl, headers: headers)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('HTTP ${response.statusCode}', requestUrl);
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
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

  /// Parse JSON-LD from the original site, with a rendered/Markdown fallback.
  /// Dates in prose are never interpreted as subtitle dates.
  static FrenchReferenceContent parseReferenceContent(String source) {
    String? title;
    String? subtitle;
    String? body;
    var metadataComplete = false;
    for (final script in RegExp(
      r'<script\b[^>]*type=["\x27]application/ld\+json["\x27][^>]*>(.*?)</script>',
      dotAll: true,
      caseSensitive: false,
    ).allMatches(source)) {
      try {
        final decoded = jsonDecode(script[1]!);
        final entries = decoded is List ? decoded : [decoded];
        for (final data in entries) {
          if (data is Map && data['articleBody'] is String) {
            title = data['headline'] as String?;
            metadataComplete =
                title != null &&
                (data['alternativeHeadline'] is String ||
                    data['description'] is String);
            subtitle =
                data['alternativeHeadline'] as String? ??
                data['description'] as String?;
            body = (data['articleBody'] as String).replaceAll(r'\n', '\n');
            break;
          }
        }
      } catch (_) {}
    }
    // Mark bold verse numbers before stripping tags. Inline citations and
    // trailing standalone concordances remain attached to their verse.
    final rendered = _htmlToText(
      source.replaceAllMapped(
        RegExp(r'<strong[^>]*>\s*(\d{1,3})\s*</strong>', caseSensitive: false),
        (m) => '\n@@VERSE ${m[1]}@@ ',
      ),
    );
    final paragraphs = <int, String>{};
    final dates = <int, List<String>>{};
    if (subtitle != null) {
      final initial = SermonRules.dates(subtitle);
      if (initial.isNotEmpty) dates[0] = initial;
    }
    final lines = (body ?? rendered).split('\n');
    var previous = 0;
    var inChapter = body != null;
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (SermonRules.isSermonTitle(line) ||
          RegExp(r'^#+\s*Kacou\b', caseSensitive: false).hasMatch(line)) {
        title ??= line;
        inChapter = true;
        continue;
      }
      if (SermonRules.isDateHeading(line)) {
        if (inChapter) {
          dates.putIfAbsent(previous, () => []).addAll(SermonRules.dates(line));
          if (previous == 0 && title != null) metadataComplete = true;
        }
        continue;
      }
      final m = RegExp(
        r'^(?:@@VERSE (\d{1,3})@@\s*|\*\*(\d{1,3})\*\*\s*|(\d{1,3})[.)-]?\s+)(.*)$',
      ).firstMatch(line);
      if (m != null) {
        final number = int.parse(m[1] ?? m[2] ?? m[3]!);
        // A complete, sequential map is required before comparisons run.
        if (number == previous + 1) {
          previous = number;
          inChapter = true;
          paragraphs[number] = m[4]!;
          continue;
        }
      }
      if (inChapter && previous == 0 && subtitle == null) {
        final initial = SermonRules.dates(line);
        if (initial.isNotEmpty) {
          dates.putIfAbsent(0, () => []).addAll(initial);
          metadataComplete = title != null;
        }
      } else if (previous > 0) {
        paragraphs[previous] = '${paragraphs[previous]}\n$line';
      }
    }
    // The site's JSON-LD sometimes omits inter-verse headings. Read only date
    // headings from the rendered article, using the explicit verse markers.
    if (body != null) {
      var after = 0;
      var started = false;
      final renderedDates = <int, List<String>>{};
      for (final raw in rendered.split('\n')) {
        final line = raw.trim();
        final marker = RegExp(r'^@@VERSE (\d{1,3})@@').firstMatch(line);
        if (marker != null) {
          after = int.parse(marker[1]!);
          started = true;
        } else if (started && SermonRules.isDateHeading(line)) {
          final found = SermonRules.dates(line);
          renderedDates.putIfAbsent(after, () => []).addAll(found);
        }
      }
      dates.addAll(renderedDates);
    }
    return FrenchReferenceContent(
      title: title,
      metadataComplete: metadataComplete,
      subtitle: subtitle,
      paragraphs: paragraphs,
      subtitleDates: dates,
    );
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
        .map((line) => _plainTextParagraphPattern.firstMatch(line))
        .whereType<RegExpMatch>()
        .map((match) => int.parse(match.group(1) ?? match.group(2)!))
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

  static final RegExp _plainTextParagraphPattern = RegExp(
    r'^\s*(?:(?:\*\*|__)(\d{1,3})(?:\*\*|__)|(\d{1,3})[.)-]?\s+(?:\*\*?|__?|~~)?\p{L})',
    unicode: true,
  );

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

class FrenchReferenceContent {
  const FrenchReferenceContent({
    this.title,
    this.metadataComplete = false,
    this.subtitle,
    required this.paragraphs,
    required this.subtitleDates,
  });
  final String? title;
  final bool metadataComplete;
  final String? subtitle;
  final Map<int, String> paragraphs;
  final Map<int, List<String>> subtitleDates;

  bool isComplete(int count) =>
      metadataComplete &&
      paragraphs.length == count &&
      List.generate(
        count,
        (i) => i + 1,
      ).every((n) => paragraphs.containsKey(n));
}
