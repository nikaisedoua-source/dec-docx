import 'package:flutter/material.dart';

import 'cloud_models.dart';
import 'cloud_storage.dart';

class StorageGate extends StatefulWidget {
  const StorageGate({super.key, required this.child});

  final Widget child;

  @override
  State<StorageGate> createState() => _StorageGateState();
}

class _StorageGateState extends State<StorageGate> {
  final CloudStorage _storage = CloudStorage();
  String _provider = 'Google Drive';
  String? _error;
  bool _loading = true;
  bool _busy = false;

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
      _error = 'Le stockage précédent est indisponible : $error';
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
      if (mounted) setState(() => _error = 'Connexion non terminée : $error');
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
                              ? 'Réautoriser votre stockage'
                              : 'Où conserver vos documents ?',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          needsAuthorization
                              ? 'Le dossier ${_storage.folder} est mémorisé, mais le navigateur demande votre autorisation pour y accéder de nouveau.'
                              : 'Ce choix est mémorisé. Vous pourrez le modifier ensuite dans Sauvegarde & cloud.',
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
                        if (needsAuthorization) ...[
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(_storage.authorize),
                            icon: const Icon(Icons.lock_open_outlined),
                            label: Text(
                              'Autoriser ${_storage.provider ?? 'le dossier'}',
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
                          label: const Text('Sur cet appareil'),
                        ),
                        if (_storage.supported) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('OU DOSSIER SYNCHRONISÉ'),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _provider,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Service cloud installé',
                            ),
                            items: cloudProviders.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(
                                      '${entry.key} · ${entry.value.quota}',
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
                                : () => _run(() => _storage.choose(_provider)),
                            icon: const Icon(Icons.cloud_done_outlined),
                            label: const Text('Choisir et relier le dossier'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sélectionnez le dossier déjà synchronisé par Google Drive, MEGA, OneDrive ou iCloud. Une simple connexion au site du service ne donne pas encore accès à ce dossier.',
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
