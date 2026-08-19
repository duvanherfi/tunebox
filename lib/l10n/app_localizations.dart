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

  /// No description provided for @menuShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get menuShare;

  /// No description provided for @artistSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get artistSubscribe;

  /// No description provided for @artistUnsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get artistUnsubscribe;

  /// No description provided for @artistSubscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get artistSubscribed;

  /// No description provided for @artistUnsubscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscription cancelled'**
  String get artistUnsubscribed;

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

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

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

  /// No description provided for @collectionSave.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get collectionSave;

  /// No description provided for @collectionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get collectionRemove;

  /// No description provided for @collectionSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your library'**
  String get collectionSaved;

  /// No description provided for @collectionRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from your library'**
  String get collectionRemoved;

  /// No description provided for @collectionSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved here. YouTube was not told: {reason}'**
  String collectionSyncFailed(String reason);

  /// No description provided for @collectionMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get collectionMore;

  /// No description provided for @collectionDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download every track'**
  String get collectionDownloadAll;

  /// No description provided for @collectionDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {count} tracks'**
  String collectionDownloading(int count);

  /// No description provided for @librarySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get librarySaved;

  /// No description provided for @libraryEmptySaved.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet. The heart on a playlist keeps it here.'**
  String get libraryEmptySaved;

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

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Playback and sound'**
  String get settingsSound;

  /// No description provided for @settingsSoundBody.
  ///
  /// In en, this message translates to:
  /// **'Autoplay, speed, fade, equalizer'**
  String get settingsSoundBody;

  /// No description provided for @settingsStorageBody.
  ///
  /// In en, this message translates to:
  /// **'Downloads, cache and what they take up'**
  String get settingsStorageBody;

  /// No description provided for @settingsBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Daily copy, write one now, restore'**
  String get settingsBackupBody;

  /// No description provided for @settingsAppearanceBody.
  ///
  /// In en, this message translates to:
  /// **'Theme, colours and the bars'**
  String get settingsAppearanceBody;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// No description provided for @settingsSystemBody.
  ///
  /// In en, this message translates to:
  /// **'The home screen widget'**
  String get settingsSystemBody;

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

  /// No description provided for @appearanceBars.
  ///
  /// In en, this message translates to:
  /// **'Player and navigation bars'**
  String get appearanceBars;

  /// No description provided for @barSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get barSolid;

  /// No description provided for @barSolidBody.
  ///
  /// In en, this message translates to:
  /// **'Opaque, as it has always been.'**
  String get barSolidBody;

  /// No description provided for @barGlass.
  ///
  /// In en, this message translates to:
  /// **'Frosted glass'**
  String get barGlass;

  /// No description provided for @barGlassBody.
  ///
  /// In en, this message translates to:
  /// **'See-through with the content blurred behind, so labels stay readable over any cover.'**
  String get barGlassBody;

  /// No description provided for @barTranslucent.
  ///
  /// In en, this message translates to:
  /// **'Translucent'**
  String get barTranslucent;

  /// No description provided for @barTranslucentBody.
  ///
  /// In en, this message translates to:
  /// **'See-through with nothing blurred. Cheaper, and muddier over a busy cover.'**
  String get barTranslucentBody;

  /// No description provided for @barClear.
  ///
  /// In en, this message translates to:
  /// **'Transparent'**
  String get barClear;

  /// No description provided for @barClearBody.
  ///
  /// In en, this message translates to:
  /// **'No background at all. Over a bright cover the labels can disappear.'**
  String get barClearBody;

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

  /// No description provided for @libraryDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get libraryDownloads;

  /// No description provided for @libraryEmptyDownloads.
  ///
  /// In en, this message translates to:
  /// **'Nothing downloaded yet. Use a track\'s menu to keep it on this device.'**
  String get libraryEmptyDownloads;

  /// No description provided for @menuDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get menuDownload;

  /// No description provided for @menuRemoveDownload.
  ///
  /// In en, this message translates to:
  /// **'Remove download'**
  String get menuRemoveDownload;

  /// No description provided for @menuDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get menuDownloading;

  /// No description provided for @menuDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Saved to this device'**
  String get menuDownloaded;

  /// No description provided for @menuDownloadRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from this device'**
  String get menuDownloadRemoved;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsCache.
  ///
  /// In en, this message translates to:
  /// **'Keep what you play'**
  String get settingsCache;

  /// No description provided for @settingsCacheBody.
  ///
  /// In en, this message translates to:
  /// **'Hearing a track again costs no data. Downloads are never touched by this.'**
  String get settingsCacheBody;

  /// No description provided for @settingsCacheLimit.
  ///
  /// In en, this message translates to:
  /// **'Cache limit: {mb} MB'**
  String settingsCacheLimit(int mb);

  /// No description provided for @settingsCacheClear.
  ///
  /// In en, this message translates to:
  /// **'Clear the cache ({size})'**
  String settingsCacheClear(String size);

  /// No description provided for @scrobbleTitle.
  ///
  /// In en, this message translates to:
  /// **'Listening history'**
  String get scrobbleTitle;

  /// No description provided for @scrobbleBody.
  ///
  /// In en, this message translates to:
  /// **'YouTube will not accept what this app reports about what you play. These services will, and have been keeping listening histories for twenty years.'**
  String get scrobbleBody;

  /// No description provided for @scrobbleConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get scrobbleConnect;

  /// No description provided for @scrobbleConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get scrobbleConnected;

  /// No description provided for @scrobbleDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get scrobbleDisconnect;

  /// No description provided for @scrobbleTokenHint.
  ///
  /// In en, this message translates to:
  /// **'User token'**
  String get scrobbleTokenHint;

  /// No description provided for @scrobbleLastFmBody.
  ///
  /// In en, this message translates to:
  /// **'Last.fm issues its keys per application, so this build needs your own — create one at last.fm/api, then approve the connection.'**
  String get scrobbleLastFmBody;

  /// No description provided for @scrobbleApproved.
  ///
  /// In en, this message translates to:
  /// **'I approved it'**
  String get scrobbleApproved;

  /// No description provided for @accountScrobble.
  ///
  /// In en, this message translates to:
  /// **'Listening history'**
  String get accountScrobble;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get settingsBackup;

  /// No description provided for @settingsBackupAuto.
  ///
  /// In en, this message translates to:
  /// **'Daily copy'**
  String get settingsBackupAuto;

  /// No description provided for @settingsBackupAutoBody.
  ///
  /// In en, this message translates to:
  /// **'Write a copy of your listening log and settings once a day, keeping the last five.'**
  String get settingsBackupAutoBody;

  /// No description provided for @settingsBackupNow.
  ///
  /// In en, this message translates to:
  /// **'Write a copy now'**
  String get settingsBackupNow;

  /// No description provided for @settingsBackupWritten.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String settingsBackupWritten(String path);

  /// No description provided for @settingsBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore a copy'**
  String get settingsBackupRestore;

  /// No description provided for @settingsBackupRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored. Reopen the app to see everything.'**
  String get settingsBackupRestored;

  /// No description provided for @settingsBackupNone.
  ///
  /// In en, this message translates to:
  /// **'There are no copies on this device yet.'**
  String get settingsBackupNone;

  /// No description provided for @menuUnlike.
  ///
  /// In en, this message translates to:
  /// **'Remove from liked songs'**
  String get menuUnlike;

  /// No description provided for @menuUnliked.
  ///
  /// In en, this message translates to:
  /// **'Removed from liked songs'**
  String get menuUnliked;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// No description provided for @searchRecentClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchRecentClear;

  /// No description provided for @settingsStorageRefresh.
  ///
  /// In en, this message translates to:
  /// **'Recalculate'**
  String get settingsStorageRefresh;

  /// No description provided for @settingsStorageCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsStorageCache;

  /// No description provided for @playbackControls.
  ///
  /// In en, this message translates to:
  /// **'Playback controls'**
  String get playbackControls;

  /// No description provided for @sleepCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get sleepCustom;

  /// No description provided for @sleepRunning.
  ///
  /// In en, this message translates to:
  /// **'The music will pause'**
  String get sleepRunning;

  /// No description provided for @sleepStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get sleepStart;

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'sec'**
  String get unitSeconds;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get unitMinutes;

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get unitHours;

  /// No description provided for @tipMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tipMore;

  /// No description provided for @tipClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get tipClear;

  /// No description provided for @tipPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get tipPrevious;

  /// No description provided for @tipNext.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get tipNext;

  /// No description provided for @tipPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get tipPlay;

  /// No description provided for @tipPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get tipPause;

  /// No description provided for @tipRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get tipRemove;

  /// No description provided for @tipReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get tipReorder;

  /// No description provided for @sortNatural.
  ///
  /// In en, this message translates to:
  /// **'Default order'**
  String get sortNatural;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// No description provided for @sortArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get sortArtist;

  /// No description provided for @sortPlays.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get sortPlays;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get sortDescending;

  /// No description provided for @sortCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String sortCount(int count);

  /// No description provided for @libraryAuto.
  ///
  /// In en, this message translates to:
  /// **'Made for you'**
  String get libraryAuto;

  /// No description provided for @autoTop.
  ///
  /// In en, this message translates to:
  /// **'Your top 100'**
  String get autoTop;

  /// No description provided for @autoDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get autoDownloads;

  /// No description provided for @autoCached.
  ///
  /// In en, this message translates to:
  /// **'Ready offline'**
  String get autoCached;

  /// No description provided for @playlistRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get playlistRename;

  /// No description provided for @playlistDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get playlistDelete;

  /// No description provided for @playlistEmptyLocal.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this playlist yet. Add tracks from any song\'s menu.'**
  String get playlistEmptyLocal;

  /// No description provided for @playlistLocalNew.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistLocalNew;

  /// No description provided for @playlistOnDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get playlistOnDevice;

  /// No description provided for @playlistInAccount.
  ///
  /// In en, this message translates to:
  /// **'In your account'**
  String get playlistInAccount;

  /// No description provided for @downloadQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get downloadQueued;

  /// No description provided for @settingsFade.
  ///
  /// In en, this message translates to:
  /// **'Fade between tracks'**
  String get settingsFade;

  /// No description provided for @settingsFadeBody.
  ///
  /// In en, this message translates to:
  /// **'Ease each track in and out instead of cutting. Zero is off.'**
  String get settingsFadeBody;

  /// No description provided for @settingsFadeValue.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String settingsFadeValue(int seconds);

  /// No description provided for @libraryArtists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryArtists;

  /// No description provided for @libraryAlbums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get libraryAlbums;

  /// No description provided for @libraryEmptyArtists.
  ///
  /// In en, this message translates to:
  /// **'No artists saved yet.'**
  String get libraryEmptyArtists;

  /// No description provided for @libraryEmptyAlbums.
  ///
  /// In en, this message translates to:
  /// **'No albums saved yet.'**
  String get libraryEmptyAlbums;

  /// No description provided for @playlistSuggestions.
  ///
  /// In en, this message translates to:
  /// **'You might also like'**
  String get playlistSuggestions;

  /// No description provided for @themePalette.
  ///
  /// In en, this message translates to:
  /// **'Base colour'**
  String get themePalette;

  /// No description provided for @lyricsShare.
  ///
  /// In en, this message translates to:
  /// **'Share the lyrics'**
  String get lyricsShare;

  /// No description provided for @lyricsPickLines.
  ///
  /// In en, this message translates to:
  /// **'Pick up to four lines.'**
  String get lyricsPickLines;

  /// No description provided for @lyricsCardReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to share.'**
  String get lyricsCardReady;

  /// No description provided for @settingsKeepAwake.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen on'**
  String get settingsKeepAwake;

  /// No description provided for @settingsKeepAwakeBody.
  ///
  /// In en, this message translates to:
  /// **'While the full player is open, for a phone left propped up.'**
  String get settingsKeepAwakeBody;

  /// No description provided for @paletteBaseColour.
  ///
  /// In en, this message translates to:
  /// **'Base colour'**
  String get paletteBaseColour;

  /// No description provided for @paletteBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get paletteBackground;

  /// No description provided for @paletteSecondColour.
  ///
  /// In en, this message translates to:
  /// **'Second colour'**
  String get paletteSecondColour;

  /// No description provided for @paletteAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get paletteAngle;

  /// No description provided for @paletteFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get paletteFlat;

  /// No description provided for @paletteLinear.
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get paletteLinear;

  /// No description provided for @paletteRadial.
  ///
  /// In en, this message translates to:
  /// **'Circular'**
  String get paletteRadial;

  /// No description provided for @paletteCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get paletteCustom;

  /// No description provided for @paletteHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get paletteHue;

  /// No description provided for @paletteSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get paletteSaturation;

  /// No description provided for @paletteBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get paletteBrightness;

  /// No description provided for @paletteReset.
  ///
  /// In en, this message translates to:
  /// **'Back to the app\'s own colour'**
  String get paletteReset;

  /// No description provided for @themeCustomise.
  ///
  /// In en, this message translates to:
  /// **'Customise'**
  String get themeCustomise;

  /// No description provided for @paletteGradientColours.
  ///
  /// In en, this message translates to:
  /// **'Gradient colours'**
  String get paletteGradientColours;

  /// No description provided for @paletteHoldToRemove.
  ///
  /// In en, this message translates to:
  /// **'Tap to change, hold to remove'**
  String get paletteHoldToRemove;

  /// No description provided for @libraryDevice.
  ///
  /// In en, this message translates to:
  /// **'On the phone'**
  String get libraryDevice;

  /// No description provided for @libraryDeviceEmpty.
  ///
  /// In en, this message translates to:
  /// **'Music stored on this phone shows up here.'**
  String get libraryDeviceEmpty;

  /// No description provided for @libraryDeviceScan.
  ///
  /// In en, this message translates to:
  /// **'Look for music'**
  String get libraryDeviceScan;

  /// No description provided for @libraryDeviceDenied.
  ///
  /// In en, this message translates to:
  /// **'Without access to your audio there is nothing to look through.'**
  String get libraryDeviceDenied;

  /// No description provided for @settingsWidget.
  ///
  /// In en, this message translates to:
  /// **'Add the home screen widget'**
  String get settingsWidget;

  /// No description provided for @settingsWidgetBody.
  ///
  /// In en, this message translates to:
  /// **'What is playing, with its controls, without opening the app.'**
  String get settingsWidgetBody;

  /// No description provided for @settingsWidgetManual.
  ///
  /// In en, this message translates to:
  /// **'This launcher cannot be asked; add it by holding the home screen and choosing Widgets.'**
  String get settingsWidgetManual;

  /// No description provided for @nightstandExit.
  ///
  /// In en, this message translates to:
  /// **'Leave the nightstand'**
  String get nightstandExit;

  /// No description provided for @nightstandNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get nightstandNothing;
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
