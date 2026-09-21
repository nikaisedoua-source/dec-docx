# Extension Word DEC DOCX

Cette extension est un complément Office gratuit et sideloadable. Elle ajoute
un panneau DEC DOCX à Word pour lire la sélection, ouvrir l’application locale,
puis réinsérer le texte validé.

## Installation depuis la version publique

1. Télécharger `manifest.xml` depuis la page Word de DEC DOCX.
2. Dans Word, ouvrir **Compléments > Autres compléments > Mes compléments**, puis
   choisir le chargement d’un complément personnalisé.
3. Sélectionner `manifest.xml`.
4. Ouvrir **Contrôler avec DEC DOCX** depuis l’onglet Accueil.

Pour un test rapide avec Node.js :

```bash
npx office-addin-dev-certs install
npx http-server . -S -C ~/.office-addin-dev-certs/localhost.crt -K ~/.office-addin-dev-certs/localhost.key -p 3000
```

Le panneau ne contient aucune clé payante et ne remplace pas le moteur Flutter.
Le panneau, ses icônes et DEC DOCX sont servis en HTTPS depuis GitHub Pages.
Le complément est gratuit et n’utilise aucune clé payante. Tant qu’il n’est pas
distribué dans Microsoft AppSource, Word demande un chargement manuel du
manifeste par l’utilisateur ou par son administrateur Microsoft 365.
