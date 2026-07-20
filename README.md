# DEC DOCX

Application Flutter pour Android, macOS, Web et Windows. Version actuelle : `1.6.0`.
Elle genere un fichier `.docx` a partir d'un texte colle, d'un fichier fourni,
ou de plusieurs fichiers fournis.

## Fonctionnalites

- Saisie separee du titre du chapitre, du sous-titre optionnel et des chapitres
  similaires optionnels.
- Saisie directe du texte des paragraphes.
- Interface utilisateur en francais, anglais, espagnol et portugais, avec
  drapeaux dans le selecteur de langue.
- Import de plusieurs fichiers `.txt`, `.md` ou `.docx`.
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

## Commandes utiles

```bash
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
