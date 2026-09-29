import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'draft_repository.dart';

/// Immutable revisions, serialized writes, and acknowledgement of the exact
/// snapshot saved. A failed write never clears dirty data or hides the error.
class DraftSession extends ChangeNotifier {
  DraftSession(
    this.repository, {
    this.delay = const Duration(milliseconds: 700),
  });
  final DraftRepository repository;
  final Duration delay;
  Timer? _timer;
  Future<void>? _writing;
  Map<String, dynamic>? _pending;
  String? _savedJson;
  String? head;
  DateTime? savedAt;
  Object? error;
  bool loading = true, saving = false, _disposed = false;
  bool get dirty => _pending != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<Map<String, dynamic>?> load() async {
    try {
      final versions = await repository.history();
      if (versions.isEmpty) return null;
      final revision = await repository.read(versions.first['id'] as String);
      head = revision['id'] as String;
      savedAt = DateTime.parse(revision['savedAt'] as String);
      final data = Map<String, dynamic>.from(revision['data'] as Map);
      _savedJson = jsonEncode(data);
      return data;
    } catch (e) {
      error = e;
      return null;
    } finally {
      loading = false;
      _notify();
    }
  }

  void change(Map<String, dynamic> data) {
    if (loading) return;
    final encoded = jsonEncode(data);
    // Copy the snapshot; callers may mutate controllers and source lists.
    _pending = encoded == _savedJson && !saving
        ? null
        : jsonDecode(encoded) as Map<String, dynamic>;
    _timer?.cancel();
    if (_pending != null && error == null) {
      _timer = Timer(delay, () {
        flush().catchError((_) {});
      });
    }
    _notify();
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_writing != null) {
      await _writing;
      if (_pending != null) await flush();
      return;
    }
    final future = _drain();
    _writing = future;
    try {
      await future;
    } finally {
      _writing = null;
    }
  }

  Future<void> _drain() async {
    while (_pending != null) {
      final snapshot = _pending!;
      final now = DateTime.now().toUtc();
      final nonce = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final id = '${now.microsecondsSinceEpoch}-$nonce';
      saving = true;
      error = null;
      _notify();
      try {
        await repository.save({
          'schema': 1,
          'id': id,
          'parent': head,
          'savedAt': now.toIso8601String(),
          'title': snapshot['title'] ?? '',
          'data': snapshot,
        });
        head = id;
        savedAt = now;
        _savedJson = jsonEncode(snapshot);
        if (jsonEncode(_pending) == _savedJson) _pending = null;
      } catch (e) {
        error = e;
        rethrow;
      } finally {
        saving = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
