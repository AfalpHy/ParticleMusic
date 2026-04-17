import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('zh'),
  ];

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @albumArtist.
  ///
  /// In en, this message translates to:
  /// **'Album Artist'**
  String get albumArtist;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// No description provided for @disc.
  ///
  /// In en, this message translates to:
  /// **'Disc'**
  String get disc;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @ranking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get ranking;

  /// No description provided for @recently.
  ///
  /// In en, this message translates to:
  /// **'Recently'**
  String get recently;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @playQueue.
  ///
  /// In en, this message translates to:
  /// **'Play Queue'**
  String get playQueue;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get followSystem;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @manageMusicFolder.
  ///
  /// In en, this message translates to:
  /// **'Manage Music Folders'**
  String get manageMusicFolder;

  /// No description provided for @openSourceLicense.
  ///
  /// In en, this message translates to:
  /// **'Open Source License'**
  String get openSourceLicense;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep Timer'**
  String get sleepTimer;

  /// No description provided for @pauseAfterCurrentTrack.
  ///
  /// In en, this message translates to:
  /// **'Pause After Current Track'**
  String get pauseAfterCurrentTrack;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @sortSongs.
  ///
  /// In en, this message translates to:
  /// **'Sort Songs'**
  String get sortSongs;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create Playlist'**
  String get createPlaylist;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @songCount.
  ///
  /// In en, this message translates to:
  /// **'{count} songs'**
  String songCount(int count);

  /// No description provided for @artistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String artistCount(int count);

  /// No description provided for @albumCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String albumCount(int count);

  /// No description provided for @playlistCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String playlistCount(int count);

  /// No description provided for @folderCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String folderCount(int count);

  /// No description provided for @settingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} in total'**
  String settingCount(int count);

  /// No description provided for @searchSongs.
  ///
  /// In en, this message translates to:
  /// **'Search Songs'**
  String get searchSongs;

  /// No description provided for @searchArtists.
  ///
  /// In en, this message translates to:
  /// **'Search Artists'**
  String get searchArtists;

  /// No description provided for @searchAlbums.
  ///
  /// In en, this message translates to:
  /// **'Search Albums'**
  String get searchAlbums;

  /// No description provided for @searchPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Search Playlists'**
  String get searchPlaylists;

  /// No description provided for @searchLicenses.
  ///
  /// In en, this message translates to:
  /// **'Search Licenses'**
  String get searchLicenses;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @pictureSize.
  ///
  /// In en, this message translates to:
  /// **'Picture Size'**
  String get pictureSize;

  /// No description provided for @large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get large;

  /// No description provided for @small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get small;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get grid;

  /// No description provided for @favorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get favorited;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// No description provided for @loop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get loop;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get playAll;

  /// No description provided for @move2Top.
  ///
  /// In en, this message translates to:
  /// **'Move to Top'**
  String get move2Top;

  /// No description provided for @playNow.
  ///
  /// In en, this message translates to:
  /// **'Play Now'**
  String get playNow;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get playNext;

  /// No description provided for @add2Queue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get add2Queue;

  /// No description provided for @editMetadata.
  ///
  /// In en, this message translates to:
  /// **'Edit Metadata'**
  String get editMetadata;

  /// No description provided for @add2Playlist.
  ///
  /// In en, this message translates to:
  /// **'Add to a Playlist'**
  String get add2Playlist;

  /// No description provided for @added2Playlist.
  ///
  /// In en, this message translates to:
  /// **'Added to a playlist'**
  String get added2Playlist;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @continueMsg.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to continue?'**
  String get continueMsg;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get addFolder;

  /// No description provided for @addRecursiveFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder(Recursive)'**
  String get addRecursiveFolder;

  /// No description provided for @addWebDAVFolder.
  ///
  /// In en, this message translates to:
  /// **'Add WebDAV Folder'**
  String get addWebDAVFolder;

  /// No description provided for @addWebDAVRecursiveFolder.
  ///
  /// In en, this message translates to:
  /// **'Add WebDAV Folder(Recursive)'**
  String get addWebDAVRecursiveFolder;

  /// No description provided for @replacePicture.
  ///
  /// In en, this message translates to:
  /// **'Replace Picture'**
  String get replacePicture;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @updateMedata.
  ///
  /// In en, this message translates to:
  /// **'Update Metadata'**
  String get updateMedata;

  /// No description provided for @defaultText.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultText;

  /// No description provided for @titleAscending.
  ///
  /// In en, this message translates to:
  /// **'Title Ascending'**
  String get titleAscending;

  /// No description provided for @titleDescending.
  ///
  /// In en, this message translates to:
  /// **'Title Descending'**
  String get titleDescending;

  /// No description provided for @artistAscending.
  ///
  /// In en, this message translates to:
  /// **'Artist Ascending'**
  String get artistAscending;

  /// No description provided for @artistDescending.
  ///
  /// In en, this message translates to:
  /// **'Artist Descending'**
  String get artistDescending;

  /// No description provided for @albumAscending.
  ///
  /// In en, this message translates to:
  /// **'Album Ascending'**
  String get albumAscending;

  /// No description provided for @albumDescending.
  ///
  /// In en, this message translates to:
  /// **'Album Descending'**
  String get albumDescending;

  /// No description provided for @durationAscending.
  ///
  /// In en, this message translates to:
  /// **'Duration Ascending'**
  String get durationAscending;

  /// No description provided for @durationDescending.
  ///
  /// In en, this message translates to:
  /// **'Duration Descending'**
  String get durationDescending;

  /// No description provided for @selectSortingType.
  ///
  /// In en, this message translates to:
  /// **'Select sorting type'**
  String get selectSortingType;

  /// No description provided for @loadingFolder.
  ///
  /// In en, this message translates to:
  /// **'Loading Folder'**
  String get loadingFolder;

  /// No description provided for @loadedSongs.
  ///
  /// In en, this message translates to:
  /// **'Loaded Songs'**
  String get loadedSongs;

  /// No description provided for @loadingNavidrome.
  ///
  /// In en, this message translates to:
  /// **'Loading Navidrome'**
  String get loadingNavidrome;

  /// No description provided for @canNotUpdate.
  ///
  /// In en, this message translates to:
  /// **'Can not update the song that is playing'**
  String get canNotUpdate;

  /// No description provided for @updateSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Update Successfully'**
  String get updateSuccessfully;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @palette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get palette;

  /// No description provided for @backgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Background Color'**
  String get backgroundColor;

  /// No description provided for @iconColor.
  ///
  /// In en, this message translates to:
  /// **'Icon Color'**
  String get iconColor;

  /// No description provided for @textColor.
  ///
  /// In en, this message translates to:
  /// **'Text Color'**
  String get textColor;

  /// No description provided for @highlightTextColor.
  ///
  /// In en, this message translates to:
  /// **'Highlight Text Color'**
  String get highlightTextColor;

  /// No description provided for @switchColor.
  ///
  /// In en, this message translates to:
  /// **'Switch Color'**
  String get switchColor;

  /// No description provided for @playBarColor.
  ///
  /// In en, this message translates to:
  /// **'Play Bar Color'**
  String get playBarColor;

  /// No description provided for @panelColor.
  ///
  /// In en, this message translates to:
  /// **'Panel Color'**
  String get panelColor;

  /// No description provided for @sidebarColor.
  ///
  /// In en, this message translates to:
  /// **'Sidebar Color'**
  String get sidebarColor;

  /// No description provided for @bottomColor.
  ///
  /// In en, this message translates to:
  /// **'Bottom Color'**
  String get bottomColor;

  /// No description provided for @searchFieldColor.
  ///
  /// In en, this message translates to:
  /// **'Search Field Color'**
  String get searchFieldColor;

  /// No description provided for @buttonColor.
  ///
  /// In en, this message translates to:
  /// **'Button Color'**
  String get buttonColor;

  /// No description provided for @dividerColor.
  ///
  /// In en, this message translates to:
  /// **'Divider Color'**
  String get dividerColor;

  /// No description provided for @selectedItemColor.
  ///
  /// In en, this message translates to:
  /// **'Selected Item Color'**
  String get selectedItemColor;

  /// No description provided for @scrollbarColor.
  ///
  /// In en, this message translates to:
  /// **'Scrollbar Color'**
  String get scrollbarColor;

  /// No description provided for @seekBarColor.
  ///
  /// In en, this message translates to:
  /// **'Seek Bar Color'**
  String get seekBarColor;

  /// No description provided for @volumeBarColor.
  ///
  /// In en, this message translates to:
  /// **'Volume Bar Color'**
  String get volumeBarColor;

  /// No description provided for @lyricsPageBackgroundColor.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Page Background Color'**
  String get lyricsPageBackgroundColor;

  /// No description provided for @lyricsPageForegroundColor.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Page Foreground Color'**
  String get lyricsPageForegroundColor;

  /// No description provided for @lyricsPageHighlightTextColor.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Page Highlight Text Color'**
  String get lyricsPageHighlightTextColor;

  /// No description provided for @lyricsPageButtonColor.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Page Button Color'**
  String get lyricsPageButtonColor;

  /// No description provided for @lyricsPageDividerColor.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Page Divider Color'**
  String get lyricsPageDividerColor;

  /// No description provided for @lyricsPageSelectedItemColor.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Page Selected Item Color'**
  String get lyricsPageSelectedItemColor;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @desktopLyrics.
  ///
  /// In en, this message translates to:
  /// **'Desktop Lyrics'**
  String get desktopLyrics;

  /// No description provided for @horizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get horizontal;

  /// No description provided for @vertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get vertical;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @closeAction.
  ///
  /// In en, this message translates to:
  /// **'Close Action'**
  String get closeAction;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @hide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// No description provided for @checkUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check Update'**
  String get checkUpdate;

  /// No description provided for @go2Download.
  ///
  /// In en, this message translates to:
  /// **'Go to Download'**
  String get go2Download;

  /// No description provided for @alreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'Already on the latest version'**
  String get alreadyLatest;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @mainPageTheme.
  ///
  /// In en, this message translates to:
  /// **'Main Page Theme'**
  String get mainPageTheme;

  /// No description provided for @lyricsPageTheme.
  ///
  /// In en, this message translates to:
  /// **'Lyrics Page Theme'**
  String get lyricsPageTheme;

  /// No description provided for @vividMode.
  ///
  /// In en, this message translates to:
  /// **'Vivid Mode'**
  String get vividMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @customMode.
  ///
  /// In en, this message translates to:
  /// **'Custom Mode'**
  String get customMode;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @switch_.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switch_;

  /// No description provided for @connect2Navidrome.
  ///
  /// In en, this message translates to:
  /// **'Connect to Navidrome'**
  String get connect2Navidrome;

  /// No description provided for @connect2WebDAV.
  ///
  /// In en, this message translates to:
  /// **'Connect to WebDAV'**
  String get connect2WebDAV;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @exportLog.
  ///
  /// In en, this message translates to:
  /// **'Export Log'**
  String get exportLog;

  /// No description provided for @showApp.
  ///
  /// In en, this message translates to:
  /// **'Show App'**
  String get showApp;

  /// No description provided for @skip2Previous.
  ///
  /// In en, this message translates to:
  /// **'Skip to Previous'**
  String get skip2Previous;

  /// No description provided for @skip2Next.
  ///
  /// In en, this message translates to:
  /// **'Skip to Next'**
  String get skip2Next;

  /// No description provided for @playOrPause.
  ///
  /// In en, this message translates to:
  /// **'Play/Pause'**
  String get playOrPause;

  /// No description provided for @unlockDeskLrc.
  ///
  /// In en, this message translates to:
  /// **'Unlock Desktop Lyrics'**
  String get unlockDeskLrc;

  /// No description provided for @autoPlayOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Auto-Play on Startup'**
  String get autoPlayOnStartup;

  /// No description provided for @return2Previous.
  ///
  /// In en, this message translates to:
  /// **'Return to Previous'**
  String get return2Previous;

  /// No description provided for @addedFolders.
  ///
  /// In en, this message translates to:
  /// **'Added Folders'**
  String get addedFolders;

  /// No description provided for @recursiveScan.
  ///
  /// In en, this message translates to:
  /// **'Scan Subfolders'**
  String get recursiveScan;

  /// No description provided for @songInfo.
  ///
  /// In en, this message translates to:
  /// **'Song Info'**
  String get songInfo;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @bitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get bitrate;

  /// No description provided for @samplerate.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get samplerate;

  /// No description provided for @filePath.
  ///
  /// In en, this message translates to:
  /// **'File Path'**
  String get filePath;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @go2Artist.
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get go2Artist;

  /// No description provided for @go2Album.
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get go2Album;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @randomize.
  ///
  /// In en, this message translates to:
  /// **'Randomize'**
  String get randomize;

  /// No description provided for @normal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normal;

  /// No description provided for @randomizeTemp.
  ///
  /// In en, this message translates to:
  /// **'Randomize(Temporary)'**
  String get randomizeTemp;

  /// No description provided for @randomizePermanent.
  ///
  /// In en, this message translates to:
  /// **'Randomize(Permanent)'**
  String get randomizePermanent;

  /// No description provided for @modifiedTimeAscending.
  ///
  /// In en, this message translates to:
  /// **'Modified Time Ascending'**
  String get modifiedTimeAscending;

  /// No description provided for @modifiedTimedescending.
  ///
  /// In en, this message translates to:
  /// **'Modified Time Descending'**
  String get modifiedTimedescending;

  /// No description provided for @cannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'Cannot be Undone'**
  String get cannotBeUndone;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
