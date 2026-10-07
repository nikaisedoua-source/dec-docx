/// Localizes diagnostics only at the display boundary. Capture groups preserve
/// file names, quoted source text, diagnostic codes and numbers verbatim.
String localizeIssue(String issue, String locale) {
  if (!const ['en', 'es', 'pt'].contains(locale)) return issue;
  String t(String en, String es, String pt) => switch (locale) {
    'es' => es,
    'pt' => pt,
    _ => en,
  };

  var prefix = '';
  var body = issue;
  final sourceLine = RegExp(r'^(.*), ligne (\d+) : (.*)$').firstMatch(issue);
  if (sourceLine != null) {
    prefix =
        '${sourceLine[1]}, ${t('line', 'línea', 'linha')} ${sourceLine[2]} : ';
    body = sourceLine[3]!;
  } else {
    final source = RegExp(
      r'^(.*) : (aucun paragraphe numerote trouve\..*)$',
    ).firstMatch(issue);
    if (source != null) {
      prefix =
          '${source[1] == 'Paragraphes' ? t('Paragraphs', 'Párrafos', 'Parágrafos') : source[1]} : ';
      body = source[2]!;
    }
  }
  final code = RegExp(r'^\[([^\]]+)\] ').firstMatch(body);
  if (code != null) {
    prefix += code[0]!;
    body = body.substring(code.end);
  }

  final exact = <String, String>{
    'Enregistrement interrompu': t(
      'Save interrupted',
      'Guardado interrumpido',
      'Salvamento interrompido',
    ),
    'Choisissez un dossier synchronisé.': t(
      'Choose a synchronized folder.',
      'Selecciona una carpeta sincronizada.',
      'Escolha uma pasta sincronizada.',
    ),
    'Accès refusé. Autorisez le dossier pour continuer.': t(
      'Access denied. Authorize the folder to continue.',
      'Acceso denegado. Autoriza la carpeta para continuar.',
      'Acesso negado. Autorize a pasta para continuar.',
    ),
    'Nom invalide': t('Invalid name', 'Nombre no válido', 'Nome inválido'),
    'Action inconnue': t(
      'Unknown action',
      'Acción desconocida',
      'Ação desconhecida',
    ),
    'Fichier introuvable': t(
      'File not found',
      'Archivo no encontrado',
      'Arquivo não encontrado',
    ),
    'Sous-titre : ce texte est le titre de la prédication. Place-le uniquement dans le champ Titre du chapitre.': t(
      'Subtitle: this is the sermon title. Enter it only in the Chapter title field.',
      'Subtítulo: este texto es el título de la predicación. Escríbelo únicamente en el campo Título del capítulo.',
      'Subtítulo: este texto é o título da pregação. Insira-o apenas no campo Título do capítulo.',
    ),
    'Paragraphes : colle ou importe le texte du chapitre. Les paragraphes doivent commencer par 1, 2, 3...': t(
      'Paragraphs: paste or import the chapter text. Paragraphs must begin with 1, 2, 3...',
      'Párrafos: pega o importa el texto del capítulo. Los párrafos deben comenzar por 1, 2, 3...',
      'Parágrafos: cole ou importe o texto do capítulo. Os parágrafos devem começar por 1, 2, 3...',
    ),
    'Paragraphes : aucun paragraphe numerote trouve. Ajoute des paragraphes qui commencent par leur numero.': t(
      'Paragraphs: no numbered paragraph was found. Add paragraphs beginning with their number.',
      'Párrafos: no se encontró ningún párrafo numerado. Añade párrafos que comiencen por su número.',
      'Parágrafos: nenhum parágrafo numerado foi encontrado. Adicione parágrafos que comecem pelo seu número.',
    ),
    'aucun paragraphe numerote trouve. Ajoute des paragraphes commencant par 1, 2, 3...': t(
      'no numbered paragraph was found. Add paragraphs beginning with 1, 2, 3...',
      'no se encontró ningún párrafo numerado. Añade párrafos que comiencen por 1, 2, 3...',
      'nenhum parágrafo numerado foi encontrado. Adicione parágrafos que comecem por 1, 2, 3...',
    ),
    'aucun paragraphe numerote trouve. Ajoute des paragraphes qui commencent par leur numero.': t(
      'no numbered paragraph was found. Add paragraphs beginning with their number.',
      'no se encontró ningún párrafo numerado. Añade párrafos que comiencen por su número.',
      'nenhum parágrafo numerado foi encontrado. Adicione parágrafos que comecem pelo seu número.',
    ),
    'Référence française incomplète : les dates des sous-titres ne peuvent pas être vérifiées. Réessaie la comparaison avant de générer.': t(
      'The French reference is incomplete: subtitle dates cannot be checked. Run the comparison again before generating the document.',
      'La referencia francesa está incompleta: no se pueden comprobar las fechas de los subtítulos. Repite la comparación antes de generar el documento.',
      'A referência francesa está incompleta: não é possível verificar as datas dos subtítulos. Repita a comparação antes de gerar o documento.',
    ),
    'Aucun texte exploitable pour générer le document.': t(
      'No usable text is available to generate the document.',
      'No hay texto utilizable para generar el documento.',
      'Não há texto utilizável para gerar o documento.',
    ),
    'Le fichier DOCX ne contient pas word/document.xml.': t(
      'The DOCX file does not contain word/document.xml.',
      'El archivo DOCX no contiene word/document.xml.',
      'O arquivo DOCX não contém word/document.xml.',
    ),
    'Aucune source de comparaison en ligne disponible.': t(
      'No online comparison source is available.',
      'No hay ninguna fuente de comparación en línea disponible.',
      'Nenhuma fonte de comparação online está disponível.',
    ),
    'Impossible de trouver les paragraphes du chapitre sur la page.': t(
      'The chapter paragraphs could not be found on the page.',
      'No se encontraron los párrafos del capítulo en la página.',
      'Não foi possível encontrar os parágrafos do capítulo na página.',
    ),
    'pinyin sans verset chinois précédent.': t(
      'pinyin without a preceding Chinese verse.',
      'pinyin sin un versículo chino anterior.',
      'pinyin sem um versículo chinês anterior.',
    ),
    'Dossier indisponible': t(
      'Folder unavailable',
      'Carpeta no disponible',
      'Pasta indisponível',
    ),
    'Dossier indisponible. Choisissez à nouveau le dossier synchronisé.': t(
      'Folder unavailable. Select the synchronized folder again.',
      'La carpeta no está disponible. Selecciona de nuevo la carpeta sincronizada.',
      'A pasta está indisponível. Selecione novamente a pasta sincronizada.',
    ),
    'Dossier indisponible. Reconnectez le disque ou le cloud.': t(
      'Folder unavailable. Reconnect the drive or cloud storage.',
      'La carpeta no está disponible. Vuelve a conectar la unidad o el almacenamiento en la nube.',
      'A pasta está indisponível. Reconecte o disco ou o armazenamento em nuvem.',
    ),
    'Chemin invalide': t('Invalid path', 'Ruta no válida', 'Caminho inválido'),
    'Fichier hors bibliothèque': t(
      'File outside the library',
      'Archivo fuera de la biblioteca',
      'Arquivo fora da biblioteca',
    ),
    'Impossible d’ouvrir le service.': t(
      'Unable to open the service.',
      'No se pudo abrir el servicio.',
      'Não foi possível abrir o serviço.',
    ),
    'Ajoute un texte avant de demander une analyse IA.': t(
      'Add text before requesting an AI review.',
      'Añade texto antes de solicitar una revisión con IA.',
      'Adicione texto antes de solicitar uma análise com IA.',
    ),
    'La réponse de l’assistant IA est vide.': t(
      'The AI assistant returned an empty response.',
      'El asistente de IA devolvió una respuesta vacía.',
      'O assistente de IA retornou uma resposta vazia.',
    ),
  };
  var translated = exact[body];
  Match? match(String pattern) => RegExp(pattern).firstMatch(body);

  var m = match(
    r'^Titre du chapitre : ce champ est obligatoire\. Mets un titre comme (.*)$',
  );
  if (m != null) {
    translated = t(
      'Chapter title: this field is required. Enter a title such as ${m[1]}',
      'Título del capítulo: este campo es obligatorio. Escribe un título como ${m[1]}',
      'Título do capítulo: este campo é obrigatório. Insira um título como ${m[1]}',
    );
  }
  m = match(
    r'^Titre du chapitre : ne l’écris pas entièrement en majuscules\. Écris-le normalement, par exemple (.*)\. Les débuts de phrase et les noms propres peuvent garder leur majuscule\.$',
  );
  if (m != null) {
    translated = t(
      'Chapter title: use normal capitalization, for example ${m[1]}. Sentences and proper names may start with a capital letter.',
      'Título del capítulo: usa mayúsculas y minúsculas normales, por ejemplo ${m[1]}. Las frases y los nombres propios pueden comenzar con mayúscula.',
      'Título do capítulo: use maiúsculas e minúsculas normalmente, por exemplo ${m[1]}. As frases e os nomes próprios podem começar com maiúscula.',
    );
  }
  m = match(
    r'^ce paragraphe n’a pas de numero -> (.*)\. Ajoute (.*) au debut de la ligne, ou transforme cette ligne en sous-titre clair comme (.*)\.$',
  );
  if (m != null) {
    translated = t(
      'this paragraph has no number → ${m[1]}. Add ${m[2]} at the start of the line, or turn this line into a clear subtitle such as ${m[3]}.',
      'este párrafo no tiene número → ${m[1]}. Añade ${m[2]} al principio de la línea o conviértela en un subtítulo claro como ${m[3]}.',
      'este parágrafo não tem número → ${m[1]}. Adicione ${m[2]} no início da linha ou transforme-a em um subtítulo claro como ${m[3]}.',
    );
  }
  m = match(
    r'^numero manquant ou incorrect\. Attendu (\d+) mais trouve (\d+)\. Ajoute le paragraphe (\d+) manquant ou corrige le numero (\d+)\.$',
  );
  if (m != null) {
    translated = t(
      'missing or incorrect number. Expected ${m[1]}, but found ${m[2]}. Add the missing paragraph ${m[3]} or correct number ${m[4]}.',
      'número ausente o incorrecto. Se esperaba ${m[1]}, pero se encontró ${m[2]}. Añade el párrafo ${m[3]} que falta o corrige el número ${m[4]}.',
      'número ausente ou incorreto. Esperado ${m[1]}, mas encontrado ${m[2]}. Adicione o parágrafo ${m[3]} ausente ou corrija o número ${m[4]}.',
    );
  }
  m = match(r'^le numero (\d+) existe mais aucun texte ne le suit\.$');
  if (m != null) {
    translated = t(
      'number ${m[1]} has no text after it.',
      'el número ${m[1]} no tiene texto después.',
      'o número ${m[1]} não tem texto depois dele.',
    );
  }
  m = match(
    r'^le numero (\d+) est seul et ne peut pas etre rattache a un texte\.$',
  );
  if (m != null) {
    translated = t(
      'number ${m[1]} stands alone and cannot be attached to text.',
      'el número ${m[1]} está solo y no se puede vincular a un texto.',
      'o número ${m[1]} está sozinho e não pode ser associado a um texto.',
    );
  }
  m = match(
    r'^verset (\d+) : ce numéro est absent de la référence française\.$',
  );
  if (m != null) {
    translated = t(
      'verse ${m[1]}: this number is absent from the French reference.',
      'versículo ${m[1]}: este número no aparece en la referencia francesa.',
      'versículo ${m[1]}: este número não aparece na referência francesa.',
    );
  }
  m = match(r'^verset (\d+) : transcription pinyin (manquante|répétée)\.$');
  if (m != null) {
    translated = m[2] == 'manquante'
        ? t(
            'verse ${m[1]}: missing pinyin transcription.',
            'versículo ${m[1]}: falta la transcripción pinyin.',
            'versículo ${m[1]}: transcrição pinyin ausente.',
          )
        : t(
            'verse ${m[1]}: repeated pinyin transcription.',
            'versículo ${m[1]}: transcripción pinyin repetida.',
            'versículo ${m[1]}: transcrição pinyin repetida.',
          );
  }
  m = match(
    r'^verset (\d+) : numéro pinyin attendu (\d+), trouvé (\d+|illisible)\.$',
  );
  if (m != null) {
    final found = m[3] == 'illisible'
        ? t('unreadable', 'ilegible', 'ilegível')
        : m[3];
    translated = t(
      'verse ${m[1]}: expected pinyin number ${m[2]}, found $found.',
      'versículo ${m[1]}: número de pinyin esperado ${m[2]}, encontrado $found.',
      'versículo ${m[1]}: número de pinyin esperado ${m[2]}, encontrado $found.',
    );
  }
  String location(String source) {
    if (source == 'Sous-titre initial') {
      return t('Initial subtitle', 'Subtítulo inicial', 'Subtítulo inicial');
    }
    final number = source.substring('Sous-titre après le verset '.length);
    return t(
      'Subtitle after verse $number',
      'Subtítulo después del versículo $number',
      'Subtítulo após o versículo $number',
    );
  }

  m = match(
    r'^(Sous-titre initial|Sous-titre après le verset \d+) : date\(s\) attendue\(s\) (.*?) ; trouvée\(s\) (.*?)\. Vérifie le jour, le mois, l’année et la position du sous-titre\.$',
  );
  if (m != null) {
    final expected = m[2] == 'aucune' ? t('none', 'ninguna', 'nenhuma') : m[2];
    final found = m[3] == 'aucune date reconnue'
        ? t(
            'no recognized date',
            'ninguna fecha reconocida',
            'nenhuma data reconhecida',
          )
        : m[3];
    translated = t(
      '${location(m[1]!)}: expected date(s) $expected; found $found. Check the day, month, year and subtitle position.',
      '${location(m[1]!)}: fecha(s) esperada(s) $expected; encontrada(s) $found. Comprueba el día, el mes, el año y la posición del subtítulo.',
      '${location(m[1]!)}: data(s) esperada(s) $expected; encontrada(s) $found. Verifique o dia, o mês, o ano e a posição do subtítulo.',
    );
  }
  m = match(
    r'^(Sous-titre initial|Sous-titre après le verset \d+) : jour et année concordent avec le français, mais le nom du mois n’a pas pu être vérifié dans cette langue\. Vérifie le mois avant de partager le document\.$',
  );
  if (m != null) {
    translated = t(
      '${location(m[1]!)}: the day and year match the French reference, but the month name could not be verified in this language. Check the month before sharing the document.',
      '${location(m[1]!)}: el día y el año coinciden con la referencia francesa, pero no se pudo verificar el nombre del mes en este idioma. Comprueba el mes antes de compartir el documento.',
      '${location(m[1]!)}: o dia e o ano coincidem com a referência francesa, mas não foi possível verificar o nome do mês neste idioma. Verifique o mês antes de compartilhar o documento.',
    );
  }
  m = match(r'^Ollama a répondu HTTP (\d+)\.$');
  if (m != null) {
    translated = t(
      'Ollama returned HTTP ${m[1]}.',
      'Ollama respondió con HTTP ${m[1]}.',
      'O Ollama retornou HTTP ${m[1]}.',
    );
  }
  m = match(
    r'^Version locale conservée \((.*?)\)\. Synchronisation à reprendre : (.*)$',
  );
  if (m != null) {
    final detail = localizeTechnicalError(m[2]!, locale);
    translated = t(
      'Local version preserved (${m[1]}). Synchronization must be resumed: $detail',
      'Versión local conservada (${m[1]}). Debes reanudar la sincronización: $detail',
      'Versão local preservada (${m[1]}). A sincronização precisa ser retomada: $detail',
    );
  }
  return translated == null ? issue : '$prefix$translated';
}

/// Translates known exception messages while retaining technical wrappers and
/// paths. Unexpected OS/plugin errors remain available as diagnostic details.
String localizeTechnicalError(Object error, String locale) {
  final value = error.toString();
  final direct = localizeIssue(value, locale);
  if (direct != value) return direct;
  final wrapper = RegExp(
    r'^(Error|NotFoundError|NotAllowedError|FormatException|FileSystemException|ClientException|Bad state|Invalid argument\(s\)|Unsupported operation): (.*)$',
    dotAll: true,
  ).firstMatch(value);
  if (wrapper == null) return value;
  final message = wrapper[2]!;
  final separator = message.indexOf(', path = ');
  final body = separator < 0 ? message : message.substring(0, separator);
  final path = separator < 0 ? '' : message.substring(separator);
  return '${wrapper[1]}: ${localizeIssue(body, locale)}$path';
}
