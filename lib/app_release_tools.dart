import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'iphone_install_guide.dart';

class InstallAppButton extends StatelessWidget {
  const InstallAppButton({
    super.key,
    required this.version,
    this.color,
    this.platform,
    this.openUrl,
    this.locale = 'fr',
  });

  final String version;
  final Color? color;
  final TargetPlatform? platform;
  final Future<bool> Function(Uri)? openUrl;
  final String locale;

  String _t(String fr, String en, String es, String pt) => switch (locale) {
    'en' => en,
    'es' => es,
    'pt' => pt,
    _ => fr,
  };

  Future<void> _install(BuildContext context, TargetPlatform target) async {
    if (target == TargetPlatform.iOS) {
      await showDialog<void>(
        context: context,
        builder: (_) => IphoneInstallGuide(locale: locale),
      );
      return;
    }
    final asset = switch (target) {
      TargetPlatform.android => 'DEC-DOCX-Android-preview.apk',
      TargetPlatform.macOS => 'DEC-DOCX-macOS-preview.zip',
      TargetPlatform.windows => 'DEC-DOCX-Windows-preview.zip',
      _ => '',
    };
    final uri = Uri.parse(
      'https://github.com/nikaisedoua-source/dec-docx/releases/download/v$version-preview/$asset',
    );
    try {
      final opened =
          await (openUrl?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.platformDefault));
      if (!opened) throw StateError('Download unavailable');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'Impossible d’ouvrir le téléchargement. Réessaie dans un instant.',
                'Unable to open the download. Please try again in a moment.',
                'No se pudo abrir la descarga. Inténtalo de nuevo en un momento.',
                'Não foi possível abrir o download. Tente novamente em instantes.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = platform ?? defaultTargetPlatform;
    final (label, icon) = switch (target) {
      TargetPlatform.android => ('Android', Icons.android_rounded),
      TargetPlatform.iOS => ('iPhone', Icons.phone_iphone_rounded),
      TargetPlatform.macOS => ('Mac', Icons.laptop_mac_rounded),
      TargetPlatform.windows => ('Windows', Icons.desktop_windows_rounded),
      _ => ('cet appareil', Icons.install_desktop_rounded),
    };
    if (target == TargetPlatform.linux || target == TargetPlatform.fuchsia) {
      return PopupMenuButton<TargetPlatform>(
        tooltip: _t(
          'Installer l’application',
          'Install the app',
          'Instalar la aplicación',
          'Instalar o aplicativo',
        ),
        icon: Icon(icon, color: color),
        onSelected: (target) => _install(context, target),
        itemBuilder: (_) => const [
          PopupMenuItem(value: TargetPlatform.android, child: Text('Android')),
          PopupMenuItem(value: TargetPlatform.iOS, child: Text('iPhone')),
          PopupMenuItem(value: TargetPlatform.macOS, child: Text('Mac')),
          PopupMenuItem(value: TargetPlatform.windows, child: Text('Windows')),
        ],
      );
    }
    return IconButton(
      tooltip: _t(
        'Installer sur $label',
        'Install on $label',
        'Instalar en $label',
        'Instalar no $label',
      ),
      onPressed: () => _install(context, target),
      icon: Badge(
        backgroundColor: color ?? Theme.of(context).colorScheme.primary,
        child: Icon(icon, color: color),
      ),
    );
  }
}

class ReleaseNotice extends StatefulWidget {
  const ReleaseNotice({
    super.key,
    required this.version,
    required this.onDismiss,
    this.locale = 'fr',
  });
  final String version;
  final VoidCallback onDismiss;
  final String locale;

  @override
  State<ReleaseNotice> createState() => _ReleaseNoticeState();
}

class _ReleaseNoticeState extends State<ReleaseNotice> {
  late final Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 8), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _t(String fr, String en, String es, String pt) =>
      switch (widget.locale) {
        'en' => en,
        'es' => es,
        'pt' => pt,
        _ => fr,
      };
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 600),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - value)),
          child: child,
        ),
      ),
      child: Semantics(
        liveRegion: true,
        child: Material(
          color: const Color(0xFF00676F),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  _t(
                    'Nouveautés disponibles · v${widget.version}',
                    'New features available · v${widget.version}',
                    'Novedades disponibles · v${widget.version}',
                    'Novidades disponíveis · v${widget.version}',
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: _t('Fermer', 'Close', 'Cerrar', 'Fechar'),
                onPressed: widget.onDismiss,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
