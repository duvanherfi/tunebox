import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/core/theme/theme_controller.dart';

/// How much of the app shows through the two bars that are on screen all day.
/// A preference rather than a decision: legibility over a bright cover and
/// seeing the list move behind the bar pull in opposite directions, and which
/// one wins is a matter of taste and of how fast the device is.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test('starts solid, which is what the app has always looked like', () async {
    final theme = ThemeController();
    await theme.load();

    expect(theme.barBackground, BarBackground.solid);
  });

  test('remembers the choice across a restart', () async {
    final first = ThemeController();
    await first.load();
    await first.setBarBackground(BarBackground.glass);

    final second = ThemeController();
    await second.load();

    expect(second.barBackground, BarBackground.glass);
  });

  test('falls back to solid when the stored name means nothing', () async {
    SharedPreferences.setMockInitialValues({'theme_bar_background': 'frosted'});

    final theme = ThemeController();
    await theme.load();

    expect(theme.barBackground, BarBackground.solid);
  });

  // The bar has to stop being see-through as it grows into the full player:
  // a now-playing screen with the queue showing through it is not a screen.
  test('is only see-through while the bar is a bar', () {
    expect(BarBackground.solid.opacityAt(0), 1);
    expect(BarBackground.clear.opacityAt(0), 0);
    expect(BarBackground.glass.opacityAt(0), lessThan(1));
    for (final kind in BarBackground.values) {
      expect(kind.opacityAt(1), 1, reason: '$kind must be solid when expanded');
    }
  });
}
