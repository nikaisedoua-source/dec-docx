# Assistant local et connexion Word

DEC DOCX peut utiliser Ollama comme assistant facultatif de contrôle. Le modèle
recommandé pour commencer est `gemma3:4b` : il reste assez léger pour un
ordinateur personnel et travaille sur le texte sans que le chapitre quitte la
machine.

## Installation locale

1. Installer Ollama depuis [ollama.com](https://ollama.com).
2. Télécharger le modèle : `ollama pull gemma3:4b`.
3. Lancer Ollama, puis ouvrir DEC DOCX.
4. Dans le panneau « Assistant de contrôle », choisir « Analyser le chapitre ».

L’assistant donne des remarques de contrôle. Il ne réécrit pas le texte, ne
complète pas les versets et ne remplace pas les contrôles déterministes de DEC
DOCX.

## Word

La version actuelle peut déjà enregistrer le `.docx`, puis proposer « Ouvrir
dans Word » sur ordinateur lorsque Word est l’application associée aux fichiers
`.docx`.

Une extension Word complète sera un module séparé, basé sur un task pane
[Office Add-in](https://learn.microsoft.com/en-us/office/dev/add-ins/word/).
Elle pourra lire la sélection du document, envoyer le contenu à DEC DOCX et
réinsérer le résultat validé. Microsoft décrit ce type d’extension comme un
manifest publié avec une application web qui utilise Office.js pour interagir
avec le document. Cette séparation permet de conserver le moteur Flutter
stable et de publier l’extension pour Word Web, Windows, macOS et iPad sans
dupliquer la logique DOCX.

Un premier complément sideloadable est fourni dans `word_addin/`. Son manifeste
est `word_addin/manifest.xml` et son panneau sait lire la sélection Word,
ouvrir l’application locale puis réinsérer le texte validé.
