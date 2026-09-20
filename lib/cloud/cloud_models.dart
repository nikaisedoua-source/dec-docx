import 'dart:typed_data';

class CloudFile {
  const CloudFile({
    required this.path,
    required this.size,
    required this.modified,
  });
  final String path;
  final int size;
  final DateTime modified;
  String get name => path.split('/').last;
  factory CloudFile.fromJson(Map<String, dynamic> json) => CloudFile(
    path: json['path'] as String,
    size: json['size'] as int,
    modified: DateTime.fromMillisecondsSinceEpoch(json['modified'] as int),
  );
}

class CloudDocument {
  const CloudDocument(this.bytes, this.name, this.language, this.person);
  final Uint8List bytes;
  final String name;
  final String language;
  final String person;
}

String safeCloudSegment(String value, String fallback) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[\x00-\x1f\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (cleaned.isEmpty ||
      RegExp(
        r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$',
        caseSensitive: false,
      ).hasMatch(cleaned)) {
    return fallback;
  }
  return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
}

const cloudProviders = <String, ({String quota, String url, String note})>{
  'MEGA': (
    quota: '20 Go annoncés',
    url: 'https://mega.io/',
    note: 'Vérifiez le quota gratuit attribué à votre compte.',
  ),
  'Google Drive': (
    quota: 'Jusqu’à 15 Go',
    url: 'https://drive.google.com/',
    note:
        'Espace partagé avec Gmail et Google Photos ; conditions selon le compte.',
  ),
  'OneDrive': (
    quota: '5 Go gratuits',
    url: 'https://onedrive.live.com/',
    note: 'Espace partagé avec les autres services Microsoft du compte.',
  ),
  'iCloud Drive': (
    quota: '5 Go gratuits',
    url: 'https://www.icloud.com/iclouddrive/',
    note: 'Espace partagé avec les photos et sauvegardes iCloud.',
  ),
};
