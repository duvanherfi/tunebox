// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navSearch => 'Search';

  @override
  String get navHome => 'Home';

  @override
  String get navLibrary => 'Library';

  @override
  String get themeTooltip => 'Theme';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'Follow the system';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutBody =>
      'The cookies stored on this device will be deleted.';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Try again';

  @override
  String get searchHint => 'Search songs or artists';

  @override
  String get filterAll => 'All';

  @override
  String get filterSongs => 'Songs';

  @override
  String get filterVideos => 'Videos';

  @override
  String get searchStartTitle => 'Search for something to begin';

  @override
  String get searchStartBody => 'Songs, artists or albums from YouTube Music.';

  @override
  String get searchEmptyTitle => 'No results';

  @override
  String get searchEmptyBody => 'Try another term, or clear the filter.';

  @override
  String get searchErrorTitle => 'Search failed';

  @override
  String playbackFailed(String error) {
    return 'Could not play: $error';
  }

  @override
  String get nothingPlaying => 'Nothing playing';

  @override
  String get libraryLikes => 'Liked';

  @override
  String get libraryPlaylists => 'Playlists';

  @override
  String get libraryHistory => 'History';

  @override
  String get libraryEmptyLikes => 'You haven\'t liked any songs yet';

  @override
  String get libraryEmptyPlaylists => 'You have no saved playlists';

  @override
  String get libraryEmptyHistory => 'You haven\'t listened to anything yet';

  @override
  String get libraryPlaylistEmpty => 'This playlist is empty';

  @override
  String get librarySignedOutTitle => 'Sign in to see your library';

  @override
  String get librarySignedOutBody =>
      'Your likes, playlists and history from YouTube Music.';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginPasteTitle => 'Paste your session cookie';

  @override
  String get loginStep1 =>
      'Open music.youtube.com in a desktop browser, already signed in.';

  @override
  String get loginStep2 => 'Press F12 and go to the Network tab.';

  @override
  String get loginStep3 => 'Reload the page and click any request in the list.';

  @override
  String get loginStep4 =>
      'Under Request Headers, copy the whole Cookie value.';

  @override
  String get loginStep5 => 'Paste it below.';

  @override
  String get loginSave => 'Save session';

  @override
  String get loginNoSapisid =>
      'I can\'t find the session cookie (SAPISID) in what you pasted. Make sure you copied the whole Cookie header.';

  @override
  String get loginStorageNote =>
      'Stored encrypted on this device and sent nowhere but YouTube. To revoke it, sign out of your Google account from any browser.';

  @override
  String get homeErrorTitle => 'Couldn\'t load the home feed';

  @override
  String get homeEmptyTitle => 'Nothing here yet';

  @override
  String get homeEmptyBody =>
      'YouTube Music has nothing to show for this device right now.';

  @override
  String get loginUseDeviceAccount => 'Use an account from this device';

  @override
  String get loginOr => 'or paste it by hand';

  @override
  String loginDeviceAccountFailed(String reason) {
    return 'That account could not be used ($reason). Paste the cookie instead.';
  }

  @override
  String get accountTooltip => 'Account';

  @override
  String get accountAppearance => 'Appearance';

  @override
  String get accountSignedOut => 'Not signed in';

  @override
  String get accountSignedIn => 'Signed in';
}
