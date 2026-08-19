import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/device_songs.dart';

/// Scanning the device is Android's feature: the roots are Android paths, and
/// the permissions it asks for come from a plugin that has no implementation on
/// desktop. Asking anyway threw `MissingPluginException` out of the library
/// tab. Measured on macOS.
void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  test('answers no rather than throwing where there is nothing to scan',
      () async {
    final directory = Directory.systemTemp.createTempSync('tunebox_device');
    addTearDown(() => directory.deleteSync(recursive: true));

    final device = DeviceSongs(roots: [directory]);

    expect(await device.scan(), Platform.isAndroid);
    expect(device.songs, isEmpty);
  });
}
