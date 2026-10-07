import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloud_models.dart';
import 'cloud_storage.dart';
import '../localized_issues.dart';

class CloudPanel extends StatefulWidget {
  const CloudPanel({
    super.key,
    required this.document,
    required this.onImport,
    required this.onPickFiles,
    required this.onExport,
    required this.onShare,
    required this.textColor,
    required this.mutedColor,
    required this.accent,
    required this.surface,
    this.locale = 'fr',
  });
  final CloudDocument? document;
  final void Function(String, Uint8List) onImport;
  final VoidCallback onPickFiles;
  final Future<void> Function(String, Uint8List) onExport;
  final Future<void> Function(String, Uint8List) onShare;
  final Color textColor, mutedColor, accent, surface;
  final String locale;
  @override
  State<CloudPanel> createState() => _CloudPanelState();
}

class _CloudPanelState extends State<CloudPanel> {
  final _storage = CloudStorage();
  String _provider = 'MEGA';
  String _search = '';
  bool _localView = true;
  String? _message;
  bool _busy = false;
  List<CloudFile> _files = [];

  String _t(String fr, String en, String es, String pt) =>
      switch (widget.locale) {
        'en' => en,
        'es' => es,
        'pt' => pt,
        _ => fr,
      };

  String _quota(String provider, String value) => switch (widget.locale) {
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

  String _providerNote(
    String provider,
    String fallback,
  ) => switch (widget.locale) {
    'en' => switch (provider) {
      'MEGA' => 'Check the free quota assigned to your account.',
      'Google Drive' =>
        'Space shared with Gmail and Google Photos; terms depend on the account.',
      'OneDrive' =>
        'Space shared with other Microsoft services on the account.',
      _ => 'Space shared with iCloud photos and backups.',
    },
    'es' => switch (provider) {
      'MEGA' => 'Comprueba la cuota gratuita asignada a tu cuenta.',
      'Google Drive' =>
        'Espacio compartido con Gmail y Google Fotos; las condiciones dependen de la cuenta.',
      'OneDrive' =>
        'Espacio compartido con otros servicios de Microsoft de la cuenta.',
      _ => 'Espacio compartido con las fotos y copias de seguridad de iCloud.',
    },
    'pt' => switch (provider) {
      'MEGA' => 'Verifique a cota gratuita atribuída à sua conta.',
      'Google Drive' =>
        'Espaço compartilhado com o Gmail e o Google Fotos; as condições dependem da conta.',
      'OneDrive' =>
        'Espaço compartilhado com outros serviços Microsoft da conta.',
      _ => 'Espaço compartilhado com as fotos e backups do iCloud.',
    },
    _ => fallback,
  };
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      await _storage.restore();
      await _refresh();
      if (mounted) {
        setState(() {
          _provider = cloudProviders.containsKey(_storage.provider)
              ? _storage.provider!
              : 'MEGA';
          _message = _storage.connected
              ? _t(
                  'Dossier ${_storage.provider} connecté et prêt.',
                  '${_storage.provider} folder connected and ready.',
                  'Carpeta de ${_storage.provider} conectada y lista.',
                  'Pasta ${_storage.provider} conectada e pronta.',
                )
              : _storage.mode == 'local'
              ? _t(
                  'Bibliothèque locale prête. Les documents restent disponibles après la fermeture.',
                  'Local library ready. Documents remain available after closing.',
                  'Biblioteca local lista. Los documentos siguen disponibles después de cerrar.',
                  'Biblioteca local pronta. Os documentos continuam disponíveis após fechar.',
                )
              : _storage.mode == 'folder'
              ? _t(
                  'Le dossier est mémorisé. Autorisez de nouveau son accès pour continuer.',
                  'The folder is remembered. Authorize access again to continue.',
                  'La carpeta está guardada. Autoriza de nuevo el acceso para continuar.',
                  'A pasta foi memorizada. Autorize novamente o acesso para continuar.',
                )
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _t(
            'La connexion au dossier n’a pas pu être restaurée. Choisissez-le à nouveau.',
            'The folder connection could not be restored. Choose it again.',
            'No se pudo restaurar la conexión con la carpeta. Elígela de nuevo.',
            'Não foi possível restaurar a conexão com a pasta. Escolha-a novamente.',
          ),
        );
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      // A local recovery copy may have been written before a cloud failure.
      // Refresh the visible library without replacing the original error.
      try {
        await _refresh();
      } catch (_) {}
      if (mounted) {
        setState(
          () => _message = _t(
            'Action non terminée : ${localizeTechnicalError(error, widget.locale)}',
            'Action not completed: ${localizeTechnicalError(error, widget.locale)}',
            'Acción no completada: ${localizeTechnicalError(error, widget.locale)}',
            'Ação não concluída: ${localizeTechnicalError(error, widget.locale)}',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final files = _localView
        ? await _storage.listLocal()
        : await _storage.list();
    if (mounted) setState(() => _files = files);
  }

  Future<void> _choose() async {
    await _storage.choose(_provider, locale: widget.locale);
    if (_storage.connected) await _refresh();
  }

  Future<void> _authorize() async {
    await _storage.authorize();
    if (_storage.connected) {
      await _refresh();
      if (mounted) {
        setState(
          () => _message = _t(
            'Dossier ${_storage.provider} reconnecté et prêt.',
            '${_storage.provider} folder reconnected and ready.',
            'Carpeta de ${_storage.provider} reconectada y lista.',
            'Pasta ${_storage.provider} reconectada e pronta.',
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    final doc = widget.document;
    if (doc == null) return;
    final path = await _storage.save(doc);
    if (mounted) {
      setState(
        () => _message = _storage.mode == 'local'
            ? _t(
                'Version enregistrée dans la bibliothèque locale : $path.',
                'Version saved in the local library: $path.',
                'Versión guardada en la biblioteca local: $path.',
                'Versão salva na biblioteca local: $path.',
              )
            : _t(
                'Copie enregistrée : $path. La synchronisation distante est gérée par ${_storage.provider} ; vérifiez son indicateur.',
                'Copy saved: $path. Remote synchronization is managed by ${_storage.provider}; check its indicator.',
                'Copia guardada: $path. La sincronización remota la gestiona ${_storage.provider}; comprueba su indicador.',
                'Cópia salva: $path. A sincronização remota é gerida pelo ${_storage.provider}; verifique o indicador.',
              ),
      );
    }
    // A refresh failure must not hide the successful write.
    try {
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _t(
            'Copie enregistrée : $path. Actualisez la liste pour la retrouver.',
            'Copy saved: $path. Refresh the list to find it.',
            'Copia guardada: $path. Actualiza la lista para encontrarla.',
            'Cópia salva: $path. Atualize a lista para encontrá-la.',
          ),
        );
      }
    }
  }

  String _formatModified(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
  }

  Future<Uint8List> _readFile(String path) =>
      _localView ? _storage.readLocal(path) : _storage.read(path);
  Future<void> _import(CloudFile file) async {
    final bytes = await _readFile(file.path);
    widget.onImport(file.name, bytes);
    if (mounted) {
      setState(
        () => _message = _t(
          'Document ajouté aux fichiers du chapitre : ${file.name}',
          'Document added to the chapter files: ${file.name}',
          'Documento añadido a los archivos del capítulo: ${file.name}',
          'Documento adicionado aos arquivos do capítulo: ${file.name}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = cloudProviders[_provider]!;
    final connected = _storage.connected;
    final localReady = _storage.mode == 'local';
    final needsAuthorization =
        _storage.mode == 'folder' && _storage.folder != null && !connected;
    final visible = _files
        .where((f) => f.path.toLowerCase().contains(_search.toLowerCase()))
        .toList();
    final style = TextStyle(
      color: widget.mutedColor,
      fontSize: 12,
      height: 1.4,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.accent.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_outlined, color: widget.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(
                    'Sauvegarde et cloud',
                    'Backup and cloud',
                    'Copia de seguridad y nube',
                    'Backup e nuvem',
                  ),
                  style: TextStyle(
                    color: widget.textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'Conservez vos documents et retrouvez-les sur vos appareils.',
              'Keep your documents and access them on your devices.',
              'Conserva tus documentos y accede a ellos desde tus dispositivos.',
              'Mantenha seus documentos e acesse-os em seus dispositivos.',
            ),
            style: style,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: widget.accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.accent.withValues(alpha: .25)),
            ),
            child: Row(
              children: [
                Icon(
                  connected
                      ? Icons.cloud_done_outlined
                      : localReady
                      ? Icons.devices_outlined
                      : needsAuthorization
                      ? Icons.lock_outline
                      : Icons.cloud_off_outlined,
                  size: 18,
                  color: widget.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    connected
                        ? _t(
                            'Dossier synchronisé prêt',
                            'Synchronized folder ready',
                            'Carpeta sincronizada lista',
                            'Pasta sincronizada pronta',
                          )
                        : localReady
                        ? _t(
                            'Bibliothèque locale prête',
                            'Local library ready',
                            'Biblioteca local lista',
                            'Biblioteca local pronta',
                          )
                        : needsAuthorization
                        ? _t(
                            'Autorisation du dossier requise',
                            'Folder authorization required',
                            'Se requiere autorización de la carpeta',
                            'Autorização da pasta necessária',
                          )
                        : _t(
                            'Aucun stockage sélectionné',
                            'No storage selected',
                            'No se seleccionó almacenamiento',
                            'Nenhum armazenamento selecionado',
                          ),
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_provider),
            initialValue: _provider,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _t(
                'Service de stockage',
                'Storage service',
                'Servicio de almacenamiento',
                'Serviço de armazenamento',
              ),
            ),
            items: cloudProviders.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      '${e.key} · ${_quota(e.key, e.value.quota)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (value) => setState(() => _provider = value!),
          ),
          const SizedBox(height: 6),
          Text(
            '${_providerNote(_provider, info.note)} ${_t('Offres gratuites vérifiées le 20/09/2026, susceptibles d’évoluer.', 'Free plans checked on 20/09/2026 and subject to change.', 'Planes gratuitos comprobados el 20/09/2026, sujetos a cambios.', 'Planos gratuitos verificados em 20/09/2026 e sujeitos a alterações.')}',
            style: style,
          ),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    if (!await launchUrl(
                      Uri.parse(info.url),
                      mode: LaunchMode.externalApplication,
                    )) {
                      throw StateError('Impossible d’ouvrir le service.');
                    }
                  }),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(
              _t(
                'Ouvrir $_provider',
                'Open $_provider',
                'Abrir $_provider',
                'Abrir $_provider',
              ),
            ),
          ),
          if (localReady) ...[
            Text(
              _t(
                'Bibliothèque locale active. Chaque Word généré est conservé automatiquement avec une nouvelle version.',
                'Local library active. Each generated Word file is saved automatically as a new version.',
                'Biblioteca local activa. Cada Word generado se guarda automáticamente como una nueva versión.',
                'Biblioteca local ativa. Cada Word gerado é salvo automaticamente como uma nova versão.',
              ),
              style: style,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy || widget.document == null
                      ? null
                      : () => _run(_save),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _t(
                      'Nouvelle version',
                      'New version',
                      'Nueva versión',
                      'Nova versão',
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _run(_refresh),
                  icon: const Icon(Icons.sync),
                  label: Text(
                    _t('Actualiser', 'Refresh', 'Actualizar', 'Atualizar'),
                  ),
                ),
              ],
            ),
          ],
          if (_storage.supported) ...[
            Text(
              connected
                  ? _t(
                      'Connexion active : DEC DOCX peut lire et enregistrer dans le dossier synchronisé.',
                      'Connection active: DEC DOCX can read and save in the synchronized folder.',
                      'Conexión activa: DEC DOCX puede leer y guardar en la carpeta sincronizada.',
                      'Conexão ativa: o DEC DOCX pode ler e salvar na pasta sincronizada.',
                    )
                  : _t(
                      'Installez et connectez l’application du cloud, puis choisissez son dossier synchronisé. Une connexion au site seule ne donne pas accès au dossier.',
                      'Install and connect the cloud app, then choose its synchronized folder. A website login alone does not grant folder access.',
                      'Instala y conecta la aplicación de nube y elige su carpeta sincronizada. Iniciar sesión en el sitio no da acceso a la carpeta.',
                      'Instale e conecte o aplicativo de nuvem e escolha sua pasta sincronizada. O login no site, sozinho, não dá acesso à pasta.',
                    ),
              style: style,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (needsAuthorization)
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _run(_authorize),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: Text(
                      _t(
                        'Réautoriser ${_storage.provider}',
                        'Reauthorize ${_storage.provider}',
                        'Volver a autorizar ${_storage.provider}',
                        'Reautorizar ${_storage.provider}',
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(_choose),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(
                    connected
                        ? _t(
                            'Changer de dossier',
                            'Change folder',
                            'Cambiar carpeta',
                            'Alterar pasta',
                          )
                        : needsAuthorization
                        ? _t(
                            'Choisir un autre dossier',
                            'Choose another folder',
                            'Elegir otra carpeta',
                            'Escolher outra pasta',
                          )
                        : _t(
                            'Relier un dossier synchronisé',
                            'Connect a synchronized folder',
                            'Conectar una carpeta sincronizada',
                            'Conectar uma pasta sincronizada',
                          ),
                  ),
                ),
              ],
            ),
            if (connected) ...[
              const SizedBox(height: 6),
              Text(
                '${_t('Dossier relié', 'Connected folder', 'Carpeta conectada', 'Pasta conectada')} · ${_storage.provider}\n${_storage.folder}',
                style: TextStyle(color: widget.textColor, fontSize: 12),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy || widget.document == null
                    ? null
                    : () => _run(_save),
                icon: const Icon(Icons.backup_outlined),
                label: Text(
                  _t(
                    'Sauvegarder le dernier Word',
                    'Save the latest Word file',
                    'Guardar el último Word',
                    'Salvar o último Word',
                  ),
                ),
              ),
              Text(
                _t(
                  'Une nouvelle version à chaque sauvegarde. Le quota et la synchronisation restent à vérifier dans votre cloud.',
                  'A new version is created with each save. Check the quota and synchronization in your cloud service.',
                  'Se crea una nueva versión con cada guardado. Comprueba la cuota y la sincronización en tu servicio de nube.',
                  'Uma nova versão é criada a cada salvamento. Verifique a cota e a sincronização no seu serviço de nuvem.',
                ),
                style: style,
              ),
              Wrap(
                spacing: 6,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : () => _run(_refresh),
                    icon: const Icon(Icons.sync),
                    label: Text(
                      _t(
                        'Actualiser mes fichiers',
                        'Refresh my files',
                        'Actualizar mis archivos',
                        'Atualizar meus arquivos',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _storage.disconnect();
                            _localView = true;
                            await _refresh();
                          }),
                    child: Text(
                      _t(
                        'Détacher le dossier',
                        'Detach folder',
                        'Desconectar carpeta',
                        'Desvincular pasta',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ] else if (!localReady) ...[
            Text(
              _t(
                'Ce navigateur ou appareil ne donne pas accès à un dossier permanent. Utilisez Enregistrer une copie, puis le dossier cloud proposé par votre appareil, ou chargez le fichier dans le service choisi.',
                'This browser or device cannot access a permanent folder. Use Save a copy, then the cloud folder offered by your device, or upload the file to the selected service.',
                'Este navegador o dispositivo no permite acceder a una carpeta permanente. Usa Guardar una copia y después la carpeta de nube del dispositivo, o carga el archivo en el servicio elegido.',
                'Este navegador ou dispositivo não acessa uma pasta permanente. Use Salvar uma cópia e depois a pasta de nuvem oferecida pelo dispositivo, ou envie o arquivo ao serviço escolhido.',
              ),
              style: style,
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(
                  _t(
                    'Cet appareil',
                    'This device',
                    'Este dispositivo',
                    'Este dispositivo',
                  ),
                ),
                selected: _localView,
                onSelected: _busy
                    ? null
                    : (_) => _run(() async {
                        _localView = true;
                        await _refresh();
                      }),
              ),
              if (connected)
                ChoiceChip(
                  label: Text(
                    _t(
                      'Dossier connecté',
                      'Connected folder',
                      'Carpeta conectada',
                      'Pasta conectada',
                    ),
                  ),
                  selected: !_localView,
                  onSelected: _busy
                      ? null
                      : (_) => _run(() async {
                          _localView = false;
                          await _refresh();
                        }),
                ),
            ],
          ),
          if (_localView || connected || localReady) ...[
            TextField(
              decoration: InputDecoration(
                labelText: _t(
                  'Rechercher par langue, personne ou nom',
                  'Search by language, person, or name',
                  'Buscar por idioma, persona o nombre',
                  'Pesquisar por idioma, pessoa ou nome',
                ),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                '${visible.length} document(s) dans la bibliothèque',
                '${visible.length} document(s) in the library',
                '${visible.length} documento(s) en la biblioteca',
                '${visible.length} documento(s) na biblioteca',
              ),
              style: style,
            ),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _t(
                    'Aucun document trouvé.',
                    'No document found.',
                    'No se encontró ningún documento.',
                    'Nenhum documento encontrado.',
                  ),
                  style: style,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 2),
                  itemBuilder: (context, index) {
                    final f = visible[index];
                    return ListTile(
                      dense: true,
                      minVerticalPadding: 4,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        Icons.description_outlined,
                        color: widget.accent,
                        size: 20,
                      ),
                      title: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: widget.textColor, fontSize: 12),
                      ),
                      subtitle: Text(
                        '${f.path.split('/').take(2).join(' / ')} · ${(f.size / 1024).ceil()} Ko · ${_formatModified(f.modified)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: _t(
                          'Récupérer le document',
                          'Retrieve document',
                          'Recuperar documento',
                          'Recuperar documento',
                        ),
                        enabled: !_busy,
                        onSelected: (value) => _run(() async {
                          if (value == 'import') {
                            await _import(f);
                          } else if (value == 'share') {
                            await widget.onShare(
                              f.name,
                              await _readFile(f.path),
                            );
                          } else {
                            await widget.onExport(
                              f.name,
                              await _readFile(f.path),
                            );
                          }
                        }),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'download',
                            child: Text(
                              _t(
                                'Enregistrer une copie',
                                'Save a copy',
                                'Guardar una copia',
                                'Salvar uma cópia',
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Text(
                              _t(
                                'Partager vers une autre application',
                                'Share with another app',
                                'Compartir con otra aplicación',
                                'Compartilhar com outro aplicativo',
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'import',
                            child: Text(
                              _t(
                                'Réimporter dans le chapitre',
                                'Import into chapter',
                                'Volver a importar al capítulo',
                                'Reimportar no capítulo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: _busy || widget.document == null
                    ? null
                    : () => _run(
                        () => widget.onExport(
                          widget.document!.name,
                          widget.document!.bytes,
                        ),
                      ),
                icon: const Icon(Icons.save_alt),
                label: Text(
                  _t(
                    'Enregistrer une copie',
                    'Save a copy',
                    'Guardar una copia',
                    'Salvar uma cópia',
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : widget.onPickFiles,
                icon: const Icon(Icons.file_open_outlined),
                label: Text(
                  _t(
                    'Ouvrir depuis mes fichiers',
                    'Open from my files',
                    'Abrir desde mis archivos',
                    'Abrir dos meus arquivos',
                  ),
                ),
              ),
            ],
          ),
          if (widget.document == null)
            Text(
              _t(
                'Générez un Word pour activer la sauvegarde.',
                'Generate a Word file to enable backup.',
                'Genera un Word para activar la copia de seguridad.',
                'Gere um Word para ativar o backup.',
              ),
              style: style,
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SelectableText(
                _message!,
                style: TextStyle(color: widget.textColor, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
