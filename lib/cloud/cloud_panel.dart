import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cloud_models.dart';
import 'cloud_storage.dart';

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
  });
  final CloudDocument? document;
  final void Function(String, Uint8List) onImport;
  final VoidCallback onPickFiles;
  final Future<void> Function(String, Uint8List) onExport;
  final Future<void> Function(String, Uint8List) onShare;
  final Color textColor, mutedColor, accent, surface;
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
              ? 'Dossier ${_storage.provider} connecté et prêt.'
              : _storage.mode == 'local'
              ? 'Bibliothèque locale prête. Les documents restent disponibles après la fermeture.'
              : _storage.mode == 'folder'
              ? 'Le dossier est mémorisé. Autorisez de nouveau son accès pour continuer.'
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'La connexion au dossier n’a pas pu être restaurée. Choisissez-le à nouveau.',
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
      if (mounted) setState(() => _message = 'Action non terminée : $error');
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
    await _storage.choose(_provider);
    if (_storage.connected) await _refresh();
  }

  Future<void> _authorize() async {
    await _storage.authorize();
    if (_storage.connected) {
      await _refresh();
      if (mounted) {
        setState(
          () => _message = 'Dossier ${_storage.provider} reconnecté et prêt.',
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
            ? 'Version enregistrée dans la bibliothèque locale : $path.'
            : 'Copie enregistrée : $path. La synchronisation distante est gérée par ${_storage.provider} ; vérifiez son indicateur.',
      );
    }
    // A refresh failure must not hide the successful write.
    try {
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Copie enregistrée : $path. Actualisez la liste pour la retrouver.',
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
        () => _message =
            'Document ajouté aux fichiers du chapitre : ${file.name}',
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
                  'Sauvegarde & cloud',
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
            'Gardez vos documents et retrouvez-les sur vos appareils.',
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
                        ? 'Dossier synchronisé prêt'
                        : localReady
                        ? 'Bibliothèque locale prête'
                        : needsAuthorization
                        ? 'Autorisation du dossier requise'
                        : 'Aucun stockage sélectionné',
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
            decoration: const InputDecoration(labelText: 'Service de stockage'),
            items: cloudProviders.entries
                .map(
                  (e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      '${e.key} · ${e.value.quota}',
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
            '${info.note} Offres gratuites vérifiées le 20/09/2026, susceptibles d’évoluer.',
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
            label: Text('Ouvrir $_provider'),
          ),
          if (localReady) ...[
            Text(
              'Bibliothèque locale active. Chaque Word généré est conservé automatiquement avec une nouvelle version.',
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
                  label: const Text('Nouvelle version'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : () => _run(_refresh),
                  icon: const Icon(Icons.sync),
                  label: const Text('Actualiser'),
                ),
              ],
            ),
          ],
          if (_storage.supported) ...[
            Text(
              connected
                  ? 'Connexion active : DEC DOCX peut lire et enregistrer dans le dossier synchronisé.'
                  : 'Installez et connectez l’application du cloud, puis choisissez son dossier synchronisé. Une connexion au site seule ne donne pas accès au dossier.',
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
                    label: Text('Réautoriser ${_storage.provider}'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _run(_choose),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(
                    connected
                        ? 'Changer de dossier'
                        : needsAuthorization
                        ? 'Choisir un autre dossier'
                        : 'Relier un dossier synchronisé',
                  ),
                ),
              ],
            ),
            if (connected) ...[
              const SizedBox(height: 6),
              Text(
                'Dossier relié · ${_storage.provider}\n${_storage.folder}',
                style: TextStyle(color: widget.textColor, fontSize: 12),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy || widget.document == null
                    ? null
                    : () => _run(_save),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Sauvegarder le dernier Word'),
              ),
              Text(
                'Une nouvelle version à chaque sauvegarde. Le quota et la synchronisation restent à vérifier dans votre cloud.',
                style: style,
              ),
              Wrap(
                spacing: 6,
                children: [
                  TextButton.icon(
                    onPressed: _busy ? null : () => _run(_refresh),
                    icon: const Icon(Icons.sync),
                    label: const Text('Actualiser mes fichiers'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            await _storage.disconnect();
                            _localView = true;
                            await _refresh();
                          }),
                    child: const Text('Détacher le dossier'),
                  ),
                ],
              ),
            ],
          ] else if (!localReady) ...[
            Text(
              'Ce navigateur ou appareil ne donne pas accès à un dossier permanent. Utilisez Enregistrer une copie, puis le dossier cloud proposé par votre appareil, ou chargez le fichier dans le service choisi.',
              style: style,
            ),
          ],
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Cet appareil'),
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
                  label: const Text('Dossier connecté'),
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
              decoration: const InputDecoration(
                labelText: 'Rechercher par langue, personne ou nom',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 8),
            Text(
              '${visible.length} document(s) dans la bibliothèque',
              style: style,
            ),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Aucun document trouvé.', style: style),
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
                        tooltip: 'Récupérer le document',
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
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'download',
                            child: Text('Enregistrer une copie'),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Text('Partager vers une autre application'),
                          ),
                          PopupMenuItem(
                            value: 'import',
                            child: Text('Réimporter dans le chapitre'),
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
                label: const Text('Enregistrer une copie'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : widget.onPickFiles,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Ouvrir depuis mes fichiers'),
              ),
            ],
          ),
          if (widget.document == null)
            Text('Générez un Word pour activer la sauvegarde.', style: style),
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
