import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';

import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/history.dart';
import 'package:particle_music/library.dart';
import 'package:particle_music/logger.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/setting_manager.dart';
import 'package:webdav_client/webdav_client.dart';

const String versionNumber = '2.1.2';

// ===================================== App =====================================

late Directory appDocs;
late Directory appSupportDir;
late Directory tmpDir;
late Directory folderConfigDir;
late Directory playlistConfigDir;
late Directory cacheConfigDir;

final isMobile = Platform.isAndroid || Platform.isIOS;
final isTV = true;

// ===================================== Library =====================================

late Library library;

final ValueNotifier<int> loadedCountNotifier = ValueNotifier(0);
final ValueNotifier<String> currentLoadingFolderNotifier = ValueNotifier('');

final ValueNotifier<bool> loadingLibraryNotifier = ValueNotifier(true);

final ValueNotifier<bool> loadingNavidromeNotifier = ValueNotifier(false);

final ValueNotifier<bool> recursiveScanNotifier = ValueNotifier(false);

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

final playlistsUseLargePictureNotifier = ValueNotifier(true);

final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

final autoPlayOnStartupNotifier = ValueNotifier(false);

final exitOnCloseNotifier = ValueNotifier(false);

late SettingManager settingManager;

String webdavUsername = '';
String webdavPassword = '';
String webdavBaseUrl = '';

Client? webdavClient;
// ===================================== Colors =====================================

final mainPageThemeNotifier = ValueNotifier(0);
final lyricsPageThemeNotifier = ValueNotifier(0);

Color backgroundCoverArtColor = Colors.grey;
Color currentCoverArtColor = Colors.grey;

// ===================================== Images =====================================

const AssetImage addImage = AssetImage('assets/images/add.png');
const AssetImage albumImage = AssetImage('assets/images/album.png');
const AssetImage arrowDownImage = AssetImage('assets/images/arrow_down.png');
const AssetImage artistImage = AssetImage('assets/images/artist.png');
const AssetImage cacheImage = AssetImage('assets/images/cache.png');
const AssetImage checkUpdateImage = AssetImage(
  'assets/images/check_update.png',
);
const AssetImage closeImage = AssetImage('assets/images/close.png');
const AssetImage deleteImage = AssetImage('assets/images/delete.png');
const AssetImage desktopLyricsImage = AssetImage(
  'assets/images/desktop_lyrics.png',
);
const AssetImage equalizerImage = AssetImage('assets/images/equalizer.png');
const AssetImage exportLogImage = AssetImage('assets/images/export_log.png');
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
const AssetImage navidromeImage = AssetImage('assets/images/navidrome.png');
const AssetImage nextButtonImage = AssetImage('assets/images/next_button.png');
const AssetImage paletteImage = AssetImage('assets/images/palette.png');
const AssetImage pauseCircleImage = AssetImage(
  'assets/images/pause_circle.png',
);
const AssetImage pictureImage = AssetImage('assets/images/picture.png');
const AssetImage playCircleFillImage = AssetImage(
  'assets/images/play_circle_fill.png',
);
const AssetImage playOutlinedImage = AssetImage(
  'assets/images/play_outlined.png',
);
const AssetImage playQueueImage = AssetImage('assets/images/play_queue.png');
const AssetImage playlistsImage = AssetImage('assets/images/playlists.png');
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
const AssetImage settingImage = AssetImage('assets/images/setting.png');
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

// ===================================== History =====================================

final History history = History();

final rankingChangeNotifier = ValueNotifier(0);
final recentlyChangeNotifier = ValueNotifier(0);

// ===================================== Logger =====================================

final logger = Logger();
