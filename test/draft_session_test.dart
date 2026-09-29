import 'dart:io';

import 'package:dec_docx/drafts/draft_repository.dart';
import 'package:dec_docx/drafts/draft_session.dart';
import 'package:dec_docx/drafts/draft_store_native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailOnceRepository implements DraftRepository {
  final revisions = <Map<String, dynamic>>[];
  bool fail = true;

  @override
  Future<List<Map<String, dynamic>>> history() async =>
      revisions.reversed.toList();

  @override
  Future<Map<String, dynamic>> read(String id) async =>
      revisions.firstWhere((revision) => revision['id'] == id);

  @override
  Future<void> save(Map<String, dynamic> revision) async {
    if (fail) {
      fail = false;
      throw const FileSystemException('disk full');
    }
    revisions.add(revision);
  }
}

void main() {
  test(
    'draft survives restart and every edit keeps an older revision',
    () async {
      final temp = await Directory.systemTemp.createTemp('dec-drafts-');
      addTearDown(() => temp.delete(recursive: true));
      final repository = DraftStore(directory: temp);
      final first = DraftSession(repository);
      addTearDown(first.dispose);
      expect(await first.load(), isNull);
      first.change({'title': 'Kacou 1', 'text': '1 Premier verset'});
      await first.flush();
      first.change({'title': 'Kacou 1', 'text': '1 Verset corrigé'});
      await first.flush();

      final history = await repository.history();
      expect(history, hasLength(2));
      expect(
        (await repository.read(history.last['id'] as String))['data']['text'],
        '1 Premier verset',
      );
      final resumed = DraftSession(repository);
      addTearDown(resumed.dispose);
      expect((await resumed.load())?['text'], '1 Verset corrigé');
      expect(resumed.dirty, isFalse);
    },
  );

  test(
    'failed write stays dirty and a retry confirms the exact text',
    () async {
      final repository = _FailOnceRepository();
      final session = DraftSession(repository);
      addTearDown(session.dispose);
      await session.load();
      session.change({'title': 'Kacou 2', 'text': '2 Texte'});
      await expectLater(session.flush(), throwsA(isA<FileSystemException>()));
      expect(session.dirty, isTrue);
      expect(session.error, isNotNull);
      expect(repository.revisions, isEmpty);
      await session.flush();
      expect(session.error, isNull);
      expect(session.dirty, isFalse);
      expect(repository.revisions.single['data']['text'], '2 Texte');
    },
  );
}
