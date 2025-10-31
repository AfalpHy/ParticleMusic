import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as mobile;
import 'package:audioplayers/audioplayers.dart' as desktop;
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

  void delete(index) {
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

      r += 25;
      g += 25;
      b += 25;
      // make coverArtFilterColor more brighter
      coverArtFilterColor = Color.fromARGB(
        160,
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
      coverArtFilterColor = coverArtAverageColor.withAlpha(160);
    }
  }

  Future<void> load() async {
    if (currentIndex < 0 || currentIndex >= playQueue.length) return;

    final currentSong = playQueue[currentIndex];

    String path = currentSong.file.path;
    await parseLyricsFile("${path.substring(0, path.lastIndexOf('.'))}.lrc");

    computeCoverArtColors(currentSong);

    currentSongNotifier.value = currentSong;
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

  void setVolume(double volume) {}

  double getVolume();
}

class DesktopAudioHandler extends MyAudioHandler {
  final player = desktop.AudioPlayer();

  DesktopAudioHandler() {
    player.setVolume(0.3);
    volumeNotifier = ValueNotifier(0.3);

    player.onPlayerComplete.listen((_) async {
      bool needPauseTmp = needPause;

      if (playModeNotifier.value == 2) {
        // repeat
        await load();
        if (isPlayingNotifier.value) {
          player.resume();
        }
      } else {
        await skipToNext(); // automatically go to next song
      }

      if (needPauseTmp) {
        await pause();
      }
    });

    player.onPlayerStateChanged.listen((state) {
      if (state == desktop.PlayerState.playing) {
        isPlayingNotifier.value = true;
        needPause = false;
      } else if (state == desktop.PlayerState.paused ||
          state == desktop.PlayerState.stopped) {
        isPlayingNotifier.value = false;
        needPause = false;
      }
    });

    currentSongNotifier.addListener(() {
      needPause = false;
    });
  }

  @override
  Future<void> load() async {
    isloading = true;
    await super.load();
    final currentSong = currentSongNotifier.value!;

    await player.setSource(desktop.DeviceFileSource(currentSong.file.path));
    isloading = false;
  }

  @override
  Future<void> play() async => await player.resume();

  @override
  Future<void> pause() async => await player.pause();

  @override
  Future<void> stop() async => await player.stop();

  @override
  Future<void> seek(Duration position) async => await player.seek(position);

  @override
  Future<void> skipToNext() async {
    await super.skipToNext();
    if (isPlayingNotifier.value) {
      player.resume();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    await super.skipToPrevious();
    if (isPlayingNotifier.value) {
      player.resume();
    }
  }

  @override
  Stream<Duration> getPositionStream() {
    return player.onPositionChanged;
  }

  @override
  Future<void> togglePlay() async {
    if (player.state == desktop.PlayerState.playing) {
      await player.pause();
    } else {
      await player.resume();
    }
  }

  @override
  void setVolume(double volume) {
    player.setVolume(volume);
  }

  @override
  double getVolume() {
    return player.volume;
  }
}

class MobileAudioHandler extends MyAudioHandler {
  final player = mobile.AudioPlayer();

  MobileAudioHandler() {
    player.playbackEventStream.map(transformEvent).pipe(playbackState);

    player.processingStateStream.listen((state) async {
      if (state == mobile.ProcessingState.completed) {
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

    player.playingStream.listen((isPlaying) {
      needPause = false;
      isPlayingNotifier.value = isPlaying;
    });

    currentSongNotifier.addListener(() {
      needPause = false;
    });
  }

  PlaybackState transformEvent(mobile.PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: {MediaAction.seek},
      playing: player.playing,
      processingState: {
        mobile.ProcessingState.idle: AudioProcessingState.idle,
        mobile.ProcessingState.loading: AudioProcessingState.loading,
        mobile.ProcessingState.buffering: AudioProcessingState.buffering,
        mobile.ProcessingState.ready: AudioProcessingState.ready,
        mobile.ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      updatePosition: player.position,
    );
  }

  Future<Uri> saveAlbumCover(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();

    final file = File('${dir.path}/cover');

    await file.writeAsBytes(bytes);
    return file.uri;
  }

  @override
  Future<void> load() async {
    isloading = true;
    await super.load();
    final currentSong = currentSongNotifier.value!;

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
    final audioSource = mobile.ProgressiveAudioSource(
      Uri.file(currentSong.file.path),
      options: mobile.ProgressiveAudioSourceOptions(
        darwinAssetOptions: mobile.DarwinAssetOptions(
          preferPreciseDurationAndTiming: true,
        ),
      ),
    );

    await player.setAudioSource(audioSource);
    isloading = false;
  }

  @override
  Future<void> play() async => await player.play();

  @override
  Future<void> pause() async => await player.pause();

  @override
  Future<void> stop() async => await player.stop();

  @override
  Future<void> seek(Duration position) async => await player.seek(position);

  @override
  Future<void> togglePlay() async {
    if (player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Stream<Duration> getPositionStream() {
    return player.positionStream;
  }

  @override
  double getVolume() {
    return player.volume;
  }
}
