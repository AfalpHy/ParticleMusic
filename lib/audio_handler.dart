import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as mobile;
import 'package:audioplayers/audioplayers.dart' as desktop;
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:audio_service/audio_service.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/setting.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:image/image.dart' as image;
import 'package:flutter/services.dart';

late MyAudioHandler audioHandler;

class LyricLine {
  final Duration timestamp;
  final String text;
  LyricLine(this.timestamp, this.text);
}

List<AudioMetadata> librarySongs = [];
Map<String, AudioMetadata> basename2LibrarySong = {};
List<AudioMetadata> playQueue = [];
List<LyricLine> lyrics = [];
Color artAverageColor = Colors.grey;

ValueNotifier<AudioMetadata?> currentSongNotifier = ValueNotifier(null);
ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
ValueNotifier<int> playModeNotifier = ValueNotifier(0);

abstract class MyAudioHandler extends BaseAudioHandler {
  int currentIndex = -1;
  List<AudioMetadata> playQueueTmp = [];
  int tmpPlayMode = 0;

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
    currentSongNotifier.value = null;
  }

  Future<Uri> saveAlbumCover(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();

    final file = File('${dir.path}/cover');

    await file.writeAsBytes(bytes);
    return file.uri;
  }

  Future<void> parseLyricsFile(String path) async {
    lyrics = [];
    final file = File(path);
    if (!file.existsSync()) {
      lyrics.add(LyricLine(Duration.zero, 'lyrics file does not exist'));
      return;
    }
    final lines = await file.readAsLines(); // read file line by line

    final regex = RegExp(r'\[(\d{2}):(\d{2})(?::(\d{2,3})|.(\d{2,3}))\](.*)');

    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final ms = match.group(3) != null
            ? int.parse(match.group(3)!.padRight(3, '0'))
            : int.parse(match.group(4)!.padRight(3, '0'));
        final text = match.group(5)!.trim();
        if (text == '') {
          continue;
        }
        lyrics.add(
          LyricLine(
            Duration(minutes: min, seconds: sec, milliseconds: ms),
            text,
          ),
        );
      }
    }
    if (lyrics.isEmpty) {
      lyrics.add(LyricLine(Duration.zero, 'lyrics parsing failed'));
    }
  }

  Color computeMixedColor(Uint8List bytes) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null) return Colors.grey;

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
    int minLuminace = 90;
    if (luminance < minLuminace) {
      r += minLuminace - luminance;
      g += minLuminace - luminance;
      b += minLuminace - luminance;
    }

    return Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
  }

  Future<void> load() async {
    if (currentIndex < 0 || currentIndex >= playQueue.length) return;
    final currentSong = playQueue[currentIndex];
    String path = currentSong.file.path;
    await parseLyricsFile("${path.substring(0, path.lastIndexOf('.'))}.lrc");

    if (currentSong.pictures.isNotEmpty) {
      artAverageColor = computeMixedColor(currentSong.pictures.first.bytes);
    } else {
      artAverageColor = Colors.grey;
    }
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

  bool isReady();

  Stream<Duration?> getDurationStream();

  Stream<Duration> getPositionStream();
}

class DesktopAudioHandler extends MyAudioHandler {
  final player = desktop.AudioPlayer();

  DesktopAudioHandler() {
    player.onPlayerComplete.listen((_) async {
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
    });

    player.onPlayerStateChanged.listen((state) {
      if (state == desktop.PlayerState.playing) {
        isPlayingNotifier.value = true;
        needPause = false;
      } else if (state == desktop.PlayerState.paused) {
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
    await super.load();
    final currentSong = currentSongNotifier.value!;

    await player.setSource(desktop.DeviceFileSource(currentSong.file.path));
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
  Stream<Duration?> getDurationStream() {
    return player.onDurationChanged;
  }

  @override
  Stream<Duration> getPositionStream() {
    return player.onPositionChanged;
  }

  @override
  bool isReady() {
    return player.state == desktop.PlayerState.playing ||
        player.state == desktop.PlayerState.paused;
  }

  @override
  Future<void> togglePlay() async {
    if (player.state == desktop.PlayerState.playing) {
      await player.pause();
    } else {
      await player.resume();
    }
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

  @override
  Future<void> load() async {
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
  bool isReady() {
    return player.processingState == mobile.ProcessingState.ready;
  }

  @override
  Stream<Duration?> getDurationStream() {
    return player.durationStream;
  }

  @override
  Stream<Duration> getPositionStream() {
    return player.positionStream;
  }
}
