import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'cloud_models.dart';

class CloudStorage {
  CloudStorage({this.configFile, this.localDirectory});
  final File? configFile;
  final Directory? localDirectory;
  String? _root;
  String? provider;
  String? mode;
  String? get folder => _root;
  String? get permission =>
      mode == 'local' || (_root != null && Directory(_root!).existsSync())
      ? 'granted'
      : mode == 'folder'
      ? 'denied'
      : null;
  bool get configured => mode != null;
  bool get connected => mode == 'folder' && permission == 'granted';
  bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  Future<File> _config() async =>
      configFile ??
      File(
        '${(await getApplicationSupportDirectory()).path}/cloud-folder.json',
      );
  Future<void> restore() async {
    final file = await _config();
    if (!await file.exists()) return;
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    mode = data['mode'] as String? ?? 'folder';
    _root = data['root'] as String?;
    provider = data['provider'] as String?;
  }

  Future<void> choose(String service) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choisir votre dossier $service synchronisé',
    );
    if (path == null) return;
    await connectDirectory(path, service);
  }

  Future<void> connectDirectory(String path, String service) async {
    if (!await Directory(path).exists()) {
      throw const FileSystemException('Dossier indisponible');
    }
    final file = await _config();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'mode': 'folder', 'root': path, 'provider': service}),
      flush: true,
    );
    _root = path;
    provider = service;
    mode = 'folder';
  }

  Future<void> chooseLocal() async {
    final file = await _config();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'mode': 'local'}), flush: true);
    _root = null;
    provider = null;
    mode = 'local';
  }

  Future<void> authorize() async {}

  Future<Directory> _library() async {
    if (mode == 'local') {
      final documents =
          localDirectory ?? await getApplicationDocumentsDirectory();
      return Directory('${documents.path}/DEC DOCX');
    }
    if (_root == null || !await Directory(_root!).exists()) {
      throw const FileSystemException(
        'Dossier indisponible. Reconnectez le disque ou le cloud.',
      );
    }
    return Directory('$_root/DEC DOCX');
  }

  Future<String> save(CloudDocument document) async {
    final root = await _library();
    final lang = safeCloudSegment(document.language, 'sans-langue');
    final person = safeCloudSegment(document.person, 'sans-personne');
    final stem = safeCloudSegment(
      document.name.replaceFirst(RegExp(r'\.docx$', caseSensitive: false), ''),
      'document',
    );
    final name =
        '$stem-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1000000)}.docx';
    final dir = Directory('${root.path}/$lang/$person');
    await dir.create(recursive: true);
    await File('${dir.path}/$name').writeAsBytes(document.bytes, flush: true);
    return '$lang/$person/$name';
  }

  Future<List<CloudFile>> list() async {
    final root = await _library();
    if (!await root.exists()) return [];
    final result = <CloudFile>[];
    await for (final entry in root.list(recursive: true, followLinks: false)) {
      if (entry is! File || !entry.path.toLowerCase().endsWith('.docx')) {
        continue;
      }
      final stat = await entry.stat();
      result.add(
        CloudFile(
          path: entry.path
              .substring(root.path.length + 1)
              .replaceAll('\\', '/'),
          size: stat.size,
          modified: stat.modified,
        ),
      );
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  Future<Uint8List> read(String path) async {
    if (path
            .split('/')
            .any(
              (p) => p.isEmpty || p == '.' || p == '..' || p.contains('\\'),
            ) ||
        path.contains(':')) {
      throw const FormatException('Chemin invalide');
    }
    final root = await _library();
    final file = File('${root.path}/$path');
    final canonicalRoot = await root.resolveSymbolicLinks();
    final canonicalFile = await file.resolveSymbolicLinks();
    if (!canonicalFile.startsWith('$canonicalRoot${Platform.pathSeparator}')) {
      throw const FormatException('Fichier hors bibliothèque');
    }
    return file.readAsBytes();
  }

  Future<void> disconnect() async {
    final file = await _config();
    if (await file.exists()) await file.delete();
    _root = null;
    provider = null;
    mode = null;
  }
}
