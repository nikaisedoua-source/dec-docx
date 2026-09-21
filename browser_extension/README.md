# Extension navigateur DEC DOCX

Cette extension WebExtension fonctionne avec Chrome et Edge en mode développeur.
Elle fonctionne aussi temporairement dans Firefox. Elle ne lit que le texte que
l’utilisateur a explicitement sélectionné après avoir ouvert le panneau.

Le bouton principal copie la sélection dans le presse-papiers local, puis ouvre
DEC DOCX. Le texte n’est envoyé à aucun serveur par l’extension. Il suffit de le
coller dans « Contenu du chapitre ».

## Chrome et Edge

1. Décompresser l’archive.
2. Ouvrir `chrome://extensions` dans Chrome ou `edge://extensions` dans Edge.
3. Activer le mode développeur.
4. Choisir « Charger l’extension non empaquetée » et sélectionner ce dossier.

## Firefox

1. Ouvrir `about:debugging#/runtime/this-firefox`.
2. Choisir « Charger un module complémentaire temporaire ».
3. Sélectionner `manifest.json`.

Firefox retire une extension temporaire au redémarrage. Une installation
permanente demandera une signature et une publication sur Firefox Add-ons.
