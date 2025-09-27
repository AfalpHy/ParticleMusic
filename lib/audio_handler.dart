import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:audio_service/audio_service.dart';
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
Map<String, AudioMetadata> basename2LibrarySongs = {};
List<AudioMetadata> playQueue = [];
List<AudioMetadata> playQueueTmp = [];
List<AudioMetadata> filteredSongs = [];
List<LyricLine> lyrics = [];
Color artAverageColor = Colors.grey;

ValueNotifier<AudioMetadata?> currentSongNotifier = ValueNotifier(null);
ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
ValueNotifier<int> playModeNotifier = ValueNotifier(0);

class MyAudioHandler extends BaseAudioHandler with ChangeNotifier {
  final player = AudioPlayer();
  int currentIndex = -1;

  MyAudioHandler() {
    player.playbackEventStream.map(transformEvent).pipe(playbackState);

    player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        if (playModeNotifier.value == 1) {
          // repeat
          await load();
        } else {
          await skipToNext(); // automatically go to next song
        }
      }
    });

    player.playingStream.listen((isPlaying) {
      isPlayingNotifier.value = isPlaying;
    });
  }

  PlaybackState transformEvent(PlaybackEvent event) {
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
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      updatePosition: player.position,
    );
  }

  void setIndex(int index) {
    currentIndex = index;
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
      if (playQueueTmp.isNotEmpty) {
        playQueueTmp.add(tmp);
      }
    }
    return true;
  }

  void singlePlay(int index, List<AudioMetadata> source) async {
    if (insert2Next(index, source)) {
      await skipToNext();
      player.play();
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
    playMode %= 3;
    playModeNotifier.value = playMode;
    if (playMode == 0) {
      playQueue = List.from(playQueueTmp);
      playQueueTmp = [];
      currentIndex = playQueue.indexOf(currentSongNotifier.value!);
    } else if (playMode == 2) {
      shuffle();
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
    player.stop();
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
      return;
    }
    final lines = await file.readAsLines(); // read file line by line

    final regex = RegExp(r'\[(\d{2}):(\d{2})(?::(\d{2})|.(\d{2}))\](.*)');

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
    int minLuminace = 50;
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

    Uri? artUri;
    if (currentSong.pictures.isNotEmpty) {
      artAverageColor = computeMixedColor(currentSong.pictures.first.bytes);
      artUri = await saveAlbumCover(currentSong.pictures.first.bytes);
    } else {
      artAverageColor = Colors.grey;
    }
    currentSongNotifier.value = currentSong;

    mediaItem.add(
      MediaItem(
        id: currentSong.file.path,
        title: currentSong.title!,
        artist: currentSong.artist,
        album: currentSong.album,
        artUri: artUri, // file:// URI
        duration: currentSong.duration,
      ),
    );
    final audioSource = ProgressiveAudioSource(
      Uri.file(currentSong.file.path),
      options: ProgressiveAudioSourceOptions(
        darwinAssetOptions: DarwinAssetOptions(
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

  @override
  Future<void> seek(Duration position) async => await player.seek(position);
}
