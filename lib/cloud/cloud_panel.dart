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
    required this.textColor,
    required this.mutedColor,
    required this.accent,
    required this.surface,
  });
  final CloudDocument? document;
  final void Function(String, Uint8List) onImport;
  final VoidCallback onPickFiles;
  final Future<void> Function(String, Uint8List) onExport;
  final Color textColor, mutedColor, accent, surface;
  @override
  State<CloudPanel> createState() => _CloudPanelState();
}

class _CloudPanelState extends State<CloudPanel> {
  final _storage = CloudStorage();
  String _provider = 'MEGA';
  String _search = '';
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
      if (mounted) {
        setState(() {
          _provider = cloudProviders.containsKey(_storage.provider)
              ? _storage.provider!
              : 'MEGA';
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
      if (mounted) setState(() => _message = 'Action non terminée : $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    final files = await _storage.list();
    if (mounted) setState(() => _files = files);
  }

  Future<void> _choose() async {
    await _storage.choose(_provider);
    if (_storage.folder != null) await _refresh();
  }

  Future<void> _save() async {
    final doc = widget.document;
    if (doc == null) return;
    final path = await _storage.save(doc);
    if (mounted) {
      setState(
        () => _message =
            'Copie enregistrée : $path. La synchronisation distante est gérée par ${_storage.provider} ; vérifiez son indicateur.',
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

  Future<void> _import(CloudFile file) async {
    final bytes = await _storage.read(file.path);
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
    final connected = _storage.folder != null;
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
          if (_storage.supported) ...[
            Text(
              'Installez et connectez l’application du cloud, puis choisissez son dossier synchronisé. DEC DOCX y crée sa bibliothèque ; aucun compte cloud n’est connecté directement ici.',
              style: style,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_choose),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(
                connected
                    ? 'Changer de dossier'
                    : 'Relier un dossier synchronisé',
              ),
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
                            if (mounted) setState(() => _files = []);
                          }),
                    child: const Text('Détacher le dossier'),
                  ),
                ],
              ),
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
              if (visible.isNotEmpty)
                SizedBox(
                  height: 230,
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final f = visible[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          f.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.textColor,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Text(
                          '${f.path.split('/').take(2).join(' / ')} · ${(f.size / 1024).ceil()} Ko',
                          style: style,
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Récupérer le document',
                          enabled: !_busy,
                          onSelected: (value) => _run(() async {
                            if (value == 'import') {
                              await _import(f);
                            } else {
                              await widget.onExport(
                                f.name,
                                await _storage.read(f.path),
                              );
                            }
                          }),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'download',
                              child: Text('Enregistrer une copie'),
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
          ] else ...[
            Text(
              'Ce navigateur ou appareil ne donne pas accès à un dossier permanent. Utilisez Enregistrer une copie, puis le dossier cloud proposé par votre appareil, ou chargez le fichier dans le service choisi.',
              style: style,
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
