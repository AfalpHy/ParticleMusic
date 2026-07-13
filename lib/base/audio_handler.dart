import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/metadata_service.dart';
import 'package:sylvakru/base/services/subsonic_client.dart';
import 'package:sylvakru/base/services/super_lyric.dart';
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
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/replay_gain.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'dart:async';

import 'package:sylvakru/portrait_view/sleep_timer.dart';

late AudioSession _session;

late MyAudioHandler audioHandler;

List<MyAudioMetadata> playQueue = [];

final ValueNotifier<MyAudioMetadata?> currentSongNotifier = ValueNotifier(null);
final isPlayingNotifier = ValueNotifier(false);
final playModeNotifier = ValueNotifier(0);
final volumeNotifier = ValueNotifier(0.3);

bool shouldUseRemoteAndroidVolume(UsbExclusivePlaybackState state) {
  return state.active &&
      (state.hardwareVolumeActive ||
          (state.digitalVolumeActive && state.bitDepth != 1));
}

double adjustedRemoteVolume(
  double current,
  AndroidVolumeDirection direction,
) {
  final delta = identical(direction, AndroidVolumeDirection.raise)
      ? 0.02
      : identical(direction, AndroidVolumeDirection.lower)
      ? -0.02
      : 0.0;
  return (current + delta).clamp(0.0, 1.0).toDouble();
}

double absoluteRemoteVolume(int index) {
  return (index.clamp(0, 100) / 100).toDouble();
}

AndroidPlaybackInfo androidPlaybackInfoFor(
  UsbExclusivePlaybackState state,
  double volume,
) {
  if (!shouldUseRemoteAndroidVolume(state)) {
    return LocalAndroidPlaybackInfo();
  }
  return RemoteAndroidPlaybackInfo(
    volumeControlType: AndroidVolumeControlType.absolute,
    maxVolume: 100,
    volume: (volume.clamp(0.0, 1.0) * 100).round(),
  );
}

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

  final usbAudioStatus = await usbAudioService.refreshStatus();
  if (usbAudioStatus.supported) {
    logger.output("usb audio:${usbAudioStatus.message}");
  }

  _session.becomingNoisyEventStream.listen((_) {
    debugPrint(
      "audio session becoming noisy; usbExclusiveActive=${audioHandler._usbExclusiveActive}",
    );
    if (audioHandler._usbExclusiveActive) {
      return;
    }
    audioHandler.pause();
  });

  _session.interruptionEventStream.listen((event) {
    debugPrint(
      "audio session interruption begin=${event.begin}; usbExclusiveActive=${audioHandler._usbExclusiveActive}",
    );
    if (event.begin && !audioHandler._usbExclusiveActive) {
      audioHandler.pause();
    }
  });
}

class MyAudioHandler extends BaseAudioHandler with WidgetsBindingObserver {
  final _player = Player();
  final _superLyric = SuperLyric();
  bool _started = false;
  int currentIndex = -1;
  List<MyAudioMetadata> _playQueueTmp = [];
  int _tmpPlayMode = 0;
  DateTime? _playLastSyncTime;
  Duration _playedDuration = Duration.zero;
  Duration _usbExclusivePosition = Duration.zero;
  bool _usbExclusiveActive = false;
  // 主动停止独占（切歌/停止播放）时置真，避免独占状态监听把主动停当成意外中断而误触发回退续播
  bool _intentionalExclusiveStop = false;
  bool _suppressPlayerCompleted = false;
  final _positionController = StreamController<Duration>.broadcast();
  ReplayGainResult _currentReplayGain = const ReplayGainResult(0, null, null);

  late final File _playQueueState;
  late final File _playState;
  late final File _equalizerState;

  bool isLoading = false;
  bool isSyncing = false;
  // load 的代次号：云端下载/权限弹窗等慢路径期间用户再切歌时，旧的 load 凭它自行作废
  int _loadGeneration = 0;

  MyAudioHandler() {
    _publishAndroidPlaybackInfo();
    // avoid reading .lrc files
    (_player.platform as NativePlayer).setProperty('sub-auto', 'no');

    _player.stream.error.listen((onData) {
      logger.output("player error:$onData");
    });

    _player.stream.completed.listen((completed) async {
      if (_suppressPlayerCompleted) {
        return;
      }
      if (completed) {
        final position = _player.state.position;
        final duration = _player.state.duration;

        // fake completed
        if ((duration - position).inSeconds > 2) {
          await pause();
          return;
        }

        bool needPauseTmp = needPause;

        while (isSyncing) {
          await Future.delayed(Duration(milliseconds: 50));
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
      layersManager.updateBackground();
    });

    _player.stream.position.listen((position) {
      // 非独占播放时，播放器位置直接驱动进度流。
      if (!_usbExclusiveActive) {
        _positionController.add(position);
      }
      if (isLoading || isSyncing) {
        return;
      }
      if (!isPlayingNotifier.value) {
        return;
      }
      unawaited(_superLyric.publishAt(position));
    });

    usbExclusivePlaybackStateNotifier.addListener(_handleUsbExclusiveState);
    usbExclusiveVolumeKeyNotifier.addListener(_handleUsbExclusiveVolumeKey);
    usbHardwareVolumeNotifier.addListener(_handleUsbHardwareVolume);
    // 切换音量控制方式后立即按新方式重下发（原始数字电平旁路、其余数字音量）。
    usbAudioPreferences.volumeControlModeNotifier.addListener(() {
      _applyUsbExclusiveVolume(
        usbExclusiveDigitalVolumeGain(volumeNotifier.value),
      );
    });
    usbAudioPreferences.dsdGainCompensationNotifier.addListener(() {
      _applyUsbExclusiveVolume(
        usbExclusiveDigitalVolumeGain(volumeNotifier.value),
      );
    });
    usbAudioPreferences.volumeSmoothHandoffNotifier.addListener(() {
      _applyUsbExclusiveVolume(
        usbExclusiveDigitalVolumeGain(volumeNotifier.value),
      );
    });
    usbAudioPreferences.replayGainModeNotifier.addListener(() {
      final song = currentSongNotifier.value;
      _currentReplayGain = song == null
          ? const ReplayGainResult(0, null, null)
          : replayGainFor(
              song,
              usbAudioPreferences.replayGainModeNotifier.value,
            );
      if (_usbExclusiveActive) {
        _applyUsbExclusiveVolume(
          usbExclusiveDigitalVolumeGain(volumeNotifier.value),
        );
      } else {
        unawaited(
          _applySharedReplayGain(_perceptualVolumeGain(volumeNotifier.value)),
        );
      }
    });
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
    }
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
  }

  void updatePlaybackState({Duration? postion, bool stop = false}) {
    final position =
        postion ??
        (_usbExclusiveActive ? _usbExclusivePosition : _player.state.position);
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
        speed: _usbExclusiveActive ? 1.0 : _player.state.rate,
        updatePosition: position,
      ),
    );
  }

  void _handleUsbExclusiveState() {
    final state = usbExclusivePlaybackStateNotifier.value;
    final wasActive = _usbExclusiveActive;
    _usbExclusivePosition = state.position;
    _usbExclusiveActive = state.active;
    _publishAndroidPlaybackInfo();

    if (state.active) {
      // 刚进入独占时把当前音量按当前控制方式下发一次，避免独占起播后音量失控。
      if (!wasActive) {
        _applyUsbExclusiveVolume(
          usbExclusiveDigitalVolumeGain(volumeNotifier.value),
        );
      }
      // 独占播放时，位置由独占链路上报，驱动进度流。
      _positionController.add(state.position);
      if (isPlayingNotifier.value != state.playing) {
        updateIsPlaying(state.playing);
      }
      updatePlaybackState(postion: state.position);
      if (state.playing) {
        unawaited(_superLyric.publishAt(state.position));
      }
      return;
    }

    if (wasActive && state.message?.contains('completed') == true) {
      logger.output("usb exclusive completed -> auto advance");
      debugPrint("usb exclusive completed -> auto advance");
      // 对齐共享路径 completed 分支的语义：单曲循环重载当前曲、睡眠定时器播完暂停
      final needPauseTmp = needPause;
      unawaited(() async {
        while (isSyncing) {
          await Future.delayed(Duration(milliseconds: 50));
        }
        if (playModeNotifier.value == 2) {
          // repeat
          await load();
        } else {
          await skipToNext();
        }
        if (needPauseTmp) {
          await pause();
        }
      }());
    } else if (wasActive && !_intentionalExclusiveStop) {
      // 独占播放中途意外失活（拔出 DAC / 写失败 ENODEV 等）：回退系统输出，从中断位置续播，
      // 不再卡住需要手动切歌才恢复。
      logger.output(
        "usb exclusive interrupted -> system output fallback:${state.message}",
      );
      debugPrint(
        "usb exclusive interrupted -> system output fallback:${state.message}",
      );
      unawaited(_resumeOnSystemOutputAfterExclusiveInterrupt(state.position));
    }
  }

  Future<void> _stopPlayerForUsbExclusive() async {
    _suppressPlayerCompleted = true;
    try {
      await _player.stop();
    } finally {
      scheduleMicrotask(() {
        _suppressPlayerCompleted = false;
      });
    }
  }

  /// 主动停止独占（切歌/停止播放）时置标志，避免独占状态监听把这次失活
  /// 误判成意外中断而触发回退续播。
  Future<void> _stopExclusiveIntentionally() async {
    _intentionalExclusiveStop = true;
    try {
      await usbAudioService.stopExclusivePlayback();
    } finally {
      _intentionalExclusiveStop = false;
    }
  }

  /// 用系统输出（media_kit）打开歌曲并按当前播放状态起播。
  /// 供 load() 非独占分支与独占意外中断回退续播复用。
  Future<void> _openPlayerMedia(MyAudioMetadata currentSong) async {
    await _applySharedReplayGain(_perceptualVolumeGain(volumeNotifier.value));
    if (currentSong.cacheExist) {
      await _player.open(
        Media(currentSong.cachePath!),
        play: isPlayingNotifier.value,
      );
      return;
    }
    String? resource;
    bool needHeader = false;
    switch (currentSong.sourceType) {
        case .webdav:
        final tmpPath = await convertToRealPathIfNeed(currentSong.path!);
        if (tmpPath == null) {
          needHeader = true;
        } else {
          resource = tmpPath;
          }
          break;
        case .subsonic:
          currentSong.path ??= subsonicClient!.getStreamUrl(currentSong.id);
          break;
        case .navidrome:
        currentSong.path ??= navidromeClient!.getStreamUrl(currentSong.id);
        break;
      case .emby:
        currentSong.path ??= embyClient!.audioUrl(currentSong.id);
        break;
      default:
        break;
    }
    resource ??= currentSong.path!;
    await _player.open(
      Media(resource, httpHeaders: needHeader ? webdavClient?.headers : null),
      play: isPlayingNotifier.value,
    );
  }

  /// 独占播放中途意外中断（拔出 DAC、写失败 ENODEV 等）时回退到系统输出，
  /// 从中断位置续播，避免卡住需要手动切歌才恢复。
  Future<void> _resumeOnSystemOutputAfterExclusiveInterrupt(
    Duration position,
  ) async {
    final currentSong = currentSongNotifier.value;
    if (currentSong == null) {
      return;
    }
    final generation = _loadGeneration;
    try {
      await _applyUsbOutputForSong(currentSong);
      if (generation != _loadGeneration) return;
      await _openPlayerMedia(currentSong);
      if (generation != _loadGeneration) return;
      if (position > Duration.zero) {
        await _player.seek(position);
      }
    } catch (error) {
      logger.output("usb exclusive interrupt fallback failed:$error");
      debugPrint("usb exclusive interrupt fallback failed:$error");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_usbExclusiveActive) {
      return;
    }
    final targetBufferMs = _exclusiveTargetBufferMsForLifecycle(state);
    debugPrint("usb exclusive lifecycle=$state targetBufferMs=$targetBufferMs");
    unawaited(usbAudioService.setExclusiveTargetBufferMs(targetBufferMs));
  }

  int _exclusiveTargetBufferMsForLifecycle(AppLifecycleState? state) {
    return preferredUsbExclusiveTargetBufferMs(
      background: switch (state) {
        AppLifecycleState.resumed => false,
        AppLifecycleState.inactive ||
        AppLifecycleState.hidden ||
        AppLifecycleState.paused ||
        AppLifecycleState.detached => true,
        null => false,
      },
    );
  }

  void initStateFiles() {
    _playQueueState = File("${appSupportDir.path}/play_queue_state.json");
    if (!(_playQueueState.existsSync())) {
      _savePlayQueueState();
    }
    _playState = File("${appSupportDir.path}/play_state.json");
    if (!(_playState.existsSync())) {
      savePlayState();
    }
    _equalizerState = File("${appSupportDir.path}/equalizer_state.json");
    if (!(_equalizerState.existsSync())) {
      saveEqualizerState();
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

  Future<void> loadPlayQueueState() async {
    final content = await _playQueueState.readAsString();

    final json = jsonDecode(content) as Map<String, dynamic>;

    _playQueueTmp.addAll(_restoreQueue(json['playQueueTmp']));
    playQueue.addAll(_restoreQueue(json['playQueue']));
  }

  void _savePlayQueueState() {
    _playQueueState.writeAsStringSync(
      jsonEncode({
        'playQueueTmp': _playQueueTmp.map((e) => e.id).toList(),
        'playQueue': playQueue.map((e) => e.id).toList(),
      }),
    );
  }

  Future<void> loadPlayState() async {
    final content = await _playState.readAsString();
    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    currentIndex = json['currentIndex'] as int? ?? -1;
    playModeNotifier.value = json['playMode'] as int? ?? 0;
    _tmpPlayMode = json['tmpPlayMode'] as int? ?? 0;

    volumeNotifier.value = json['volume'] as double? ?? 0.3;

    if (!_started) {
      _started = true;
      if (autoPlayOnStartupNotifier.value) {
        if (playQueue.isEmpty) {
          currentIndex = 0;
          playQueue = List.from(library.songListManager.getSongList());
        }
        if (playQueue.isNotEmpty) {
          isPlayingNotifier.value = true;
        } else {
          currentIndex = -1;
        }
      }
    }

    if (currentIndex != -1 && playQueue.isNotEmpty) {
      // reload may make some songs not in the library to be removed
      if (currentIndex >= playQueue.length) {
        currentIndex = 0;
      }
      await load();
    }
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

  Future<void> loadEqualizerState() async {
    final content = await _equalizerState.readAsString();
    gains = (jsonDecode(content) as List<dynamic>).cast();
    applyEqualizer();
  }

  void saveEqualizerState() {
    _equalizerState.writeAsStringSync(jsonEncode(gains));
  }

  void saveAllStates() {
    audioHandler.savePlayState();
    audioHandler._savePlayQueueState();
  }

  bool insert2Next(MyAudioMetadata song) {
    int songIndex = playQueue.indexOf(song);
    if (songIndex != -1) {
      if (songIndex == currentIndex) {
        return false;
      }
      if (songIndex < currentIndex) {
        playQueue.removeAt(songIndex);
        playQueue.insert(currentIndex, song);
        currentIndex -= 1;
      } else {
        playQueue.removeAt(songIndex);
        playQueue.insert(currentIndex + 1, song);
      }
    } else {
      playQueue.insert(currentIndex + 1, song);
      if (playModeNotifier.value == 1 ||
          (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1)) {
        _playQueueTmp.add(song);
      }
    }
    return true;
  }

  bool add2Last(MyAudioMetadata song) {
    int songIndex = playQueue.indexOf(song);
    if (songIndex != -1) {
      if (songIndex == currentIndex) {
        return false;
      }
      if (songIndex < currentIndex) {
        currentIndex -= 1;
      }
      playQueue.removeAt(songIndex);
      playQueue.add(song);
    } else {
      playQueue.add(song);
      if (playModeNotifier.value == 1 ||
          (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1)) {
        _playQueueTmp.add(song);
      }
    }
    return true;
  }

  void singlePlay(MyAudioMetadata song) async {
    if (insert2Next(song)) {
      await skipToNext();
      play();
    }
  }

  Future<void> setPlayQueue(List<MyAudioMetadata> source) async {
    playQueue = List.from(source);
    if (playModeNotifier.value == 1 ||
        (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1)) {
      shuffle();
    }
    _savePlayQueueState();
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

  void changePlayMode(int newPlayMode) {
    if (newPlayMode == playModeNotifier.value) {
      return;
    }

    switch (newPlayMode) {
      case 0:
        if (_playQueueTmp.isNotEmpty) {
          playQueue = List.from(_playQueueTmp);
          _playQueueTmp = [];
          currentIndex = playQueue.indexOf(currentSongNotifier.value!);
          _savePlayQueueState();
        }
        break;
      case 1:
        if (_playQueueTmp.isEmpty) {
          shuffle();
          _savePlayQueueState();
        }
        break;
      default:
        break;
    }

    playModeNotifier.value = newPlayMode;

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
      _savePlayQueueState();
    } else if (playMode == 1) {
      shuffle();
      _savePlayQueueState();
    }
    savePlayState();
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
    _savePlayQueueState();
    savePlayState();
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
    isSyncing = true;
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
    isSyncing = false;
    _savePlayQueueState();
    savePlayState();
  }

  Future<void> _setLyricsAndUpdateColors(MyAudioMetadata song) async {
    await setParsedLyrics(song);
    currentCoverArtColor = await computeCoverArtColor(song);
    contrastColorTheme = ContrastColorGenerator.generate(currentCoverArtColor);
    if (lyricsPageThemeNotifier.value == .vivid) {
      colorManager.updateLyricsPageColors();
    }

    if (miniModeNotifier.value) {
      colorManager.updateMiniViewColors();
    }
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    final previousSong = currentSongNotifier.value;
    final previousNext = previousSong == null
        ? null
        : playQueue[(playQueue.indexOf(previousSong) + 1) % playQueue.length];
    if (previousSong != null) {
      if (_playLastSyncTime != null) {
        _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      }
      if (previousSong.duration != null) {
        double times =
            _playedDuration.inSeconds / previousSong.duration!.inSeconds;
        if (times > 0.5) {
          library.tryAddCache(previousSong);
          history.addSongTimes(previousSong, times.round());
        }
      }
    }
    _playLastSyncTime = null;
    _playedDuration = Duration.zero;

    // save currentIndex
    savePlayState();

    final currentSong = playQueue[currentIndex];

    await _setLyricsAndUpdateColors(currentSong);
    if (generation != _loadGeneration) {
      return;
    }
    _currentReplayGain = replayGainFor(
      currentSong,
      usbAudioPreferences.replayGainModeNotifier.value,
    );
    _superLyric.updateLines(currentSong.parsedLyrics!.lines);

    currentSongNotifier.value = currentSong;

    isLoading = true;
    try {
      await _stopExclusiveIntentionally();
      _usbExclusiveActive = false;
      _usbExclusivePosition = Duration.zero;
      if (previousSong != null && previousSong != currentSong) {
        library.cancelCacheDownload(previousSong);
      }
      if (previousNext != null && previousNext != currentSong) {
        library.cancelCacheDownload(previousNext);
      }

      final openedExclusive = await _tryOpenUsbExclusive(
        currentSong,
        generation: generation,
      );
      if (generation != _loadGeneration) {
        isLoading = false;
        return;
      }
      if (openedExclusive) {
        await _stopPlayerForUsbExclusive();
        if (isPlayingNotifier.value) {
          _playLastSyncTime = DateTime.now();
        }
      } else {
        await _applyUsbOutputForSong(currentSong);
        if (generation != _loadGeneration) {
          isLoading = false;
          return;
        }
        await _openPlayerMedia(currentSong);
      }

      if (isPlayingNotifier.value) {
        _playLastSyncTime = DateTime.now();
      }
    } catch (error) {
      _player.stop();
      logger.output("[${currentSong.title}] $error");
    }
    isLoading = false;

    updateServiceMediaItem(currentSong);

    if (isPlayingNotifier.value) {
      unawaited(_superLyric.publishAt(Duration.zero));
    } else {
      _superLyric.reset();
      unawaited(_superLyric.sendStop());
    }
    updatePlaybackState(postion: Duration.zero);
    _prefetchNextSongCache();
  }

  /// 独占模式连播优化：当前曲开播后预下载队列下一首云端歌曲，
  /// 自动切歌时下一首已整首缓存，可直接走独占。先等当前曲的缓存
  /// 下载完（tryAddCache 按路径去重，重复调用会合并），避免抢带宽。
  void _prefetchNextSongCache() {
    if (!Platform.isAndroid ||
        !usbAudioPreferences.performanceModeNotifier.value) {
      return;
    }
    if (playQueue.length < 2) {
      return;
    }
    final current = playQueue[currentIndex];
    final next = playQueue[(currentIndex + 1) % playQueue.length];
    final generation = _loadGeneration;
    if (next.sourceType == .local || next.cacheExist) {
      return;
    }
    unawaited(() async {
      try {
        await library.tryAddCache(current);
        if (generation != _loadGeneration ||
            currentSongNotifier.value != current) {
          return;
        }
        await library.tryAddCache(next);
        if (generation != _loadGeneration ||
            currentSongNotifier.value != current) {
          return;
        }
        logger.output("prefetched next song cache:${next.title}");
      } catch (error) {
        logger.output("prefetch next cache failed:$error");
      }
    }());
  }

  Future<bool> _tryOpenUsbExclusive(
    MyAudioMetadata song, {
    int? generation,
  }) async {
    if (!_shouldTryUsbExclusive(song)) {
      return false;
    }

    final isDsd = song.isDsd;
    if (isDsd &&
        usbAudioPreferences.dsdModeNotifier.value == UsbDsdMode.pcm) {
      // DSD 模式=PCM：由共享路径（mpv/libavcodec）解码转 PCM，不进独占直驱
      logger.output("usb exclusive skipped:dsd pcm mode -> shared output");
      debugPrint("usb exclusive skipped:dsd pcm mode -> shared output");
      return false;
    }

    final capability = await usbAudioService.getExclusiveCapabilities();
    var exclusiveCapability = capability;
    if (exclusiveCapability.available &&
        !exclusiveCapability.permissionGranted) {
      logger.output(
        "usb exclusive requesting permission:${exclusiveCapability.message}",
      );
      debugPrint(
        "usb exclusive requesting permission:${exclusiveCapability.message}",
      );
      await usbAudioService.probeExclusiveAccess();
      exclusiveCapability = await usbAudioService.getExclusiveCapabilities();
    }

    if (!exclusiveCapability.available ||
        !exclusiveCapability.permissionGranted) {
      logger.output("usb exclusive unavailable:${exclusiveCapability.message}");
      debugPrint("usb exclusive unavailable:${exclusiveCapability.message}");
      return false;
    }

    // DSD 走 DoP 时输出帧率由引擎按文件头计算（DSD 速率 ÷ 16），不做采样率白名单校验
    final exclusiveSampleRate = isDsd
        ? null
        : _preferredExclusiveSampleRate(song);
    if (!isDsd && exclusiveSampleRate == null) {
      // 源采样率无法在独占直驱下与 DAC 时钟对齐（没有 SRC），干净回退到系统输出而不是变调播放。
      logger.output(
        "usb exclusive fallback:unsupported source samplerate=${song.samplerate}",
      );
      debugPrint(
        "usb exclusive fallback:unsupported source samplerate=${song.samplerate}",
      );
      return false;
    }

    final filePath = await _exclusivePlayablePath(song, generation: generation);
    if (filePath == null) {
      return false;
    }
    // .part 表示缓存还在下载中，走流式独占（引擎按增长中的文件读取）
    final streaming = filePath.endsWith('.part');

    if (generation != null && generation != _loadGeneration) {
      // 权限弹窗/路径解析期间用户已切到别的歌，放弃启动独占
      return false;
    }

    final state = await usbAudioService.startExclusivePlayback(
      UsbExclusivePlaybackRequest(
        playbackId: 'load-${generation ?? _loadGeneration}',
        filePath: filePath,
        title: getTitle(song),
        sourceFormat: _normalizedExclusiveFormat(song),
        sampleRate: exclusiveSampleRate,
        bitDepth: isDsd ? null : _preferredExclusiveBitDepth(),
        dsdMode: isDsd ? usbAudioPreferences.dsdModeNotifier.value.name : null,
        volumeGain: usbExclusiveDigitalVolumeGain(volumeNotifier.value),
        replayGainDb: _effectiveReplayGainDb(
          usbExclusiveDigitalVolumeGain(volumeNotifier.value),
        ),
        volumeMode: usbAudioPreferences.volumeControlModeNotifier.value.name,
        dsdGainCompensationDb:
            usbAudioPreferences.dsdGainCompensationNotifier.value,
        smoothVolumeHandoff:
            usbAudioPreferences.volumeSmoothHandoffNotifier.value,
        targetBufferMs: _exclusiveTargetBufferMsForLifecycle(
          WidgetsBinding.instance.lifecycleState,
        ),
        startPaused: !isPlayingNotifier.value,
        streaming: streaming,
        totalBytes: streaming ? _estimateStreamTotalBytes(song) : null,
      ),
    );

    if (!state.active) {
      logger.output("usb exclusive fallback:${state.message}");
      debugPrint("usb exclusive fallback:${state.message}");
      return false;
    }

    _usbExclusiveActive = true;
    _usbExclusivePosition = state.position;
    updateIsPlaying(state.playing);
    updatePlaybackState(postion: state.position);
    debugPrint(
      "usb exclusive opened: active=${state.active}, playing=${state.playing}, position=${state.position.inMilliseconds}",
    );
    return true;
  }

  bool _shouldTryUsbExclusive(MyAudioMetadata song) {
    if (!Platform.isAndroid) {
      logger.output("usb exclusive skipped:not android");
      debugPrint("usb exclusive skipped:not android");
      return false;
    }
    if (!usbAudioPreferences.performanceModeNotifier.value) {
      logger.output("usb exclusive skipped:performance mode off");
      debugPrint("usb exclusive skipped:performance mode off");
      return false;
    }
    return true;
  }

  String? _normalizedExclusiveFormat(MyAudioMetadata song) {
    final format = song.format?.toLowerCase().trim();
    if (format != null && format.isNotEmpty) {
      if (format.contains('flac')) return 'flac';
      if (format.contains('wav') || format.contains('wave')) return 'wav';
      if (format.contains('dsf')) return 'dsf';
      if (format.contains('dff')) return 'dff';
      return format;
    }

    final path = (song.path ?? song.cachePath ?? '').toLowerCase();
    if (path.endsWith('.flac')) return 'flac';
    if (path.endsWith('.wav') || path.endsWith('.wave')) return 'wav';
    if (path.endsWith('.dsf')) return 'dsf';
    if (path.endsWith('.dff')) return 'dff';
    return null;
  }

  /// 流式独占的完整文件字节数估算：时长 × 码率，再放大保证 ≥ 真实大小，
  /// 让引擎侧 MediaExtractor 能对增长中的 .part 正确 seek（真实边界由 readAt
  /// 按当前 .part 长度兜底等待）。时长未知时返回 null（引擎回退旧行为）。
  int? _estimateStreamTotalBytes(MyAudioMetadata song) {
    final durationSec = song.duration?.inSeconds ?? 0;
    if (durationSec <= 0) {
      return null;
    }
    final bytesPerSecond =
        ((song.bitrate ?? 0) > 0 ? song.bitrate! : 2000) * 1000 ~/ 8;
    return (durationSec * bytesPerSecond * 1.2).toInt();
  }

  Future<String?> _exclusivePlayablePath(
    MyAudioMetadata song, {
    int? generation,
  }) async {
    if (song.sourceType == .local && song.path != null) {
      return await convertToRealPathIfNeed(song.path!) ?? song.path;
    }

    if (song.cacheExist && song.cachePath != null) {
      return song.cachePath;
    }

    // 云端歌曲未缓存：后台下载缓存，短暂等到够起播的水位就用 .part
    // 文件流式独占；等不到则回退共享流式立即出声，不阻塞整首下载
    unawaited(
      library.tryAddCache(song).catchError((Object error) {
        logger.output("usb exclusive cache failed:$error");
      }),
    );

    // 能边下边播（流式独占）的格式：无损/DSD + 系统可流式解码的常见有损容器。
    // wv/ape 等系统无解码器的不在此列，未缓存时先走共享出声，缓存完成后再走独占。
    // 与原生 UsbExclusiveAudioEngine.streamableLossyExts 保持一致。
    const streamableExts = {
      'flac', 'wav', 'wave', 'dsf', 'dff',
      'mp3', 'm4a', 'm4b', 'mp4', 'aac', 'ogg', 'oga', 'opus',
    };
    final ext = _normalizedExclusiveFormat(song)?.toLowerCase();
    if (!streamableExts.contains(ext)) {
      // 独占无法流式的格式，没必要等水位
      return null;
    }

    final partPath = '${song.cachePath!}.part';
    // 起播水位：约 10 秒的数据量（码率未知按 2 Mbps 估算）
    final bytesPerSecond =
        ((song.bitrate ?? 0) > 0 ? song.bitrate! : 2000) * 1000 ~/ 8;
    final startBytes = bytesPerSecond * 10;
    var lastSize = -1;
    while (true) {
      if (generation != null && generation != _loadGeneration) {
        return null;
      }
      if (song.cacheExist && song.cachePath != null) {
        return song.cachePath; // 等待期间下载已完成
      }
      final part = File(partPath);
      final size = part.existsSync() ? part.lengthSync() : 0;
      // 水位够且下载速度跟得上播放（一轮 200ms 内至少推进等量数据）才起播；
      // 必须有一次真实的增量测量，避免把上次中断的 .part 残留当成有效水位
      if (lastSize >= 0 &&
          size >= startBytes &&
          size - lastSize >= bytesPerSecond ~/ 5) {
        logger.output(
          "usb exclusive streaming start:part=$size bytes, watermark=$startBytes",
        );
        debugPrint(
          "usb exclusive streaming start:part=$size bytes, watermark=$startBytes",
        );
        return partPath;
      }
      lastSize = size;
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  int? _preferredExclusiveBitDepth() {
    return preferredUsbExclusiveBitDepth();
  }

  int? _preferredExclusiveSampleRate(MyAudioMetadata song) {
    // 真独占按源采样率打包并直驱 DAC，输出时钟必须等于源采样率，否则会变调 + 持续欠载。
    // 因此忽略“固定采样率”偏好（那是给系统共享链路用的），只有源采样率本身可用时才允许独占。
    final source = song.samplerate;
    if (source == null || source <= 0) {
      return null;
    }
    return UsbAudioPreferences.sampleRates.contains(source) ? source : null;
  }

  Future<void> _applyUsbOutputForSong(MyAudioMetadata song) async {
    // 不再用独占开关门控：独占关闭时也请求系统 Preferred Mixer 无损输出（单纯用 DAC 无损）。
    // 设备不支持无损时原生侧自然 no-op（preferredApplied=false，胶囊点显白）。
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final status = await usbAudioService.refreshStatus();
      final sampleRate = _preferredSystemUsbSampleRate(status, song);
      logger.output(
        "usb output apply song samplerate=${song.samplerate}, request=$sampleRate",
      );
      debugPrint(
        "usb output apply song samplerate=${song.samplerate}, request=$sampleRate",
      );
      await usbAudioService.applyPreferredOutput(
        deviceId: status.bestAvailableDeviceId,
        sampleRate: sampleRate,
        encoding: usbAudioPreferences.preferredEncoding(),
      );
    } catch (error) {
      logger.output("usb output apply failed:$error");
      debugPrint("usb output apply failed:$error");
    }
  }

  int? _dsdPcmTargetRate(MyAudioMetadata song) {
    return switch (song.dsdMultiple) {
      64 => usbAudioPreferences.dsd64PcmRateNotifier.value,
      128 => usbAudioPreferences.dsd128PcmRateNotifier.value,
      256 => usbAudioPreferences.dsd256PcmRateNotifier.value,
      512 => usbAudioPreferences.dsd512PcmRateNotifier.value,
      _ => null,
    };
  }

  int? _matchedSafeSampleRate(int? sourceSampleRate) {
    if (sourceSampleRate == null || sourceSampleRate <= 0) {
      return null;
    }

    final supportedRates = UsbAudioPreferences.sampleRates;
    if (supportedRates.contains(sourceSampleRate)) {
      return sourceSampleRate;
    }

    final sameFamilyRates =
        supportedRates.where((rate) => sourceSampleRate % rate == 0).toList()
          ..sort();
    if (sameFamilyRates.isNotEmpty) {
      return sameFamilyRates.last;
    }

    return supportedRates
        .where((rate) => rate <= sourceSampleRate)
        .fold<int?>(
          null,
          (best, rate) => best == null || rate > best ? rate : best,
        );
  }

  int? _preferredSystemUsbSampleRate(
    UsbAudioStatus status,
    MyAudioMetadata song,
  ) {
    // DSD 转 PCM 走共享输出时，按 DSD 倍率对应的偏好请求目标输出率
    //（这是"目标输出率请求"，精确转换由解码器/系统混音器完成）
    final dsdPcmRate = _dsdPcmTargetRate(song);
    if (dsdPcmRate != null && _statusSupportsSampleRate(status, dsdPcmRate)) {
      return dsdPcmRate;
    }

    final fixedRate = usbAudioPreferences.preferredFixedSampleRate();
    if (fixedRate != null) {
      return fixedRate;
    }

    final matchedSourceRate = _matchedSafeSampleRate(song.samplerate);
    if (matchedSourceRate != null &&
        _statusSupportsSampleRate(status, matchedSourceRate)) {
      return matchedSourceRate;
    }
    return _bestSystemUsbSampleRate(status);
  }

  bool _statusSupportsSampleRate(UsbAudioStatus status, int sampleRate) {
    final deviceId = status.bestAvailableDeviceId;
    for (final device in status.devices) {
      if (device.id != deviceId) {
        continue;
      }
      final rates = device.supportedMixerSampleRates.isNotEmpty
          ? device.supportedMixerSampleRates
          : device.sampleRates;
      return rates.contains(sampleRate);
    }
    return false;
  }

  int? _bestSystemUsbSampleRate(UsbAudioStatus status) {
    final deviceId = status.bestAvailableDeviceId;
    for (final device in status.devices) {
      if (device.id != deviceId) {
        continue;
      }
      final rates = device.supportedMixerSampleRates.isNotEmpty
          ? device.supportedMixerSampleRates
          : device.sampleRates;
      final validRates =
          rates.where(UsbAudioPreferences.sampleRates.contains).toList()
            ..sort();
      return validRates.isEmpty
          ? status.bestAvailableSampleRate
          : validRates.last;
    }
    return status.bestAvailableSampleRate;
  }

  void updateServiceMediaItem(MyAudioMetadata currentSong) {
    Uri? artUri;

    if (currentSong.pictureExist) {
      artUri = File(currentSong.picturePath).uri;
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
    if (_usbExclusiveActive) {
      debugPrint(
        "usb exclusive resume requested: playing=${isPlayingNotifier.value}, position=${_usbExclusivePosition.inMilliseconds}",
      );
      final state = await usbAudioService.resumeExclusivePlayback();
      debugPrint(
        "usb exclusive resume result: active=${state.active}, playing=${state.playing}, position=${state.position.inMilliseconds}, message=${state.message}",
      );
      updateIsPlaying(state.playing);
      unawaited(_superLyric.publishAt(state.position));
      updatePlaybackState(postion: state.position);
      return;
    }

    final currentSong = playQueue[currentIndex];
    updateIsPlaying(true);
    final openedExclusive = await _tryOpenUsbExclusive(currentSong);
    if (openedExclusive) {
      await _stopPlayerForUsbExclusive();
      unawaited(_superLyric.publishAt(_usbExclusivePosition));
      updatePlaybackState(postion: _usbExclusivePosition);
      return;
    }

    await _applyUsbOutputForSong(currentSong);
    _player.play();

    unawaited(_superLyric.publishAt(_player.state.position));
    updatePlaybackState();
  }

  @override
  Future<void> pause() async {
    debugPrint(
      "audio handler pause requested: usbExclusiveActive=$_usbExclusiveActive, playing=${isPlayingNotifier.value}",
    );
    if (_usbExclusiveActive) {
      final state = await usbAudioService.pauseExclusivePlayback();
      unawaited(_superLyric.sendStop());
      _superLyric.reset();
      updateIsPlaying(state.playing);
      updatePlaybackState(postion: state.position);
      return;
    }

    _player.pause();
    unawaited(_superLyric.sendStop());
    _superLyric.reset();
    updateIsPlaying(false);
    updatePlaybackState();
  }

  @override
  Future<void> stop() async {
    if (_usbExclusiveActive) {
      await _stopExclusiveIntentionally();
      _usbExclusiveActive = false;
      _usbExclusivePosition = Duration.zero;
    }

    _player.stop();
    unawaited(_superLyric.sendStop());
    _superLyric.reset();
    updateIsPlaying(false);
    updatePlaybackState(stop: true);
  }

  @override
  Future<void> seek(Duration position) async {
    updatePlaybackState(postion: position);
    if (_usbExclusiveActive) {
      final state = await usbAudioService.seekExclusivePlayback(position);
      if (isPlayingNotifier.value) {
        unawaited(_superLyric.publishAt(state.position));
      }
      updateLyricsNotifier.value++;
      updatePlaybackState(postion: state.position);
      return;
    }

    await _player.seek(position);
    // ensure position is updated
    await Future.delayed(Duration(milliseconds: 50));
    if (isPlayingNotifier.value) {
      unawaited(_superLyric.publishAt(position));
    }
    updateLyricsNotifier.value++;
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
    return _positionController.stream;
  }

  Duration getPosition() {
    return _usbExclusiveActive ? _usbExclusivePosition : _player.state.position;
  }

  void setVolume(double volume) {
    final perceptualGain = _perceptualVolumeGain(volume);
    _player.setVolume(perceptualGain * 100);
    if (_usbExclusiveActive) {
      _applyUsbExclusiveVolume(usbExclusiveDigitalVolumeGain(volume));
    } else {
      unawaited(_applySharedReplayGain(perceptualGain));
    }
    _publishAndroidPlaybackInfo();
  }

  void _publishAndroidPlaybackInfo() {
    androidPlaybackInfo.add(
      androidPlaybackInfoFor(
        usbExclusivePlaybackStateNotifier.value,
        volumeNotifier.value,
      ),
    );
  }

  void _setUserVolume(double volume) {
    final next = volume.clamp(0.0, 1.0).toDouble();
    volumeNotifier.value = next;
    setVolume(next);
    savePlayState();
    usbVolumeOverlayNotifier.value += 1;
  }

  @override
  Future<void> androidAdjustRemoteVolume(
    AndroidVolumeDirection direction,
  ) async {
    if (!shouldUseRemoteAndroidVolume(
      usbExclusivePlaybackStateNotifier.value,
    )) {
      return;
    }
    _setUserVolume(adjustedRemoteVolume(volumeNotifier.value, direction));
  }

  @override
  Future<void> androidSetRemoteVolume(int volumeIndex) async {
    if (!shouldUseRemoteAndroidVolume(
      usbExclusivePlaybackStateNotifier.value,
    )) {
      return;
    }
    _setUserVolume(absoluteRemoteVolume(volumeIndex));
  }

  // 与共享输出一致的感知音量曲线，返回 0..1 的线性幅度。
  double _perceptualVolumeGain(double volume) {
    return math.log(volume * 9 + 1) / math.log(10);
  }

  double _effectiveReplayGainDb(double userLinearGain) {
    return replayGainWithinOutputHeadroom(
      _currentReplayGain.gainDb,
      userLinearGain,
    );
  }

  Future<void> _applySharedReplayGain(double userLinearGain) async {
    final gainDb = _effectiveReplayGainDb(userLinearGain);
    try {
      await (_player.platform as NativePlayer).setProperty(
        'volume-gain',
        gainDb.toStringAsFixed(3),
      );
    } on Object catch (error) {
      logger.output("replay gain apply failed:$error");
    }
  }

  // 把当前音量与控制模式下发给 USB 独占引擎，由原生层选择硬件音量或安全回退。
  void _applyUsbExclusiveVolume(double digitalGain) {
    if (!_usbExclusiveActive) {
      return;
    }
    unawaited(
      usbAudioService.setExclusiveVolume(
        gain: digitalGain,
        replayGainDb: _effectiveReplayGainDb(digitalGain),
        mode: usbAudioPreferences.volumeControlModeNotifier.value.name,
        dsdGainCompensationDb:
            usbAudioPreferences.dsdGainCompensationNotifier.value,
        smoothHandoff: usbAudioPreferences.volumeSmoothHandoffNotifier.value,
      ),
    );
  }

  int _lastVolumeKeyValue = 0;

  void _handleUsbHardwareVolume() {
    final event = usbHardwareVolumeNotifier.value;
    final state = usbExclusivePlaybackStateNotifier.value;
    if (!_usbExclusiveActive ||
        !state.active ||
        event == null ||
        event.playbackId != state.playbackId ||
        event.protocol != state.hardwareVolumeProtocol) {
      return;
    }
    final volume = usbUserVolumeFromHardwareGain(
      event.gainQ16,
      event.replayGainMilliDb / 1000,
      event.isDsd ? event.dsdGainCompensationDb : 0,
    );
    if ((volumeNotifier.value - volume).abs() > 0.000001) {
      volumeNotifier.value = volume;
      _player.setVolume(_perceptualVolumeGain(volume) * 100);
      savePlayState();
    }
    _publishAndroidPlaybackInfo();
    usbVolumeOverlayNotifier.value += 1;
  }

  // 独占模式下安卓物理音量键：按累计方向差值增减音量，再走 setVolume 下发数字音量。
  void _handleUsbExclusiveVolumeKey() {
    final value = usbExclusiveVolumeKeyNotifier.value;
    final delta = value - _lastVolumeKeyValue;
    _lastVolumeKeyValue = value;
    if (delta == 0 || !_usbExclusiveActive) {
      return;
    }
    const step = 0.02; // 每按一次 2%
    final next = (volumeNotifier.value + delta * step).clamp(0.0, 1.0);
    _setUserVolume(next);
  }

  void applyEqualizer() async {
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
