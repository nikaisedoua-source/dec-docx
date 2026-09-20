# DEC DOCX

Application Flutter pour Android, macOS, Web et Windows. Version actuelle : `1.9.0`.
Elle genere un fichier `.docx` a partir d'un texte colle, d'un fichier fourni,
ou de plusieurs fichiers fournis.

## Telechargements publics

Les liens directs sont listes dans [TELECHARGEMENTS.md](TELECHARGEMENTS.md).

## Fonctionnalites

- Saisie separee du titre du chapitre, du sous-titre optionnel et des chapitres
  similaires optionnels.
- Saisie directe du texte des paragraphes.
- Interface utilisateur en francais, anglais, espagnol et portugais, avec
  drapeaux dans le selecteur de langue.
- Import de plusieurs fichiers `.txt`, `.md`, `.docx` ou `.pdf`.
  Sur le Web, PDF.js lit les PDF localement dans le navigateur, y compris les
  caractères chinois et les accents pinyin (version et licence dans
  `web/vendor/pdfjs/`). Les applications natives conservent leur lecteur
  existant ; ce PDF chinois y nécessite encore une correction du lecteur.
- Telechargement d'un texte depuis une URL directement dans l'application.
- Nettoyage des copies de conversations : les lignes de nom, heure ou date
  avant les paragraphes numerotes sont ignorees.
- Generation Word au format indique dans les fichiers temoins : titre en gras et
  en majuscules, sous-titre en italique, numero en gras separe du texte par un
  espace, page A4.
- Chapitres similaires ajoutes tels que saisis par le traducteur, sans prefixe
  francais automatique, a la fin du dernier paragraphe en bleu italique.
- Validation bloquante quand un paragraphe n'a pas de numero ou quand un numero
  saute.
- Reparation des mauvais formats courants : numeros seuls sur une ligne et
  plusieurs paragraphes numerotes colles sur une meme ligne.
- Comparaison du nombre de paragraphes avec le chapitre francais correspondant
  sur `www.philippekacou.org`, sans limite fixe de numero de chapitre. Si la
  connexion internet est absente, la generation reste possible avec les
  controles locaux.
- Identite visuelle DEC DOCX dans l'interface.
- Enregistrement du `.docx` sur desktop et mobile.
- Partage du document lorsque la plateforme ne renvoie pas de chemin de sortie.
- Bibliothèque locale organisée par langue puis par personne ou groupe, avec
  ouverture dans Word, partage vers les applications disponibles et ouverture
  du dossier de conservation.
- Mode chinois dédié : les lignes consécutives sans nouveau numéro restent dans
  le même verset. Les couples chinois + pinyin acceptent les formes
  `Pinyin : 1` et `Pinyin 1 :` ; le Word place le pinyin sous le chinois.
  Les transcriptions absentes, répétées ou mal numérotées sont signalées par
  des codes `ZH-PINYIN-*`, avec les lignes sources. Les titres de partie
  sont séparés et générés en gras. Les dates coupées par la pagination restent
  dans leur verset. Le titre chinois conserve la casse du pinyin.
- Complément Word gratuit à charger depuis `word_addin/manifest.xml` pour lire
  une sélection, ouvrir DEC DOCX et réinsérer le texte validé.

## Sauvegarde cloud

La section **Sauvegarde & cloud** relie la bibliothèque à un dossier synchronisé
MEGA, Google Drive, OneDrive ou iCloud Drive, avec versions et récupération.
Le fournisseur assure la synchronisation ; DEC DOCX confirme l’écriture locale.
Consulter [CLOUD_STORAGE.md](CLOUD_STORAGE.md) pour la configuration, les quotas
et les limites sur mobile et dans les navigateurs.

## Commandes utiles

```bash
python3 tool/prepare_release_assets.py
flutter pub get
flutter analyze
flutter test
flutter build apk
flutter build macos
flutter build windows
```

La compilation macOS exige une installation Xcode complete. La compilation
Windows doit etre lancee depuis une machine Windows avec le support Flutter
desktop active.

Sur cette machine, `flutter build apk`, `flutter analyze` et `flutter test`
fonctionnent. `flutter build macos` echoue tant que `xcodebuild` est absent, et
`flutter build windows` est refuse par Flutter hors Windows.
