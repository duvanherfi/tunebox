import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Removes a test's temporary directory, giving a write still on its way the
/// moment it needs to land.
///
/// The player writes fire and forget — the play log and the resume point go out
/// on a track starting or the player stopping and nobody holds on to their
/// futures — so `stop()` returning is not the same as the last write having
/// finished. Turning the event queue lets those land, and it is what these
/// tests did on their own; what it cannot promise is that none is still in
/// flight, and under load one arriving late paints a green run red with
/// `FileSystemException: Deletion failed … Directory not empty`.
///
/// So the removal itself waits on the condition instead of on a duration: it
/// retries until the directory actually comes away. Nothing in flight means it
/// succeeds on the first try and costs nothing; something in flight costs
/// exactly as long as that write. A directory that never comes away is a real
/// problem and still throws — swallowing the failure would only move the mess
/// to the next run's temporary folder.
Future<void> removeWhenSettled(Directory directory) async {
  await pumpEventQueue();
  final giveUpAt = DateTime.now().add(const Duration(seconds: 5));

  while (true) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (!directory.existsSync()) return;
      if (DateTime.now().isAfter(giveUpAt)) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
}
