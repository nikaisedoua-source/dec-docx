# Configuration GitHub pour DEC DOCX

Ce projet est prepare pour une distribution gratuite sans store :

- GitHub Pages sert la version web et le fichier `update.json`.
- GitHub Releases heberge les installables Android, macOS et Windows.
- L'application mobile/desktop peut afficher un message de mise a jour quand `update.json` annonce une version plus recente.

## 1. Creer le depot

1. Va sur GitHub et cree un depot public, par exemple `dec-docx`.
2. Dans ce dossier, initialise Git si ce n'est pas encore fait :

```bash
git init
git branch -M main
git add .
git commit -m "Initial DEC DOCX release"
git remote add origin https://github.com/nikaisedoua-source/dec-docx.git
git push -u origin main
```

Le compte GitHub configure est `nikaisedoua-source`.

## 2. Activer GitHub Pages

1. Ouvre le depot GitHub.
2. Va dans `Settings` > `Pages`.
3. Dans `Build and deployment`, choisis `GitHub Actions`.
4. Va dans `Actions`.
5. Lance le workflow `Deploy DEC DOCX Web`.

Apres le deploiement, la version web sera disponible ici :

```text
https://nikaisedoua-source.github.io/dec-docx/
```

## 3. Publier les installables

1. Va dans `Actions`.
2. Lance `Publish DEC DOCX Release`.
3. Mets la version, par exemple `v1.6.0`.

Le workflow publie ces fichiers dans GitHub Releases :

- `DEC_DOCX.apk`
- `DEC_DOCX-mac.zip`
- `DEC_DOCX-windows.zip`, si le dossier Windows est disponible
- `update.json`

## 4. Configurer les messages de mise a jour

Le fichier `update.json` doit rester accessible en ligne. L'URL conseillee est :

```text
https://nikaisedoua-source.github.io/dec-docx/update.json
```

Quand tu reconstruis l'application, utilise cette commande avec ton URL :

```bash
/Users/macbookpro/developement/flutter/bin/flutter build apk --release --dart-define=DEC_DOCX_UPDATE_MANIFEST_URL=https://nikaisedoua-source.github.io/dec-docx/update.json
```

Pour macOS :

```bash
/Users/macbookpro/developement/flutter/bin/flutter build macos --release --dart-define=DEC_DOCX_UPDATE_MANIFEST_URL=https://nikaisedoua-source.github.io/dec-docx/update.json
```

Pour le web :

```bash
/Users/macbookpro/developement/flutter/bin/flutter build web --release --base-href /dec-docx/ --dart-define=DEC_DOCX_UPDATE_MANIFEST_URL=https://nikaisedoua-source.github.io/dec-docx/update.json
```

## 5. Mettre a jour une nouvelle version

1. Change la version dans `pubspec.yaml`, par exemple `1.6.1+10`.
2. Change `_appVersion` dans `lib/main.dart`, par exemple `1.6.1`.
3. Reconstruis Android, macOS, Web et Windows.
4. Copie les nouveaux fichiers dans `DEC_DOCX/`.
5. Mets a jour `update.json`.
6. Pousse sur GitHub.
7. Lance `Deploy DEC DOCX Web`.
8. Lance `Publish DEC DOCX Release` avec le nouveau tag, par exemple `v1.6.1`.

## 6. Utilisation de la version web

La version web s'utilise directement dans le navigateur :

1. Ouvre `https://nikaisedoua-source.github.io/dec-docx/`.
2. Choisis ou colle ton texte.
3. Entre obligatoirement la langue.
4. Genere le fichier DOCX.
5. Le navigateur telecharge le fichier, par exemple `KACOU 20 allemand.docx`.

Sur iPhone, ouvre l'URL avec Safari puis utilise `Partager` > `Ajouter a l'ecran d'accueil` pour avoir une icone comme une application.
