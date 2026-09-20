import 'dart:convert';

import 'package:http/http.dart' as http;

/// Optional local assistant powered by Ollama. It never edits the source text;
/// it only returns a review that the user can inspect before generating DOCX.
class LocalAiAssistant {
  const LocalAiAssistant({
    this.endpoint = 'http://localhost:11434/api/chat',
    this.model = 'gemma3:4b',
  });

  final String endpoint;
  final String model;

  Future<String> reviewChapter({
    required String title,
    required String language,
    required String text,
  }) async {
    if (text.trim().isEmpty) {
      throw const FormatException('Ajoute un texte avant de demander une analyse IA.');
    }

    final prompt = '''
Tu es l'assistant de contrôle de DEC DOCX. Analyse le chapitre ci-dessous sans le réécrire,
sans inventer de verset et sans corriger silencieusement le contenu.
Réponds en français avec au maximum 5 points courts :
- numérotation manquante ou sautée ;
- paragraphes vides ou texte probablement collé ;
- concordances ou chapitres similaires mal placés ;
- incohérences évidentes entre le titre, la langue et le contenu ;
- si tout semble correct, dis-le clairement.
Présente chaque remarque comme « À vérifier : ... ».

Titre : $title
Langue : $language
Texte :
$text
''';

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': model,
            'stream': false,
            'messages': [
              {
                'role': 'system',
                'content': 'Tu es prudent, factuel et tu ne modifies jamais le texte source.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'options': {'temperature': 0.1},
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Ollama a répondu HTTP ${response.statusCode}.',
        Uri.parse(endpoint),
      );
    }

    final payload = jsonDecode(response.body);
    final message = payload is Map<String, dynamic>
        ? payload['message']
        : null;
    final content = message is Map<String, dynamic>
        ? message['content']?.toString().trim()
        : null;
    if (content == null || content.isEmpty) {
      throw const FormatException('La réponse de l’assistant IA est vide.');
    }
    return content;
  }
}
