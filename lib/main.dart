import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:url_launcher/url_launcher.dart';

import 'docx_builder.dart';
import 'cloud/cloud_models.dart';
import 'cloud/cloud_panel.dart';
import 'cloud/cloud_storage.dart';
import 'cloud/storage_gate.dart';
import 'pdf_web_stub.dart' if (dart.library.js_interop) 'pdf_web.dart';
import 'ai_assistant.dart';
import 'sermon_reference.dart';
import 'french_consistency.dart';
import 'localized_issues.dart';
import 'verse_editor.dart';
import 'app_release_tools.dart';
import 'glass_surface.dart';
import 'release_seen_io.dart'
    if (dart.library.js_interop) 'release_seen_web.dart';
import 'drafts/draft_session.dart';
import 'drafts/draft_store.dart';
import 'drafts/draft_repository.dart';

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
const _appVersion = '1.9.17';
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
    'Partager vers une application',
    'Share to another app',
    'Compartir con otra aplicación',
    'Compartilhar com outro aplicativo',
  );
  String get downloadForWord => _text(
    'Télécharger pour Word',
    'Download for Word',
    'Descargar para Word',
    'Baixar para Word',
  );
  String get wordAddIn => _text(
    'Complément Microsoft Word',
    'Microsoft Word add-in',
    'Complemento de Microsoft Word',
    'Suplemento do Microsoft Word',
  );
  String get browserExtension => _text(
    'Extension pour navigateurs',
    'Browser extension',
    'Extensión para navegadores',
    'Extensão para navegadores',
  );
  String get shareAndWord => _text(
    'Partager & Microsoft Word',
    'Share & Microsoft Word',
    'Compartir y Microsoft Word',
    'Compartilhar e Microsoft Word',
  );
  String get shareAndWordDescription => _text(
    'Envoyez le Word vers une autre application, téléchargez-le ou installez le panneau DEC DOCX dans Word.',
    'Send the Word file to another app, download it, or install the DEC DOCX pane in Word.',
    'Envíe el archivo Word a otra aplicación, descárguelo o instale el panel DEC DOCX en Word.',
    'Envie o arquivo Word para outro aplicativo, baixe-o ou instale o painel DEC DOCX no Word.',
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
  String documentLanguageLabel(KacouLanguage language) {
    const french = <String, String>{
      'francais': 'français',
      'anglais': 'anglais',
      'espagnol': 'espagnol',
      'portugais': 'portugais',
      'allemand': 'allemand',
      'russe': 'russe',
      'italien': 'italien',
      'attie': 'attié',
      'agni': 'agni',
      'wan': 'wan',
      'yemba': 'yemba',
      'fon': 'fon',
      'kikongo': 'kikongo',
      'gouin': 'gouin',
      'moore': 'mooré',
      'bambara': 'bambara',
      'chinois': 'chinois',
    };
    const english = <String, String>{
      'francais': 'French',
      'anglais': 'English',
      'espagnol': 'Spanish',
      'portugais': 'Portuguese',
      'allemand': 'German',
      'russe': 'Russian',
      'italien': 'Italian',
      'attie': 'Attié',
      'agni': 'Agni',
      'wan': 'Wan',
      'yemba': 'Yemba',
      'fon': 'Fon',
      'kikongo': 'Kikongo',
      'gouin': 'Gouin',
      'moore': 'Mooré',
      'bambara': 'Bambara',
      'chinois': 'Chinese',
    };
    const spanish = <String, String>{
      'francais': 'francés',
      'anglais': 'inglés',
      'espagnol': 'español',
      'portugais': 'portugués',
      'allemand': 'alemán',
      'russe': 'ruso',
      'italien': 'italiano',
      'attie': 'attié',
      'agni': 'agni',
      'wan': 'wan',
      'yemba': 'yemba',
      'fon': 'fon',
      'kikongo': 'kikongo',
      'gouin': 'gouin',
      'moore': 'moore',
      'bambara': 'bambara',
      'chinois': 'chino',
    };
    const portuguese = <String, String>{
      'francais': 'francês',
      'anglais': 'inglês',
      'espagnol': 'espanhol',
      'portugais': 'português',
      'allemand': 'alemão',
      'russe': 'russo',
      'italien': 'italiano',
      'attie': 'attié',
      'agni': 'agni',
      'wan': 'wan',
      'yemba': 'yemba',
      'fon': 'fon',
      'kikongo': 'kikongo',
      'gouin': 'gouin',
      'moore': 'more',
      'bambara': 'bambara',
      'chinois': 'chinês',
    };
    final labels = switch (this.language) {
      AppLanguage.fr => french,
      AppLanguage.en => english,
      AppLanguage.es => spanish,
      AppLanguage.pt => portuguese,
    };
    return labels[language.name] ?? language.name;
  }

  String get tagline => _text(
    'Corrige les DOCX mal formés sans inventer de versets',
    'Repairs malformed DOCX without inventing verses',
    'Corrige DOCX mal formados sin inventar versículos',
    'Corrige DOCX mal formatados sem inventar versículos',
  );
  String get versionLabel => _text(
    'Version $_appVersion',
    'Version $_appVersion',
    'Versión $_appVersion',
    'Versão $_appVersion',
  );
  String get clear => _text('Vider', 'Clear', 'Limpiar', 'Limpar');
  String get freshBadge => _text(
    'NOUVELLE APP - installation propre',
    'NEW APP - clean install',
    'NUEVA APP - instalación limpia',
    'NOVO APP - instalação limpa',
  );
  String get workflowTips => _text(
    '1. Entre le titre du chapitre.\n2. Choisis ou écris la langue du document.\n3. Les concordances restent en place et seront en vert ; les chapitres similaires finaux seront en bleu.',
    '1. Enter the chapter title.\n2. Choose or type the document language.\n3. Concordances stay in place and will be green; final similar chapters will be blue.',
    '1. Introduce el título del capítulo.\n2. Elige o escribe el idioma del documento.\n3. Las concordancias permanecen en su lugar y aparecerán en verde; los capítulos similares finales aparecerán en azul.',
    '1. Informe o título do capítulo.\n2. Escolha ou escreva o idioma do documento.\n3. As concordâncias permanecem no lugar e aparecerão em verde; os capítulos semelhantes finais aparecerão em azul.',
  );
  String get inputTitle => _text(
    'Contenu du chapitre',
    'Chapter content',
    'Contenido del capítulo',
    'Conteúdo do capítulo',
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
    'Colle les paragraphes numérotés. Les numéros seuls seront rattachés au texte suivant ; un verset manquant reste une erreur.',
    'Paste numbered paragraphs. Standalone numbers are attached to the next text; a missing verse remains an error.',
    'Pega los párrafos numerados. Los números aislados se unen al texto siguiente; un versículo faltante sigue siendo un error.',
    'Cole os parágrafos numerados. Números isolados são ligados ao texto seguinte; a ausência de um versículo continua sendo um erro.',
  );
  String get chapterTitle => _text(
    'Titre du chapitre',
    'Chapter title',
    'Título del capítulo',
    'Título do capítulo',
  );
  String get chapterTitleHint => _text(
    'KACOU 1 : C’est ici la voix de Matthieu 25 :6',
    'KACOU 1: This is the voice of Matthew 25:6',
    'KACOU 1: Aquí está la voz de Mateo 25:6',
    'KACOU 1: Aqui está a voz de Mateus 25:6',
  );
  String get chapterTitleLowercaseHelp => _text(
    'Écris le titre normalement, pas tout en majuscules. Les débuts de phrase et les noms propres peuvent avoir une majuscule.',
    'Use normal capitalization, not all caps. Sentences and proper names may start with a capital letter.',
    'Usa mayúsculas normales, no todo en mayúsculas. Las frases y los nombres propios pueden empezar con mayúscula.',
    'Use maiúsculas normalmente; não escreva tudo em maiúsculas. Frases e nomes próprios podem começar com maiúscula.',
  );
  String get subtitle => _text(
    'Sous-titre optionnel',
    'Optional subtitle',
    'Subtítulo opcional',
    'Subtítulo opcional',
  );
  String get subtitleHint => _text(
    'Laisse vide si le chapitre n’a pas de sous-titre. Il sera ajouté en italique.',
    'Leave empty if the chapter has no subtitle. It will be added in italics.',
    'Déjalo vacío si el capítulo no tiene subtítulo. Se añadirá en cursiva.',
    'Deixe vazio se o capítulo não tiver subtítulo. Ele será acrescentado em itálico.',
  );
  String get similarChapters => _text(
    'Chapitres similaires finaux',
    'Final similar chapters',
    'Capítulos similares finales',
    'Capítulos semelhantes finais',
  );
  String get similarChaptersHint => _text(
    'Uniquement le bloc final du texte. Il sera ajouté en bleu et en italique à la fin du dernier paragraphe.',
    'Only the final block of the text. It will be added in blue italic at the end of the last paragraph.',
    'Solo el bloque final del texto. Se añadirá en azul y cursiva al final del último párrafo.',
    'Somente o bloco final do texto. Ele será acrescentado em azul e itálico ao final do último parágrafo.',
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
    'Ejemplo: ruso, alemán, chino...',
    'Exemplo: russo, alemão, chinês...',
  );
  String get fileNameRule => _text(
    'Nom automatique : KACOU <numéro> <langue>.docx',
    'Automatic name: KACOU <number> <language>.docx',
    'Nombre automático: KACOU <número> <idioma>.docx',
    'Nome automático: KACOU <número> <idioma>.docx',
  );
  String get addFiles => _text(
    'Importer un fichier',
    'Import a file',
    'Importar un archivo',
    'Importar um arquivo',
  );
  String get pdfReadFailed => _text(
    'PDF illisible : utilise un PDF contenant du texte sélectionnable ou convertis le fichier en TXT.',
    'Unreadable PDF: use a PDF with selectable text or convert the file to TXT.',
    'PDF ilegible: usa un PDF con texto seleccionable o convierte el archivo a TXT.',
    'PDF ilegível: use um PDF com texto selecionável ou converta o arquivo para TXT.',
  );
  String get download =>
      _text('Téléchargement', 'Download', 'Descarga', 'Download');
  String get downloadButton =>
      _text('Télécharger', 'Download', 'Descargar', 'Baixar');
  String get urlLabel =>
      _text('Lien du texte', 'Text URL', 'URL del texto', 'URL do texto');
  String get output => _text('Sortie', 'Output', 'Salida', 'Saída');
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
    'Vérifier le format',
    'Check format',
    'Verificar formato',
    'Verificar formato',
  );
  String get sources => _text(
    'Fichiers ajoutés',
    'Added files',
    'Archivos agregados',
    'Arquivos adicionados',
  );
  String get noSources => _text(
    'Aucun fichier ajouté.',
    'No file added.',
    'No se ha añadido ningún archivo.',
    'Nenhum arquivo adicionado.',
  );
  String get remove => _text('Retirer', 'Remove', 'Quitar', 'Remover');
  String get importedFilesEditorTitle => _text(
    'Modifier les fichiers importés',
    'Edit imported files',
    'Editar archivos importados',
    'Editar arquivos importados',
  );
  String get importedFilesEditorDescription => _text(
    'Chaque fichier reste séparé : modifie un verset, supprime-le ou corrige son texte avant la génération.',
    'Each file stays separate: edit, delete, or correct a verse before generating the document.',
    'Cada archivo permanece separado: edita, elimina o corrige un versículo antes de generar el documento.',
    'Cada arquivo permanece separado: edite, exclua ou corrija um versículo antes de gerar o documento.',
  );
  String get footer => _text(
    'DEC DOCX $_appVersion : tous les documents sont comparés avec le chapitre français de référence.',
    'DEC DOCX $_appVersion: all documents are compared with the French reference chapter.',
    'DEC DOCX $_appVersion: todos los documentos se comparan con el capítulo francés de referencia.',
    'DEC DOCX $_appVersion: todos os documentos são comparados com o capítulo francês de referência.',
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
    'Introduce una dirección web válida.',
    'Informe um endereço web válido.',
  );
  String get unreadableFile => _text(
    'Aucun fichier lisible.',
    'No readable file.',
    'Ningún archivo legible.',
    'Nenhum arquivo legível.',
  );
  String filesAdded(int count) => _text(
    '$count fichier(s) ajouté(s) et préparé(s) par Fresh.',
    '$count file(s) added and prepared by Fresh.',
    '$count archivo(s) agregado(s) y preparado(s) por Fresh.',
    '$count arquivo(s) adicionado(s) e preparado(s) pelo Fresh.',
  );
  String formatReady(int paragraphs) => _text(
    'Format OK : $paragraphs paragraphe(s) numéroté(s) détecté(s). Aucun verset n’a été ajouté.',
    'Format OK: $paragraphs numbered paragraph(s) detected. No verse was added.',
    'Formato OK: $paragraphs párrafo(s) numerado(s) detectado(s). No se añadió ningún versículo.',
    'Formato OK: $paragraphs parágrafo(s) numerado(s) detectado(s). Nenhum versículo foi adicionado.',
  );
  String downloaded(Uri uri) => _text(
    'Texte téléchargé depuis $uri.',
    'Text downloaded from $uri.',
    'Texto descargado desde $uri.',
    'Texto baixado de $uri.',
  );
  String downloadFailed(Object error) => _text(
    'Téléchargement impossible : ${technicalError(error)}',
    'Download failed: ${technicalError(error)}',
    'No se pudo descargar: ${technicalError(error)}',
    'Não foi possível baixar: ${technicalError(error)}',
  );
  String validationErrors(List<String> errors) => _text(
    'Correction nécessaire avant génération :\n${errors.map((error) => localizeIssue(error, 'fr')).join('\n')}',
    'Correction required before generation:\n${errors.map((error) => localizeIssue(error, 'en')).join('\n')}',
    'Corrección necesaria antes de generar:\n${errors.map((error) => localizeIssue(error, 'es')).join('\n')}',
    'Correção necessária antes de gerar:\n${errors.map((error) => localizeIssue(error, 'pt')).join('\n')}',
  );
  String issue(String value) => localizeIssue(value, language.name);
  String technicalError(Object value) =>
      localizeTechnicalError(value, language.name);
  String referenceUnavailable(int chapter, Object error) => _text(
    '[FR-UNAVAILABLE] La référence française de Kacou $chapter est inaccessible (${technicalError(error)}). Vérifie ta connexion puis relance la génération pour contrôler les dates des sous-titres et la numérotation.',
    '[FR-UNAVAILABLE] The French reference for Kacou $chapter is unavailable (${technicalError(error)}). Check your connection and run generation again to verify subtitle dates and numbering.',
    '[FR-UNAVAILABLE] La referencia francesa de Kacou $chapter no está disponible (${technicalError(error)}). Comprueba la conexión y vuelve a generar el documento para verificar las fechas de los subtítulos y la numeración.',
    '[FR-UNAVAILABLE] A referência francesa de Kacou $chapter está indisponível (${technicalError(error)}). Verifique a conexão e gere novamente o documento para conferir as datas dos subtítulos e a numeração.',
  );
  String get subtitleDatesVerified => _text(
    'Dates des sous-titres vérifiées avec le français.',
    'Subtitle dates checked against the French reference.',
    'Fechas de los subtítulos comprobadas con la referencia francesa.',
    'Datas dos subtítulos verificadas com a referência francesa.',
  );
  String get referencesPreserved => _text(
    'Références [Kc…] conservées telles que saisies.',
    'References [Kc…] preserved as entered.',
    'Referencias [Kc…] conservadas tal como se introdujeron.',
    'Referências [Kc…] preservadas como foram inseridas.',
  );
  String libraryLocation(String path) => _text(
    'Bibliothèque locale / $path',
    'Local library / $path',
    'Biblioteca local / $path',
    'Biblioteca local / $path',
  );
  String synchronizedCopy(String provider, String path) => _text(
    'Copie locale enregistrée · copie écrite dans le dossier $provider / $path',
    'Local copy saved · copy written to the $provider folder / $path',
    'Copia local guardada · copia escrita en la carpeta $provider / $path',
    'Cópia local salva · cópia gravada na pasta $provider / $path',
  );
  String get folderCopyUnconfirmed => _text(
    'Bibliothèque locale · copie dans le dossier non confirmée',
    'Local library · folder copy not confirmed',
    'Biblioteca local · copia en la carpeta sin confirmar',
    'Biblioteca local · cópia na pasta não confirmada',
  );
  String get languageRequired => _text(
    'Langue obligatoire : choisis une langue du site ou écris-la manuellement pour nommer correctement le fichier.',
    'Language required: choose a site language or type it manually so the file can be named correctly.',
    'Idioma obligatorio: elige un idioma del sitio o escríbelo manualmente para nombrar correctamente el archivo.',
    'Idioma obrigatório: escolha um idioma do site ou escreva-o manualmente para nomear corretamente o arquivo.',
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
    'Chapitres similaires détectés en ligne : $similarChapters\nAjoute ce bloc dans « Chapitres similaires finaux » avant de générer.',
    'Similar chapters found online: $similarChapters\nAdd this block in "Final similar chapters" before generating.',
    'Capítulos similares detectados en línea: $similarChapters\nAñade este bloque en «Capítulos similares finales» antes de generar.',
    'Capítulos semelhantes encontrados online: $similarChapters\nAdicione este bloco em “Capítulos semelhantes finais” antes de gerar.',
  );
  String get comparingReference => _text(
    'Comparaison avec la version française du site www.philippekacou.org...',
    'Comparing with the French version on www.philippekacou.org...',
    'Comparando con la versión francesa de www.philippekacou.org...',
    'Comparando com a versão francesa de www.philippekacou.org...',
  );
  String referenceTitleNumberMissing() => _text(
    'Titre du chapitre : le numéro Kacou est introuvable. Mets un titre comme « KACOU 1 : ... » pour permettre la comparaison avec le site.',
    'Chapter title: the Kacou number is missing. Use a title like "KACOU 1: ...", otherwise site comparison is impossible.',
    'Título del capítulo: falta el número Kacou. Usa un título como «KACOU 1: ...» para poder compararlo con el sitio.',
    'Título do capítulo: falta o número Kacou. Use um título como “KACOU 1: ...” para permitir a comparação com o site.',
  );
  String referenceFetchFailed(int chapter, Object error) => _text(
    'Mode hors connexion : la comparaison en ligne de Kacou $chapter a été ignorée (${technicalError(error)}). Le document a été généré avec les contrôles locaux.',
    'Offline mode: online comparison for Kacou $chapter was skipped (${technicalError(error)}). The document was generated with local checks.',
    'Modo sin conexión: se omitió la comparación en línea de Kacou $chapter (${technicalError(error)}). El documento se generó con las comprobaciones locales.',
    'Modo offline: a comparação online de Kacou $chapter foi ignorada (${technicalError(error)}). O documento foi gerado com as verificações locais.',
  );
  String paragraphCountMismatch({
    required int chapter,
    required int localCount,
    required int referenceCount,
  }) {
    final gap = (referenceCount - localCount).abs();
    final frAction = localCount < referenceCount
        ? 'Il manque $gap paragraphe(s). Ajoute les paragraphes manquants dans le texte ou les fichiers importés.'
        : 'Il y a $gap paragraphe(s) en trop. Retire les paragraphes en trop ou vérifie les numéros.';
    final enAction = localCount < referenceCount
        ? '$gap paragraph(s) are missing. Add them to the text or imported files.'
        : '$gap extra paragraph(s) were found. Remove the extra paragraphs or check the numbers.';
    final esAction = localCount < referenceCount
        ? 'Faltan $gap párrafo(s). Añádelos al texto o a los archivos importados.'
        : 'Hay $gap párrafo(s) de más. Elimina los párrafos sobrantes o revisa los números.';
    final ptAction = localCount < referenceCount
        ? 'Faltam $gap parágrafo(s). Adicione-os ao texto ou aos arquivos importados.'
        : 'Há $gap parágrafo(s) a mais. Remova os parágrafos excedentes ou confira os números.';

    return _text(
      'Comparaison avec le site : ton texte Kacou $chapter contient $localCount paragraphe(s), mais le chapitre français du site en contient $referenceCount. $frAction Vérifie aussi que le titre indique le bon numéro Kacou.',
      'Site comparison: your Kacou $chapter text has $localCount paragraph(s), but the French chapter on the site has $referenceCount. $enAction Also check that the title has the right Kacou number.',
      'Comparación con el sitio: tu texto Kacou $chapter contiene $localCount párrafo(s), pero el capítulo francés del sitio contiene $referenceCount. $esAction Comprueba también que el título indique el número Kacou correcto.',
      'Comparação com o site: seu texto Kacou $chapter contém $localCount parágrafo(s), mas o capítulo francês do site contém $referenceCount. $ptAction Confira também se o título indica o número Kacou correto.',
    );
  }

  String referenceOk({
    required int chapter,
    required int paragraphCount,
  }) => _text(
    'Comparaison réussie : Kacou $chapter contient $paragraphCount paragraphe(s), comme la version française du site.',
    'Comparison OK: Kacou $chapter has $paragraphCount paragraph(s), like the French version on the site.',
    'Comparación correcta: Kacou $chapter contiene $paragraphCount párrafo(s), como la versión francesa del sitio.',
    'Comparação concluída: Kacou $chapter contém $paragraphCount parágrafo(s), como a versão francesa do site.',
  );
  String localChecksOk({
    required int chapter,
    required int paragraphCount,
  }) => _text(
    'Contrôle local réussi : Kacou $chapter contient $paragraphCount paragraphe(s). La comparaison en ligne est disponible lorsque la connexion Internet fonctionne.',
    'Local check OK: Kacou $chapter has $paragraphCount paragraph(s). Online comparison is available without a fixed limit when internet works.',
    'Comprobación local correcta: Kacou $chapter contiene $paragraphCount párrafo(s). La comparación en línea está disponible cuando hay conexión a Internet.',
    'Verificação local concluída: Kacou $chapter contém $paragraphCount parágrafo(s). A comparação online está disponível quando há conexão com a Internet.',
  );
  String created(String path) => _text(
    'Document créé : $path',
    'Document created: $path',
    'Documento creado: $path',
    'Documento criado: $path',
  );
  String get shared => _text(
    'Document prêt pour le partage.',
    'Document ready to share.',
    'Documento listo para compartir.',
    'Documento pronto para compartilhar.',
  );
  String shareStarted(Object value) => _text(
    'Partage lancé avec $value.',
    'Sharing started with $value.',
    'Compartición iniciada con $value.',
    'Compartilhamento iniciado com $value.',
  );
  String shareNotFinished(Object error) => _text(
    'Partage non terminé : ${technicalError(error)}',
    'Sharing did not finish: ${technicalError(error)}',
    'La compartición no terminó: ${technicalError(error)}',
    'O compartilhamento não terminou: ${technicalError(error)}',
  );
  String get wordPageOpenFailed => _text(
    'Impossible d’ouvrir la page du complément Word.',
    'Unable to open the Word add-in page.',
    'No se pudo abrir la página del complemento de Word.',
    'Não foi possível abrir a página do suplemento do Word.',
  );
  String get browserPageOpenFailed => _text(
    'Impossible d’ouvrir la page de l’extension navigateur.',
    'Unable to open the browser extension page.',
    'No se pudo abrir la página de la extensión del navegador.',
    'Não foi possível abrir a página da extensão do navegador.',
  );
  String get shareCancelled => _text(
    'Partage annulé. Le document reste dans votre bibliothèque.',
    'Sharing cancelled. The document remains in your library.',
    'Compartición cancelada. El documento permanece en tu biblioteca.',
    'Compartilhamento cancelado. O documento continua na sua biblioteca.',
  );
  String get browserShareFallback => _text(
    'Le navigateur a ouvert le partage ou téléchargé une copie selon ses capacités.',
    'The browser opened sharing or downloaded a copy according to its capabilities.',
    'El navegador abrió la compartición o descargó una copia según sus capacidades.',
    'O navegador abriu o compartilhamento ou baixou uma cópia conforme seus recursos.',
  );
  String get systemShareFallback => _text(
    'Le système ne confirme pas l’application destinataire. Le document reste enregistré.',
    'The system did not confirm the target app. The document remains saved.',
    'El sistema no confirmó la aplicación de destino. El documento sigue guardado.',
    'O sistema não confirmou o aplicativo de destino. O documento continua salvo.',
  );
  String get generatedDownloadHint => _text(
    'Document généré. Utilisez Télécharger ou Partager pour conserver une copie.',
    'Document generated. Use Download or Share to keep a copy.',
    'Documento generado. Usa Descargar o Compartir para conservar una copia.',
    'Documento gerado. Use Baixar ou Compartilhar para guardar uma cópia.',
  );
  String get shareDownloadRequired => _text(
    'Générez un Word pour activer le partage et le téléchargement.',
    'Generate a Word file to enable sharing and downloading.',
    'Genera un Word para activar la compartición y la descarga.',
    'Gere um Word para ativar o compartilhamento e o download.',
  );
  String get saveDialogTitle => _text(
    'Enregistrer dans mes fichiers ou mon cloud',
    'Save to my files or cloud',
    'Guardar en mis archivos o en mi nube',
    'Salvar nos meus arquivos ou na minha nuvem',
  );
  String get browserFileShareUnavailable => _text(
    'Le partage de fichiers n’est pas disponible dans ce navigateur. Utilisez « Enregistrer une copie », puis partagez le Word depuis vos fichiers.',
    'File sharing is not available in this browser. Use “Save a copy”, then share the Word file from your files.',
    'La compartición de archivos no está disponible en este navegador. Usa «Guardar una copia» y comparte el Word desde tus archivos.',
    'O compartilhamento de arquivos não está disponível neste navegador. Use “Salvar uma cópia” e compartilhe o Word pelos seus arquivos.',
  );
  String get generatedWordRequired => _text(
    'Générez un Word pour activer la sauvegarde.',
    'Generate a Word file to enable backup.',
    'Genera un Word para activar la copia de seguridad.',
    'Gere um Word para ativar o backup.',
  );
  String get changeStyle => _text(
    'Changer de style',
    'Change style',
    'Cambiar estilo',
    'Alterar estilo',
  );
  String designLabel(DesignMode mode) => switch (mode) {
    DesignMode.aura => 'Aura',
    DesignMode.edition => _text(
      'Édition',
      'Editorial',
      'Editorial',
      'Editorial',
    ),
    DesignMode.nocturne => _text('Nocturne', 'Night', 'Nocturno', 'Noturno'),
  };
  String designDescription(DesignMode mode) => switch (mode) {
    DesignMode.aura => _text(
      'Violet lumineux',
      'Luminous violet',
      'Violeta luminoso',
      'Violeta luminoso',
    ),
    DesignMode.edition => _text(
      'Papier éditorial',
      'Editorial paper',
      'Papel editorial',
      'Papel editorial',
    ),
    DesignMode.nocturne => _text(
      'Studio sombre',
      'Dark studio',
      'Estudio oscuro',
      'Estúdio escuro',
    ),
  };
  String error(Object error) => _text(
    'Erreur : ${technicalError(error)}',
    'Error: ${technicalError(error)}',
    'Error: ${technicalError(error)}',
    'Erro: ${technicalError(error)}',
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

class DocxGeneratorApp extends StatefulWidget {
  const DocxGeneratorApp({super.key, this.skipStorageSetup = false});

  final bool skipStorageSetup;

  @override
  State<DocxGeneratorApp> createState() => _DocxGeneratorAppState();
}

class _DocxGeneratorAppState extends State<DocxGeneratorApp> {
  late AppLanguage _language;

  @override
  void initState() {
    super.initState();
    final systemLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _language = AppLanguage.values.firstWhere(
      (language) => language.name == systemLanguage,
      orElse: () => AppLanguage.en,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appName,
      locale: Locale(_language.name),
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('es'),
        Locale('pt'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
      home: widget.skipStorageSetup
          ? GeneratorPage(
              draftsEnabled: false,
              initialLanguage: _language,
              onLanguageChanged: (language) =>
                  setState(() => _language = language),
            )
          : StorageGate(
              locale: _language.name,
              child: GeneratorPage(
                initialLanguage: _language,
                onLanguageChanged: (language) =>
                    setState(() => _language = language),
              ),
            ),
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
  const GeneratorPage({
    super.key,
    this.draftsEnabled = true,
    this.draftRepository,
    this.initialLanguage,
    this.onLanguageChanged,
  });
  final bool draftsEnabled;
  final DraftRepository? draftRepository;
  final AppLanguage? initialLanguage;
  final ValueChanged<AppLanguage>? onLanguageChanged;

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage>
    with SingleTickerProviderStateMixin {
  DraftSession? _drafts;
  bool _applyingDraft = false;
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
  final List<TextEditingController> _fileSourceControllers = [];
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
  bool _showReleaseNotice = false;
  late final AnimationController _ambientController;

  AppStrings get _strings => AppStrings(_language);
  DesignPalette get _palette => DesignPalette.forMode(_designMode);

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage ?? AppLanguage.fr;
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _chapterTitleController.addListener(_syncAutomaticFileName);
    _documentLanguageController.addListener(_syncAutomaticFileName);
    _manualTextController.addListener(_invalidateEditedText);
    _subtitleController.addListener(_invalidateEditedText);
    _chapterTitleController.addListener(_invalidateEditedText);
    _documentLanguageController.addListener(_invalidateEditedText);
    if (widget.draftsEnabled) {
      _drafts = DraftSession(widget.draftRepository ?? DraftStore());
      _drafts!.addListener(_draftStatusChanged);
      for (final field in _draftFields.values) {
        field.addListener(_draftChanged);
      }
      unawaited(_restoreDraft());
    }
    _similarChaptersController.addListener(_invalidateEditedText);
    _personNameController.addListener(_invalidateEditedText);
    _fileNameController.addListener(_invalidateEditedText);
    _checkForUpdateNotice();
    _showNewReleaseOnce();
  }

  Future<void> _showNewReleaseOnce() async {
    final isNew = await markReleaseSeen(_appVersion);
    if (mounted && isNew) setState(() => _showReleaseNotice = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ambientController.stop();
    } else if (!_ambientController.isAnimating) {
      _ambientController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (final field in _draftFields.values) {
      field.removeListener(_draftChanged);
    }
    _drafts?.removeListener(_draftStatusChanged);
    _drafts?.dispose();
    _ambientController.dispose();
    _chapterTitleController.removeListener(_syncAutomaticFileName);
    _documentLanguageController.removeListener(_syncAutomaticFileName);
    _subtitleController.removeListener(_invalidateEditedText);
    _chapterTitleController.removeListener(_invalidateEditedText);
    _documentLanguageController.removeListener(_invalidateEditedText);
    _chapterTitleController.dispose();
    _subtitleController.dispose();
    _similarChaptersController.dispose();
    _manualTextController.removeListener(_invalidateEditedText);
    _manualTextController.dispose();
    _downloadUrlController.dispose();
    _fileNameController.dispose();
    _documentLanguageController.dispose();
    _personNameController.dispose();
    for (final controller in _fileSourceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _invalidateEditedText() {
    if (!mounted) return;
    setState(() {
      _issueMessages = const [];
      _status = null;
      _aiReview = null;
      _cloudDocument = null;
      _generatedPath = null;
      _libraryPath = null;
    });
  }

  Map<String, TextEditingController> get _draftFields => {
    'title': _chapterTitleController,
    'subtitle': _subtitleController,
    'similar': _similarChaptersController,
    'text': _manualTextController,
    'url': _downloadUrlController,
    'fileName': _fileNameController,
    'language': _documentLanguageController,
    'person': _personNameController,
  };
  Map<String, dynamic> _draftSnapshot() => {
    for (final entry in _draftFields.entries) entry.key: entry.value.text,
    'uiLanguage': _language.name,
    'sources': _fileSources
        .map((s) => {'name': s.name, 'text': s.text})
        .toList(),
  };
  void _draftStatusChanged() {
    if (mounted) setState(() {});
  }

  void _draftChanged() {
    if (!_applyingDraft) _drafts?.change(_draftSnapshot());
  }

  void _addFileSource(DocumentSource source) {
    final controller = TextEditingController(text: source.text);
    controller.addListener(() => _fileSourceChanged(controller));
    _fileSources.add(source);
    _fileSourceControllers.add(controller);
  }

  void _fileSourceChanged(TextEditingController controller) {
    final index = _fileSourceControllers.indexOf(controller);
    if (index < 0 || _applyingDraft) return;
    final source = _fileSources[index];
    if (source.text == controller.text) return;
    _fileSources[index] = DocumentSource(
      name: source.name,
      text: controller.text,
    );
    _invalidateEditedText();
    _draftChanged();
  }

  void _clearFileSources() {
    for (final controller in _fileSourceControllers) {
      controller.dispose();
    }
    _fileSourceControllers.clear();
    _fileSources.clear();
  }

  void _replaceFileSources(Iterable<DocumentSource> sources) {
    _clearFileSources();
    for (final source in sources) {
      _addFileSource(source);
    }
  }

  void _applyDraft(Map<String, dynamic> data) {
    _applyingDraft = true;
    try {
      final savedLanguage = data['uiLanguage'] as String?;
      if (savedLanguage != null) {
        _language = AppLanguage.values.firstWhere(
          (language) => language.name == savedLanguage,
          orElse: () => _language,
        );
        widget.onLanguageChanged?.call(_language);
      }
      // Restore fields in order, including the saved file name after the
      // automatic name listeners have run.
      for (final entry in _draftFields.entries) {
        entry.value.text = data[entry.key] as String? ?? '';
      }
      _fileNameController.text =
          data['fileName'] as String? ?? 'document_genere';
      _replaceFileSources(
        (data['sources'] as List? ?? []).map(
          (s) => DocumentSource(
            name: s['name'] as String,
            text: s['text'] as String,
          ),
        ),
      );
      _invalidateEditedText();
    } finally {
      _applyingDraft = false;
    }
  }

  Future<void> _restoreDraft() async {
    final data = await _drafts!.load();
    if (mounted && data != null) _applyDraft(data);
  }

  String _draftLabel(String fr, String en, String es, String pt) =>
      _strings._text(fr, en, es, pt);
  Widget _draftPanel() {
    final session = _drafts!;
    final text = session.error != null
        ? _draftLabel(
            'Enregistrement non confirmé. Votre texte reste à l’écran ; réessayez.',
            'Save not confirmed. Your text is still on screen; retry.',
            'Guardado sin confirmar. El texto sigue en pantalla; reintente.',
            'Salvamento não confirmado. O texto permanece na tela; tente novamente.',
          )
        : session.saving || session.dirty
        ? _draftLabel(
            'Enregistrement du brouillon…',
            'Saving draft…',
            'Guardando borrador…',
            'Salvando rascunho…',
          )
        : session.savedAt != null
        ? _draftLabel(
            'Brouillon enregistré sur cet appareil',
            'Draft saved on this device',
            'Borrador guardado en este dispositivo',
            'Rascunho salvo neste dispositivo',
          )
        : _draftLabel(
            'Sauvegarde automatique du brouillon prête',
            'Draft autosave ready',
            'Guardado automático listo',
            'Salvamento automático pronto',
          );
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _palette.surfaceStrong,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            key: const ValueKey('draft-status'),
            children: [
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 240),
                child: Icon(
                  session.error != null
                      ? Icons.error_outline_rounded
                      : session.saving || session.dirty
                      ? Icons.sync_rounded
                      : session.savedAt != null
                      ? Icons.check_circle_outline_rounded
                      : Icons.edit_note_rounded,
                  key: ValueKey(
                    '${session.error != null}-${session.saving || session.dirty}-${session.savedAt != null}',
                  ),
                  color: session.error != null
                      ? _palette.accentText
                      : _palette.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 240),
                  child: Text(
                    text,
                    key: ValueKey(text),
                    style: TextStyle(
                      color: session.error != null
                          ? _palette.accentText
                          : _palette.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (session.savedAt != null)
            Text(
              session.savedAt!.toLocal().toString().split('.').first,
              style: TextStyle(color: _palette.mutedText, fontSize: 12),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: session.saving
                    ? null
                    : () async {
                        try {
                          await session.flush();
                        } catch (_) {}
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _draftLabel('Enregistrer', 'Save', 'Guardar', 'Salvar'),
                ),
              ),
              TextButton.icon(
                onPressed: session.saving ? null : _showDraftHistory,
                icon: const Icon(Icons.history),
                label: Text(
                  _draftLabel(
                    'Historique local',
                    'Local history',
                    'Historial local',
                    'Histórico local',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDraftHistory() async {
    final session = _drafts!;
    try {
      final versions = await session.repository.history();
      if (!mounted) return;
      final id = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _draftLabel(
              'Historique local · 50 dernières versions',
              'Local history · latest 50 versions',
              'Historial local · últimas 50 versiones',
              'Histórico local · últimas 50 versões',
            ),
          ),
          content: SizedBox(
            width: 560,
            height: 360,
            child: versions.isEmpty
                ? Text(
                    _draftLabel(
                      'Aucune version enregistrée.',
                      'No saved versions.',
                      'No hay versiones guardadas.',
                      'Nenhuma versão salva.',
                    ),
                  )
                : ListView.builder(
                    itemCount: versions.length,
                    itemBuilder: (context, i) {
                      final v = versions[i];
                      return ListTile(
                        title: Text(
                          (v['title'] as String).isEmpty
                              ? _draftLabel(
                                  'Sans titre',
                                  'Untitled',
                                  'Sin título',
                                  'Sem título',
                                )
                              : v['title'] as String,
                        ),
                        subtitle: Text(
                          DateTime.parse(
                            v['savedAt'] as String,
                          ).toLocal().toString().split('.').first,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, v['id'] as String),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_draftLabel('Fermer', 'Close', 'Cerrar', 'Fechar')),
            ),
          ],
        ),
      );
      if (id == null || !mounted) return;
      final revision = await session.repository.read(id);
      final data = Map<String, dynamic>.from(revision['data'] as Map);
      if (!mounted) return;
      final restore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _draftLabel(
              'Restaurer cette version ?',
              'Restore this version?',
              '¿Restaurar esta versión?',
              'Restaurar esta versão?',
            ),
          ),
          content: SizedBox(
            width: 560,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(
                '${data['title']}\n${data['subtitle']}\n\n${data['text']}\n\n${(data['sources'] as List? ?? []).map((s) => '${s['name']}\n${s['text']}').join('\n\n')}',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                _draftLabel('Annuler', 'Cancel', 'Cancelar', 'Cancelar'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                _draftLabel('Restaurer', 'Restore', 'Restaurar', 'Restaurar'),
              ),
            ),
          ],
        ),
      );
      if (restore != true || !mounted) return;
      // Preserve the current draft before replacing it. Restoration itself is
      // a new revision, so both versions remain recoverable.
      await session.flush();
      if (!mounted) return;
      _applyDraft(data);
      _draftChanged();
      await session.flush();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _draftLabel(
                    'Historique indisponible : ',
                    'History unavailable: ',
                    'Historial no disponible: ',
                    'Histórico indisponível: ',
                  ) +
                  e.toString(),
            ),
          ),
        );
      }
    }
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
        uiLocale: _language.name,
      );
      if (mounted) setState(() => _aiReview = review);
    } catch (error) {
      _setStatus(
        '${_strings.assistantSetup}\n${_strings.technicalError(error)}',
      );
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
    final document = CloudDocument(
      bytes,
      fileName,
      _documentLanguageController.text,
      _personNameController.text,
    );
    final storage = CloudStorage();
    await storage.restore();
    try {
      final path = await storage.save(document);
      return storage.mode == 'folder'
          ? _strings.synchronizedCopy(storage.provider ?? '', path)
          : _strings.libraryLocation(path);
    } catch (error) {
      if (error.toString().contains('Version locale conservée')) {
        return _strings.folderCopyUnconfirmed;
      }
      rethrow;
    }
  }

  Future<void> _shareDocumentPath() async {
    final path = _libraryPath ?? _generatedPath;
    if (path == null || kIsWeb) return;
    final result = await SharePlus.instance.share(
      ShareParams(
        title: _strings.appTitle,
        sharePositionOrigin: _shareOrigin(),
        files: [XFile(path, mimeType: _docxMimeType)],
      ),
    );
    _setShareResult(result);
  }

  void _setShareResult(ShareResult result) {
    switch (result.status) {
      case ShareResultStatus.success:
        _setStatus(_strings.shareStarted(result.raw));
        return;
      case ShareResultStatus.dismissed:
        _setStatus(_strings.shareCancelled);
        return;
      case ShareResultStatus.unavailable:
        _setStatus(
          kIsWeb ? _strings.browserShareFallback : _strings.systemShareFallback,
        );
        return;
    }
  }

  Rect? _shareOrigin() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  Future<void> _shareLatestDocument() async {
    final document = _cloudDocument;
    if (document == null) return;
    try {
      final ShareResult result;
      if (kIsWeb) {
        result = await SharePlus.instance.share(
          ShareParams(
            title: document.name,
            downloadFallbackEnabled: false,
            sharePositionOrigin: _shareOrigin(),
            files: [
              XFile.fromData(
                document.bytes,
                mimeType: _docxMimeType,
                name: document.name,
              ),
            ],
          ),
        );
      } else if (_libraryPath != null || _generatedPath != null) {
        final path = _libraryPath ?? _generatedPath!;
        result = await _shareDocumentPathOverride(path);
      } else {
        result = await _shareGeneratedFile(document.name, document.bytes);
      }
      _setShareResult(result);
    } catch (error) {
      _setStatus(_strings.shareNotFinished(error));
    }
  }

  Future<void> _downloadLatestForWord() async {
    final document = _cloudDocument;
    if (document == null) return;
    if (!kIsWeb && (_generatedPath != null || _libraryPath != null)) {
      await _openGeneratedDocument();
      return;
    }
    await _exportCloudCopy(document.name, document.bytes);
  }

  Future<void> _openWordAddIn() async {
    final opened = await launchUrl(
      Uri.parse('https://nikaisedoua-source.github.io/dec-docx/word.html'),
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!opened) _setStatus(_strings.wordPageOpenFailed);
  }

  Future<void> _openBrowserExtension() async {
    final opened = await launchUrl(
      Uri.parse(
        'https://nikaisedoua-source.github.io/dec-docx/navigateurs.html',
      ),
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!opened) {
      _setStatus(_strings.browserPageOpenFailed);
    }
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

    _invalidateEditedText();
    setState(() {
      for (final source in imported) {
        _addFileSource(source);
      }
      _status = imported.isEmpty
          ? (pdfError ? _strings.pdfReadFailed : _strings.unreadableFile)
          : _strings.filesAdded(imported.length);
      _issueMessages = const [];
    });
    _draftChanged();
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
        _addFileSource(DocumentSource(name: title, text: text));
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
        final savedMessage = libraryPath == null
            ? _strings.generatedDownloadHint
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
      return _ReferenceCheckResult.error(
        _strings.referenceUnavailable(chapterNumber, error),
      );
    }

    final localCount = DocxBuilder.paragraphCount(document);
    final errors = <String>[];
    if (document.similarChapters == null &&
        input.similarChapters.trim().isEmpty &&
        reference.similarChapters != null) {
      errors.add(
        _strings.similarChaptersOnlineMissing(reference.similarChapters!),
      );
    }
    if (localCount != reference.paragraphCount) {
      errors.add(
        _strings.paragraphCountMismatch(
          chapter: chapterNumber,
          localCount: localCount,
          referenceCount: reference.paragraphCount,
        ),
      );
    }
    final dateNotices = <String>[];
    errors.addAll(
      compareFrenchConsistency(
        document,
        reference,
        language: input.language,
        notices: dateNotices,
      ),
    );
    if (errors.isNotEmpty) {
      return _ReferenceCheckResult.errors(errors);
    }

    final referenceMessage = _strings.referenceOk(
      chapter: chapterNumber,
      paragraphCount: localCount,
    );
    final dateMessage = dateNotices.isEmpty
        ? _strings.subtitleDatesVerified
        : dateNotices.map(_strings.issue).join('\n');
    return _ReferenceCheckResult.ok(
      '$referenceMessage\n$dateMessage\n${_strings.referencesPreserved}',
    );
  }

  Future<ShareResult> _shareGeneratedFile(
    String fileName,
    Uint8List bytes,
  ) async {
    if (kIsWeb) {
      return ShareResult.unavailable;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return _shareDocumentPathOverride(file.path);
  }

  Future<ShareResult> _shareDocumentPathOverride(String path) async {
    return SharePlus.instance.share(
      ShareParams(
        title: _strings.appTitle,
        sharePositionOrigin: _shareOrigin(),
        files: [XFile(path, mimeType: _docxMimeType)],
      ),
    );
  }

  Future<void> _exportCloudCopy(String name, Uint8List bytes) async {
    final path = await FilePicker.saveFile(
      dialogTitle: _strings.saveDialogTitle,
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['docx'],
      bytes: bytes,
    );
    if (!kIsWeb && path != null) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
  }

  Future<void> _shareCloudCopy(String name, Uint8List bytes) async {
    try {
      final ShareResult result;
      if (kIsWeb) {
        result = await SharePlus.instance.share(
          ShareParams(
            title: name,
            downloadFallbackEnabled: false,
            sharePositionOrigin: _shareOrigin(),
            files: [XFile.fromData(bytes, mimeType: _docxMimeType, name: name)],
          ),
        );
      } else {
        result = await _shareGeneratedFile(name, bytes);
      }
      _setShareResult(result);
    } catch (_) {
      _setStatus(_strings.browserFileShareUnavailable);
    }
  }

  void _importCloudCopy(String name, Uint8List bytes) {
    final text = DocxBuilder.extractTextFromDocx(bytes);
    if (text.trim().isEmpty) {
      throw const FormatException(
        'Ce fichier Word ne contient pas de texte exploitable.',
      );
    }
    _invalidateEditedText();
    setState(() => _addFileSource(DocumentSource(name: name, text: text)));
    _draftChanged();
  }

  void _removeSource(DocumentSource source) {
    final index = _fileSources.indexOf(source);
    if (index < 0) return;
    _invalidateEditedText();
    setState(() {
      _fileSources.removeAt(index);
      final controller = _fileSourceControllers.removeAt(index);
      controller.dispose();
    });
    _draftChanged();
  }

  Future<void> _clearAll() async {
    try {
      await _drafts?.flush();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _draftLabel(
                'Le brouillon actuel n’a pas été enregistré. Réessayez avant de l’effacer.',
                'The current draft was not saved. Retry before clearing it.',
                'El borrador actual no se guardó. Reintente antes de borrarlo.',
                'O rascunho atual não foi salvo. Tente novamente antes de apagá-lo.',
              ),
            ),
          ),
        );
      }
      return;
    }
    _applyingDraft = true;
    setState(() {
      _chapterTitleController.clear();
      _subtitleController.clear();
      _similarChaptersController.clear();
      _documentLanguageController.clear();
      _personNameController.clear();
      _fileNameController.text = 'document_genere';
      _manualTextController.clear();
      _downloadUrlController.clear();
      _clearFileSources();
      _cloudDocument = null;
      _status = null;
      _aiReview = null;
      _issueMessages = const [];
      _generatedPath = null;
      _libraryPath = null;
    });
    _applyingDraft = false;
    _draftChanged();
    try {
      await _drafts?.flush();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_drafts?.loading == true) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                                    issues: _issueMessages
                                        .map(strings.issue)
                                        .toList(),
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
                  final inputPanel = _InputPanel(
                    strings: strings,
                    chapterTitleController: _chapterTitleController,
                    subtitleController: _subtitleController,
                    similarChaptersController: _similarChaptersController,
                    manualTextController: _manualTextController,
                    fileSources: _fileSources,
                    fileSourceControllers: _fileSourceControllers,
                    onRemoveSource: _removeSource,
                    editingEnabled: !_isGenerating && !_isDownloading,
                    verseIssues: _issueMessages,
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
                  final editor = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [if (_drafts != null) _draftPanel(), inputPanel],
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
                    issues: _issueMessages.map(strings.issue).toList(),
                    generatedPath: _generatedPath,
                    libraryPath: _libraryPath,
                    cloudPanel: CloudPanel(
                      document: _cloudDocument,
                      onImport: _importCloudCopy,
                      onPickFiles: _pickFiles,
                      onExport: _exportCloudCopy,
                      onShare: _shareCloudCopy,
                      textColor: palette.text,
                      mutedColor: palette.mutedText,
                      accent: palette.accent,
                      surface: palette.surfaceStrong,
                      locale: strings.language.name,
                    ),
                    onOpenGenerated: _openGeneratedDocument,
                    onShareGenerated: _shareDocumentPath,
                    documentReady: _cloudDocument != null,
                    onShareLatest: _shareLatestDocument,
                    onDownloadForWord: _downloadLatestForWord,
                    onOpenWordAddIn: _openWordAddIn,
                    onOpenBrowserExtension: _openBrowserExtension,
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
                              GlassSurface(
                                tint: palette.surfaceStrong,
                                radius: 22,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: _CompactTopBar(
                                  strings: strings,
                                  language: _language,
                                  onLanguageChanged: (language) {
                                    setState(() {
                                      _language = language;
                                      _status = _issueMessages.isEmpty
                                          ? null
                                          : _strings.validationErrors(
                                              _issueMessages,
                                            );
                                      _aiReview = null;
                                    });
                                    widget.onLanguageChanged?.call(language);
                                    _draftChanged();
                                  },
                                  onClear: _clearAll,
                                  designMode: _designMode,
                                  onDesignModeChanged: (mode) =>
                                      setState(() => _designMode = mode),
                                  palette: palette,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_showReleaseNotice) ...[
                                ReleaseNotice(
                                  version: _appVersion,
                                  locale: strings.language.name,
                                  onDismiss: () => setState(
                                    () => _showReleaseNotice = false,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
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
    if (MediaQuery.sizeOf(context).width < 620) {
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
              if (kIsWeb)
                InstallAppButton(
                  version: _appVersion,
                  color: palette.text,
                  locale: strings.language.name,
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
                strings: strings,
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
          strings: strings,
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
        if (kIsWeb)
          InstallAppButton(
            version: _appVersion,
            color: palette.text,
            locale: strings.language.name,
          ),
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
    required this.strings,
    required this.palette,
    required this.onChanged,
  });

  final DesignMode mode;
  final AppStrings strings;
  final DesignPalette palette;
  final ValueChanged<DesignMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DesignMode>(
      tooltip: strings.changeStyle,
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
                      '${strings.designLabel(item)} · ${strings.designDescription(item)}',
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
              strings.designLabel(mode),
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
    if (MediaQuery.disableAnimationsOf(context)) return child;
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
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

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

class _SectionCard extends StatefulWidget {
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
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  Timer? _startTimer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _startTimer?.cancel();
      _entrance.value = 1;
      _started = true;
      return;
    }
    if (_started) return;
    _started = true;
    final stepNumber = int.tryParse(widget.step) ?? 1;
    _startTimer = Timer(Duration(milliseconds: 90 * stepNumber), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = widget.palette;
    return GlassSurface(
      tint: palette.surfaceStrong,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _entrance,
                  builder: (context, child) {
                    final progress = Curves.easeOutBack.transform(
                      _entrance.value,
                    );
                    return Transform.scale(
                      scale: 0.72 + progress * 0.28,
                      child: child,
                    );
                  },
                  child: Container(
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
                        widget.step,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
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
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.description,
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
            widget.child,
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
    required this.fileSources,
    required this.fileSourceControllers,
    required this.onRemoveSource,
    required this.editingEnabled,
    required this.verseIssues,
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
  final List<DocumentSource> fileSources;
  final List<TextEditingController> fileSourceControllers;
  final ValueChanged<DocumentSource> onRemoveSource;
  final bool editingEnabled;
  final List<String> verseIssues;
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
                            child: Text(
                              strings.documentLanguageLabel(language),
                            ),
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
                      errorText: verseIssues
                          .where(
                            (issue) =>
                                issue.startsWith('[TITLE-IN-SUBTITLE]') ||
                                issue.startsWith(
                                  '[FR-DATE] Sous-titre initial',
                                ),
                          )
                          .firstOrNull,
                      errorMaxLines: 5,
                      errorStyle: TextStyle(
                        color:
                            ThemeData.estimateBrightnessForColor(
                                  palette.surface,
                                ) ==
                                Brightness.dark
                            ? const Color(0xFFFFB4AB)
                            : const Color(0xFFB91C1C),
                      ),
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
                enabled: editingEnabled,
                minLines: MediaQuery.sizeOf(context).width < 600 ? 6 : 12,
                maxLines: 24,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: strings.inputHint,
                  alignLabelWithHint: true,
                ),
              ),
              VerseEditor(
                controller: manualTextController,
                foregroundColor: palette.text,
                languageController: documentLanguageController,
                locale: strings.language.name,
                enabled: editingEnabled,
                issues: verseIssues,
              ),
              if (fileSources.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  strings.importedFilesEditorTitle,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.importedFilesEditorDescription,
                  style: TextStyle(color: palette.mutedText, height: 1.4),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < fileSources.length; index++) ...[
                  _ImportedSourceEditor(
                    source: fileSources[index],
                    controller: fileSourceControllers[index],
                    languageController: documentLanguageController,
                    locale: strings.language.name,
                    enabled: editingEnabled,
                    issues: verseIssues,
                    onRemove: () => onRemoveSource(fileSources[index]),
                    removeLabel: strings.remove,
                    palette: palette,
                  ),
                  if (index != fileSources.length - 1)
                    const SizedBox(height: 14),
                ],
              ],
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

class _ImportedSourceEditor extends StatelessWidget {
  const _ImportedSourceEditor({
    required this.source,
    required this.controller,
    required this.languageController,
    required this.locale,
    required this.enabled,
    required this.issues,
    required this.onRemove,
    required this.removeLabel,
    required this.palette,
  });

  final DocumentSource source;
  final TextEditingController controller;
  final TextEditingController languageController;
  final String locale;
  final bool enabled;
  final List<String> issues;
  final VoidCallback onRemove;
  final String removeLabel;
  final DesignPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      decoration: BoxDecoration(
        color: palette.surfaceStrong.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.accent.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source.name,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: Text(removeLabel),
              ),
            ],
          ),
          TextField(
            controller: controller,
            enabled: enabled,
            minLines: 4,
            maxLines: 16,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              labelText: source.name,
              alignLabelWithHint: true,
            ),
          ),
          VerseEditor(
            controller: controller,
            foregroundColor: palette.text,
            languageController: languageController,
            locale: locale,
            enabled: enabled,
            issues: issues,
            sourceName: source.name,
          ),
        ],
      ),
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
    required this.documentReady,
    required this.onShareLatest,
    required this.onDownloadForWord,
    required this.onOpenWordAddIn,
    required this.onOpenBrowserExtension,
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
  final bool documentReady;
  final VoidCallback onShareLatest;
  final VoidCallback onDownloadForWord;
  final VoidCallback onOpenWordAddIn;
  final VoidCallback onOpenBrowserExtension;
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceStrong,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.accent.withValues(alpha: .45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.ios_share_rounded, color: palette.accent),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        strings.shareAndWord,
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
                  strings.shareAndWordDescription,
                  style: TextStyle(
                    color: palette.mutedText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: documentReady ? onShareLatest : null,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: Text(strings.shareDocument),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.text,
                        side: BorderSide(
                          color: palette.accent.withValues(alpha: .65),
                        ),
                      ),
                      onPressed: documentReady ? onDownloadForWord : null,
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: Text(
                        kIsWeb ? strings.downloadForWord : strings.openInWord,
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.text,
                        side: BorderSide(
                          color: palette.accent.withValues(alpha: .65),
                        ),
                      ),
                      onPressed: onOpenWordAddIn,
                      icon: const Icon(Icons.extension_outlined, size: 18),
                      label: Text(strings.wordAddIn),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.text,
                        side: BorderSide(
                          color: palette.accent.withValues(alpha: .65),
                        ),
                      ),
                      onPressed: onOpenBrowserExtension,
                      icon: const Icon(Icons.language_rounded, size: 18),
                      label: Text(strings.browserExtension),
                    ),
                  ],
                ),
                if (!documentReady) ...[
                  const SizedBox(height: 7),
                  Text(
                    strings.shareDownloadRequired,
                    style: TextStyle(color: palette.mutedText, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
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
    return _FeedbackEntrance(
      identity: status,
      child: Container(
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
      ),
    );
  }
}

class _FeedbackEntrance extends StatelessWidget {
  const _FeedbackEntrance({required this.identity, required this.child});

  final String identity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(identity),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - progress)),
          child: child,
        ),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
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

    return _FeedbackEntrance(
      identity: text,
      child: Container(
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
