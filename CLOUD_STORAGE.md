# Sauvegarde et récupération dans DEC DOCX

## Fonctionnement livré

La section **Sauvegarde & cloud** utilise un dossier déjà synchronisé par
l'application de stockage de l'utilisateur. Elle ne se connecte pas aux API
cloud et ne gère ni mot de passe ni jeton OAuth. Choisir le nom d'un service
ne suffit pas à activer sa synchronisation : il faut choisir son vrai dossier
synchronisé, avec le client cloud installé et connecté.

1. Installer et connecter MEGA, Google Drive, OneDrive ou iCloud Drive.
2. Dans DEC DOCX, choisir le service puis **Relier un dossier synchronisé**.
3. Sélectionner le dossier géré par ce service.
4. Générer un Word puis **Sauvegarder le dernier Word**.
5. Sur un autre ordinateur, synchroniser ce même dossier avec le même compte,
   le relier dans DEC DOCX puis **Actualiser mes fichiers**.
6. Rechercher par nom, langue ou personne ; le menu du document permet
   **Enregistrer une copie** ou **Réimporter dans le chapitre**.

Arborescence : `dossier choisi/DEC DOCX/langue/personne/document-version.docx`.
Chaque génération crée d'abord une version locale, puis une copie dans le
dossier synchronisé lorsqu'il est relié. Chaque sauvegarde crée un nouveau nom
et conserve les anciennes versions.
Détacher le dossier retire uniquement le réglage local ; les documents restent.
Les documents générés restent accessibles dans la bibliothèque locale après
redémarrage. Sur le Web, cette bibliothèque repose sur IndexedDB et demande au
navigateur de rendre son stockage persistant lorsque cette possibilité existe.

## Disponibilité et limites

- Web : la bibliothèque locale fonctionne avec IndexedDB. L'accès à un dossier
  synchronisé n'est proposé que si `showDirectoryPicker` est disponible,
  en contexte sécurisé (HTTPS ou localhost). L'autorisation est conservée via
  IndexedDB, mais le navigateur peut demander de l'accorder de nouveau.
- Desktop natif : chemin du dossier enregistré dans le répertoire de support
  de l'application. La persistance des autorisations macOS sandboxées reste à
  valider dans une application distribuée signée.
- Mobile, Safari et autres navigateurs sans sélecteur de dossier : les boutons
  d'enregistrement et d'ouverture utilisent les fichiers du système. Le cloud
  doit être accessible via ce système, sinon télécharger puis charger le
  document dans l'application du fournisseur.
- Le statut confirme une écriture dans le dossier local. Il ne confirme jamais
  une téléversement distant. Connexion réseau, quota et progression doivent être
  vérifiés dans le client cloud. Aucune synchronisation en arrière-plan n'est
  opérée par DEC DOCX.
- Pas de création de compte, d'achat d'espace ni d'upload cloud pendant les tests.
- Une connexion OAuth directe (sans client de synchronisation) n'est pas incluse.
  Elle nécessite l'enregistrement de DEC DOCX chez chaque fournisseur, les
  identifiants publics d'application, les URL de redirection autorisées et des
  tests de consentement/révocation avec un compte de test.

## Offres consultées le 20 septembre 2026

Les quotas sont ceux du compte entier, pas une réservation exclusive pour
DEC DOCX. Les offres peuvent changer et certains comptes ont des conditions.

- MEGA annonce 20 Go : https://apps.apple.com/us/app/mega-encrypted-cloud-storage/id706857885
- Google Drive : jusqu'à 15 Go partagés avec Gmail/Photos : https://support.google.com/drive/answer/9312312?hl=en
- OneDrive : 5 Go partagés : https://support.microsoft.com/en-us/onedrive/microsoft-storage-faqs
- iCloud : 5 Go partagés : https://support.apple.com/en-ca/guide/icloud/mm3d17a80e23/1.0/icloud/1.0

## Vérification

- `flutter test --no-pub test/widget_test.dart test/cloud_storage_test.dart`
- `node --test test/cloud_storage_web_test.mjs`
- Les tests natifs écrivent et relisent des fichiers temporaires réels.
- Les tests JavaScript simulent les handles de fichiers et IndexedDB ; ils
  vérifient versions, restauration du lien, lecture, refus et annulation.
- Un transfert entre deux appareils via un compte réel reste à vérifier avec
  le dossier du fournisseur choisi par l'utilisateur.
