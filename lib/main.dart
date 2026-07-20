import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'docx_builder.dart';
import 'sermon_reference.dart';

const _appName = 'DEC DOCX';
const _appVersion = '1.6.0';
const _updateManifestUrl = String.fromEnvironment(
  'DEC_DOCX_UPDATE_MANIFEST_URL',
  defaultValue: '',
);

void main() {
  runApp(const DocxGeneratorApp());
}

enum AppLanguage {
  fr('🇫🇷 FR'),
  en('🇬🇧 EN'),
  es('🇪🇸 ES'),
  pt('🇵🇹 PT');

  const AppLanguage(this.label);

  final String label;
}

class KacouLanguage {
  const KacouLanguage(this.name, this.locale);

  final String name;
  final String? locale;
}

const _kacouLanguages = <KacouLanguage>[
  KacouLanguage('francais', 'fr-fr'),
  KacouLanguage('anglais', 'en-en'),
  KacouLanguage('espagnol', 'es-es'),
  KacouLanguage('portugais', 'pt-pt'),
  KacouLanguage('allemand', 'de-de'),
  KacouLanguage('russe', 'ru-ru'),
  KacouLanguage('italien', 'it-it'),
  KacouLanguage('attie', 'ci-ati'),
  KacouLanguage('agni', 'ci-any'),
  KacouLanguage('wan', 'ci-wan'),
  KacouLanguage('yemba', 'cm-ybb'),
  KacouLanguage('fon', 'bj-fon'),
  KacouLanguage('kikongo', 'ao-kg'),
  KacouLanguage('gouin', 'bf-gux'),
  KacouLanguage('moore', 'bf-mos'),
  KacouLanguage('bambara', 'ml-bmq'),
  KacouLanguage('chinois', null),
];

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String get appTitle => _appName;
  String get tagline => _text(
    'Corrige les DOCX mal formes sans inventer de versets',
    'Repairs malformed DOCX without inventing verses',
    'Corrige DOCX mal formados sin inventar versiculos',
    'Corrige DOCX mal formatados sem inventar versiculos',
  );
  String get versionLabel => _text(
    'Version $_appVersion',
    'Version $_appVersion',
    'Version $_appVersion',
    'Versao $_appVersion',
  );
  String get clear => _text('Vider', 'Clear', 'Limpiar', 'Limpar');
  String get freshBadge => _text(
    'NOUVELLE APP - installation propre',
    'NEW APP - clean install',
    'NUEVA APP - instalacion limpia',
    'NOVO APP - instalacao limpa',
  );
  String get workflowTips => _text(
    '1. Entre le titre du chapitre.\n2. Choisis ou ecris la langue du document.\n3. Les concordances restent en place et seront en vert; les chapitres similaires finaux seront en bleu.',
    '1. Enter the chapter title.\n2. Choose or type the document language.\n3. Concordances stay in place and will be green; final similar chapters will be blue.',
    '1. Ingresa el titulo del capitulo.\n2. Elige o escribe el idioma del documento.\n3. Las concordancias quedan en su lugar y seran verdes; los capitulos similares finales seran azules.',
    '1. Informe o titulo do capitulo.\n2. Escolha ou escreva o idioma do documento.\n3. As concordancias ficam no lugar e serao verdes; os capitulos similares finais serao azuis.',
  );
  String get inputTitle => _text(
    'Contenu du chapitre',
    'Chapter content',
    'Contenido del capitulo',
    'Conteudo do capitulo',
  );
  String get inputHint => _text(
    'Colle les paragraphes numerotes. Les numeros seuls seront rattaches au texte suivant; un verset manquant reste une erreur.',
    'Paste numbered paragraphs. Standalone numbers are attached to the next text; a missing verse remains an error.',
    'Pega los parrafos numerados. Los numeros solos se unen al texto siguiente; un versiculo faltante sigue siendo error.',
    'Cole os paragrafos numerados. Numeros sozinhos sao ligados ao texto seguinte; versiculo ausente continua erro.',
  );
  String get chapterTitle => _text(
    'Titre du chapitre',
    'Chapter title',
    'Titulo del capitulo',
    'Titulo do capitulo',
  );
  String get chapterTitleHint => _text(
    'KACOU 1 : C’EST ICI LA VOIX DE MATTHIEU 25 :6',
    'KACOU 1: THIS IS THE VOICE OF MATTHEW 25:6',
    'KACOU 1: AQUI ESTA LA VOZ DE MATEO 25:6',
    'KACOU 1: AQUI ESTA A VOZ DE MATEUS 25:6',
  );
  String get subtitle => _text(
    'Sous-titre optionnel',
    'Optional subtitle',
    'Subtitulo opcional',
    'Subtitulo opcional',
  );
  String get subtitleHint => _text(
    'Laisse vide si le chapitre n’a pas de sous-titre. Il sera ajouté en italique.',
    'Leave empty if the chapter has no subtitle. It will be added in italics.',
    'Deja vacio si el capitulo no tiene subtitulo. Se agregara en cursiva.',
    'Deixe vazio se o capitulo nao tiver subtitulo. Sera adicionado em italico.',
  );
  String get similarChapters => _text(
    'Chapitres similaires finaux',
    'Final similar chapters',
    'Capitulos similares finales',
    'Capitulos similares finais',
  );
  String get similarChaptersHint => _text(
    'Uniquement le bloc final du texte. Il sera ajoute en bleu italique a la fin du dernier paragraphe.',
    'Only the final block of the text. It will be added in blue italic at the end of the last paragraph.',
    'Solo el bloque final del texto. Se agregara en azul cursiva al final del ultimo parrafo.',
    'Somente o bloco final do texto. Sera adicionado em azul italico ao final do ultimo paragrafo.',
  );
  String get siteLanguage => _text(
    'Langue du site',
    'Site language',
    'Idioma del sitio',
    'Idioma do site',
  );
  String get documentLanguage => _text(
    'Langue du document',
    'Document language',
    'Idioma del documento',
    'Idioma do documento',
  );
  String get documentLanguageHint => _text(
    'Exemple : russe, allemand, chinois...',
    'Example: Russian, German, Chinese...',
    'Ejemplo: ruso, aleman, chino...',
    'Exemplo: russo, alemao, chines...',
  );
  String get fileNameRule => _text(
    'Nom automatique : KACOU <numero> <langue>.docx',
    'Automatic name: KACOU <number> <language>.docx',
    'Nombre automatico: KACOU <numero> <idioma>.docx',
    'Nome automatico: KACOU <numero> <idioma>.docx',
  );
  String get addFiles => _text(
    'Importer et reparer TXT, MD ou DOCX',
    'Import and repair TXT, MD or DOCX',
    'Importar y reparar TXT, MD o DOCX',
    'Importar e reparar TXT, MD ou DOCX',
  );
  String get download =>
      _text('Telechargement', 'Download', 'Descarga', 'Download');
  String get downloadButton =>
      _text('Telecharger', 'Download', 'Descargar', 'Baixar');
  String get urlLabel =>
      _text('Lien du texte', 'Text URL', 'URL del texto', 'URL do texto');
  String get output => _text('Sortie', 'Output', 'Salida', 'Saida');
  String get fileName => _text(
    'Nom du fichier',
    'File name',
    'Nombre del archivo',
    'Nome do arquivo',
  );
  String get generate => _text(
    'Corriger et generer',
    'Repair and generate',
    'Reparar y generar',
    'Reparar e gerar',
  );
  String get checkFormat => _text(
    'Verifier le format',
    'Check format',
    'Verificar formato',
    'Verificar formato',
  );
  String get sources => _text(
    'Fichiers ajoutes',
    'Added files',
    'Archivos agregados',
    'Arquivos adicionados',
  );
  String get noSources => _text(
    'Aucun fichier ajoute.',
    'No file added.',
    'Ningun archivo agregado.',
    'Nenhum arquivo adicionado.',
  );
  String get remove => _text('Retirer', 'Remove', 'Quitar', 'Remover');
  String get footer => _text(
    'DEC DOCX $_appVersion : detection DOCX mal forme, correction des numeros existants, comparaison non bornee et fonctionnement hors connexion.',
    'DEC DOCX $_appVersion: malformed DOCX detection, existing number repair, unbounded comparison and offline use.',
    'DEC DOCX $_appVersion: deteccion DOCX mal formado, reparacion de numeros existentes, comparacion sin limite y uso sin conexion.',
    'DEC DOCX $_appVersion: deteccao DOCX mal formatado, reparo de numeros existentes, comparacao sem limite e uso offline.',
  );
  String get noInput => _text(
    'Ajoute un texte ou au moins un fichier.',
    'Add text or at least one file.',
    'Agrega un texto o al menos un archivo.',
    'Adicione um texto ou pelo menos um arquivo.',
  );
  String get invalidUrl => _text(
    'Entre une adresse web valide.',
    'Enter a valid web address.',
    'Introduce una direccion web valida.',
    'Informe um endereco web valido.',
  );
  String get unreadableFile => _text(
    'Aucun fichier lisible.',
    'No readable file.',
    'Ningun archivo legible.',
    'Nenhum arquivo legivel.',
  );
  String filesAdded(int count) => _text(
    '$count fichier(s) ajoute(s) et prepares par Fresh.',
    '$count file(s) added and prepared by Fresh.',
    '$count archivo(s) agregado(s) y preparado(s) por Fresh.',
    '$count arquivo(s) adicionado(s) e preparado(s) pelo Fresh.',
  );
  String formatReady(int paragraphs) => _text(
    'Format OK : $paragraphs paragraphe(s) numerote(s) detecte(s). Aucun verset n’a ete ajoute.',
    'Format OK: $paragraphs numbered paragraph(s) detected. No verse was added.',
    'Formato OK: $paragraphs parrafo(s) numerado(s) detectado(s). No se agrego ningun versiculo.',
    'Formato OK: $paragraphs paragrafo(s) numerado(s) detectado(s). Nenhum versiculo foi adicionado.',
  );
  String downloaded(Uri uri) => _text(
    'Texte telecharge depuis $uri.',
    'Text downloaded from $uri.',
    'Texto descargado desde $uri.',
    'Texto baixado de $uri.',
  );
  String downloadFailed(Object error) => _text(
    'Telechargement impossible : $error',
    'Download failed: $error',
    'Descarga imposible: $error',
    'Download impossivel: $error',
  );
  String validationErrors(List<String> errors) => _text(
    'Correction necessaire avant generation :\n${errors.join('\n')}',
    'Correction required before generation:\n${errors.join('\n')}',
    'Correccion necesaria antes de generar:\n${errors.join('\n')}',
    'Correcao necessaria antes de gerar:\n${errors.join('\n')}',
  );
  String get languageRequired => _text(
    'Langue obligatoire : choisis une langue du site ou ecris-la manuellement pour nommer correctement le fichier.',
    'Language required: choose a site language or type it manually so the file can be named correctly.',
    'Idioma obligatorio: elige un idioma del sitio o escribelo manualmente para nombrar correctamente el archivo.',
    'Idioma obrigatorio: escolha um idioma do site ou escreva manualmente para nomear corretamente o arquivo.',
  );
  String updateAvailable({
    required String version,
    required String message,
    required String url,
  }) => _text(
    'Mise a jour disponible : DEC DOCX $version\n$message\nTelechargement : $url',
    'Update available: DEC DOCX $version\n$message\nDownload: $url',
    'Actualizacion disponible: DEC DOCX $version\n$message\nDescarga: $url',
    'Atualizacao disponivel: DEC DOCX $version\n$message\nDownload: $url',
  );
  String similarChaptersOnlineMissing(String similarChapters) => _text(
    'Chapitres similaires detectes en ligne : $similarChapters\nAjoute ce bloc dans "Chapitres similaires finaux" avant de generer.',
    'Similar chapters found online: $similarChapters\nAdd this block in "Final similar chapters" before generating.',
    'Capitulos similares detectados en linea: $similarChapters\nAgrega este bloque en "Capitulos similares finales" antes de generar.',
    'Capitulos similares encontrados online: $similarChapters\nAdicione este bloco em "Capitulos similares finais" antes de gerar.',
  );
  String get comparingReference => _text(
    'Comparaison avec la version française du site www.philippekacou.org...',
    'Comparing with the French version on www.philippekacou.org...',
    'Comparando con la version francesa en www.philippekacou.org...',
    'Comparando com a versao francesa em www.philippekacou.org...',
  );
  String referenceTitleNumberMissing() => _text(
    'Titre du chapitre : le numero Kacou est introuvable. Mets un titre comme "KACOU 1 : ...", sinon la comparaison avec le site est impossible.',
    'Chapter title: the Kacou number is missing. Use a title like "KACOU 1: ...", otherwise site comparison is impossible.',
    'Titulo del capitulo: falta el numero Kacou. Usa un titulo como "KACOU 1: ..."; si no, la comparacion con el sitio es imposible.',
    'Titulo do capitulo: falta o numero Kacou. Use um titulo como "KACOU 1: ..."; senao a comparacao com o site e impossivel.',
  );
  String referenceFetchFailed(int chapter, Object error) => _text(
    'Mode hors connexion : la comparaison en ligne de Kacou $chapter a ete ignoree ($error). Le document a ete genere avec les controles locaux.',
    'Offline mode: online comparison for Kacou $chapter was skipped ($error). The document was generated with local checks.',
    'Modo sin conexion: se omitio la comparacion en linea de Kacou $chapter ($error). El documento se genero con controles locales.',
    'Modo offline: a comparacao online de Kacou $chapter foi ignorada ($error). O documento foi gerado com verificacoes locais.',
  );
  String paragraphCountMismatch({
    required int chapter,
    required int localCount,
    required int referenceCount,
  }) {
    final gap = (referenceCount - localCount).abs();
    final frAction = localCount < referenceCount
        ? 'Il manque $gap paragraphe(s). Ajoute les paragraphes manquants dans le texte colle.'
        : 'Il y a $gap paragraphe(s) en trop. Retire les paragraphes en trop ou verifie les numeros.';
    final enAction = localCount < referenceCount
        ? '$gap paragraph(s) are missing. Add the missing paragraphs to the pasted text.'
        : '$gap extra paragraph(s) were found. Remove the extra paragraphs or check the numbers.';
    final esAction = localCount < referenceCount
        ? 'Faltan $gap parrafo(s). Agrega los parrafos faltantes al texto pegado.'
        : 'Hay $gap parrafo(s) de mas. Quita los parrafos sobrantes o revisa los numeros.';
    final ptAction = localCount < referenceCount
        ? 'Faltam $gap paragrafo(s). Adicione os paragrafos faltantes ao texto colado.'
        : 'Ha $gap paragrafo(s) extra. Remova os paragrafos extras ou confira os numeros.';

    return _text(
      'Comparaison site : ton texte Kacou $chapter contient $localCount paragraphe(s), mais le chapitre francais du site en contient $referenceCount. $frAction Verifie aussi que le titre indique le bon numero Kacou.',
      'Site comparison: your Kacou $chapter text has $localCount paragraph(s), but the French chapter on the site has $referenceCount. $enAction Also check that the title has the right Kacou number.',
      'Comparacion del sitio: tu texto Kacou $chapter tiene $localCount parrafo(s), pero el capitulo frances del sitio tiene $referenceCount. $esAction Verifica tambien que el titulo tenga el numero Kacou correcto.',
      'Comparacao do site: seu texto Kacou $chapter tem $localCount paragrafo(s), mas o capitulo frances do site tem $referenceCount. $ptAction Confira tambem se o titulo tem o numero Kacou correto.',
    );
  }

  String referenceOk({
    required int chapter,
    required int paragraphCount,
  }) => _text(
    'Comparaison OK : Kacou $chapter contient $paragraphCount paragraphe(s), comme la version francaise du site.',
    'Comparison OK: Kacou $chapter has $paragraphCount paragraph(s), like the French version on the site.',
    'Comparacion OK: Kacou $chapter tiene $paragraphCount parrafo(s), como la version francesa del sitio.',
    'Comparacao OK: Kacou $chapter tem $paragraphCount paragrafo(s), como a versao francesa do site.',
  );
  String localChecksOk({
    required int chapter,
    required int paragraphCount,
  }) => _text(
    'Controle local OK : Kacou $chapter contient $paragraphCount paragraphe(s). La comparaison en ligne est disponible sans limite quand internet fonctionne.',
    'Local check OK: Kacou $chapter has $paragraphCount paragraph(s). Online comparison is available without a fixed limit when internet works.',
    'Control local OK: Kacou $chapter tiene $paragraphCount parrafo(s). La comparacion en linea esta disponible sin limite fijo cuando hay internet.',
    'Verificacao local OK: Kacou $chapter tem $paragraphCount paragrafo(s). A comparacao online fica disponivel sem limite fixo quando ha internet.',
  );
  String created(String path) => _text(
    'Document cree : $path',
    'Document created: $path',
    'Documento creado: $path',
    'Documento criado: $path',
  );
  String get shared => _text(
    'Document prepare pour le partage.',
    'Document ready to share.',
    'Documento listo para compartir.',
    'Documento pronto para compartilhar.',
  );
  String error(Object error) => _text(
    'Erreur : $error',
    'Error: $error',
    'Error: $error',
    'Erro: $error',
  );
  String words(int count) => _text(
    '$count mots',
    '$count words',
    '$count palabras',
    '$count palavras',
  );

  String _text(String fr, String en, String es, String pt) {
    return switch (language) {
      AppLanguage.fr => fr,
      AppLanguage.en => en,
      AppLanguage.es => es,
      AppLanguage.pt => pt,
    };
  }
}

class DocxGeneratorApp extends StatelessWidget {
  const DocxGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F7A6D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const GeneratorPage(),
    );
  }
}

class _ReferenceCheckResult {
  const _ReferenceCheckResult({required this.errors, required this.message});

  factory _ReferenceCheckResult.ok(String? message) {
    return _ReferenceCheckResult(errors: const [], message: message);
  }

  factory _ReferenceCheckResult.error(String error) {
    return _ReferenceCheckResult(errors: [error], message: null);
  }

  factory _ReferenceCheckResult.errors(List<String> errors) {
    return _ReferenceCheckResult(errors: errors, message: null);
  }

  final List<String> errors;
  final String? message;
}

class GeneratorPage extends StatefulWidget {
  const GeneratorPage({super.key});

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  final _chapterTitleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _similarChaptersController = TextEditingController();
  final _manualTextController = TextEditingController();
  final _downloadUrlController = TextEditingController();
  final _fileNameController = TextEditingController(text: 'document_genere');
  final _documentLanguageController = TextEditingController();
  final _referenceService = const SermonReferenceService();
  final List<DocumentSource> _fileSources = [];
  AppLanguage _language = AppLanguage.fr;
  KacouLanguage? _selectedDocumentLanguage;
  bool _isGenerating = false;
  bool _isDownloading = false;
  String? _status;

  AppStrings get _strings => AppStrings(_language);

  @override
  void initState() {
    super.initState();
    _chapterTitleController.addListener(_syncAutomaticFileName);
    _documentLanguageController.addListener(_syncAutomaticFileName);
    _clearRuntimeCache();
    _checkForUpdateNotice();
  }

  @override
  void dispose() {
    _chapterTitleController.removeListener(_syncAutomaticFileName);
    _documentLanguageController.removeListener(_syncAutomaticFileName);
    _chapterTitleController.dispose();
    _subtitleController.dispose();
    _similarChaptersController.dispose();
    _manualTextController.dispose();
    _downloadUrlController.dispose();
    _fileNameController.dispose();
    _documentLanguageController.dispose();
    super.dispose();
  }

  void _syncAutomaticFileName() {
    final chapterNumber = DocxBuilder.extractKacouChapterNumber(
      _chapterTitleController.text,
    );
    final language = _documentLanguageController.text.trim();
    if (chapterNumber == null || language.isEmpty) {
      return;
    }

    final nextName = _automaticFileName(
      chapterNumber: chapterNumber,
      language: language,
    );
    if (_fileNameController.text != nextName) {
      _fileNameController.text = nextName;
    }
  }

  Future<void> _clearRuntimeCache() async {
    try {
      final directory = await getTemporaryDirectory();
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // Ignore files locked by the system.
          }
        }
      }
    } catch (_) {
      // Cache cleanup must never block app startup.
    }
  }

  Future<void> _checkForUpdateNotice() async {
    if (_updateManifestUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(_updateManifestUrl);
    if (uri == null || !uri.hasScheme) {
      return;
    }

    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final payload = jsonDecode(await utf8.decoder.bind(response).join());
      if (payload is! Map<String, dynamic>) {
        return;
      }

      final latestVersion = payload['version']?.toString().trim() ?? '';
      final message = payload['message']?.toString().trim() ?? '';
      final downloadUrl = payload['downloadUrl']?.toString().trim() ?? '';

      if (latestVersion.isEmpty ||
          !_isVersionNewer(latestVersion, _appVersion) ||
          !mounted) {
        return;
      }

      setState(
        () => _status = _strings.updateAvailable(
          version: latestVersion,
          message: message.isEmpty
              ? 'Une nouvelle version est prete.'
              : message,
          url: downloadUrl,
        ),
      );
    } catch (_) {
      // Update checks are advisory. Offline users can keep working.
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'docx'],
      withData: true,
    );

    if (result == null) {
      return;
    }

    final imported = <DocumentSource>[];
    for (final file in result.files) {
      final bytes = await _readPlatformFile(file);
      if (bytes == null) {
        continue;
      }

      final extension = file.extension?.toLowerCase();
      final rawText = extension == 'docx'
          ? DocxBuilder.extractTextFromDocx(bytes)
          : utf8.decode(bytes, allowMalformed: true);
      final text = _normalizeWebText(rawText);

      imported.add(DocumentSource(name: _fileTitle(file.name), text: text));
    }

    setState(() {
      _fileSources.addAll(imported);
      _status = imported.isEmpty
          ? _strings.unreadableFile
          : _strings.filesAdded(imported.length);
    });
  }

  Future<void> _downloadTextFromUrl() async {
    final uri = Uri.tryParse(_downloadUrlController.text.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() => _status = _strings.invalidUrl);
      return;
    }

    setState(() {
      _isDownloading = true;
      _status = null;
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      final rawText = utf8.decode(bytes, allowMalformed: true);
      final text = _normalizeWebText(rawText);
      final title = _fileTitle(
        uri.pathSegments.isEmpty
            ? uri.host
            : uri.pathSegments.last.isEmpty
            ? uri.host
            : uri.pathSegments.last,
      );

      setState(() {
        _fileSources.add(DocumentSource(name: title, text: text));
        _downloadUrlController.clear();
        _status = _strings.downloaded(uri);
      });
    } catch (error) {
      setState(() => _status = _strings.downloadFailed(error));
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<Uint8List?> _readPlatformFile(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes;
    }
    if (file.path != null) {
      return File(file.path!).readAsBytes();
    }
    return null;
  }

  Future<void> _generate() async {
    final input = _chapterInput();
    final documentLanguage = input.language.trim();

    setState(() {
      _isGenerating = true;
      _status = _strings.comparingReference;
    });

    try {
      if (documentLanguage.isEmpty) {
        setState(() => _status = _strings.languageRequired);
        return;
      }

      final validation = DocxBuilder.validateChapter(input);
      if (validation.hasErrors) {
        setState(() => _status = _strings.validationErrors(validation.errors));
        return;
      }

      final document = validation.documents.first;
      final referenceCheck = await _compareWithFrenchReference(input, document);
      if (referenceCheck.errors.isNotEmpty) {
        setState(
          () => _status = _strings.validationErrors(referenceCheck.errors),
        );
        return;
      }

      final chapterNumber = DocxBuilder.extractKacouChapterNumber(input.title)!;
      final localCount = DocxBuilder.paragraphCount(document);
      final checkMessage =
          referenceCheck.message ??
          _strings.localChecksOk(
            chapter: chapterNumber,
            paragraphCount: localCount,
          );
      final bytes = DocxBuilder.buildChapter(input);
      final fileName = _automaticFileName(
        chapterNumber: chapterNumber,
        language: documentLanguage,
      );
      _fileNameController.text = fileName;

      final path = await FilePicker.saveFile(
        dialogTitle: _strings.generate,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['docx'],
        bytes: bytes,
      );

      if (path == null) {
        await _shareGeneratedFile(fileName, bytes);
        setState(() => _status = '$checkMessage\n${_strings.shared}');
      } else {
        setState(() => _status = '$checkMessage\n${_strings.created(path)}');
      }
    } catch (error) {
      setState(() => _status = _strings.error(error));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  ChapterInput _chapterInput() {
    return ChapterInput(
      title: _chapterTitleController.text,
      subtitle: _subtitleController.text,
      similarChapters: _similarChaptersController.text,
      language: _documentLanguageController.text,
      sources: [
        if (_manualTextController.text.trim().isNotEmpty)
          DocumentSource(
            name: 'Texte saisi',
            text: _normalizeWebText(_manualTextController.text),
          ),
        ..._fileSources,
      ],
    );
  }

  String _normalizeWebText(String text) {
    if (!kIsWeb) {
      return text;
    }

    return _removeTelegramNames(text);
  }

  static String _removeTelegramNames(String text) {
    const handlePattern = r'(?:(?<=^)|(?<=[\s:;,\(\[\{]))@[A-Za-z0-9_]{5,32}';
    final handleRegExp = RegExp(handlePattern, caseSensitive: false);
    final linkRegExp = RegExp(
      r'\b(?:https?://)?(?:t\.me|telegram\.me)/[A-Za-z0-9_]{5,32}\b',
      caseSensitive: false,
    );

    final cleaned = text
        .replaceAll(linkRegExp, '')
        .replaceAll(handleRegExp, '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');

    return cleaned;
  }

  Future<_ReferenceCheckResult> _compareWithFrenchReference(
    ChapterInput input,
    ParsedDocument document,
  ) async {
    final chapterNumber = DocxBuilder.extractKacouChapterNumber(input.title);
    if (chapterNumber == null) {
      return _ReferenceCheckResult.error(
        _strings.referenceTitleNumberMissing(),
      );
    }

    late final SermonReferenceResult reference;
    try {
      reference = await _referenceService.fetchReference(
        chapterNumber,
        locale: _referenceLocaleFor(input.language),
      );
    } catch (error) {
      return _ReferenceCheckResult.ok(
        _strings.referenceFetchFailed(chapterNumber, error),
      );
    }

    final localCount = DocxBuilder.paragraphCount(document);

    if (document.similarChapters == null &&
        input.similarChapters.trim().isEmpty &&
        reference.similarChapters != null) {
      return _ReferenceCheckResult.error(
        _strings.similarChaptersOnlineMissing(reference.similarChapters!),
      );
    }

    if (localCount != reference.paragraphCount) {
      return _ReferenceCheckResult.errors([
        _strings.paragraphCountMismatch(
          chapter: chapterNumber,
          localCount: localCount,
          referenceCount: reference.paragraphCount,
        ),
      ]);
    }

    return _ReferenceCheckResult.ok(
      _strings.referenceOk(chapter: chapterNumber, paragraphCount: localCount),
    );
  }

  Future<void> _shareGeneratedFile(String fileName, Uint8List bytes) async {
    if (kIsWeb) {
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        title: _strings.appTitle,
        files: [XFile(file.path, mimeType: _docxMimeType)],
      ),
    );
  }

  void _removeSource(DocumentSource source) {
    setState(() => _fileSources.remove(source));
  }

  void _clearAll() {
    setState(() {
      _chapterTitleController.clear();
      _subtitleController.clear();
      _similarChaptersController.clear();
      _documentLanguageController.clear();
      _fileNameController.text = 'document_genere';
      _selectedDocumentLanguage = null;
      _manualTextController.clear();
      _downloadUrlController.clear();
      _fileSources.clear();
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BrandMark(size: 30),
            const SizedBox(width: 10),
            Text(strings.appTitle),
          ],
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<AppLanguage>(
              value: _language,
              items: AppLanguage.values
                  .map(
                    (language) => DropdownMenuItem(
                      value: language,
                      child: Text(language.label),
                    ),
                  )
                  .toList(),
              onChanged: (language) {
                if (language != null) {
                  setState(() => _language = language);
                }
              },
            ),
          ),
          IconButton(
            tooltip: strings.clear,
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final editor = _InputPanel(
              strings: strings,
              chapterTitleController: _chapterTitleController,
              subtitleController: _subtitleController,
              similarChaptersController: _similarChaptersController,
              manualTextController: _manualTextController,
              downloadUrlController: _downloadUrlController,
              isDownloading: _isDownloading,
              onPickFiles: _pickFiles,
              onDownloadText: _downloadTextFromUrl,
            );
            final settings = _SettingsPanel(
              strings: strings,
              fileNameController: _fileNameController,
              documentLanguageController: _documentLanguageController,
              selectedDocumentLanguage: _selectedDocumentLanguage,
              onLanguageSelected: (language) {
                setState(() {
                  _selectedDocumentLanguage = language;
                  _documentLanguageController.text = language?.name ?? '';
                });
              },
              sources: _fileSources,
              status: _status,
              isGenerating: _isGenerating,
              onGenerate: _generate,
              onRemoveSource: _removeSource,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandHeader(strings: strings),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: editor),
                            const SizedBox(width: 20),
                            Expanded(flex: 2, child: settings),
                          ],
                        )
                      else ...[
                        editor,
                        const SizedBox(height: 16),
                        settings,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            strings.footer,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        border: Border.all(color: const Color(0xFFDCE8E5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const _BrandMark(size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.appTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(strings.tagline, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            strings.versionLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/brand/dnts-document.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _InputPanel extends StatelessWidget {
  const _InputPanel({
    required this.strings,
    required this.chapterTitleController,
    required this.subtitleController,
    required this.similarChaptersController,
    required this.manualTextController,
    required this.downloadUrlController,
    required this.isDownloading,
    required this.onPickFiles,
    required this.onDownloadText,
  });

  final AppStrings strings;
  final TextEditingController chapterTitleController;
  final TextEditingController subtitleController;
  final TextEditingController similarChaptersController;
  final TextEditingController manualTextController;
  final TextEditingController downloadUrlController;
  final bool isDownloading;
  final VoidCallback onPickFiles;
  final VoidCallback onDownloadText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: chapterTitleController,
          decoration: InputDecoration(
            labelText: strings.chapterTitle,
            hintText: strings.chapterTitleHint,
            suffixText: '*',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: subtitleController,
          decoration: InputDecoration(
            labelText: strings.subtitle,
            hintText: strings.subtitleHint,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: similarChaptersController,
          decoration: InputDecoration(
            labelText: strings.similarChapters,
            hintText: strings.similarChaptersHint,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          strings.workflowTips,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        Text(strings.inputTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        TextField(
          controller: manualTextController,
          minLines: 16,
          maxLines: 26,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(hintText: strings.inputHint),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onPickFiles,
          icon: const Icon(Icons.upload_file),
          label: Text(strings.addFiles),
        ),
        const SizedBox(height: 18),
        Text(strings.download, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final field = TextField(
              controller: downloadUrlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: strings.urlLabel,
                hintText: 'https://example.com/text.txt',
              ),
            );
            final button = FilledButton.icon(
              onPressed: isDownloading ? null : onDownloadText,
              icon: isDownloading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(strings.downloadButton),
            );

            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 10), button],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field),
                const SizedBox(width: 10),
                SizedBox(height: 56, child: button),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.strings,
    required this.fileNameController,
    required this.documentLanguageController,
    required this.selectedDocumentLanguage,
    required this.onLanguageSelected,
    required this.sources,
    required this.status,
    required this.isGenerating,
    required this.onGenerate,
    required this.onRemoveSource,
  });

  final AppStrings strings;
  final TextEditingController fileNameController;
  final TextEditingController documentLanguageController;
  final KacouLanguage? selectedDocumentLanguage;
  final ValueChanged<KacouLanguage?> onLanguageSelected;
  final List<DocumentSource> sources;
  final String? status;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final ValueChanged<DocumentSource> onRemoveSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.output, style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        DropdownButtonFormField<KacouLanguage>(
          initialValue: selectedDocumentLanguage,
          decoration: InputDecoration(labelText: strings.siteLanguage),
          items: _kacouLanguages
              .map(
                (language) => DropdownMenuItem(
                  value: language,
                  child: Text(language.name),
                ),
              )
              .toList(),
          onChanged: onLanguageSelected,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: documentLanguageController,
          decoration: InputDecoration(
            labelText: strings.documentLanguage,
            hintText: strings.documentLanguageHint,
            suffixText: '*',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: fileNameController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: strings.fileName,
            helperText: strings.fileNameRule,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: isGenerating ? null : onGenerate,
          icon: isGenerating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.description_outlined),
          label: Text(strings.generate),
        ),
        const SizedBox(height: 20),
        Text(strings.sources, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (sources.isEmpty)
          Text(strings.noSources, style: theme.textTheme.bodyMedium)
        else
          ...sources.map(
            (source) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                tileColor: theme.colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: const Icon(Icons.article_outlined),
                title: Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(strings.words(_wordCount(source.text))),
                trailing: IconButton(
                  tooltip: strings.remove,
                  onPressed: () => onRemoveSource(source),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
          ),
        if (status != null) ...[
          const SizedBox(height: 14),
          _StatusMessage(text: status!),
        ],
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = RegExp(
      r'(erreur|error|erro|correction|manquant|missing|falta|incorrect|impossible)',
      caseSensitive: false,
    ).hasMatch(text);
    final isWarning = RegExp(
      r'(detecte|detected|detectado|offline|hors connexion)',
      caseSensitive: false,
    ).hasMatch(text);
    final lines = text.split('\n');
    final title = lines.first.trim();
    final body = lines.skip(1).join('\n').trim();
    final background = isError
        ? const Color(0xFFFFF1F0)
        : isWarning
        ? const Color(0xFFFFF8E1)
        : const Color(0xFFEAF7F4);
    final foreground = isError
        ? const Color(0xFF9F1239)
        : isWarning
        ? const Color(0xFF854D0E)
        : const Color(0xFF0F5C52);
    final border = isError
        ? const Color(0xFFE11D48)
        : isWarning
        ? const Color(0xFFF59E0B)
        : const Color(0xFF1F7A6D);
    final icon = isError
        ? Icons.error_outline
        : isWarning
        ? Icons.report_problem_outlined
        : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border(left: BorderSide(color: border, width: 5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _wordCount(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .length;
}

String _fileTitle(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot <= 0 ? fileName : fileName.substring(0, dot);
}

String _normalizedFileName(String value) {
  final base = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), ' ');
  final name = base.isEmpty ? 'document_genere' : base;
  return name.toLowerCase().endsWith('.docx') ? name : '$name.docx';
}

String _automaticFileName({
  required int chapterNumber,
  required String language,
}) {
  final normalizedLanguage = _fileNamePart(language);
  return _normalizedFileName('KACOU $chapterNumber $normalizedLanguage');
}

String _referenceLocaleFor(String language) {
  final normalized = _normalizeLanguageName(language);
  final match = _kacouLanguages.where(
    (item) => _normalizeLanguageName(item.name) == normalized,
  );
  return match.isEmpty ? 'fr-fr' : match.first.locale ?? 'fr-fr';
}

String _fileNamePart(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return normalized.isEmpty ? 'langue' : normalized;
}

String _normalizeLanguageName(String value) {
  const replacements = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };
  var output = value.trim().toLowerCase();
  for (final entry in replacements.entries) {
    output = output.replaceAll(entry.key, entry.value);
  }
  return output.replaceAll(RegExp(r'\s+'), ' ');
}

bool _isVersionNewer(String candidate, String current) {
  final candidateParts = _versionParts(candidate);
  final currentParts = _versionParts(current);
  final length = candidateParts.length > currentParts.length
      ? candidateParts.length
      : currentParts.length;

  for (var index = 0; index < length; index++) {
    final candidatePart = index < candidateParts.length
        ? candidateParts[index]
        : 0;
    final currentPart = index < currentParts.length ? currentParts[index] : 0;
    if (candidatePart > currentPart) {
      return true;
    }
    if (candidatePart < currentPart) {
      return false;
    }
  }

  return false;
}

List<int> _versionParts(String value) {
  return value
      .split(RegExp(r'[.+-]'))
      .map((part) => int.tryParse(part) ?? 0)
      .toList(growable: false);
}

const _docxMimeType =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
