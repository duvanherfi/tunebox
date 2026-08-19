import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/features/nightstand/nightstand.dart';

/// The drift is what keeps a still screen from marking an OLED. It is a pure
/// function precisely so it can be checked without lighting anything up.
void main() {
  test('walks four distinct places and returns to the first', () {
    final walked = <Offset>[
      for (var tick = 0; tick < 4; tick++) nightstandDrift(tick),
    ];

    expect(walked.toSet().length, 4);
    expect(nightstandDrift(4), nightstandDrift(0));
    expect(nightstandDrift(9), nightstandDrift(1));
  });

  test('never strays more than eight pixels', () {
    for (var tick = 0; tick < 40; tick++) {
      final offset = nightstandDrift(tick);
      expect(offset.dx.abs(), lessThanOrEqualTo(8));
      expect(offset.dy.abs(), lessThanOrEqualTo(8));
    }
  });
}
