import 'package:flutter/material.dart';

/// Manual installation instructions for Safari, available from the web app.
class IphoneInstallGuide extends StatelessWidget {
  const IphoneInstallGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Installer DEC DOCX sur iPhone'),
      scrollable: true,
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Ajoutez DEC DOCX à votre écran d’accueil depuis Safari.'),
          SizedBox(height: 20),
          _InstallStep(
            number: '1',
            icon: Icons.explore_outlined,
            title: 'Ouvrez le lien dans Safari',
            detail:
                'Si vous venez de WhatsApp ou Telegram, copiez le lien puis collez-le dans la barre d’adresse de Safari.',
          ),
          SelectableText('https://nikaisedoua-source.github.io/dec-docx/'),
          SizedBox(height: 16),
          _InstallStep(
            number: '2',
            icon: Icons.ios_share,
            title: 'Touchez Partager',
            detail:
                'Cherchez le carré avec une flèche vers le haut. Selon votre version de Safari, ouvrez d’abord le menu de la page.',
          ),
          _InstallStep(
            number: '3',
            icon: Icons.add_box_outlined,
            title: 'Choisissez « Sur l’écran d’accueil »',
            detail:
                'Faites défiler la liste des actions. Si cette option manque, touchez « Modifier les actions » en bas pour l’ajouter.',
          ),
          _InstallStep(
            number: '4',
            icon: Icons.check_circle_outline,
            title: 'Confirmez avec Ajouter',
            detail:
                'Si « Ouvrir comme app web » apparaît, activez cette option. Gardez le nom DEC DOCX, puis touchez Ajouter.',
          ),
          Text(
            'L’icône DEC DOCX apparaît sur votre écran d’accueil. Touchez-la pour ouvrir l’application.',
          ),
          SizedBox(height: 12),
          Text(
            'L’ajout se confirme dans Safari. Une connexion Internet reste nécessaire pour vérifier les références françaises lors de la génération.',
          ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.primary,
            minimumSize: const Size(64, 44),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Compris'),
        ),
      ],
    );
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final String number;
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. $title',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
