import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/folder_manager.dart';
import 'package:particle_music/history_manager.dart';
import 'package:particle_music/library_manager.dart';
import 'package:particle_music/logger.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/mobile/pages/main_page.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting_manager.dart';

const String versionNumber = '1.0.14';

// ===================================== App =====================================

late Directory appDocs;
late Directory appSupportDir;
late Directory tmpDir;

late double appWidth;

final isMobile = Platform.isAndroid || Platform.isIOS;

// ===================================== Library =====================================

LibraryManager libraryManager = LibraryManager();

Set<String> filePathValidSet = {};

List<MyAudioMetadata> librarySongList = [];
List<MyAudioMetadata> libraryAdditionalSongList = [];
ValueNotifier<int> librarySongListUpdateNotifier = ValueNotifier(0);
Map<String, MyAudioMetadata> filePath2LibrarySong = {};

final ValueNotifier<int> loadedCountNotifier = ValueNotifier(0);
final ValueNotifier<String> currentLoadingFolderNotifier = ValueNotifier('');

Map<String, List<MyAudioMetadata>> artist2SongList = {};
Map<String, List<MyAudioMetadata>> album2SongList = {};
List<MapEntry<String, List<MyAudioMetadata>>> artistMapEntryList = [];
List<MapEntry<String, List<MyAudioMetadata>>> albumMapEntryList = [];

final ValueNotifier<bool> loadingLibraryNotifier = ValueNotifier(true);

// ===================================== Folder =====================================

late FolderManager folderManager;

// ===================================== MiniMode =====================================

final miniModeNotifier = ValueNotifier(false);

// ===================================== Sidebar =====================================

final ValueNotifier<String> sidebarHighlighLabel = ValueNotifier('');

// ===================================== DesktopMainPage =====================================

MyAudioMetadata? backgroundSong;

// ===================================== PlayQueuePage =====================================

final ValueNotifier<bool> displayPlayQueuePageNotifier = ValueNotifier(false);

// ===================================== Lyrics =====================================

LyricLine? currentLyricLine;
bool currentLyricLineIsKaraoke = false;

double lyricsFontSizeOffset = 0;
final lyricsFontSizeOffsetChangeNotifier = ValueNotifier(0);
final updateLyricsNotifier = ValueNotifier(0);

final ValueNotifier<bool> displayLyricsPageNotifier = ValueNotifier(false);
final ValueNotifier<bool> immersiveModeNotifier = ValueNotifier(false);
Timer? immersiveModeTimer;

// ===================================== Settings =====================================

ValueNotifier<bool> vibrationOnNoitifier = ValueNotifier(true);

ValueNotifier<bool> timedPause = ValueNotifier(false);
ValueNotifier<int> remainTimes = ValueNotifier(0);
ValueNotifier<bool> pauseAfterCompleted = ValueNotifier(false);
bool needPause = false;
Timer? pauseTimer;

final artistsIsListViewNotifier = ValueNotifier(true);
final artistsIsAscendingNotifier = ValueNotifier(true);
final artistsUseLargePictureNotifier = ValueNotifier(false);

final albumsIsAscendingNotifier = ValueNotifier(true);
final albumsUseLargePictureNotifier = ValueNotifier(false);

final playlistsUseLargePictureNotifier = ValueNotifier(true);

final enableCustomColorNotifier = ValueNotifier(false);
final enableCustomLyricsPageNotifier = ValueNotifier(false);

final updateColorNotifier = ValueNotifier(0);

final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

final exitOnCloseNotifier = ValueNotifier(false);

late SettingManager settingManager;

// ===================================== Colors =====================================

final darkModeNotifier = ValueNotifier(false);

// for desktop
Color backgroundFilterColor = Colors.grey;
// for mobile
late Color pageBackgroundColor;

Color currentCoverArtColor = Colors.grey;
Color lyricsBackgroundColor = Colors.black;

late Color iconColor;
late Color textColor;
late Color highlightTextColor;
late Color switchColor;
late Color playBarColor;
late Color panelColor;
late Color sidebarColor;
late Color bottomColor;
late Color searchFieldColor;
late Color buttonColor;
late Color dividerColor;
late Color selectedItemColor;
late Color seekBarColor;
late Color volumeBarColor;

Color customPageBackgroundColor = Color.fromARGB(255, 245, 245, 245);
Color customIconColor = Colors.black;
Color customTextColor = Color.fromARGB(255, 30, 30, 30);
Color customHighlightTextColor = Colors.black;
Color customSwitchColor = Colors.black87;
Color customPlayBarColor = Colors.white70;
Color customPanelColor = Colors.grey.shade100;
Color customSidebarColor = Colors.grey.shade200;
Color customBottomColor = Colors.grey.shade50;
Color customSearchFieldColor = Colors.white;
Color customButtonColor = Colors.white70;
Color customDividerColor = Colors.grey;
Color customSelectedItemColor = Colors.white;
Color customSeekBarColor = Colors.black;
Color customVolumeBarColor = Colors.black;

const Color lightModePageBackgroundColor = Color.fromARGB(255, 245, 245, 245);
const Color lightModeIconColor = Colors.black;
const Color lightModeTextColor = Color.fromARGB(255, 30, 30, 30);
const Color lightModeHighlightTextColor = Colors.black;
const Color lightModeSwitchColor = Colors.black87;
const Color lightModePlayBarColor = Colors.white70;
const Color lightModePanelColor = Color.fromARGB(100, 245, 245, 245);
const Color lightModeSidebarColor = Color.fromARGB(100, 238, 238, 238);
const Color lightModeBottomColor = Color.fromARGB(100, 250, 250, 250);
const Color lightModeSeekBarColor = Colors.black;
const Color lightModeVolumeBarColor = Colors.black;

const Color darkModePageBackgroundColor = Color.fromARGB(255, 50, 50, 50);
const Color darkModeCommonColor = Color.fromARGB(255, 97, 97, 97);
const Color darkModeIconColor = Color.fromARGB(255, 195, 195, 195);
const Color darkModeTextColor = Color.fromARGB(255, 195, 195, 195);
const Color darkModeHighlightTextColor = Color.fromARGB(255, 230, 230, 230);
const Color darkModeSwitchColor = Color.fromARGB(221, 0, 0, 0);
const Color darkModePlayerColor = Color.fromARGB(128, 30, 30, 30);
const Color darkModePanelColor = Color.fromARGB(255, 50, 50, 50);
const Color darkModeSidebarColor = Color.fromARGB(255, 55, 55, 55);
const Color darkModeBottomColor = Color.fromARGB(255, 60, 60, 60);
const Color darkModeSearchFieldColor = darkModeCommonColor;
const Color darkModeButtonColor = darkModeCommonColor;
const Color darkModeDividerColor = darkModeCommonColor;
const Color darkModeSelectedItemColor = darkModeCommonColor;
const Color darkModeSeekBarColor = Color.fromARGB(255, 195, 195, 195);
const Color darkModeVolumeBarColor = Color.fromARGB(255, 195, 195, 195);

// ===================================== Images =====================================

const AssetImage addImage = AssetImage('assets/images/add.png');
const AssetImage albumImage = AssetImage('assets/images/album.png');
const AssetImage arrowDownImage = AssetImage('assets/images/arrow_down.png');
const AssetImage artistImage = AssetImage('assets/images/artist.png');
const AssetImage checkUpdateImage = AssetImage(
  'assets/images/check_update.png',
);
const AssetImage closeImage = AssetImage('assets/images/close.png');
const AssetImage deleteImage = AssetImage('assets/images/delete.png');
const AssetImage desktopLyricsImage = AssetImage(
  'assets/images/desktop_lyrics.png',
);
const AssetImage folderImage = AssetImage('assets/images/folder.png');
const AssetImage fullscreenExitImage = AssetImage(
  'assets/images/fullscreen_exit.png',
);
const AssetImage fullscreenImage = AssetImage('assets/images/fullscreen.png');
const AssetImage gridImage = AssetImage('assets/images/grid.png');
const AssetImage infoImage = AssetImage('assets/images/info.png');
const AssetImage languageImage = AssetImage('assets/images/language.png');
const AssetImage listImage = AssetImage('assets/images/list.png');
const AssetImage location = AssetImage('assets/images/location.png');
const AssetImage longArrowDownImage = AssetImage(
  'assets/images/long_arrow_down.png',
);
const AssetImage longArrowUpImage = AssetImage(
  'assets/images/long_arrow_up.png',
);
const AssetImage loopImage = AssetImage('assets/images/loop.png');
const AssetImage lyricsImage = AssetImage('assets/images/lyrics.png');
const AssetImage maximizeImage = AssetImage('assets/images/maximize.png');
const AssetImage miniModeImage = AssetImage('assets/images/mini_mode.png');
const AssetImage minimizeImage = AssetImage('assets/images/minimize.png');
const AssetImage musicNoteImage = AssetImage('assets/images/music_note.png');
const AssetImage nextButtonImage = AssetImage('assets/images/next_button.png');
const AssetImage paletteImage = AssetImage('assets/images/palette.png');
const AssetImage pauseCircleImage = AssetImage(
  'assets/images/pause_circle.png',
);
const AssetImage pictureImage = AssetImage('assets/images/picture.png');

const AssetImage playCircleFillImage = AssetImage(
  'assets/images/play_circle_fill.png',
);
const AssetImage playCircleImage = AssetImage('assets/images/play_circle.png');
const AssetImage playQueueImage = AssetImage('assets/images/play_queue.png');
const AssetImage playlistAddImage = AssetImage(
  'assets/images/playlist_add.png',
);
const AssetImage playlistsImage = AssetImage('assets/images/playlists.png');
const AssetImage playnextCircleImage = AssetImage(
  'assets/images/playnext_circle.png',
);
const AssetImage powerOffImage = AssetImage('assets/images/power_off.png');
const AssetImage previousButtonImage = AssetImage(
  'assets/images/previous_button.png',
);
const AssetImage rankingImage = AssetImage('assets/images/ranking.png');
const AssetImage recentlyImage = AssetImage('assets/images/recently.png');
const AssetImage reloadImage = AssetImage('assets/images/reload.png');
const AssetImage reorderImage = AssetImage('assets/images/reorder.png');
const AssetImage repeatImage = AssetImage('assets/images/repeat.png');
const AssetImage reverseImage = AssetImage('assets/images/reverse.png');
const AssetImage selectImage = AssetImage('assets/images/select.png');
const AssetImage sequenceImage = AssetImage('assets/images/sequence.png');
const AssetImage shuffleImage = AssetImage('assets/images/shuffle.png');
const AssetImage songsImage = AssetImage('assets/images/songs.png');
const AssetImage speakerOffImage = AssetImage('assets/images/speaker_off.png');
const AssetImage speakerImage = AssetImage('assets/images/speaker.png');
const AssetImage themeImage = AssetImage('assets/images/theme.png');
const AssetImage timerImage = AssetImage('assets/images/timer.png');
const AssetImage unmaximizeImage = AssetImage('assets/images/unmaximize.png');
const AssetImage vibrationImage = AssetImage('assets/images/vibration.png');

// ===================================== AudioHandler =====================================

late MyAudioHandler audioHandler;

List<MyAudioMetadata> playQueue = [];

final ValueNotifier<MyAudioMetadata?> currentSongNotifier = ValueNotifier(null);
final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
final ValueNotifier<int> playModeNotifier = ValueNotifier(0);
final ValueNotifier<double> volumeNotifier = ValueNotifier(0.3);

// ===================================== Playlist =====================================

late PlaylistsManager playlistsManager;

// ===================================== DesktopLyrics =====================================

WindowController? lyricsWindowController;
bool lyricsWindowVisible = false;

LyricLine? desktopLyricLine;
Duration desktopLyricsCurrentPosition = Duration.zero;
bool desktopLyricsIsKaraoke = false;

final updateDesktopLyricsNotifier = ValueNotifier(0);

final showDesktopLrcOnAndroidNotifier = ValueNotifier(false);
final lockDesktopLrcOnAndroidNotifier = ValueNotifier(false);

final verticalDesktopLrcNotifier = ValueNotifier(false);

// ===================================== Keyboard =====================================

bool shiftIsPressed = false;
bool ctrlIsPressed = false;

// ===================================== Windows =====================================

ValueNotifier<bool> isMaximizedNotifier = ValueNotifier(false);
ValueNotifier<bool> isFullScreenNotifier = ValueNotifier(false);

// ===================================== Desktop =====================================

final PanelManager panelManager = PanelManager();

// ===================================== Mobile =====================================

final SwipeObserver swipeObserver = SwipeObserver();

// ===================================== History =====================================

final HistoryManager historyManager = HistoryManager();

final rankingChangeNotifier = ValueNotifier(0);
final recentlyChangeNotifier = ValueNotifier(0);

// ===================================== Logger =====================================

final logger = Logger();
