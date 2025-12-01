import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:audio_service/audio_service.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/lyrics.dart';
import 'package:particle_music/setting.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:image/image.dart' as image;
import 'package:flutter/services.dart';

late MyAudioHandler audioHandler;

List<AudioMetadata> playQueue = [];

Color coverArtAverageColor = Colors.grey;
Color coverArtFilterColor = coverArtAverageColor.withAlpha(160);

ValueNotifier<AudioMetadata?> currentSongNotifier = ValueNotifier(null);
ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
ValueNotifier<int> playModeNotifier = ValueNotifier(0);
late final ValueNotifier<double> volumeNotifier;

abstract class MyAudioHandler extends BaseAudioHandler {
  int currentIndex = -1;
  List<AudioMetadata> playQueueTmp = [];
  int tmpPlayMode = 0;
  bool isloading = false;

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
      if (playQueueTmp.isNotEmpty) {
        playQueueTmp.add(tmp);
      }
    }
    return true;
  }

  void singlePlay(int index, List<AudioMetadata> source) async {
    if (insert2Next(index, source)) {
      await skipToNext();
      play();
    }
  }

  void shuffle() {
    if (playQueue.isEmpty) {
      return;
    }
    playQueueTmp = List.from(playQueue);
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
      playQueue = List.from(playQueueTmp);
      playQueueTmp = [];
      currentIndex = playQueue.indexOf(currentSongNotifier.value!);
    } else if (playMode == 1) {
      shuffle();
    }
  }

  void toggleRepeat() {
    if (playModeNotifier.value != 2) {
      tmpPlayMode = playModeNotifier.value;
      playModeNotifier.value = 2;
    } else {
      playModeNotifier.value = tmpPlayMode;
    }
  }

  void delete(int index) {
    AudioMetadata tmp = playQueue[index];
    if (playQueueTmp.isNotEmpty) {
      playQueueTmp.remove(tmp);
    }
    playQueue.removeAt(index);
  }

  void clear() {
    stop();
    playQueue = [];
    playQueueTmp = [];
    lyrics = [];
    currentIndex = -1;
    coverArtAverageColor = Colors.grey;
    coverArtFilterColor = coverArtAverageColor.withAlpha(160);
    currentSongNotifier.value = null;
  }

  void computeCoverArtColors(AudioMetadata currentSong) {
    coverArtAverageColor = Colors.grey;
    coverArtFilterColor = coverArtAverageColor.withAlpha(160);

    if (currentSong.pictures.isEmpty) return;

    final bytes = currentSong.pictures.first.bytes;

    final decoded = image.decodeImage(bytes);
    if (decoded == null) return;

    // simple average of top pixels
    double r = 0, g = 0, b = 0, count = 0;
    for (int y = 0; y < decoded.height; y += 5) {
      for (int x = 0; x < decoded.width; x += 5) {
        final pixel = decoded.getPixel(x, y);

        r += pixel.r.toDouble();
        g += pixel.g.toDouble();
        b += pixel.b.toDouble();
        count++;
      }
    }
    r /= count;
    g /= count;
    b /= count;
    int luminance = image.getLuminanceRgb(r, g, b).toInt();
    int minLuminace = 50;
    int maxLuminace = 200;
    if (luminance < minLuminace) {
      r += minLuminace - luminance;
      g += minLuminace - luminance;
      b += minLuminace - luminance;
      coverArtAverageColor = Color.fromARGB(
        255,
        r.toInt(),
        g.toInt(),
        b.toInt(),
      );
      // make coverArtFilterColor more brighter
      if (isMobile) {
        r += 25;
        g += 25;
        b += 25;
      }
    } else if (luminance > maxLuminace) {
      r -= luminance - maxLuminace;
      g -= luminance - maxLuminace;
      b -= luminance - maxLuminace;
      coverArtAverageColor = Color.fromARGB(
        255,
        r.toInt(),
        g.toInt(),
        b.toInt(),
      );
    } else {
      coverArtAverageColor = Color.fromARGB(
        255,
        r.toInt(),
        g.toInt(),
        b.toInt(),
      );
    }
    coverArtFilterColor = coverArtAverageColor.withAlpha(160);
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
    if (currentIndex < 0 || currentIndex >= playQueue.length) return;

    final currentSong = playQueue[currentIndex];

    await parseLyricsFile(currentSong);

    computeCoverArtColors(currentSong);

    currentSongNotifier.value = currentSong;

    Uri? artUri;
    if (currentSong.pictures.isNotEmpty) {
      artUri = await saveAlbumCover(currentSong.pictures.first.bytes);
    }

    mediaItem.add(
      MediaItem(
        id: currentSong.file.path,
        title: getTitle(currentSong),
        artist: currentSong.artist,
        album: currentSong.album,
        artUri: artUri, // file:// URI
        duration: currentSong.duration,
      ),
    );
  }

  @override
  Future<void> skipToNext() async {
    if (playQueue.isEmpty) return;
    currentIndex = (currentIndex == playQueue.length - 1)
        ? 0
        : currentIndex + 1;
    await load();
  }

  @override
  Future<void> skipToPrevious() async {
    if (playQueue.isEmpty) return;
    currentIndex = (currentIndex == 0)
        ? playQueue.length - 1
        : currentIndex - 1;
    await load();
  }

  Future<void> togglePlay();

  Stream<Duration> getPositionStream();

  void setVolume(double volume);

  double getVolume();
}

class WLAudioHandler extends MyAudioHandler {
  final _player = audioplayers.AudioPlayer();

  WLAudioHandler() {
    _player.setVolume(0.3);
    volumeNotifier = ValueNotifier(0.3);
    _player.onPlayerStateChanged.map(transformState).pipe(playbackState);

    _player.onPlayerComplete.listen((_) async {
      bool needPauseTmp = needPause;

      if (playModeNotifier.value == 2) {
        // repeat
        await load();
        if (isPlayingNotifier.value) {
          _player.resume();
        }
      } else {
        await skipToNext(); // automatically go to next song
      }

      if (needPauseTmp) {
        await pause();
      }
    });

    _player.onPlayerStateChanged.listen((state) {
      if (state == audioplayers.PlayerState.playing) {
        isPlayingNotifier.value = true;
        needPause = false;
      } else if (state == audioplayers.PlayerState.paused ||
          state == audioplayers.PlayerState.stopped) {
        isPlayingNotifier.value = false;
        needPause = false;
      }
    });

    currentSongNotifier.addListener(() {
      needPause = false;
    });
  }

  PlaybackState transformState(audioplayers.PlayerState state) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        state == audioplayers.PlayerState.playing
            ? MediaControl.pause
            : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: {MediaAction.seek},
      playing: state == audioplayers.PlayerState.playing,
      processingState: {
        audioplayers.PlayerState.stopped: AudioProcessingState.idle,
        audioplayers.PlayerState.playing: AudioProcessingState.ready,
        audioplayers.PlayerState.paused: AudioProcessingState.ready,
        audioplayers.PlayerState.completed: AudioProcessingState.completed,
        audioplayers.PlayerState.disposed: AudioProcessingState.idle,
      }[state]!,
    );
  }

  @override
  Future<void> load() async {
    isloading = true;
    await super.load();

    await _player.setSource(
      audioplayers.DeviceFileSource(currentSongNotifier.value!.file.path),
    );
    isloading = false;
  }

  @override
  Future<void> play() async {
    if (playQueue.isEmpty) return;
    await _player.resume();
  }

  @override
  Future<void> pause() async => await _player.pause();

  @override
  Future<void> stop() async => await _player.stop();

  @override
  Future<void> seek(Duration position) async => await _player.seek(position);

  @override
  Future<void> skipToNext() async {
    await super.skipToNext();
    if (isPlayingNotifier.value) {
      _player.resume();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    await super.skipToPrevious();
    if (isPlayingNotifier.value) {
      _player.resume();
    }
  }

  @override
  Stream<Duration> getPositionStream() {
    return _player.onPositionChanged;
  }

  @override
  Future<void> togglePlay() async {
    if (_player.state == audioplayers.PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  @override
  void setVolume(double volume) {
    _player.setVolume(volume);
  }

  @override
  double getVolume() {
    return _player.volume;
  }
}

class AIMAudioHandler extends MyAudioHandler {
  final _player = just_audio.AudioPlayer();

  AIMAudioHandler() {
    if (Platform.isMacOS) {
      _player.setVolume(0.3);
      volumeNotifier = ValueNotifier(0.3);
    }
    _player.playbackEventStream.map(transformEvent).pipe(playbackState);

    _player.processingStateStream.listen((state) async {
      if (state == just_audio.ProcessingState.completed) {
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
    });

    currentSongNotifier.addListener(() {
      needPause = false;
    });
  }

  PlaybackState transformEvent(just_audio.PlaybackEvent event) {
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
        just_audio.ProcessingState.idle: AudioProcessingState.idle,
        just_audio.ProcessingState.loading: AudioProcessingState.loading,
        just_audio.ProcessingState.buffering: AudioProcessingState.buffering,
        just_audio.ProcessingState.ready: AudioProcessingState.ready,
        just_audio.ProcessingState.completed: AudioProcessingState.completed,
      }[event.processingState]!,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
    );
  }

  @override
  Future<void> load() async {
    isloading = true;
    await super.load();

    final audioSource = just_audio.ProgressiveAudioSource(
      Uri.file(currentSongNotifier.value!.file.path),
      options: just_audio.ProgressiveAudioSourceOptions(
        darwinAssetOptions: just_audio.DarwinAssetOptions(
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
  Future<void> seek(Duration position) async => await _player.seek(position);

  @override
  Future<void> togglePlay() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Stream<Duration> getPositionStream() {
    return _player.positionStream;
  }

  @override
  void setVolume(double volume) {
    _player.setVolume(volume);
  }

  @override
  double getVolume() {
    return _player.volume;
  }
}
