import 'package:flutter/material.dart';

/// Manual installation instructions for Safari, available from the web app.
class IphoneInstallGuide extends StatelessWidget {
  const IphoneInstallGuide({super.key, this.locale = 'fr'});

  final String locale;

  String _t(String fr, String en, String es, String pt) => switch (locale) {
    'en' => en,
    'es' => es,
    'pt' => pt,
    _ => fr,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _t(
          'Installer DEC DOCX sur iPhone',
          'Install DEC DOCX on iPhone',
          'Instalar DEC DOCX en iPhone',
          'Instalar o DEC DOCX no iPhone',
        ),
      ),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _t(
              'Ajoutez DEC DOCX à votre écran d’accueil depuis Safari.',
              'Add DEC DOCX to your home screen from Safari.',
              'Añade DEC DOCX a tu pantalla de inicio desde Safari.',
              'Adicione o DEC DOCX à tela de início pelo Safari.',
            ),
          ),
          const SizedBox(height: 20),
          _InstallStep(
            number: '1',
            icon: Icons.explore_outlined,
            title: _t(
              'Ouvrez le lien dans Safari',
              'Open the link in Safari',
              'Abre el enlace en Safari',
              'Abra o link no Safari',
            ),
            detail: _t(
              'Si vous venez de WhatsApp ou Telegram, copiez le lien puis collez-le dans la barre d’adresse de Safari.',
              'If you came from WhatsApp or Telegram, copy the link and paste it into Safari’s address bar.',
              'Si vienes de WhatsApp o Telegram, copia el enlace y pégalo en la barra de direcciones de Safari.',
              'Se você veio do WhatsApp ou Telegram, copie o link e cole-o na barra de endereço do Safari.',
            ),
          ),
          const SelectableText(
            'https://nikaisedoua-source.github.io/dec-docx/',
          ),
          const SizedBox(height: 16),
          _InstallStep(
            number: '2',
            icon: Icons.ios_share,
            title: _t(
              'Touchez Partager',
              'Tap Share',
              'Toca Compartir',
              'Toque em Compartilhar',
            ),
            detail: _t(
              'Cherchez le carré avec une flèche vers le haut. Selon votre version de Safari, ouvrez d’abord le menu de la page.',
              'Look for the square with an upward arrow. Depending on your Safari version, open the page menu first.',
              'Busca el cuadrado con una flecha hacia arriba. Según tu versión de Safari, abre primero el menú de la página.',
              'Procure o quadrado com uma seta para cima. Dependendo da versão do Safari, abra primeiro o menu da página.',
            ),
          ),
          _InstallStep(
            number: '3',
            icon: Icons.add_box_outlined,
            title: _t(
              'Choisissez « Sur l’écran d’accueil »',
              'Choose “Add to Home Screen”',
              'Elige «Añadir a pantalla de inicio»',
              'Escolha “Adicionar à Tela de Início”',
            ),
            detail: _t(
              'Faites défiler la liste des actions. Si cette option manque, touchez « Modifier les actions » en bas pour l’ajouter.',
              'Scroll through the actions. If this option is missing, tap “Edit Actions” at the bottom to add it.',
              'Desplázate por las acciones. Si no aparece, toca «Editar acciones» abajo para añadirla.',
              'Role a lista de ações. Se a opção não aparecer, toque em “Editar ações” na parte inferior para adicioná-la.',
            ),
          ),
          _InstallStep(
            number: '4',
            icon: Icons.check_circle_outline,
            title: _t(
              'Confirmez avec Ajouter',
              'Confirm with Add',
              'Confirma con Añadir',
              'Confirme com Adicionar',
            ),
            detail: _t(
              'Si « Ouvrir comme app web » apparaît, activez cette option. Gardez le nom DEC DOCX, puis touchez Ajouter.',
              'If “Open as Web App” appears, enable it. Keep the name DEC DOCX, then tap Add.',
              'Si aparece «Abrir como app web», actívalo. Conserva el nombre DEC DOCX y toca Añadir.',
              'Se aparecer “Abrir como app web”, ative a opção. Mantenha o nome DEC DOCX e toque em Adicionar.',
            ),
          ),
          Text(
            _t(
              'L’icône DEC DOCX apparaît sur votre écran d’accueil. Touchez-la pour ouvrir l’application.',
              'The DEC DOCX icon appears on your home screen. Tap it to open the app.',
              'El icono de DEC DOCX aparece en tu pantalla de inicio. Tócalo para abrir la aplicación.',
              'O ícone do DEC DOCX aparece na tela de início. Toque nele para abrir o aplicativo.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'L’ajout se confirme dans Safari. Une connexion Internet reste nécessaire pour vérifier les références françaises lors de la génération.',
              'The installation is confirmed in Safari. An Internet connection is still required to check French references during generation.',
              'La instalación se confirma en Safari. Se necesita conexión a Internet para comprobar las referencias francesas durante la generación.',
              'A instalação é confirmada no Safari. Ainda é necessária uma conexão à Internet para verificar as referências francesas durante a geração.',
            ),
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
          child: Text(_t('Compris', 'Got it', 'Entendido', 'Entendi')),
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
