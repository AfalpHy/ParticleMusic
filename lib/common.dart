import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/history_manager.dart';
import 'package:particle_music/logger.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/mobile/pages/main_page.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting_manager.dart';

// ===================================== App =====================================

late Directory appDocs;
late Directory appSupportDir;
late Directory tmpDir;

late double appWidth;

final isMobile = Platform.isAndroid || Platform.isIOS;

// ===================================== library =====================================

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

// ===================================== MiniMode =====================================

final miniModeNotifier = ValueNotifier(false);

// ===================================== Sidebar =====================================

final ValueNotifier<String> sidebarHighlighLabel = ValueNotifier('');

// ===================================== DesktopMainPage =====================================

MyAudioMetadata? backgroundSong;

// ===================================== PlayQueuePage =====================================

final ValueNotifier<bool> displayPlayQueuePageNotifier = ValueNotifier(false);

// ===================================== Lyrics =====================================

final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);
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

Color backgroundColor = Colors.grey;
Color currentCoverArtColor = Colors.grey;
Color lyricsBackgroundColor = Colors.black;

Color sidebarColor = Colors.grey.shade200;
Color customSidebarColor = Colors.grey.shade200;
Color vividSidebarColor = Colors.grey.shade200.withAlpha(100);

Color bottomColor = Colors.grey.shade50;
Color customBottomColor = Colors.grey.shade50;
Color vividBottomColor = Colors.grey.shade50.withAlpha(100);

Color commonColor = Colors.grey.shade100;

Color iconColor = Colors.black;
Color textColor = Colors.black;
Color switchColor = Colors.black87;
Color panelColor = Colors.grey.shade100;
Color searchFieldColor = Colors.white;
Color buttonColor = Colors.white70;
Color dividerColor = Colors.grey;
Color selectedItemColor = Colors.white;

Color customIconColor = Colors.black;
Color customTextColor = Colors.black;
Color customSwitchColor = Colors.black87;
Color customPanelColor = Colors.grey.shade100;

Color vividIconColor = Colors.black;
Color vividTextColor = Colors.black;
Color vividSwitchColor = Colors.black87;
Color vividPanelColor = Colors.grey.shade100.withAlpha(100);

// ===================================== Images =====================================

const AssetImage addImage = AssetImage('assets/images/add.png');
const AssetImage albumImage = AssetImage('assets/images/album.png');
const AssetImage arrowDownImage = AssetImage('assets/images/arrow_down.png');
const AssetImage artistImage = AssetImage('assets/images/artist.png');
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
const AssetImage selectImage = AssetImage('assets/images/select.png');
const AssetImage sequenceImage = AssetImage('assets/images/sequence.png');
const AssetImage shuffleImage = AssetImage('assets/images/shuffle.png');
const AssetImage songsImage = AssetImage('assets/images/songs.png');
const AssetImage speakerOffImage = AssetImage('assets/images/speaker_off.png');
const AssetImage speakerImage = AssetImage('assets/images/speaker.png');
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
