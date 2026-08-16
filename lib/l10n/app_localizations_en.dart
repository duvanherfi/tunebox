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

  @override
  String get themeDynamic => 'Colours from the cover';

  @override
  String get themeDynamicBody =>
      'Repaint the app around the artwork that is playing.';

  @override
  String get statsTitle => 'Your listening';

  @override
  String get statsWeek => 'Week';

  @override
  String get statsMonth => 'Month';

  @override
  String get statsYear => 'Year';

  @override
  String statsPlays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plays',
      one: '1 play',
      zero: 'No plays yet',
    );
    return '$_temp0';
  }

  @override
  String get statsEmpty => 'Play something and it will show up here.';

  @override
  String get statsArtists => 'Most played artists';

  @override
  String get statsSongs => 'Most played songs';

  @override
  String get accountStats => 'Your listening';

  @override
  String get navExplore => 'Explore';

  @override
  String get exploreNew => 'New';

  @override
  String get exploreCharts => 'Charts';

  @override
  String get exploreMoods => 'Moods';

  @override
  String get libraryDownloads => 'Downloads';

  @override
  String get libraryEmptyDownloads =>
      'Nothing downloaded yet. Use a track\'s menu to keep it on this device.';

  @override
  String get menuDownload => 'Download';

  @override
  String get menuRemoveDownload => 'Remove download';

  @override
  String get menuDownloading => 'Downloading…';

  @override
  String get menuDownloaded => 'Saved to this device';

  @override
  String get menuDownloadRemoved => 'Removed from this device';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsCache => 'Keep what you play';

  @override
  String get settingsCacheBody =>
      'Hearing a track again costs no data. Downloads are never touched by this.';

  @override
  String settingsCacheLimit(int mb) {
    return 'Cache limit: $mb MB';
  }

  @override
  String settingsCacheClear(String size) {
    return 'Clear the cache ($size)';
  }

  @override
  String get scrobbleTitle => 'Listening history';

  @override
  String get scrobbleBody =>
      'YouTube will not accept what this app reports about what you play. These services will, and have been keeping listening histories for twenty years.';

  @override
  String get scrobbleConnect => 'Connect';

  @override
  String get scrobbleConnected => 'Connected';

  @override
  String get scrobbleDisconnect => 'Disconnect';

  @override
  String get scrobbleTokenHint => 'User token';

  @override
  String get scrobbleLastFmBody =>
      'Last.fm issues its keys per application, so this build needs your own — create one at last.fm/api, then approve the connection.';

  @override
  String get scrobbleApproved => 'I approved it';

  @override
  String get accountScrobble => 'Listening history';

  @override
  String get settingsBackup => 'Backups';

  @override
  String get settingsBackupAuto => 'Daily copy';

  @override
  String get settingsBackupAutoBody =>
      'Write a copy of your listening log and settings once a day, keeping the last five.';

  @override
  String get settingsBackupNow => 'Write a copy now';

  @override
  String settingsBackupWritten(String path) {
    return 'Saved to $path';
  }

  @override
  String get settingsBackupRestore => 'Restore a copy';

  @override
  String get settingsBackupRestored =>
      'Restored. Reopen the app to see everything.';

  @override
  String get settingsBackupNone => 'There are no copies on this device yet.';

  @override
  String get menuUnlike => 'Remove from liked songs';

  @override
  String get menuUnliked => 'Removed from liked songs';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchRecentClear => 'Clear';

  @override
  String get settingsStorageRefresh => 'Recalculate';

  @override
  String get settingsStorageCache => 'Cache';

  @override
  String get playbackControls => 'Playback controls';

  @override
  String get sleepCustom => 'Custom';

  @override
  String get sleepRunning => 'The music will pause';

  @override
  String get sleepStart => 'Start';

  @override
  String get unitSeconds => 'sec';

  @override
  String get unitMinutes => 'min';

  @override
  String get unitHours => 'hours';

  @override
  String get tipMore => 'More';

  @override
  String get tipClear => 'Clear';

  @override
  String get tipPrevious => 'Previous track';

  @override
  String get tipNext => 'Next track';

  @override
  String get tipPlay => 'Play';

  @override
  String get tipPause => 'Pause';

  @override
  String get tipRemove => 'Remove';

  @override
  String get tipReorder => 'Drag to reorder';

  @override
  String get sortNatural => 'Default order';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortArtist => 'Artist';

  @override
  String get sortPlays => 'Most played';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String sortCount(int count) {
    return '$count tracks';
  }

  @override
  String get libraryAuto => 'Made for you';

  @override
  String get autoTop => 'Your top 100';

  @override
  String get autoDownloads => 'Downloaded';

  @override
  String get autoCached => 'Ready offline';

  @override
  String get playlistRename => 'Rename';

  @override
  String get playlistDelete => 'Delete';

  @override
  String get playlistEmptyLocal =>
      'Nothing in this playlist yet. Add tracks from any song\'s menu.';

  @override
  String get playlistLocalNew => 'New playlist';

  @override
  String get playlistOnDevice => 'On this device';

  @override
  String get playlistInAccount => 'In your account';

  @override
  String get downloadQueued => 'Waiting';

  @override
  String get settingsFade => 'Fade between tracks';

  @override
  String get settingsFadeBody =>
      'Ease each track in and out instead of cutting. Zero is off.';

  @override
  String settingsFadeValue(int seconds) {
    return '$seconds s';
  }

  @override
  String get libraryArtists => 'Artists';

  @override
  String get libraryAlbums => 'Albums';

  @override
  String get libraryEmptyArtists => 'No artists saved yet.';

  @override
  String get libraryEmptyAlbums => 'No albums saved yet.';

  @override
  String get playlistSuggestions => 'You might also like';

  @override
  String get themePalette => 'Base colour';
}
