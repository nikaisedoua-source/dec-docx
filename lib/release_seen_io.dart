import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<bool> markReleaseSeen(String version) async {
  try {
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/last_seen_release.txt');
    if (await file.exists() && await file.readAsString() == version) return false;
    await directory.create(recursive: true);
    await file.writeAsString(version, flush: true);
    return true;
  } catch (_) {
    return false;
  }
}
