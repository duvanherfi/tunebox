import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tunebox/data/settings.dart';

/// The nightstand is nine scalars and no store of its own. What is worth
/// testing is that they come back as they were left, and that the two which
/// take the app somewhere on their own are off until someone says otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts fully drawn and never enters by itself', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.load();

    expect(settings.nightstandClock, isTrue);
    expect(settings.nightstandArt, isTrue);
    expect(settings.nightstandTitle, isTrue);
    expect(settings.nightstandProgress, isTrue);
    expect(settings.nightstandControls, NightstandControls.onTouch);
    expect(settings.nightstandDim, 20);
    expect(settings.nightstandBurnIn, isTrue);
    expect(settings.nightstandIdleSeconds, 0);
    expect(settings.nightstandOnCharge, isFalse);
  });

  test('every knob survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final written = Settings();
    await written.load();

    await written.setNightstandClock(false);
    await written.setNightstandArt(false);
    await written.setNightstandTitle(false);
    await written.setNightstandProgress(false);
    await written.setNightstandControls(NightstandControls.always);
    await written.setNightstandDim(65);
    await written.setNightstandBurnIn(false);
    await written.setNightstandIdleSeconds(120);
    await written.setNightstandOnCharge(true);

    final read = Settings();
    await read.load();

    expect(read.nightstandClock, isFalse);
    expect(read.nightstandArt, isFalse);
    expect(read.nightstandTitle, isFalse);
    expect(read.nightstandProgress, isFalse);
    expect(read.nightstandControls, NightstandControls.always);
    expect(read.nightstandDim, 65);
    expect(read.nightstandBurnIn, isFalse);
    expect(read.nightstandIdleSeconds, 120);
    expect(read.nightstandOnCharge, isTrue);
  });

  test('a control mode this version does not know reads as onTouch', () async {
    SharedPreferences.setMockInitialValues({'nightstand_controls': 'sometimes'});
    final settings = Settings();
    await settings.load();

    expect(settings.nightstandControls, NightstandControls.onTouch);
  });
}
