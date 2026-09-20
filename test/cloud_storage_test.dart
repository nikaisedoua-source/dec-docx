import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dec_docx/cloud/cloud_models.dart';
import 'package:dec_docx/cloud/cloud_storage_native.dart';

void main() {
  test('saves versions, restores folder and retrieves exact bytes', () async {
    final temp = await Directory.systemTemp.createTemp('dec-cloud-test-');
    addTearDown(() => temp.delete(recursive: true));
    final root = await Directory('${temp.path}/drive').create();
    final config = File('${temp.path}/settings.json');
    final storage = CloudStorage(configFile: config);
    await storage.connectDirectory(root.path, 'Google Drive');
    final bytes = Uint8List.fromList([80, 75, 3, 4, 10]);
    final document = CloudDocument(
      bytes,
      'Kacou 182.docx',
      'chinois',
      'Groupe A',
    );
    final first = await storage.save(document);
    final second = await storage.save(document);
    expect(first, isNot(second));
    expect(first, startsWith('chinois/Groupe A/'));
    final restored = CloudStorage(configFile: config);
    await restored.restore();
    expect(restored.provider, 'Google Drive');
    expect(await restored.list(), hasLength(2));
    expect(await restored.read(first), bytes);
    await expectLater(restored.read('../settings.json'), throwsFormatException);
    await restored.disconnect();
    expect(restored.folder, isNull);
    expect(await File('${root.path}/DEC DOCX/$first').exists(), isTrue);
  });

  test(
    'missing cloud folder is an error, never a claimed successful save',
    () async {
      final temp = await Directory.systemTemp.createTemp('dec-cloud-offline-');
      addTearDown(() => temp.delete(recursive: true));
      final root = await Directory('${temp.path}/drive').create();
      final storage = CloudStorage(
        configFile: File('${temp.path}/settings.json'),
      );
      await storage.connectDirectory(root.path, 'OneDrive');
      await root.delete();
      await expectLater(
        storage.save(CloudDocument(Uint8List(1), 'test.docx', 'fr', 'a')),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'folder names preserve languages but prevent traversal and reserved names',
    () {
      expect(safeCloudSegment('../a/b', 'fallback'), '.._a_b');
      expect(safeCloudSegment('...', 'fallback'), 'fallback');
      expect(safeCloudSegment('CON', 'fallback'), 'fallback');
      expect(safeCloudSegment('中文', 'fallback'), '中文');
    },
  );
}
