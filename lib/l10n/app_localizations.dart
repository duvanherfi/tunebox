import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @themeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTooltip;

  /// No description provided for @themeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeTitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the system'**
  String get themeSystem;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'The cookies stored on this device will be deleted.'**
  String get signOutBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs or artists'**
  String get searchHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get filterSongs;

  /// No description provided for @filterVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get filterVideos;

  /// No description provided for @searchStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Search for something to begin'**
  String get searchStartTitle;

  /// No description provided for @searchStartBody.
  ///
  /// In en, this message translates to:
  /// **'Songs, artists or albums from YouTube Music.'**
  String get searchStartBody;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try another term, or clear the filter.'**
  String get searchEmptyBody;

  /// No description provided for @searchErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get searchErrorTitle;

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play: {error}'**
  String playbackFailed(String error);

  /// No description provided for @nothingPlaying.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get nothingPlaying;

  /// No description provided for @libraryLikes.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get libraryLikes;

  /// No description provided for @libraryPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get libraryPlaylists;

  /// No description provided for @libraryHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get libraryHistory;

  /// No description provided for @libraryEmptyLikes.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t liked any songs yet'**
  String get libraryEmptyLikes;

  /// No description provided for @libraryEmptyPlaylists.
  ///
  /// In en, this message translates to:
  /// **'You have no saved playlists'**
  String get libraryEmptyPlaylists;

  /// No description provided for @libraryEmptyHistory.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t listened to anything yet'**
  String get libraryEmptyHistory;

  /// No description provided for @libraryPlaylistEmpty.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty'**
  String get libraryPlaylistEmpty;

  /// No description provided for @librarySignedOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your library'**
  String get librarySignedOutTitle;

  /// No description provided for @librarySignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your likes, playlists and history from YouTube Music.'**
  String get librarySignedOutBody;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste your session cookie'**
  String get loginPasteTitle;

  /// No description provided for @loginStep1.
  ///
  /// In en, this message translates to:
  /// **'Open music.youtube.com in a desktop browser, already signed in.'**
  String get loginStep1;

  /// No description provided for @loginStep2.
  ///
  /// In en, this message translates to:
  /// **'Press F12 and go to the Network tab.'**
  String get loginStep2;

  /// No description provided for @loginStep3.
  ///
  /// In en, this message translates to:
  /// **'Reload the page and click any request in the list.'**
  String get loginStep3;

  /// No description provided for @loginStep4.
  ///
  /// In en, this message translates to:
  /// **'Under Request Headers, copy the whole Cookie value.'**
  String get loginStep4;

  /// No description provided for @loginStep5.
  ///
  /// In en, this message translates to:
  /// **'Paste it below.'**
  String get loginStep5;

  /// No description provided for @loginSave.
  ///
  /// In en, this message translates to:
  /// **'Save session'**
  String get loginSave;

  /// No description provided for @loginNoSapisid.
  ///
  /// In en, this message translates to:
  /// **'I can\'t find the session cookie (SAPISID) in what you pasted. Make sure you copied the whole Cookie header.'**
  String get loginNoSapisid;

  /// No description provided for @loginStorageNote.
  ///
  /// In en, this message translates to:
  /// **'Stored encrypted on this device and sent nowhere but YouTube. To revoke it, sign out of your Google account from any browser.'**
  String get loginStorageNote;

  /// No description provided for @homeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the home feed'**
  String get homeErrorTitle;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'YouTube Music has nothing to show for this device right now.'**
  String get homeEmptyBody;

  /// No description provided for @loginUseDeviceAccount.
  ///
  /// In en, this message translates to:
  /// **'Use an account from this device'**
  String get loginUseDeviceAccount;

  /// No description provided for @loginOr.
  ///
  /// In en, this message translates to:
  /// **'or paste it by hand'**
  String get loginOr;

  /// No description provided for @loginDeviceAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'That account could not be used ({reason}). Paste the cookie instead.'**
  String loginDeviceAccountFailed(String reason);

  /// No description provided for @accountTooltip.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTooltip;

  /// No description provided for @accountAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountAppearance;

  /// No description provided for @accountSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get accountSignedOut;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedIn;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Up next'**
  String get queueTitle;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing queued'**
  String get queueEmpty;

  /// No description provided for @queueTooltip.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueTooltip;

  /// No description provided for @shuffleOn.
  ///
  /// In en, this message translates to:
  /// **'Shuffle on'**
  String get shuffleOn;

  /// No description provided for @shuffleOff.
  ///
  /// In en, this message translates to:
  /// **'Shuffle off'**
  String get shuffleOff;

  /// No description provided for @repeatOff.
  ///
  /// In en, this message translates to:
  /// **'Repeat off'**
  String get repeatOff;

  /// No description provided for @repeatAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat queue'**
  String get repeatAll;

  /// No description provided for @repeatOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat track'**
  String get repeatOne;

  /// No description provided for @queueRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from the queue'**
  String get queueRemoved;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @menuPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get menuPlayNext;

  /// No description provided for @menuAddToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get menuAddToQueue;

  /// No description provided for @menuLike.
  ///
  /// In en, this message translates to:
  /// **'Add to liked songs'**
  String get menuLike;

  /// No description provided for @menuAddToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get menuAddToPlaylist;

  /// No description provided for @menuCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get menuCopyLink;

  /// No description provided for @menuLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get menuLinkCopied;

  /// No description provided for @menuLiked.
  ///
  /// In en, this message translates to:
  /// **'Added to liked songs'**
  String get menuLiked;

  /// No description provided for @menuQueued.
  ///
  /// In en, this message translates to:
  /// **'Added to the queue'**
  String get menuQueued;

  /// No description provided for @menuAddedTo.
  ///
  /// In en, this message translates to:
  /// **'Added to {playlist}'**
  String menuAddedTo(String playlist);

  /// No description provided for @menuFailed.
  ///
  /// In en, this message translates to:
  /// **'That did not work: {reason}'**
  String menuFailed(String reason);

  /// No description provided for @playlistNew.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistNew;

  /// No description provided for @playlistNameHint.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistNameHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @playlistPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playlistPickTitle;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @artistSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get artistSongs;

  /// No description provided for @menuGoArtist.
  ///
  /// In en, this message translates to:
  /// **'Go to artist'**
  String get menuGoArtist;

  /// No description provided for @menuGoAlbum.
  ///
  /// In en, this message translates to:
  /// **'Go to album'**
  String get menuGoAlbum;

  /// No description provided for @menuRadio.
  ///
  /// In en, this message translates to:
  /// **'Start radio'**
  String get menuRadio;

  /// No description provided for @menuRadioStarted.
  ///
  /// In en, this message translates to:
  /// **'Radio started'**
  String get menuRadioStarted;

  /// No description provided for @lyricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsTitle;

  /// No description provided for @lyricsNone.
  ///
  /// In en, this message translates to:
  /// **'No lyrics found for this track.'**
  String get lyricsNone;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsPlayback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsPlayback;

  /// No description provided for @settingsAutoplay.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get settingsAutoplay;

  /// No description provided for @settingsAutoplayBody.
  ///
  /// In en, this message translates to:
  /// **'When the queue ends, continue with a radio of what you were listening to.'**
  String get settingsAutoplayBody;

  /// No description provided for @settingsSkipSilence.
  ///
  /// In en, this message translates to:
  /// **'Skip silence'**
  String get settingsSkipSilence;

  /// No description provided for @settingsSkipSilenceBody.
  ///
  /// In en, this message translates to:
  /// **'Jump over silent stretches inside a track.'**
  String get settingsSkipSilenceBody;

  /// No description provided for @settingsNormalize.
  ///
  /// In en, this message translates to:
  /// **'Even out the volume'**
  String get settingsNormalize;

  /// No description provided for @settingsNormalizeBody.
  ///
  /// In en, this message translates to:
  /// **'Lift quiet masters so one track does not arrive much louder than the last.'**
  String get settingsNormalizeBody;

  /// No description provided for @settingsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed: {value}×'**
  String settingsSpeed(String value);

  /// No description provided for @settingsEqualizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get settingsEqualizer;

  /// No description provided for @settingsEqualizerOn.
  ///
  /// In en, this message translates to:
  /// **'Use the equalizer'**
  String get settingsEqualizerOn;

  /// No description provided for @settingsSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get settingsSleep;

  /// No description provided for @settingsSleepMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String settingsSleepMinutes(int minutes);

  /// No description provided for @settingsSleepPending.
  ///
  /// In en, this message translates to:
  /// **'Stopping in {minutes} min'**
  String settingsSleepPending(int minutes);

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback and sound'**
  String get accountSettings;

  /// No description provided for @settingsEqualizerIdle.
  ///
  /// In en, this message translates to:
  /// **'Play something to adjust the bands: Android only opens the equalizer once there is sound.'**
  String get settingsEqualizerIdle;

  /// No description provided for @themeDynamic.
  ///
  /// In en, this message translates to:
  /// **'Colours from the cover'**
  String get themeDynamic;

  /// No description provided for @themeDynamicBody.
  ///
  /// In en, this message translates to:
  /// **'Repaint the app around the artwork that is playing.'**
  String get themeDynamicBody;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your listening'**
  String get statsTitle;

  /// No description provided for @statsWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statsWeek;

  /// No description provided for @statsMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsMonth;

  /// No description provided for @statsYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get statsYear;

  /// No description provided for @statsPlays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No plays yet} =1{1 play} other{{count} plays}}'**
  String statsPlays(int count);

  /// No description provided for @statsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Play something and it will show up here.'**
  String get statsEmpty;

  /// No description provided for @statsArtists.
  ///
  /// In en, this message translates to:
  /// **'Most played artists'**
  String get statsArtists;

  /// No description provided for @statsSongs.
  ///
  /// In en, this message translates to:
  /// **'Most played songs'**
  String get statsSongs;

  /// No description provided for @accountStats.
  ///
  /// In en, this message translates to:
  /// **'Your listening'**
  String get accountStats;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @exploreNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get exploreNew;

  /// No description provided for @exploreCharts.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get exploreCharts;

  /// No description provided for @exploreMoods.
  ///
  /// In en, this message translates to:
  /// **'Moods'**
  String get exploreMoods;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
