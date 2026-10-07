import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../iphone_install_guide.dart';
import '../localized_issues.dart';

import 'cloud_models.dart';
import 'cloud_storage.dart';

class StorageGate extends StatefulWidget {
  const StorageGate({super.key, required this.child, this.locale});

  final Widget child;
  final String? locale;

  @override
  State<StorageGate> createState() => _StorageGateState();
}

class _StorageGateState extends State<StorageGate> {
  final CloudStorage _storage = CloudStorage();
  String _provider = 'Google Drive';
  String? _error;
  bool _loading = true;
  bool _busy = false;

  String get _locale =>
      widget.locale ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;

  String _t(String fr, String en, String es, String pt) => switch (_locale) {
    'en' => en,
    'es' => es,
    'pt' => pt,
    _ => fr,
  };

  String _quota(String provider, String value) => switch (_locale) {
    'en' => switch (provider) {
      'MEGA' => '20 GB advertised',
      'Google Drive' => 'Up to 15 GB',
      _ => '5 GB free',
    },
    'es' => switch (provider) {
      'MEGA' => '20 GB anunciados',
      'Google Drive' => 'Hasta 15 GB',
      _ => '5 GB gratuitos',
    },
    'pt' => switch (provider) {
      'MEGA' => '20 GB anunciados',
      'Google Drive' => 'Até 15 GB',
      _ => '5 GB gratuitos',
    },
    _ => value,
  };

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      await _storage.restore();
      if (_storage.provider != null &&
          cloudProviders.containsKey(_storage.provider)) {
        _provider = _storage.provider!;
      }
    } catch (error) {
      _error = _t(
        'Le stockage précédent est indisponible : ${localizeTechnicalError(error, _locale)}',
        'The previous storage location is unavailable: ${localizeTechnicalError(error, _locale)}',
        'El almacenamiento anterior no está disponible: ${localizeTechnicalError(error, _locale)}',
        'O armazenamento anterior não está disponível: ${localizeTechnicalError(error, _locale)}',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = _t(
            'Connexion non terminée : ${localizeTechnicalError(error, _locale)}',
            'Connection did not finish: ${localizeTechnicalError(error, _locale)}',
            'La conexión no terminó: ${localizeTechnicalError(error, _locale)}',
            'A conexão não terminou: ${localizeTechnicalError(error, _locale)}',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if ((_storage.mode == 'local') || _storage.connected) return widget.child;

    final needsAuthorization =
        _storage.mode == 'folder' && _storage.folder != null;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff37106b), Color(0xff130b31)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  color: const Color(0xfffbf7ff),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.folder_copy_outlined,
                          size: 42,
                          color: Color(0xff6f2bd3),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          needsAuthorization
                              ? _t(
                                  'Réautoriser votre stockage',
                                  'Reauthorize your storage',
                                  'Volver a autorizar el almacenamiento',
                                  'Reautorizar seu armazenamento',
                                )
                              : _t(
                                  'Où conserver vos documents ?',
                                  'Where should your documents be kept?',
                                  '¿Dónde guardar sus documentos?',
                                  'Onde seus documentos devem ser guardados?',
                                ),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          needsAuthorization
                              ? _t(
                                  'Le dossier ${_storage.folder} est mémorisé, mais le navigateur demande votre autorisation pour y accéder de nouveau.',
                                  'The folder ${_storage.folder} is remembered, but the browser needs your authorization to access it again.',
                                  'La carpeta ${_storage.folder} está guardada, pero el navegador necesita autorización para acceder de nuevo.',
                                  'A pasta ${_storage.folder} foi memorizada, mas o navegador precisa de autorização para acessá-la novamente.',
                                )
                              : _t(
                                  'Ce choix est mémorisé. Vous pourrez le modifier ensuite dans Sauvegarde et cloud.',
                                  'This choice is remembered. You can change it later in Backup and cloud.',
                                  'Esta elección se guarda. Podrá cambiarla después en Copia de seguridad y nube.',
                                  'Esta escolha é memorizada. Você poderá alterá-la depois em Backup e nuvem.',
                                ),
                          textAlign: TextAlign.center,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: Color(0xff9c1c3e)),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (kIsWeb) ...[
                          TextButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  IphoneInstallGuide(locale: _locale),
                            ),
                            icon: const Icon(Icons.phone_iphone),
                            label: Text(
                              _t(
                                'Installer sur iPhone — guide',
                                'Install on iPhone — guide',
                                'Instalar en iPhone — guía',
                                'Instalar no iPhone — guia',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (needsAuthorization) ...[
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(_storage.authorize),
                            icon: const Icon(Icons.lock_open_outlined),
                            label: Text(
                              _t(
                                'Autoriser ${_storage.provider ?? 'le dossier'}',
                                'Authorize ${_storage.provider ?? 'the folder'}',
                                'Autorizar ${_storage.provider ?? 'la carpeta'}',
                                'Autorizar ${_storage.provider ?? 'a pasta'}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff35125f),
                            side: const BorderSide(color: Color(0xff7c3bd1)),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _run(_storage.chooseLocal),
                          icon: const Icon(Icons.computer_outlined),
                          label: Text(
                            _t(
                              'Sur cet appareil',
                              'On this device',
                              'En este dispositivo',
                              'Neste dispositivo',
                            ),
                          ),
                        ),
                        if (_storage.supported) ...[
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    _t(
                                      'OU DOSSIER SYNCHRONISÉ',
                                      'OR SYNCHRONIZED FOLDER',
                                      'O CARPETA SINCRONIZADA',
                                      'OU PASTA SINCRONIZADA',
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _provider,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _t(
                                'Service cloud installé',
                                'Installed cloud service',
                                'Servicio de nube instalado',
                                'Serviço de nuvem instalado',
                              ),
                            ),
                            items: cloudProviders.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(
                                      '${entry.key} · ${_quota(entry.key, entry.value.quota)}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _provider = value!),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                    () => _storage.choose(
                                      _provider,
                                      locale: _locale,
                                    ),
                                  ),
                            icon: const Icon(Icons.cloud_done_outlined),
                            label: Text(
                              _t(
                                'Choisir et relier le dossier',
                                'Choose and connect the folder',
                                'Elegir y conectar la carpeta',
                                'Escolher e conectar a pasta',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t(
                              'Sélectionnez le dossier déjà synchronisé par Google Drive, MEGA, OneDrive ou iCloud. Une simple connexion au site du service ne donne pas encore accès à ce dossier.',
                              'Select the folder already synchronized by Google Drive, MEGA, OneDrive, or iCloud. Signing in to the service website alone does not grant access to this folder.',
                              'Seleccione la carpeta ya sincronizada por Google Drive, MEGA, OneDrive o iCloud. Iniciar sesión en el sitio del servicio no da acceso a esta carpeta.',
                              'Selecione a pasta já sincronizada pelo Google Drive, MEGA, OneDrive ou iCloud. Apenas entrar no site do serviço não dá acesso a essa pasta.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (_busy) ...[
                          const SizedBox(height: 14),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
