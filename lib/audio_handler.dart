import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/desktop/extensions/window_controller_extension.dart';
import 'package:particle_music/desktop/pages/main_page.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/lyrics.dart';
import 'package:particle_music/setting.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:flutter/services.dart';

late MyAudioHandler audioHandler;

List<AudioMetadata> playQueue = [];

Color currentCoverArtColor = Colors.grey;

final ValueNotifier<AudioMetadata?> currentSongNotifier = ValueNotifier(null);
final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
final ValueNotifier<int> playModeNotifier = ValueNotifier(0);
final ValueNotifier<double> volumeNotifier = ValueNotifier(0.3);

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  int currentIndex = -1;
  List<AudioMetadata> _playQueueTmp = [];
  int _tmpPlayMode = 0;
  bool isloading = false;

  late final File _playQueueState;
  late final File _playState;

  MyAudioHandler() {
    _player.playbackEventStream.map(transformEvent).pipe(playbackState);

    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
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

    _player.playingStream.listen((isPlaying) {
      needPause = false;
      isPlayingNotifier.value = isPlaying;
      lyricsWindowController?.sendPlaying(isPlaying);
    });

    currentSongNotifier.addListener(() {
      needPause = false;
      if (!isMobile) {
        for (int i = 0; i < panelManager.backgroundSongStack.length; i++) {
          if (panelManager.bgColorUseCurrentSongStack[i]) {
            panelManager.backgroundSongStack[i] = currentSongNotifier.value;
          }
        }
        if (panelManager.bgColorUseCurrentSongStack.isNotEmpty &&
            panelManager.bgColorUseCurrentSongStack.last) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            backgroundSong = currentSongNotifier.value;
            backgroundColor = currentCoverArtColor;
            updateBackgroundNotifier.value++;
          });
        }
      }
    });
  }

  PlaybackState transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: {MediaAction.seek},
      playing: _player.playing,
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[event.processingState]!,
      speed: _player.playing ? 1 : 0,
      updatePosition: event.updatePosition,
      bufferedPosition: event.bufferedPosition,
    );
  }

  void initStateFiles(String supportPath) {
    _playQueueState = File("$supportPath/playQueueState.txt");
    if (!(_playQueueState.existsSync())) {
      savePlayQueueState();
    }
    _playState = File("$supportPath/playState.txt");
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
      AudioMetadata? song;
      song = filePath2LibrarySong[path];
      if (song != null) {
        _playQueueTmp.add(song);
      }
    }

    tmp = (json['playQueue'] as List<dynamic>?)?.cast<String>() ?? [];
    for (final path in tmp) {
      AudioMetadata? song;
      song = filePath2LibrarySong[path];
      if (song != null) {
        playQueue.add(song);
      }
    }
  }

  void savePlayQueueState() {
    if (Platform.isIOS) {
      int prefixLength = appDocs.path.length;
      _playQueueState.writeAsStringSync(
        jsonEncode({
          'playQueueTmp': _playQueueTmp
              .map((s) => s.file.path.substring(prefixLength))
              .toList(),
          'playQueue': playQueue
              .map((s) => s.file.path.substring(prefixLength))
              .toList(),
        }),
      );
    } else {
      _playQueueState.writeAsStringSync(
        jsonEncode({
          'playQueueTmp': _playQueueTmp.map((s) => s.file.path).toList(),
          'playQueue': playQueue.map((s) => s.file.path).toList(),
        }),
      );
    }
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

  bool insert2Next(int index, List<AudioMetadata> source) {
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

  void singlePlay(int index, List<AudioMetadata> source) async {
    if (insert2Next(index, source)) {
      await skipToNext();
      play();
    }
  }

  Future<void> setPlayQueue(List<AudioMetadata> source) async {
    playQueue = List.from(source);
    if (playModeNotifier.value == 1 ||
        (playModeNotifier.value == 2 && audioHandler._tmpPlayMode == 1)) {
      shuffle();
    }
    savePlayQueueState();
    await load();
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
    AudioMetadata tmp = playQueue[index];
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
    lyrics = [];
    currentLyricLine = null;
    if (!isMobile) {
      await updateDesktopLyrics();
    }
    currentIndex = -1;
    currentSongNotifier.value = null;
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
  }

  Future<Uri> saveAlbumCover(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    String filePath = '${dir.path}/particle_music_cover';
    // must use different file path to update cover, it's weird on linux
    if (Platform.isLinux) {
      filePath += '${bytes.length}';
    }
    final file = File(filePath);

    await file.writeAsBytes(bytes);
    return file.uri;
  }

  Future<void> load() async {
    if (isloading) {
      return;
    }
    if (currentIndex < 0 || currentIndex >= playQueue.length) return;
    isloading = true;

    // save currentIndex
    savePlayState();

    final currentSong = playQueue[currentIndex];

    await parseLyricsFile(currentSong);

    currentCoverArtColor = computeCoverArtColor(currentSong);

    currentSongNotifier.value = currentSong;

    Uri? artUri;
    if (currentSong.pictures.isNotEmpty) {
      artUri = await saveAlbumCover(currentSong.pictures.first.bytes);
    }

    mediaItem.add(
      MediaItem(
        id: currentSong.file.path,
        title: getTitle(currentSong),
        artist: getArtist(currentSong),
        album: getAlbum(currentSong),
        artUri: artUri, // file:// URI
        duration: currentSong.duration,
      ),
    );

    final audioSource = ProgressiveAudioSource(
      Uri.file(currentSongNotifier.value!.file.path),
      options: ProgressiveAudioSourceOptions(
        darwinAssetOptions: DarwinAssetOptions(
          preferPreciseDurationAndTiming: true,
        ),
      ),
    );

    await _player.setAudioSource(audioSource);

    isloading = false;
  }

  @override
  Future<void> play() async {
    if (playQueue.isEmpty) return;
    await _player.play();
  }

  @override
  Future<void> pause() async => await _player.pause();

  @override
  Future<void> stop() async => await _player.stop();

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    updateLyricsNotifier.value++;
    updateDesktopLyrics();
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

  Future<void> togglePlay() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Stream<Duration> getPositionStream() {
    return _player.positionStream;
  }

  Duration getPosition() {
    return _player.position;
  }

  void setVolume(double volume) {
    _player.setVolume(volume);
  }
}
