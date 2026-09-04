import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/my_window_listener.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/services/play_queue_logic.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/services/taskbar_service.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/base/utils/path.dart';
import 'package:sylvakru/base/widgets/equalizer.dart';
import 'package:sylvakru/base/widgets/lyric_list_view.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/base/utils/contrast_color_generator.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'dart:async';

import 'package:sylvakru/portrait_view/sleep_timer.dart';

late AudioSession _session;

late MyAudioHandler audioHandler;

List<MyAudioMetadata> playQueue = [];
String? playQueueForStreamId;
const String playQueueForStreamName = '_sylvakru_play_queue_';

final ValueNotifier<MyAudioMetadata?> currentSongNotifier = ValueNotifier(null);
final isPlayingNotifier = ValueNotifier(false);
final playModeNotifier = ValueNotifier(0);
final volumeNotifier = ValueNotifier(0.3);

final autoPlayOnStartupNotifier = ValueNotifier(false);

Future<void> initAudioService() async {
  MediaKit.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),

    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.afalphy.sylvakru',
      androidNotificationChannelName: 'Sylvakru',
      androidNotificationOngoing: true,
    ),
  );
  _session = await AudioSession.instance;
  await _session.configure(AudioSessionConfiguration.music());

  await _session.setActive(true);

  _session.becomingNoisyEventStream.listen((_) {
    audioHandler.pause();
  });

  _session.interruptionEventStream.listen((event) {
    if (event.begin) {
      audioHandler.pause();
    }
  });
}

class MyAudioHandler extends BaseAudioHandler {
  final _player = Player();
  bool _started = false;
  int currentIndex = -1;
  List<MyAudioMetadata> _playQueueTmp = [];
  int _tmpPlayMode = 0;
  DateTime? _playLastSyncTime;
  Duration _playedDuration = Duration.zero;

  File? _playQueueState;
  late File _playState;
  late File _equalizerState;
  late File _positionState;

  Timer? _positionTimer;

  bool isLoading = false;

  MyAudioHandler() {
    // avoid reading .lrc files
    (_player.platform as NativePlayer).setProperty('sub-auto', 'no');

    _player.stream.error.listen((onData) {
      logger.output("player error:$onData");
    });

    _player.stream.completed.listen((completed) async {
      if (completed) {
        final position = _player.state.position;
        final duration = _player.state.duration;

        // fake completed
        if ((duration - position).inSeconds > 2) {
          await pause();
          return;
        }

        bool needPauseTmp = needPause;

        if (Loader.busy) {
          await pause();
          return;
        }
        if (playModeNotifier.value == 2) {
          // repeat
          await load();
        } else {
          await skipToNext(); // automatically go to next song
        }

        if (needPauseTmp) {
          await pause();
        }
      }
    });

    currentSongNotifier.addListener(() {
      needPause = false;
      if (viewModeNotifier.value == .bigPicture) {
        if (useCurrentSongForBg) {
          colorManager.updateBigPictureRelatedColors(
            currentSongNotifier.value?.picture,
          );
        }
        return;
      }
      layersManager.updateBackground();
    });

    // _player.stream.position.listen((position) {
    //   if (isLoading) {
    //     return;
    //   }
    // });
  }

  void updateIsPlaying(bool isPlaying) {
    if (isPlaying) {
      _playLastSyncTime = DateTime.now();
    } else if (_playLastSyncTime != null) {
      _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      _playLastSyncTime = null;
    }
    needPause = false;
    isPlayingNotifier.value = isPlaying;
    if (Platform.isWindows) {
      if (!windowIsClosed) {
        setupTaskbar();
      }
    }
  }

  void updatePlaybackState({Duration? postion, bool stop = false}) {
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          isPlayingNotifier.value ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: {MediaAction.seek},
        playing: isPlayingNotifier.value,
        processingState: stop ? .idle : .ready,
        speed: _player.state.rate,
        updatePosition: postion ?? _player.state.position,
      ),
    );
  }

  void _prepare() {
    if (isNotStreamSource) {
      _playQueueState = File(
        "${appSupportDir.path}/${sourceType.name}/play_queue_state.json",
      );
      if (!(_playQueueState!.existsSync())) {
        _playQueueState!.createSync(recursive: true);
        _savePlayQueueState();
      }
    }

    _playState = File(
      "${appSupportDir.path}/${sourceType.name}/play_state.json",
    );
    if (!(_playState.existsSync())) {
      _playState.createSync(recursive: true);
      savePlayState();
    }
    _equalizerState = File("${appSupportDir.path}/equalizer_state.json");
    if (!(_equalizerState.existsSync())) {
      saveEqualizerState();
    }

    _positionState = File(
      "${appSupportDir.path}/${sourceType.name}/position_state.json",
    );
    if (!(_positionState.existsSync())) {
      _positionState.createSync(recursive: true);
      _positionState.writeAsString(Duration.zero.inMilliseconds.toString());
    }
  }

  List<MyAudioMetadata> _restoreQueue(List<dynamic>? rawList) {
    final result = <MyAudioMetadata>[];

    for (final id in rawList ?? []) {
      final song = library.id2Song[id];
      if (song != null) result.add(song);
    }

    return result;
  }

  Future<void> loadStates() async {
    _prepare();
    await _loadPlayState();
    await _loadPlayQueueState();
    await _loadEqualizerState();
    await _tryPlay();
  }

  Future<void> _loadPlayQueueState() async {
    if (isNotStreamSource) {
      final content = await _playQueueState!.readAsString();

      final json = jsonDecode(content) as Map<String, dynamic>;

      _playQueueTmp.addAll(_restoreQueue(json['playQueueTmp']));
      playQueue.addAll(_restoreQueue(json['playQueue']));
    } else {
      playQueue.clear();
      playQueue = await streamClient?.getPlayQueue() ?? [];
      _playQueueTmp = List.from(playQueue);
    }
  }

  Future<void> _savePlayQueueState() async {
    if (isNotStreamSource) {
      _playQueueState!.writeAsStringSync(
        jsonEncode({
          'playQueueTmp': _playQueueTmp.map((e) => e.id).toList(),
          'playQueue': playQueue.map((e) => e.id).toList(),
        }),
      );
    } else {
      await streamClient?.savePlayQueue(playQueue.map((e) => e.id).toList());
    }
  }

  Future<void> _tryPlay() async {
    if (!_started) {
      _started = true;
      if (autoPlayOnStartupNotifier.value) {
        if (playQueue.isEmpty) {
          currentIndex = 0;
          playQueue = List.from(library.songList);
        }
        if (playQueue.isNotEmpty) {
          isPlayingNotifier.value = true;
        } else {
          currentIndex = -1;
        }
      }
    }

    if (playQueue.isNotEmpty) {
      // reload may make some songs not in the library to be removed
      if (currentIndex == -1 || currentIndex >= playQueue.length) {
        currentIndex = 0;
      }

      final positionMs = await _positionState.readAsString();

      await load(start: Duration(milliseconds: int.tryParse(positionMs) ?? 0));

      if (isPlayingNotifier.value) {
        _positionTimer ??= Timer.periodic(Duration(seconds: 1), (_) {
          _positionState.writeAsString(getPosition().inMilliseconds.toString());
        });
      }
    }
  }

  Future<void> _loadPlayState() async {
    final content = await _playState.readAsString();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    currentIndex = json['currentIndex'] as int? ?? -1;
    playModeNotifier.value = json['playMode'] as int? ?? 0;
    _tmpPlayMode = json['tmpPlayMode'] as int? ?? 0;

    volumeNotifier.value = json['volume'] as double? ?? 0.3;

    if (!isMobile) {
      setVolume(volumeNotifier.value);
    }
  }

  void savePlayState() {
    _playState.writeAsStringSync(
      jsonEncode({
        'currentIndex': currentIndex,
        'playMode': playModeNotifier.value,
        'tmpPlayMode': _tmpPlayMode,
        'volume': volumeNotifier.value,
      }),
    );
  }

  Future<void> _loadEqualizerState() async {
    if (!isPremiumNotifier.value) {
      return;
    }
    final content = await _equalizerState.readAsString();
    gains = (jsonDecode(content) as List<dynamic>).cast();
    await applyEqualizer();
  }

  void saveEqualizerState() {
    _equalizerState.writeAsStringSync(jsonEncode(gains));
  }

  void saveAllStates() async {
    await audioHandler._savePlayQueueState();
    audioHandler.savePlayState();
  }

  bool insert2Next(MyAudioMetadata song) {
    final result = PlayQueueLogic.insert2Next(playQueue, currentIndex, song);
    if (result == null) {
      return false;
    }
    currentIndex = result.currentIndex;
    if (result.wasNewlyInserted &&
        (playModeNotifier.value == 1 ||
            (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1))) {
      _playQueueTmp.add(song);
    }
    return true;
  }

  bool add2Last(MyAudioMetadata song) {
    final result = PlayQueueLogic.add2Last(playQueue, currentIndex, song);
    if (result == null) {
      return false;
    }
    currentIndex = result.currentIndex;
    if (result.wasNewlyInserted &&
        (playModeNotifier.value == 1 ||
            (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1))) {
      _playQueueTmp.add(song);
    }
    return true;
  }

  void singlePlay(MyAudioMetadata song) async {
    if (insert2Next(song)) {
      await skipToNext();
    }
    play();
  }

  Future<void> setPlayQueue(
    List<MyAudioMetadata> source,
    int playMode, {
    int? targetIndex,
  }) async {
    if (targetIndex != null) {
      currentIndex = targetIndex;
    } else {
      currentIndex = playMode == 0 ? 0 : math.Random().nextInt(source.length);
      playModeNotifier.value = playMode;
    }
    playQueue = List.from(source);
    if (playModeNotifier.value == 1 ||
        (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1)) {
      shuffle();
    }
    await audioHandler.load();
    audioHandler.play();

    saveAllStates();
  }

  void reversePlayQueue() {
    if (playQueue.isEmpty) {
      return;
    }
    playQueue = playQueue.reversed.toList();
    currentIndex = playQueue.indexOf(currentSongNotifier.value!);
    saveAllStates();
  }

  void shuffle() {
    if (playQueue.isEmpty) {
      return;
    }
    _playQueueTmp = List.from(playQueue);
    final others = List.of(playQueue)..removeAt(currentIndex);
    others.shuffle();
    playQueue = [playQueue[currentIndex], ...others];
    currentIndex = 0;
  }

  void changePlayMode(int newPlayMode) async {
    if (newPlayMode == playModeNotifier.value) {
      return;
    }

    switch (newPlayMode) {
      case 0:
        if (_playQueueTmp.isNotEmpty) {
          playQueue = List.from(_playQueueTmp);
          _playQueueTmp = [];
          currentIndex = playQueue.indexOf(currentSongNotifier.value!);
        }
        break;
      case 1:
        if (_playQueueTmp.isEmpty) {
          shuffle();
        }
        break;
      default:
        break;
    }
    playModeNotifier.value = newPlayMode;
    if (newPlayMode != 2) {
      await _savePlayQueueState();
    }

    savePlayState();
  }

  void switchPlayMode() {
    int playMode = playModeNotifier.value;
    playMode += 1;
    playMode %= 2;
    playModeNotifier.value = playMode;
    if (playMode == 0) {
      playQueue = List.from(_playQueueTmp);
      _playQueueTmp = [];
      currentIndex = playQueue.indexOf(currentSongNotifier.value!);
    } else if (playMode == 1) {
      shuffle();
    }
    saveAllStates();
  }

  void toggleRepeat() {
    if (playModeNotifier.value != 2) {
      _tmpPlayMode = playModeNotifier.value;
      playModeNotifier.value = 2;
    } else {
      playModeNotifier.value = _tmpPlayMode;
    }
    savePlayState();
  }

  void delete(int index) {
    MyAudioMetadata tmp = playQueue[index];
    if (_playQueueTmp.isNotEmpty) {
      _playQueueTmp.remove(tmp);
    }
    playQueue.removeAt(index);
  }

  Future<void> clear() async {
    stop();
    playQueue = [];
    _playQueueTmp = [];
    currentIndex = -1;
    currentSongNotifier.value = null;
    currentCoverArtColor = Colors.grey;
    saveAllStates();
  }

  void justClear() {
    _player.stop();
    updateIsPlaying(false);
    updatePlaybackState(stop: true);
    _positionTimer?.cancel();
    _positionTimer = null;

    playQueue = [];
    _playQueueTmp = [];
    currentIndex = -1;
    currentSongNotifier.value = null;
    currentCoverArtColor = Colors.grey;
  }

  List<MyAudioMetadata> getNewQueue(List<MyAudioMetadata> oldQueue) {
    final List<MyAudioMetadata> newPlayQueue = [];
    for (final song in oldQueue) {
      final newSong = library.id2Song[song.id];
      if (newSong != null) {
        newPlayQueue.add(newSong);
      }
    }
    return newPlayQueue;
  }

  Future<void> sync() async {
    if (isNotStreamSource) {
      playQueue = getNewQueue(playQueue);
      _playQueueTmp = getNewQueue(_playQueueTmp);
      final currentSong = currentSongNotifier.value;
      if (currentSong != null) {
        final tmpCurrentSong = library.id2Song[currentSong.id];
        if (tmpCurrentSong != null) {
          await _setLyricsAndUpdateColors(tmpCurrentSong);
          currentSongNotifier.value = tmpCurrentSong;
          currentIndex = playQueue.indexOf(tmpCurrentSong);
          updateServiceMediaItem(tmpCurrentSong);
        } else {
          currentSongNotifier.value = null;
          currentIndex = -1;
          if (playQueue.isNotEmpty) {
            await skipToNext();
          } else {
            await stop();
          }
        }
      }
      saveAllStates();
    } else {
      await _loadPlayQueueState();
      currentIndex = playQueue.indexWhere(
        (e) => e.id == currentSongNotifier.value?.id,
      );
      if (currentIndex != -1) {
        final tmpCurrentSong = playQueue[currentIndex];
        await _setLyricsAndUpdateColors(tmpCurrentSong);
        currentSongNotifier.value = tmpCurrentSong;
        updateServiceMediaItem(tmpCurrentSong);
      } else if (playQueue.isNotEmpty) {
        await skipToNext();
      } else {
        currentSongNotifier.value = null;
        await stop();
      }
    }
  }

  Future<void> _setLyricsAndUpdateColors(MyAudioMetadata song) async {
    await setParsedLyrics(song);
    currentCoverArtColor = await computeColor(song.picture);
    updateHoverFocusColor();
    contrastColorTheme = ContrastColorGenerator.generate(currentCoverArtColor);
    if (lyricsPageThemeNotifier.value == .vivid) {
      colorManager.updateLyricsPageColors();
    }

    if (viewModeNotifier.value == .mini) {
      colorManager.updateMiniViewColors();
    }
  }

  Future<void> load({Duration? start}) async {
    if (currentSongNotifier.value != null) {
      if (_playLastSyncTime != null) {
        _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      }

      int durationSeconds = getDuration(currentSongNotifier.value).inSeconds;
      // fix wrong duration
      if (durationSeconds <= 0) {
        durationSeconds = _player.state.duration.inSeconds;
        if (durationSeconds > 0 && isNotStreamSource) {
          await library.updateDuration(
            currentSongNotifier.value!,
            _player.state.duration,
          );
        }
      }
      if (durationSeconds > 0) {
        double times = _playedDuration.inSeconds / durationSeconds;
        if (times > 0.5) {
          library.tryAddCache(currentSongNotifier.value!);
          history.addSongTimes(currentSongNotifier.value!, times.round());
        }
      }
    }
    _playLastSyncTime = null;
    _playedDuration = Duration.zero;

    // save currentIndex
    savePlayState();

    final currentSong = playQueue[currentIndex];

    await _setLyricsAndUpdateColors(currentSong);

    currentSongNotifier.value = currentSong;

    isLoading = true;
    try {
      if (currentSong.cacheExist) {
        await _player.open(
          Media(currentSong.cachePath!, start: start),
          play: isPlayingNotifier.value,
        );
      } else {
        String? resource;
        bool needHeader = false;
        switch (sourceType) {
          case .webdav:
            final tmpPath = await covertToRedirectPathIfNeed(currentSong.path!);
            if (tmpPath == null) {
              needHeader = true;
            } else {
              resource = tmpPath;
            }
            break;
          case .navidrome:
          case .emby:
            resource = streamClient?.getStreamUrl(currentSong.id);
            break;
          default:
            break;
        }
        resource ??= currentSong.path!;

        await _player.open(
          Media(
            resource,
            httpHeaders: needHeader ? webdavClient?.headers : null,
            start: start,
          ),
          play: isPlayingNotifier.value,
        );
      }

      if (isPlayingNotifier.value) {
        _playLastSyncTime = DateTime.now();
      }
    } catch (error) {
      stop();
      logger.output("[${currentSong.title}] $error");
    }
    isLoading = false;

    updateServiceMediaItem(currentSong);

    updatePlaybackState(postion: Duration.zero);

    if (start == null) {
      _positionState.writeAsString(Duration.zero.inMilliseconds.toString());
    }
  }

  void updateServiceMediaItem(MyAudioMetadata currentSong) {
    Uri? artUri;

    if (currentSong.picture.isExist) {
      artUri = File(currentSong.picture.path).uri;
    }

    mediaItem.add(
      MediaItem(
        id: currentSong.id,
        title: getTitle(currentSong),
        artist: getArtist(currentSong),
        album: getAlbum(currentSong),
        artUri: artUri, // file:// URI
        duration: currentSong.duration,
      ),
    );
  }

  @override
  Future<void> play() async {
    if (playQueue.isEmpty) return;
    _player.play();

    updateIsPlaying(true);
    updatePlaybackState();

    _positionTimer ??= Timer.periodic(Duration(seconds: 1), (_) {
      _positionState.writeAsString(getPosition().inMilliseconds.toString());
    });
  }

  @override
  Future<void> pause() async {
    _player.pause();
    updateIsPlaying(false);
    updatePlaybackState();
    _positionTimer?.cancel();
    _positionTimer = null;
    _positionState.writeAsString(getPosition().inMilliseconds.toString());
  }

  @override
  Future<void> stop() async {
    _player.stop();
    updateIsPlaying(false);
    updatePlaybackState(stop: true);
    _positionTimer?.cancel();
    _positionTimer = null;
    _positionState.writeAsString(Duration.zero.inMilliseconds.toString());
  }

  @override
  Future<void> seek(Duration position) async {
    updatePlaybackState(postion: position);
    await _player.seek(position);
    // ensure position is updated
    await Future.delayed(Duration(milliseconds: 50));
    updateLyricsNotifier.value++;
    _positionState.writeAsString(getPosition().inMilliseconds.toString());
  }

  @override
  Future<void> skipToNext() async {
    if (playQueue.isEmpty) return;

    currentIndex = (currentIndex + 1) % playQueue.length;
    await load();
  }

  @override
  Future<void> skipToPrevious() async {
    if (playQueue.isEmpty) return;

    currentIndex = (currentIndex + playQueue.length - 1) % playQueue.length;
    await load();
  }

  void togglePlay() {
    if (isPlayingNotifier.value) {
      pause();
    } else {
      play();
    }
  }

  Stream<Duration> getPositionStream() {
    return _player.stream.position;
  }

  Stream<Duration> getDurationStream() {
    return _player.stream.duration;
  }

  Duration getPosition() {
    return _player.state.position;
  }

  Duration getCurrentDuration() {
    return _player.state.duration;
  }

  void setVolume(double volume) {
    double adjustedVolume = (math.log(volume * 9 + 1) / math.log(10)) * 100;
    _player.setVolume(adjustedVolume);
  }

  Future<void> applyEqualizer() async {
    bool isAllZero = gains.every((g) => g.abs() < 0.01);
    String af = '';

    if (!isAllZero) {
      double g1 = gains[0]; // 31Hz
      double g2 = gains[1]; // 62Hz
      double g3 = gains[2]; // 125Hz
      double g4 = gains[3]; // 250Hz
      double g5 = gains[4]; // 500Hz
      double g6 = gains[5]; // 1kHz
      double g7 = gains[6]; // 2kHz
      double g8 = gains[7]; // 4kHz
      double g9 = gains[8]; // 8kHz
      double g10 = gains[9]; // 16kHz

      double b1 = g1; // 65Hz
      double b2 = 0.0;
      double b3 = g2; // 131Hz
      double b4 = g3; // 185Hz
      double b5 = 0.0; // 263Hz
      double b6 = g4; // 371Hz
      double b7 = g5; // 525Hz
      double b8 = 0.0; // 742Hz
      double b9 = g6; // 1050Hz
      double b10 = g7; // 1480Hz
      double b11 = 0.0; // 2090Hz
      double b12 = g8; // 2960Hz
      double b13 = 0.0;
      double b14 = g9; // 5920Hz
      double b15 = 0.0; // 8370Hz
      double b16 = g10; // 11800Hz
      double b17 = g10; // 16700Hz
      double b18 = g10; // 20000Hz

      List<double> bValues = [
        b1,
        b2,
        b3,
        b4,
        b5,
        b6,
        b7,
        b8,
        b9,
        b10,
        b11,
        b12,
        b13,
        b14,
        b15,
        b16,
        b17,
        b18,
      ];

      final List<String> activeParams = [];
      for (int i = 0; i < bValues.length; i++) {
        double multiplier = math.pow(10, bValues[i] / 20).toDouble();

        activeParams.add('${i + 1}b=${multiplier.toStringAsFixed(3)}');
      }
      af = 'superequalizer=${activeParams.join(":")}';
    }

    await (_player.platform as NativePlayer).setProperty('af', af);
    saveEqualizerState();
  }
}
