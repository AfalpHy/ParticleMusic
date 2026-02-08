import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:media_kit/media_kit.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/extensions/window_controller_extension.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/my_audio_metadata.dart';
import 'package:particle_music/utils.dart';
import 'dart:async';

late AudioSession _session;

Future<void> initAudioService() async {
  MediaKit.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),

    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.afalphy.particle_music',
      androidNotificationChannelName: 'Particle Music',
      androidNotificationOngoing: true,
    ),
  );
  _session = await AudioSession.instance;
  await _session.configure(AudioSessionConfiguration.music());

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
  int currentIndex = -1;
  List<MyAudioMetadata> _playQueueTmp = [];
  int _tmpPlayMode = 0;
  DateTime? _playLastSyncTime;
  Duration _playedDuration = Duration.zero;

  late final File _playQueueState;
  late final File _playState;

  MyAudioHandler() {
    _player.stream.completed.listen((completed) async {
      if (completed) {
        bool needPauseTmp = needPause;

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
      if (!isMobile) {
        panelManager.updateBackground();
      }
    });

    _player.stream.position.listen((position) {
      final currentSong = currentSongNotifier.value;
      if (currentSong == null) {
        return;
      }
      ParsedLyrics parsedLyrics = currentSong.parsedLyrics!;

      List<LyricLine> lyrics = parsedLyrics.lyrics;

      int current = 0;

      for (int i = 0; i < lyrics.length; i++) {
        final line = lyrics[i];
        if (position < line.start) {
          break;
        }
        if (line.start > lyrics[current].start) {
          current = i;
        }
      }

      final tmpLyricLine = currentLyricLine;

      currentLyricLine = lyrics[current];
      currentLyricLineIsKaraoke = parsedLyrics.isKaraoke;

      if ((showDesktopLrcOnAndroidNotifier.value || lyricsWindowVisible) &&
          currentLyricLine != tmpLyricLine) {
        updateDesktopLyrics();
      }
    });
  }

  void updateIsPlaying(bool isPlaying) {
    if (isPlaying) {
      if (_playedDuration == Duration.zero) {
        historyManager.add2Recently(currentSongNotifier.value!);
      }
      _playLastSyncTime = DateTime.now();
    } else if (_playLastSyncTime != null) {
      _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      _playLastSyncTime = null;
    }
    needPause = false;
    isPlayingNotifier.value = isPlaying;

    lyricsWindowController?.sendPlaying(isPlaying);
    if (showDesktopLrcOnAndroidNotifier.value) {
      FlutterOverlayWindow.shareData(isPlaying);
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

  void initStateFiles() {
    _playQueueState = File("${appSupportDir.path}/play_queue_state.txt");
    if (!(_playQueueState.existsSync())) {
      savePlayQueueState();
    }
    _playState = File("${appSupportDir.path}/play_state.txt");
    if (!(_playState.existsSync())) {
      savePlayState();
    }
  }

  Future<void> loadPlayQueueState() async {
    final content = await _playQueueState.readAsString();

    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    List<String> tmp =
        (json['playQueueTmp'] as List<dynamic>?)?.cast<String>() ?? [];
    for (final path in tmp) {
      MyAudioMetadata? song;
      song = filePath2LibrarySong[path];
      if (song != null) {
        _playQueueTmp.add(song);
      }
    }

    tmp = (json['playQueue'] as List<dynamic>?)?.cast<String>() ?? [];
    for (final path in tmp) {
      MyAudioMetadata? song;
      song = filePath2LibrarySong[path];
      if (song != null) {
        playQueue.add(song);
      }
    }
  }

  void savePlayQueueState() {
    _playQueueState.writeAsStringSync(
      jsonEncode({
        'playQueueTmp': _playQueueTmp
            .map((e) => clipFilePathIfNeed(e.filePath))
            .toList(),
        'playQueue': playQueue
            .map((e) => clipFilePathIfNeed(e.filePath))
            .toList(),
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

  bool insert2Next(int index, List<MyAudioMetadata> source) {
    final tmp = source[index];
    int tmpIndex = playQueue.indexOf(tmp);
    if (tmpIndex != -1) {
      if (tmpIndex == currentIndex) {
        return false;
      }
      if (tmpIndex < currentIndex) {
        playQueue.removeAt(tmpIndex);
        playQueue.insert(currentIndex, tmp);
        currentIndex -= 1;
      } else {
        playQueue.removeAt(tmpIndex);
        playQueue.insert(currentIndex + 1, tmp);
      }
    } else {
      playQueue.insert(currentIndex + 1, tmp);
      if (_playQueueTmp.isNotEmpty) {
        _playQueueTmp.add(tmp);
      }
    }
    savePlayQueueState();
    return true;
  }

  void singlePlay(int index, List<MyAudioMetadata> source) async {
    if (insert2Next(index, source)) {
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
    savePlayQueueState();
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

  void switchPlayMode() {
    int playMode = playModeNotifier.value;
    playMode += 1;
    playMode %= 2;
    playModeNotifier.value = playMode;
    if (playMode == 0) {
      playQueue = List.from(_playQueueTmp);
      _playQueueTmp = [];
      currentIndex = playQueue.indexOf(currentSongNotifier.value!);
      savePlayQueueState();
    } else if (playMode == 1) {
      shuffle();
      savePlayQueueState();
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
    savePlayQueueState();
  }

  Future<void> clear() async {
    stop();
    playQueue = [];
    _playQueueTmp = [];
    currentLyricLine = null;
    if (!isMobile) {
      await updateDesktopLyrics();
    }
    currentIndex = -1;
    currentSongNotifier.value = null;
    currentCoverArtColor = Colors.grey;
    savePlayQueueState();
    savePlayState();
  }

  Future<void> clearForReload() async {
    stop();
    playQueue = [];
    _playQueueTmp = [];
    currentLyricLine = null;
    if (!isMobile) {
      await updateDesktopLyrics();
    }
    currentSongNotifier.value = null;
    currentCoverArtColor = Colors.grey;
  }

  Future<void> load() async {
    if (currentSongNotifier.value != null) {
      if (_playLastSyncTime != null) {
        _playedDuration += DateTime.now().difference(_playLastSyncTime!);
      }
      if (currentSongNotifier.value!.duration != null) {
        double times =
            _playedDuration.inSeconds /
            currentSongNotifier.value!.duration!.inSeconds;
        if (times > 0.5) {
          historyManager.addSongTimes(
            currentSongNotifier.value!,
            times.round(),
          );
        }
      }

      _playLastSyncTime = null;
    }

    // save currentIndex
    savePlayState();

    final currentSong = playQueue[currentIndex];

    await setParsedLyrics(currentSong);
    currentCoverArtColor = await computeCoverArtColor(currentSong);

    currentSongNotifier.value = currentSong;
    if (isPlayingNotifier.value) {
      historyManager.add2Recently(currentSong);
    }

    Uri? artUri;
    if (currentSong.picturePath != null) {
      artUri = Uri.file(currentSong.picturePath!);
    }

    try {
      await _player.open(
        Media(currentSong.filePath),
        play: isPlayingNotifier.value,
      );
    } catch (error) {
      logger.output("[${currentSong.filePath}] $error");
    }

    if (isPlayingNotifier.value) {
      _playLastSyncTime = DateTime.now();
    }
    _playedDuration = Duration.zero;

    mediaItem.add(
      MediaItem(
        id: currentSong.filePath,
        title: getTitle(currentSong),
        artist: getArtist(currentSong),
        album: getAlbum(currentSong),
        artUri: artUri, // file:// URI
        duration: currentSong.duration,
      ),
    );
    updatePlaybackState();
  }

  @override
  Future<void> play() async {
    if (playQueue.isEmpty) return;
    _player.play();

    updateIsPlaying(true);
    updatePlaybackState();
  }

  @override
  Future<void> pause() async {
    _player.pause();
    updateIsPlaying(false);
    updatePlaybackState();
  }

  @override
  Future<void> stop() async {
    _player.stop();
    updateIsPlaying(false);
    updatePlaybackState(stop: true);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    updatePlaybackState(postion: position);
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
    return _player.stream.position;
  }

  Duration getPosition() {
    return _player.state.position;
  }

  void setVolume(double volume) {
    _player.setVolume(volume * 100);
  }
}
