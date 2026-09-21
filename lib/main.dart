import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

import 'docx_builder.dart';
import 'cloud/cloud_models.dart';
import 'cloud/cloud_panel.dart';
import 'cloud/storage_gate.dart';
import 'pdf_web_stub.dart' if (dart.library.js_interop) 'pdf_web.dart';
import 'ai_assistant.dart';
import 'sermon_reference.dart';

enum DesignMode {
  aura,
  edition,
  nocturne;

  String get label => switch (this) {
    DesignMode.aura => 'Aura',
    DesignMode.edition => 'Édition',
    DesignMode.nocturne => 'Nocturne',
  };

  String get description => switch (this) {
    DesignMode.aura => 'Violet lumineux',
    DesignMode.edition => 'Papier éditorial',
    DesignMode.nocturne => 'Studio sombre',
  };
}

class DesignPalette {
  const DesignPalette({
    required this.background,
    required this.backgroundSecondary,
    required this.surface,
    required this.surfaceStrong,
    required this.accent,
    required this.accentSecondary,
    required this.accentText,
    required this.text,
    required this.mutedText,
    required this.input,
    required this.border,
  });

  final Color background;
  final Color backgroundSecondary;
  final Color surface;
  final Color surfaceStrong;
  final Color accent;
  final Color accentSecondary;
  final Color accentText;
  final Color text;
  final Color mutedText;
  final Color input;
  final Color border;

  Color get inputText =>
      input.computeLuminance() > 0.5 ? const Color(0xFF20243A) : text;

  Color get inputHint => input.computeLuminance() > 0.5
      ? const Color(0xFF606578)
      : const Color(0xFFBDB2CB);

  static DesignPalette forMode(DesignMode mode) => switch (mode) {
    DesignMode.aura => const DesignPalette(
      background: Color(0xFF26005E),
      backgroundSecondary: Color(0xFF8A087D),
      surface: Color(0x6626004F),
      surfaceStrong: Color(0xFF4B176F),
      accent: Color(0xFFE13DE7),
      accentSecondary: Color(0xFF7A35E8),
      accentText: Colors.white,
      text: Colors.white,
      mutedText: Color(0xFFD7C4E7),
      input: Color(0xFFF9F8FC),
      border: Color(0x44FFFFFF),
    ),
    DesignMode.edition => const DesignPalette(
      background: Color(0xFFE8E1D8),
      backgroundSecondary: Color(0xFFF4ECE1),
      surface: Color(0xFFF7F1E8),
      surfaceStrong: Color(0xFFFFFCF6),
      accent: Color(0xFF765D75),
      accentSecondary: Color(0xFFB48A65),
      accentText: Colors.white,
      text: Color(0xFF3E3937),
      mutedText: Color(0xFF695F59),
      input: Color(0xFFFFFCF6),
      border: Color(0xFFD9CDBC),
    ),
    DesignMode.nocturne => const DesignPalette(
      background: Color(0xFF110D17),
      backgroundSecondary: Color(0xFF362249),
      surface: Color(0xE61B1721),
      surfaceStrong: Color(0xFF241C2E),
      accent: Color(0xFFC2A0FF),
      accentSecondary: Color(0xFF8B6BD0),
      accentText: Color(0xFF241235),
      text: Color(0xFFF1EAF8),
      mutedText: Color(0xFFB6A9C2),
      input: Color(0xFF211C29),
      border: Color(0x66352B40),
    ),
  };
}

const _appName = 'DEC DOCX';
const _appVersion = '1.9.1';
const _updateManifestUrl = String.fromEnvironment(
  'DEC_DOCX_UPDATE_MANIFEST_URL',
  defaultValue: 'https://nikaisedoua-source.github.io/dec-docx/update.json',
);
// Syncfusion Flutter 18.3+ no longer exposes license-key registration.
// https://help.syncfusion.com/flutter/licensing/overview
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
  const KacouLanguage(this.name);

  final String name;
}

const _kacouLanguages = <KacouLanguage>[
  KacouLanguage('francais'),
  KacouLanguage('anglais'),
  KacouLanguage('espagnol'),
  KacouLanguage('portugais'),
  KacouLanguage('allemand'),
  KacouLanguage('russe'),
  KacouLanguage('italien'),
  KacouLanguage('attie'),
  KacouLanguage('agni'),
  KacouLanguage('wan'),
  KacouLanguage('yemba'),
  KacouLanguage('fon'),
  KacouLanguage('kikongo'),
  KacouLanguage('gouin'),
  KacouLanguage('moore'),
  KacouLanguage('bambara'),
  KacouLanguage('chinois'),
];

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String get appTitle => _appName;
  String get assistant => _text(
    'Assistant de contrôle',
    'Review assistant',
    'Asistente de revisión',
    'Assistente de revisão',
  );
  String get assistantDescription => _text(
    'Analyse locale facultative : l’assistant ne modifie jamais ton texte.',
    'Optional local review: the assistant never edits your text.',
    'Revisión local opcional: el asistente nunca edita tu texto.',
    'Revisão local opcional: o assistente nunca edita seu texto.',
  );
  String get assistantRun => _text(
    'Analyser le chapitre',
    'Review chapter',
    'Analizar capítulo',
    'Analisar capítulo',
  );
  String get assistantSetup => _text(
    'Nécessite Ollama + gemma3:4b sur cet ordinateur.',
    'Requires Ollama + gemma3:4b on this computer.',
    'Requiere Ollama + gemma3:4b en este equipo.',
    'Requer Ollama + gemma3:4b neste computador.',
  );
  String get issues => _text(
    'Index des contrôles',
    'Validation index',
    'Índice de validación',
    'Índice de validação',
  );
  String get openInWord => _text(
    'Ouvrir dans Word',
    'Open in Word',
    'Abrir en Word',
    'Abrir no Word',
  );
  String get shareDocument => _text(
    'Partager le document',
    'Share document',
    'Compartir documento',
    'Compartilhar documento',
  );
  String get openFolder =>
      _text('Ouvrir le dossier', 'Open folder', 'Abrir carpeta', 'Abrir pasta');
  String get personName => _text(
    'Personne ou groupe',
    'Person or group',
    'Persona o grupo',
    'Pessoa ou grupo',
  );
  String get personNameHint => _text(
    'Exemple : Jean, équipe Chine...',
    'Example: Jean, China team...',
    'Ejemplo: Juan, equipo chino...',
    'Exemplo: João, equipe chinesa...',
  );
  String get localLibrary => _text(
    'Bibliothèque locale',
    'Local library',
    'Biblioteca local',
    'Biblioteca local',
  );
  String get localLibraryDescription => _text(
    'Une copie est conservée par langue et par personne sur cet appareil.',
    'A copy is kept by language and person on this device.',
    'Se conserva una copia por idioma y persona en este dispositivo.',
    'Uma cópia é guardada por idioma e pessoa neste dispositivo.',
  );
  String savedInLibrary(String path) => _text(
    'Copie conservée dans $path',
    'Copy saved in $path',
    'Copia guardada en $path',
    'Cópia guardada em $path',
  );
  String get chineseStructureTitle => _text(
    'Format chinois actif',
    'Chinese format active',
    'Formato chino activo',
    'Formato chinês ativo',
  );
  String get chineseStructureDescription => _text(
    'Chaque verset réunit le texte chinois et sa transcription pinyin, présentée juste en dessous. Les numéros pinyin sont vérifiés ; les titres de partie restent séparés et en gras.',
    'Each verse groups Chinese text with its pinyin transcription directly below. Pinyin numbers are checked; section headings stay separate and bold.',
    'Cada versículo reúne el texto chino y su pinyin justo debajo. Se verifican los números pinyin; los títulos quedan separados y en negrita.',
    'Cada versículo reúne o texto chinês e o pinyin logo abaixo. Os números pinyin são verificados; os títulos ficam separados e em negrito.',
  );
  String get openDocumentFailed => _text(
    'Impossible d’ouvrir le document avec l’application associée.',
    'Could not open the document with the associated app.',
    'No se pudo abrir el documento con la aplicación asociada.',
    'Não foi possível abrir o documento com o aplicativo associado.',
  );
  String get optionalDetails => _text(
    'Sous-titre et chapitres similaires',
    'Subtitle and similar chapters',
    'Subtítulo y capítulos similares',
    'Subtítulo e capítulos semelhantes',
  );
  String get importLink => _text(
    'Importer depuis un lien',
    'Import from a link',
    'Importar desde un enlace',
    'Importar de um link',
  );
  String get chooseLanguage => _text(
    'Choisir une langue',
    'Choose a language',
    'Elegir un idioma',
    'Escolher um idioma',
  );
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
  String get chapterDetails => _text(
    'Informations du chapitre',
    'Chapter details',
    'Información del capítulo',
    'Informações do capítulo',
  );
  String get chapterDetailsDescription => _text(
    'Renseigne les informations qui apparaîtront dans le document final.',
    'Enter the information that will appear in the final document.',
    'Introduce la información que aparecerá en el documento final.',
    'Informe os dados que aparecerão no documento final.',
  );
  String get contentDescription => _text(
    'Colle le texte ou importe un fichier existant.',
    'Paste the text or import an existing file.',
    'Pega el texto o importa un archivo existente.',
    'Cole o texto ou importe um arquivo existente.',
  );
  String get exportDescription => _text(
    'Vérifie le nom puis génère ton document.',
    'Check the name, then generate your document.',
    'Comprueba el nombre y genera tu documento.',
    'Confira o nome e gere seu documento.',
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
    'KACOU 1 : C’est ici la voix de Matthieu 25 :6',
    'KACOU 1: This is the voice of Matthew 25:6',
    'KACOU 1: Aqui esta la voz de Mateo 25:6',
    'KACOU 1: Aqui esta a voz de Mateus 25:6',
  );
  String get chapterTitleLowercaseHelp => _text(
    'Écris le titre normalement, pas tout en majuscules. Les débuts de phrase et les noms propres peuvent avoir une majuscule.',
    'Use normal capitalization, not all caps. Sentences and proper names may start with a capital letter.',
    'Usa mayusculas normales, no todo en mayusculas. Las frases y los nombres propios pueden empezar con mayuscula.',
    'Use maiusculas normalmente, nao escreva tudo em maiusculas. Frases e nomes proprios podem comecar com maiuscula.',
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
    'Importer un fichier',
    'Import a file',
    'Importar y reparar TXT, MD, DOCX o PDF',
    'Importar e reparar TXT, MD, DOCX ou PDF',
  );
  String get pdfReadFailed => _text(
    'PDF illisible : utilise un PDF contenant du texte sélectionnable ou convertis le fichier en TXT.',
    'Unreadable PDF: use a PDF with selectable text or convert the file to TXT.',
    'PDF ilegible: usa un PDF con texto seleccionable o convierte el archivo a TXT.',
    'PDF ilegível: use um PDF com texto selecionável ou converta o arquivo para TXT.',
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
    'Corriger et générer',
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
    'DEC DOCX $_appVersion : tous les documents sont compares avec le chapitre francais de reference.',
    'DEC DOCX $_appVersion: all documents are compared with the French reference chapter.',
    'DEC DOCX $_appVersion: todos los documentos se comparan con el capitulo frances de referencia.',
    'DEC DOCX $_appVersion: todos os documentos sao comparados com o capitulo frances de referencia.',
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
  String updateAvailable({required String version, required String message}) =>
      _text(
        'Mise à jour disponible : DEC DOCX $version\n$message',
        'Update available: DEC DOCX $version\n$message',
        'Actualización disponible: DEC DOCX $version\n$message',
        'Atualização disponível: DEC DOCX $version\n$message',
      );
  String get updateNow =>
      _text('Mettre à jour', 'Update', 'Actualizar', 'Atualizar');
  String get updateDownloadFailed => _text(
    'Impossible d’ouvrir le téléchargement de la mise à jour.',
    'Unable to open the update download.',
    'No se pudo abrir la descarga de la actualización.',
    'Não foi possível abrir o download da atualização.',
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
  const DocxGeneratorApp({super.key, this.skipStorageSetup = false});

  final bool skipStorageSetup;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6157F5),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F5FA),
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Arial', 'sans-serif'],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF3F5FA),
          foregroundColor: Color(0xFF20243A),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: Color(0xFFE7E9F2)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F8FC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E5EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E5EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF6157F5), width: 2),
          ),
          helperStyle: const TextStyle(color: Color(0xFF74798D), height: 1.35),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: skipStorageSetup
          ? const GeneratorPage()
          : const StorageGate(child: GeneratorPage()),
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

class _GeneratorPageState extends State<GeneratorPage>
    with SingleTickerProviderStateMixin {
  final _chapterTitleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _similarChaptersController = TextEditingController();
  final _manualTextController = TextEditingController();
  final _downloadUrlController = TextEditingController();
  final _fileNameController = TextEditingController(text: 'document_genere');
  final _documentLanguageController = TextEditingController();
  final _personNameController = TextEditingController();
  final _referenceService = const SermonReferenceService();
  final _aiAssistant = const LocalAiAssistant();
  final List<DocumentSource> _fileSources = [];
  AppLanguage _language = AppLanguage.fr;
  DesignMode _designMode = DesignMode.aura;
  bool _isGenerating = false;
  bool _isDownloading = false;
  bool _isAiReviewing = false;
  String? _status;
  String? _generatedPath;
  String? _libraryPath;
  CloudDocument? _cloudDocument;
  String? _aiReview;
  List<String> _issueMessages = const [];
  String? _availableUpdateVersion;
  String? _updateDownloadUrl;
  late final AnimationController _ambientController;

  AppStrings get _strings => AppStrings(_language);
  DesignPalette get _palette => DesignPalette.forMode(_designMode);

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _chapterTitleController.addListener(_syncAutomaticFileName);
    _documentLanguageController.addListener(_syncAutomaticFileName);
    _checkForUpdateNotice();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _chapterTitleController.removeListener(_syncAutomaticFileName);
    _documentLanguageController.removeListener(_syncAutomaticFileName);
    _chapterTitleController.dispose();
    _subtitleController.dispose();
    _similarChaptersController.dispose();
    _manualTextController.dispose();
    _downloadUrlController.dispose();
    _fileNameController.dispose();
    _documentLanguageController.dispose();
    _personNameController.dispose();
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

  void _setStatus(String? value, {List<String>? issues}) {
    if (!mounted) return;
    setState(() {
      _status = value;
      _issueMessages =
          issues ??
          (value != null &&
                  RegExp(
                    r'(erreur|error|erro|manquant|missing|incorrect|impossible)',
                    caseSensitive: false,
                  ).hasMatch(value)
              ? _extractIssueMessages(value)
              : const []);
    });
  }

  List<String> _extractIssueMessages(String? value) {
    if (value == null || value.trim().isEmpty) return const [];
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.length <= 1) return lines;
    return lines.skip(1).toList(growable: false);
  }

  Future<void> _reviewWithAi() async {
    if (_manualTextController.text.trim().isEmpty && _fileSources.isEmpty) {
      _setStatus(_strings.assistantSetup);
      return;
    }
    setState(() {
      _isAiReviewing = true;
      _aiReview = null;
    });
    try {
      final text = [
        if (_manualTextController.text.trim().isNotEmpty)
          _manualTextController.text,
        ..._fileSources.map((source) => source.text),
      ].join('\n\n');
      final review = await _aiAssistant.reviewChapter(
        title: _chapterTitleController.text,
        language: _documentLanguageController.text,
        text: text,
      );
      if (mounted) setState(() => _aiReview = review);
    } catch (error) {
      _setStatus('${_strings.assistantSetup}\n$error');
    } finally {
      if (mounted) setState(() => _isAiReviewing = false);
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

    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        return;
      }

      final latestVersion = payload['version']?.toString().trim() ?? '';
      final fallbackUrl = payload['downloadUrl']?.toString().trim() ?? '';
      final downloadUrl = kIsWeb
          ? payload['webUrl']?.toString().trim() ?? fallbackUrl
          : Platform.isMacOS
          ? payload['macDownloadUrl']?.toString().trim() ?? fallbackUrl
          : Platform.isWindows
          ? payload['windowsDownloadUrl']?.toString().trim() ?? fallbackUrl
          : fallbackUrl;

      if (latestVersion.isEmpty ||
          !_isVersionNewer(latestVersion, _appVersion) ||
          !mounted) {
        return;
      }

      setState(() {
        _updateDownloadUrl = downloadUrl;
        _availableUpdateVersion = latestVersion;
      });
    } catch (_) {
      // Update checks are advisory. Offline users can keep working.
    }
  }

  Future<void> _openUpdateDownload() async {
    final uri = Uri.tryParse(_updateDownloadUrl ?? '');
    if (uri == null ||
        !uri.hasScheme ||
        !await launchUrl(
          uri,
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        )) {
      if (mounted) {
        _setStatus(_strings.updateDownloadFailed);
      }
    }
  }

  Future<void> _openGeneratedDocument() async {
    final path = _generatedPath ?? _libraryPath;
    if (path == null || kIsWeb) return;
    final opened = await launchUrl(
      Uri.file(path),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _setStatus(
        _strings.openDocumentFailed,
        issues: [_strings.openDocumentFailed],
      );
    }
  }

  Future<String?> _saveInLibrary(String fileName, Uint8List bytes) async {
    if (kIsWeb) return null;
    final root = await getApplicationDocumentsDirectory();
    final language = _safeFolderName(
      _documentLanguageController.text,
      fallback: 'sans-langue',
    );
    final person = _safeFolderName(
      _personNameController.text,
      fallback: 'sans-personne',
    );
    final directory = Directory('${root.path}/DEC DOCX/$language/$person');
    await directory.create(recursive: true);
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _safeFolderName(String value, {required String fallback}) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  Future<void> _shareDocumentPath() async {
    final path = _libraryPath ?? _generatedPath;
    if (path == null || kIsWeb) return;
    await SharePlus.instance.share(
      ShareParams(
        title: _strings.appTitle,
        files: [XFile(path, mimeType: _docxMimeType)],
      ),
    );
  }

  Future<void> _openLibraryFolder() async {
    final path = _libraryPath;
    if (path == null || kIsWeb) return;
    final opened = await launchUrl(
      Uri.file(File(path).parent.path),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      _setStatus(_strings.openDocumentFailed);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'docx', 'pdf'],
      withData: true,
    );

    if (result == null) {
      return;
    }

    final imported = <DocumentSource>[];
    var pdfError = false;
    for (final file in result.files) {
      final bytes = await _readPlatformFile(file);
      if (bytes == null) {
        continue;
      }

      final extension = file.extension?.toLowerCase();
      late final String rawText;
      try {
        rawText = extension == 'pdf'
            ? await _extractPdfText(bytes)
            : extension == 'docx'
            ? DocxBuilder.extractTextFromDocx(bytes)
            : utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        if (extension == 'pdf') {
          pdfError = true;
        }
        continue;
      }
      if (rawText.trim().isEmpty) {
        if (extension == 'pdf') {
          pdfError = true;
        }
        continue;
      }
      final text = _normalizeWebText(rawText);

      imported.add(DocumentSource(name: _fileTitle(file.name), text: text));
    }

    setState(() {
      _fileSources.addAll(imported);
      _status = imported.isEmpty
          ? (pdfError ? _strings.pdfReadFailed : _strings.unreadableFile)
          : _strings.filesAdded(imported.length);
      _issueMessages = const [];
    });
  }

  Future<String> _extractPdfText(Uint8List bytes) async {
    if (kIsWeb) return extractWebPdfText(bytes);
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  Future<void> _downloadTextFromUrl() async {
    final uri = Uri.tryParse(_downloadUrlController.text.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _setStatus(_strings.invalidUrl);
      return;
    }

    setState(() {
      _isDownloading = true;
      _status = null;
      _generatedPath = null;
      _issueMessages = const [];
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
        _issueMessages = const [];
      });
    } catch (error) {
      _setStatus(_strings.downloadFailed(error));
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
      _issueMessages = const [];
      _generatedPath = null;
      _libraryPath = null;
    });

    try {
      if (documentLanguage.isEmpty) {
        _setStatus(
          _strings.languageRequired,
          issues: [_strings.languageRequired],
        );
        return;
      }

      final validation = DocxBuilder.validateChapter(input);
      if (validation.hasErrors) {
        _setStatus(
          _strings.validationErrors(validation.errors),
          issues: validation.errors,
        );
        return;
      }

      final document = validation.documents.first;
      final referenceCheck = await _compareWithFrenchReference(input, document);
      if (referenceCheck.errors.isNotEmpty) {
        _setStatus(
          _strings.validationErrors(referenceCheck.errors),
          issues: referenceCheck.errors,
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
      setState(
        () => _cloudDocument = CloudDocument(
          bytes,
          fileName,
          documentLanguage,
          _personNameController.text,
        ),
      );

      String? libraryPath;
      try {
        libraryPath = await _saveInLibrary(fileName, bytes);
      } catch (_) {
        // The user-selected save location remains the source of truth if the
        // app library is unavailable on a restricted device.
      }
      _libraryPath = libraryPath;

      final path = await FilePicker.saveFile(
        dialogTitle: _strings.generate,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['docx'],
        bytes: bytes,
      );

      if (path == null) {
        if (libraryPath != null) {
          await _shareDocumentPathOverride(libraryPath);
        } else {
          await _shareGeneratedFile(fileName, bytes);
        }
        final savedMessage = libraryPath == null
            ? _strings.shared
            : _strings.savedInLibrary(libraryPath);
        _setStatus('$checkMessage\n$savedMessage');
      } else {
        _generatedPath = path;
        final savedMessage = libraryPath == null
            ? _strings.created(path)
            : '${_strings.created(path)}\n${_strings.savedInLibrary(libraryPath)}';
        _setStatus('$checkMessage\n$savedMessage');
      }
    } catch (error) {
      _setStatus(_strings.error(error));
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
      reference = await _referenceService.fetchFrenchParagraphCount(
        chapterNumber,
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

    await _shareDocumentPathOverride(file.path);
  }

  Future<void> _shareDocumentPathOverride(String path) async {
    await SharePlus.instance.share(
      ShareParams(
        title: _strings.appTitle,
        files: [XFile(path, mimeType: _docxMimeType)],
      ),
    );
  }

  Future<void> _exportCloudCopy(String name, Uint8List bytes) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Enregistrer dans mes fichiers ou mon cloud',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['docx'],
      bytes: bytes,
    );
    if (!kIsWeb && path != null) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
  }

  void _importCloudCopy(String name, Uint8List bytes) {
    final text = DocxBuilder.extractTextFromDocx(bytes);
    if (text.trim().isEmpty) {
      throw const FormatException(
        'Ce fichier Word ne contient pas de texte exploitable.',
      );
    }
    setState(() => _fileSources.add(DocumentSource(name: name, text: text)));
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
      _personNameController.clear();
      _fileNameController.text = 'document_genere';
      _manualTextController.clear();
      _downloadUrlController.clear();
      _fileSources.clear();
      _cloudDocument = null;
      _status = null;
      _aiReview = null;
      _issueMessages = const [];
      _generatedPath = null;
      _libraryPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final theme = Theme.of(context);
    final palette = _palette;
    final pageTheme = theme.copyWith(
      scaffoldBackgroundColor: palette.background,
      textTheme: theme.textTheme.copyWith(
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(
          color: palette.inputText,
          fontSize: 15,
          height: 1.45,
        ),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(
          color: palette.inputText,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.inputText, fontSize: 14),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: const Size(0, 44),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          disabledForegroundColor: palette.mutedText.withValues(alpha: .65),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: palette.input,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
        labelStyle: TextStyle(
          color: palette.inputHint,
          fontSize: 14,
          height: 1.4,
        ),
        hintStyle: TextStyle(
          color: palette.inputHint,
          fontSize: 14,
          height: 1.4,
        ),
        prefixIconColor: palette.inputHint,
        suffixIconColor: palette.inputHint,
        helperMaxLines: 3,
        helperStyle: TextStyle(
          color: palette.mutedText,
          fontSize: 12,
          height: 1.5,
        ),
        floatingLabelStyle: TextStyle(
          color: palette.text,
          backgroundColor: palette.surfaceStrong,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final compact = MediaQuery.sizeOf(context).width < 920;
    final generateButton = _PulsingGenerateButton(
      palette: palette,
      isGenerating: _isGenerating,
      label: strings.generate,
      onPressed: _generate,
    );

    return Theme(
      data: pageTheme,
      child: Scaffold(
        backgroundColor: palette.background,
        bottomNavigationBar: compact
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_status != null) ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: SingleChildScrollView(
                            child: _issueMessages.isNotEmpty
                                ? _IssueIndex(
                                    issues: _issueMessages,
                                    title: strings.issues,
                                    status: _status!,
                                  )
                                : _StatusMessage(text: _status!),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      generateButton,
                    ],
                  ),
                ),
              )
            : null,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: _AuroraBackground(
                  animation: _ambientController,
                  palette: palette,
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  final editor = _InputPanel(
                    strings: strings,
                    chapterTitleController: _chapterTitleController,
                    subtitleController: _subtitleController,
                    similarChaptersController: _similarChaptersController,
                    manualTextController: _manualTextController,
                    downloadUrlController: _downloadUrlController,
                    documentLanguageController: _documentLanguageController,
                    onLanguageSelected: (language) {
                      setState(() {
                        _documentLanguageController.text = language?.name ?? '';
                      });
                    },
                    isDownloading: _isDownloading,
                    onPickFiles: _pickFiles,
                    onDownloadText: _downloadTextFromUrl,
                    palette: palette,
                  );
                  final settings = _SettingsPanel(
                    strings: strings,
                    fileNameController: _fileNameController,
                    personNameController: _personNameController,
                    sources: _fileSources,
                    status: wide ? _status : null,
                    isGenerating: _isGenerating,
                    showGenerateButton: wide,
                    aiReview: _aiReview,
                    isAiReviewing: _isAiReviewing,
                    onReviewWithAi: _reviewWithAi,
                    issues: _issueMessages,
                    generatedPath: _generatedPath,
                    libraryPath: _libraryPath,
                    cloudPanel: CloudPanel(
                      document: _cloudDocument,
                      onImport: _importCloudCopy,
                      onPickFiles: _pickFiles,
                      onExport: _exportCloudCopy,
                      textColor: palette.text,
                      mutedColor: palette.mutedText,
                      accent: palette.accent,
                      surface: palette.surfaceStrong,
                    ),
                    onOpenGenerated: _openGeneratedDocument,
                    onShareGenerated: _shareDocumentPath,
                    onOpenLibraryFolder: _openLibraryFolder,
                    onGenerate: _generate,
                    onRemoveSource: _removeSource,
                    palette: palette,
                  );

                  final horizontalPadding = constraints.maxWidth < 600
                      ? 14.0
                      : 28.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      14,
                      horizontalPadding,
                      20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: _PageEntrance(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CompactTopBar(
                                strings: strings,
                                language: _language,
                                onLanguageChanged: (language) =>
                                    setState(() => _language = language),
                                onClear: _clearAll,
                                designMode: _designMode,
                                onDesignModeChanged: (mode) =>
                                    setState(() => _designMode = mode),
                                palette: palette,
                              ),
                              const SizedBox(height: 16),
                              if (_availableUpdateVersion != null) ...[
                                _AnimatedUpdateBanner(
                                  buttonLabel:
                                      '${strings.updateNow} — v$_availableUpdateVersion',
                                  onUpdate: _openUpdateDownload,
                                ),
                                const SizedBox(height: 12),
                              ],
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 420),
                                reverseDuration: const Duration(
                                  milliseconds: 220,
                                ),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: <Widget>[...previous, ?current],
                                ),
                                child: wide
                                    ? Row(
                                        key: ValueKey(_designMode),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(flex: 7, child: editor),
                                          const SizedBox(width: 20),
                                          Expanded(flex: 3, child: settings),
                                        ],
                                      )
                                    : Column(
                                        key: ValueKey('mobile-$_designMode'),
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          editor,
                                          const SizedBox(height: 16),
                                          settings,
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                strings.versionLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFD5BFE6),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground({required this.animation, required this.palette});

  final Animation<double> animation;
  final DesignPalette palette;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final value = animation.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1 + value * 0.35, -1),
              end: Alignment(1 - value * 0.2, 1),
              colors: [
                palette.background,
                palette.backgroundSecondary,
                palette.accentSecondary,
                palette.background,
              ],
              stops: const [0, 0.34, 0.7, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -120 + value * 90,
                bottom: -180 + value * 50,
                child: _GlowOrb(
                  size: 520,
                  color: palette.accent.withValues(alpha: 0.28),
                ),
              ),
              Positioned(
                right: -150 + value * 70,
                top: -130 + value * 55,
                child: _GlowOrb(
                  size: 500,
                  color: palette.accentSecondary.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.strings,
    required this.language,
    required this.onLanguageChanged,
    required this.onClear,
    required this.designMode,
    required this.onDesignModeChanged,
    required this.palette,
  });

  final AppStrings strings;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onClear;
  final DesignMode designMode;
  final ValueChanged<DesignMode> onDesignModeChanged;
  final DesignPalette palette;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 420) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _BrandMark(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  strings.appTitle,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: strings.clear,
                onPressed: onClear,
                icon: Icon(Icons.restart_alt_rounded, color: palette.text),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DesignModeControl(
                mode: designMode,
                palette: palette,
                onChanged: onDesignModeChanged,
              ),
              _LanguageControl(
                language: language,
                onChanged: onLanguageChanged,
                palette: palette,
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        const _BrandMark(size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            strings.appTitle,
            style: TextStyle(
              color: palette.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _DesignModeControl(
          mode: designMode,
          palette: palette,
          onChanged: onDesignModeChanged,
        ),
        const SizedBox(width: 8),
        _LanguageControl(
          language: language,
          onChanged: onLanguageChanged,
          palette: palette,
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: strings.clear,
          onPressed: onClear,
          icon: Icon(Icons.restart_alt_rounded, color: palette.text),
        ),
      ],
    );
  }
}

class _LanguageControl extends StatelessWidget {
  const _LanguageControl({
    required this.language,
    required this.onChanged,
    required this.palette,
  });

  final AppLanguage language;
  final ValueChanged<AppLanguage> onChanged;
  final DesignPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 11, right: 4),
      decoration: BoxDecoration(
        color: palette.input,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: palette.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: language,
          dropdownColor: palette.input,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: palette.inputText,
          ),
          style: TextStyle(
            color: palette.inputText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          items: AppLanguage.values
              .map(
                (item) =>
                    DropdownMenuItem(value: item, child: Text(item.label)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _DesignModeControl extends StatelessWidget {
  const _DesignModeControl({
    required this.mode,
    required this.palette,
    required this.onChanged,
  });

  final DesignMode mode;
  final DesignPalette palette;
  final ValueChanged<DesignMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DesignMode>(
      tooltip: 'Changer de style',
      color: palette.surfaceStrong,
      onSelected: onChanged,
      itemBuilder: (context) => DesignMode.values
          .map(
            (item) => PopupMenuItem(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item == mode
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: palette.accent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${item.label} · ${item.description}',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surfaceStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette_outlined, color: palette.accent, size: 17),
            const SizedBox(width: 6),
            Text(
              mode.label,
              style: TextStyle(
                color: palette.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageEntrance extends StatelessWidget {
  const _PageEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      child: child,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

class _AnimatedUpdateBanner extends StatefulWidget {
  const _AnimatedUpdateBanner({
    required this.buttonLabel,
    required this.onUpdate,
  });

  final String buttonLabel;
  final VoidCallback onUpdate;

  @override
  State<_AnimatedUpdateBanner> createState() => _AnimatedUpdateBannerState();
}

class _AnimatedUpdateBannerState extends State<_AnimatedUpdateBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.97,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ScaleTransition(
        scale: _controller,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF008B95), Color(0xFF005B65)],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55008B95),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onUpdate,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.system_update_alt_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      widget.buttonLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
        'assets/brand/dnts-document.webp',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    required this.palette,
  });

  final String step;
  final IconData icon;
  final String title;
  final String description;
  final Widget child;
  final DesignPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330E001E),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.accent, palette.accentSecondary],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      step,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.mutedText,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
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
    required this.documentLanguageController,
    required this.onLanguageSelected,
    required this.isDownloading,
    required this.onPickFiles,
    required this.onDownloadText,
    required this.palette,
  });

  final AppStrings strings;
  final TextEditingController chapterTitleController;
  final TextEditingController subtitleController;
  final TextEditingController similarChaptersController;
  final TextEditingController manualTextController;
  final TextEditingController downloadUrlController;
  final TextEditingController documentLanguageController;
  final ValueChanged<KacouLanguage?> onLanguageSelected;
  final bool isDownloading;
  final VoidCallback onPickFiles;
  final VoidCallback onDownloadText;
  final DesignPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          step: '01',
          icon: Icons.edit_note_rounded,
          title: strings.chapterDetails,
          description: strings.chapterDetailsDescription,
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: chapterTitleController,
                decoration: InputDecoration(
                  labelText: strings.chapterTitle,
                  hintText: strings.chapterTitleHint,
                  suffixIcon: Tooltip(
                    message: strings.chapterTitleLowercaseHelp,
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(Icons.info_outline_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: documentLanguageController,
                decoration: InputDecoration(
                  labelText: strings.documentLanguage,
                  hintText: strings.documentLanguageHint,
                  prefixIcon: const Icon(Icons.language_rounded),
                  suffixIcon: PopupMenuButton<KacouLanguage>(
                    tooltip: strings.chooseLanguage,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    onSelected: onLanguageSelected,
                    itemBuilder: (context) => _kacouLanguages
                        .map(
                          (language) => PopupMenuItem(
                            value: language,
                            child: Text(language.name),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: documentLanguageController,
                builder: (context, value, child) {
                  final language = value.text.toLowerCase();
                  final isChinese =
                      language.contains('chinois') ||
                      language.contains('chinese') ||
                      language.contains('zh');
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: isChinese
                        ? _ChineseStructureCard(
                            key: const ValueKey('chinese-format'),
                            strings: strings,
                            palette: palette,
                          )
                        : const SizedBox.shrink(key: ValueKey('other-format')),
                  );
                },
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                key: const PageStorageKey('chapter-options'),
                maintainState: true,
                initiallyExpanded:
                    subtitleController.text.isNotEmpty ||
                    similarChaptersController.text.isNotEmpty,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
                textColor: palette.text,
                collapsedTextColor: palette.mutedText,
                iconColor: palette.accent,
                collapsedIconColor: palette.mutedText,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  strings.optionalDetails,
                  style: TextStyle(fontSize: 14, color: palette.text),
                ),
                children: [
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
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: strings.similarChapters,
                      hintText: strings.similarChaptersHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          step: '02',
          icon: Icons.article_outlined,
          title: strings.inputTitle,
          description: strings.contentDescription,
          palette: palette,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.text,
                  side: BorderSide(
                    color: palette.accent.withValues(alpha: .65),
                  ),
                ),
                onPressed: onPickFiles,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(strings.addFiles, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manualTextController,
                minLines: MediaQuery.sizeOf(context).width < 600 ? 6 : 12,
                maxLines: 24,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: strings.inputHint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              ExpansionTile(
                key: const PageStorageKey('import-link'),
                maintainState: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 4),
                textColor: palette.text,
                collapsedTextColor: palette.mutedText,
                iconColor: palette.accent,
                collapsedIconColor: palette.mutedText,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  strings.importLink,
                  style: TextStyle(fontSize: 14, color: palette.text),
                ),
                children: [
                  TextField(
                    controller: downloadUrlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: strings.urlLabel,
                      hintText: 'https://example.com/text.txt',
                      prefixIcon: const Icon(Icons.link_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: palette.accentText,
                      ),
                      onPressed: isDownloading ? null : onDownloadText,
                      icon: isDownloading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(strings.downloadButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChineseStructureCard extends StatelessWidget {
  const _ChineseStructureCard({
    super.key,
    required this.strings,
    required this.palette,
  });

  final AppStrings strings;
  final DesignPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.accent.withValues(alpha: .4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.translate_rounded, color: palette.accent, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.chineseStructureTitle,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  strings.chineseStructureDescription,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.strings,
    required this.fileNameController,
    required this.personNameController,
    required this.sources,
    required this.status,
    required this.isGenerating,
    required this.showGenerateButton,
    required this.onGenerate,
    required this.onRemoveSource,
    required this.palette,
    required this.aiReview,
    required this.isAiReviewing,
    required this.onReviewWithAi,
    required this.issues,
    required this.generatedPath,
    required this.libraryPath,
    required this.cloudPanel,
    required this.onOpenGenerated,
    required this.onShareGenerated,
    required this.onOpenLibraryFolder,
  });

  final AppStrings strings;
  final TextEditingController fileNameController;
  final TextEditingController personNameController;
  final List<DocumentSource> sources;
  final String? status;
  final bool isGenerating;
  final bool showGenerateButton;
  final VoidCallback onGenerate;
  final ValueChanged<DocumentSource> onRemoveSource;
  final DesignPalette palette;
  final String? aiReview;
  final bool isAiReviewing;
  final VoidCallback onReviewWithAi;
  final List<String> issues;
  final String? generatedPath;
  final String? libraryPath;
  final Widget cloudPanel;
  final VoidCallback onOpenGenerated;
  final VoidCallback onShareGenerated;
  final VoidCallback onOpenLibraryFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SectionCard(
      step: '03',
      icon: Icons.auto_awesome_rounded,
      title: strings.output,
      description: strings.exportDescription,
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: fileNameController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: strings.fileName,
              helperText: strings.fileNameRule,
              helperMaxLines: 3,
              helperStyle: TextStyle(color: palette.mutedText),
              floatingLabelStyle: TextStyle(
                color: palette.text,
                backgroundColor: palette.surfaceStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(Icons.description_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: personNameController,
            decoration: InputDecoration(
              labelText: strings.personName,
              hintText: strings.personNameHint,
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (showGenerateButton)
            _PulsingGenerateButton(
              palette: palette,
              isGenerating: isGenerating,
              label: strings.generate,
              onPressed: onGenerate,
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.sources,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${sources.length}',
                  style: TextStyle(
                    color: palette.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (sources.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surfaceStrong,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                strings.noSources,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.mutedText,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  tileColor: palette.surfaceStrong,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(Icons.article_outlined, color: palette.accent),
                  title: Text(
                    source.name,
                    style: TextStyle(color: palette.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    strings.words(_wordCount(source.text)),
                    style: TextStyle(color: palette.mutedText),
                  ),
                  trailing: IconButton(
                    tooltip: strings.remove,
                    onPressed: () => onRemoveSource(source),
                    icon: Icon(Icons.close_rounded, color: palette.mutedText),
                  ),
                ),
              ),
            ),
          if (status != null) ...[
            const SizedBox(height: 14),
            if (issues.isNotEmpty)
              _IssueIndex(
                issues: issues,
                title: strings.issues,
                status: status!,
              )
            else
              _StatusMessage(text: status!),
          ],
          const SizedBox(height: 14),
          if ((generatedPath != null || libraryPath != null) && !kIsWeb) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.text,
                side: BorderSide(color: palette.accent.withValues(alpha: .65)),
              ),
              onPressed: onOpenGenerated,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(strings.openInWord),
            ),
            const SizedBox(height: 14),
          ],
          if (libraryPath != null && !kIsWeb) ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: palette.surfaceStrong,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_copy_outlined, color: palette.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.localLibrary,
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    strings.localLibraryDescription,
                    style: TextStyle(color: palette.mutedText, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    libraryPath!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.mutedText, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.text,
                          side: BorderSide(
                            color: palette.accent.withValues(alpha: .65),
                          ),
                        ),
                        onPressed: onShareGenerated,
                        icon: const Icon(Icons.share_outlined, size: 17),
                        label: Text(strings.shareDocument),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.text,
                          side: BorderSide(
                            color: palette.accent.withValues(alpha: .65),
                          ),
                        ),
                        onPressed: onOpenLibraryFolder,
                        icon: const Icon(Icons.folder_open_outlined, size: 17),
                        label: Text(strings.openFolder),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          cloudPanel,
          const SizedBox(height: 14),
          _AssistantPanel(
            strings: strings,
            palette: palette,
            review: aiReview,
            isReviewing: isAiReviewing,
            onReview: onReviewWithAi,
          ),
        ],
      ),
    );
  }
}

class _IssueIndex extends StatelessWidget {
  const _IssueIndex({
    required this.issues,
    required this.title,
    required this.status,
  });

  final List<String> issues;
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    final entries = issues.isEmpty ? [status] : issues;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE11D48).withValues(alpha: .3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rule_rounded,
                color: Color(0xFF9F1239),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9F1239),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${entries.length}',
                style: const TextStyle(
                  color: Color(0xFF9F1239),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...entries.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key + 1}.',
                    style: const TextStyle(
                      color: Color(0xFF9F1239),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Color(0xFF7F1D3C),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantPanel extends StatelessWidget {
  const _AssistantPanel({
    required this.strings,
    required this.palette,
    required this.review,
    required this.isReviewing,
    required this.onReview,
  });

  final AppStrings strings;
  final DesignPalette palette;
  final String? review;
  final bool isReviewing;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceStrong.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: palette.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.assistant,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'LOCAL',
                style: TextStyle(
                  color: palette.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.assistantDescription,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.text,
              side: BorderSide(color: palette.accent.withValues(alpha: .65)),
            ),
            onPressed: isReviewing ? null : onReview,
            icon: isReviewing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.manage_search_rounded, size: 18),
            label: Text(strings.assistantRun),
          ),
          if (review != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              review!,
              style: TextStyle(color: palette.text, fontSize: 12, height: 1.45),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                strings.assistantSetup,
                style: TextStyle(color: palette.mutedText, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingGenerateButton extends StatefulWidget {
  const _PulsingGenerateButton({
    required this.isGenerating,
    required this.label,
    required this.onPressed,
    required this.palette,
  });

  final bool isGenerating;
  final String label;
  final VoidCallback onPressed;
  final DesignPalette palette;

  @override
  State<_PulsingGenerateButton> createState() => _PulsingGenerateButtonState();
}

class _PulsingGenerateButtonState extends State<_PulsingGenerateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.palette.accent, widget.palette.accentSecondary],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
          boxShadow: [
            BoxShadow(
              color: widget.palette.accent.withValues(
                alpha: 0.22 + _pulse.value * 0.26,
              ),
              blurRadius: 18 + _pulse.value * 18,
              spreadRadius: _pulse.value * 3,
            ),
          ],
        ),
        child: child,
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: widget.isGenerating ? null : widget.onPressed,
        icon: widget.isGenerating
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_fix_high_rounded),
        label: Text(widget.label),
      ),
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

String _fileNamePart(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return normalized.isEmpty ? 'langue' : normalized;
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
