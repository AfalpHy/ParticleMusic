import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:marquee/marquee.dart';
import 'package:audio_service/audio_service.dart';

List<AudioMetadata> songs = [];

class MyAudioHandler extends BaseAudioHandler with ChangeNotifier {
  final player = AudioPlayer();
  AudioMetadata? currentSong;
  int currentIndex = -1;
  bool isPlaying = false;

  MyAudioHandler() {
    player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
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

  Future<void> load() async {
    if (currentIndex < 0 || currentIndex >= songs.length) return;
    currentSong = songs[currentIndex];
    await player.pause();
    await player.setFilePath(currentSong!.file.path);
  }

  @override
  Future<void> play() async {
    await player.play();
    isPlaying = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    await player.pause();
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    await player.stop();
    isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> skipToNext() async {
    if (songs.isEmpty) return;
    currentIndex = (currentIndex == songs.length - 1) ? 0 : currentIndex + 1;
    await load();
    if (isPlaying) {
      await play();
    } else {
      notifyListeners();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (songs.isEmpty) return;
    currentIndex = (currentIndex == 0) ? songs.length - 1 : currentIndex - 1;
    await load();
    if (isPlaying) {
      await play();
    } else {
      notifyListeners();
    }
  }
}

late MyAudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.app.audio',
      androidNotificationChannelName: 'Music Playback',
      androidNotificationOngoing: true,
    ),
  );
  runApp(
    ChangeNotifierProvider.value(
      value: audioHandler, // directly provide your handler
      child: const MyApp(),
    ),
  );
}

// --------------------
// App Root
// --------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Particle Music',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const HomePage(),
    );
  }
}

// --------------------
// Home Page
// --------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    loadSongs();
  }

  Future<void> loadSongs() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    List<AudioMetadata> tempSongs = [];
    if (result != null) {
      List<File> files = result.files
          .where((platformFile) => platformFile.path != null)
          .map((platformFile) => File(platformFile.path!))
          .toList();

      for (var file in files) {
        if ((file.path.endsWith('.mp3') ||
            file.path.endsWith('.flac') ||
            file.path.endsWith('.m4a'))) {
          try {
            final meta = readMetadata(file, getImage: true);
            tempSongs.add(meta);
          } catch (_) {
            continue; // skip unreadable files
          }
        }
      }
    }

    setState(() {
      songs = tempSongs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final audiohanlder = Provider.of<MyAudioHandler>(context, listen: false);
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text("Particle Music")),
          body: songs.isEmpty
              ? const Center(child: Text("No songs found"))
              : ListView.builder(
                  physics: BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      leading: (() {
                        if (song.pictures.isNotEmpty) {
                          return ClipRRect(
                            clipBehavior: Clip.antiAlias,
                            borderRadius: BorderRadius.circular(
                              2,
                            ), // same as you want
                            child: Image.memory(
                              song.pictures.first.bytes,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.music_note, size: 50);
                              },
                            ),
                          );
                        }
                        return ClipRRect(
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.circular(2),
                          child: const Icon(Icons.music_note, size: 50),
                        );
                      })(),
                      title: Text(
                        song.title ?? "Unknown Title",
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist ?? "Unknown Artist",
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        audiohanlder.setIndex(index);
                        audiohanlder.load();
                        audiohanlder.play();
                      },
                    );
                  },
                ),
          bottomNavigationBar: SizedBox(height: 40),
        ),
        Positioned(left: 15, right: 15, bottom: 15, child: PlayerBar()),
      ],
    );
  }
}

// --------------------
// Bottom Player Bar
// --------------------
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MyAudioHandler>(
      builder: (context, audioHandler, child) {
        if (audioHandler.currentSong == null) return const SizedBox.shrink();

        return ClipRRect(
          borderRadius: BorderRadius.circular(25), // rounded half-circle ends
          child: Material(
            child: InkWell(
              onTap: () {
                // Open lyrics page
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LyricPage()));
              },

              child: Row(
                children: [
                  // Album cover or icon
                  if (audioHandler.currentSong!.pictures.isNotEmpty)
                    ClipOval(
                      child: Image.memory(
                        audioHandler.currentSong!.pictures.first.bytes,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.music_note, size: 50),
                      ),
                    )
                  else
                    ClipOval(child: const Icon(Icons.music_note, size: 50)),
                  const SizedBox(width: 12),

                  // Title - Artist Marquee
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final text =
                            "${audioHandler.currentSong!.title ?? 'Unknown Title'} - ${audioHandler.currentSong!.artist ?? 'Unknown Artist'}";
                        final textPainter = TextPainter(
                          text: TextSpan(
                            text: text,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          maxLines: 1,
                          textDirection: TextDirection.ltr,
                        )..layout(maxWidth: double.infinity);

                        if (textPainter.width > constraints.maxWidth) {
                          // Text too long → use Marquee
                          return SizedBox(
                            height: 20,
                            child: Marquee(
                              text: text,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              scrollAxis: Axis.horizontal,
                              blankSpace: 20,
                              velocity: 30.0,
                              pauseAfterRound: const Duration(seconds: 1),
                              startPadding: 10,
                              accelerationDuration: const Duration(seconds: 1),
                              accelerationCurve: Curves.linear,
                              decelerationDuration: const Duration(seconds: 1),
                              decelerationCurve: Curves.easeOut,
                            ),
                          );
                        } else {
                          // Text fits → use normal Text
                          return Text(
                            text,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        }
                      },
                    ),
                  ),

                  // Play/Pause Button
                  IconButton(
                    icon: Icon(
                      audioHandler.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                    ),
                    onPressed: () => audioHandler.isPlaying
                        ? audioHandler.pause()
                        : audioHandler.play(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class LyricPage extends StatelessWidget {
  const LyricPage({super.key});

  @override
  Widget build(BuildContext context) {
    final audioHandler = Provider.of<MyAudioHandler>(context);

    if (audioHandler.currentSong == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Lyrics")),
        body: const Center(child: Text("No song playing")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(audioHandler.currentSong!.title ?? "Unknown Title"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          ClipOval(
            child: audioHandler.currentSong!.pictures.isNotEmpty
                ? Image.memory(
                    audioHandler.currentSong!.pictures.first.bytes,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.music_note, size: 200),
                  )
                : const Icon(Icons.music_note, size: 200),
          ),

          const SizedBox(height: 24),
          // Play Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.skip_previous, size: 48),
                onPressed: audioHandler.skipToPrevious,
              ),
              IconButton(
                icon: Icon(
                  audioHandler.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 48,
                ),
                onPressed: () => audioHandler.isPlaying
                    ? audioHandler.pause()
                    : audioHandler.play(),
              ),
              IconButton(
                icon: Icon(Icons.skip_next, size: 48),
                onPressed: audioHandler.skipToNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
