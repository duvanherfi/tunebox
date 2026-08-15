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

  @override
  String get queueTitle => 'Up next';

  @override
  String get queueEmpty => 'Nothing queued';

  @override
  String get queueTooltip => 'Queue';

  @override
  String get shuffleOn => 'Shuffle on';

  @override
  String get shuffleOff => 'Shuffle off';

  @override
  String get repeatOff => 'Repeat off';

  @override
  String get repeatAll => 'Repeat queue';

  @override
  String get repeatOne => 'Repeat track';

  @override
  String get queueRemoved => 'Removed from the queue';

  @override
  String get undo => 'Undo';

  @override
  String get menuPlayNext => 'Play next';

  @override
  String get menuAddToQueue => 'Add to queue';

  @override
  String get menuLike => 'Add to liked songs';

  @override
  String get menuAddToPlaylist => 'Add to playlist';

  @override
  String get menuCopyLink => 'Copy link';

  @override
  String get menuLinkCopied => 'Link copied';

  @override
  String get menuLiked => 'Added to liked songs';

  @override
  String get menuQueued => 'Added to the queue';

  @override
  String menuAddedTo(String playlist) {
    return 'Added to $playlist';
  }

  @override
  String menuFailed(String reason) {
    return 'That did not work: $reason';
  }

  @override
  String get playlistNew => 'New playlist';

  @override
  String get playlistNameHint => 'Playlist name';

  @override
  String get create => 'Create';

  @override
  String get playlistPickTitle => 'Add to playlist';

  @override
  String get play => 'Play';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get artistSongs => 'Songs';

  @override
  String get menuGoArtist => 'Go to artist';

  @override
  String get menuGoAlbum => 'Go to album';

  @override
  String get menuRadio => 'Start radio';

  @override
  String get menuRadioStarted => 'Radio started';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsNone => 'No lyrics found for this track.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPlayback => 'Playback';

  @override
  String get settingsAutoplay => 'Keep playing';

  @override
  String get settingsAutoplayBody =>
      'When the queue ends, continue with a radio of what you were listening to.';

  @override
  String get settingsSkipSilence => 'Skip silence';

  @override
  String get settingsSkipSilenceBody =>
      'Jump over silent stretches inside a track.';

  @override
  String get settingsNormalize => 'Even out the volume';

  @override
  String get settingsNormalizeBody =>
      'Lift quiet masters so one track does not arrive much louder than the last.';

  @override
  String settingsSpeed(String value) {
    return 'Speed: $value×';
  }

  @override
  String get settingsEqualizer => 'Equalizer';

  @override
  String get settingsEqualizerOn => 'Use the equalizer';

  @override
  String get settingsSleep => 'Sleep timer';

  @override
  String settingsSleepMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String settingsSleepPending(int minutes) {
    return 'Stopping in $minutes min';
  }

  @override
  String get accountSettings => 'Playback and sound';

  @override
  String get settingsEqualizerIdle =>
      'Play something to adjust the bands: Android only opens the equalizer once there is sound.';
}
