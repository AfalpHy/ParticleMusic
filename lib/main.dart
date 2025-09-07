import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:marquee/marquee.dart';
import 'package:audio_service/audio_service.dart';

List<AudioMetadata> songs = [];

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();
  PlayerModel? playerModel;
  MyAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }
  void setPlayerModel(PlayerModel model) {
    playerModel = model;
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        _player.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      playing: _player.playing,
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      updatePosition: _player.position,
    );
  }

  Future<void> playFile(String path) async {
    await _player.setFilePath(path);
    await _player.play();
  }

  @override
  Future<void> play() async {
    playerModel?.togglePlayPause();
  }

  @override
  Future<void> pause() async {
    playerModel?.togglePlayPause();
  }

  @override
  Future<void> stop() async {
    playerModel?.stop();
  }

  @override
  Future<void> skipToNext() async {
    playerModel?.next();
  }

  @override
  Future<void> skipToPrevious() async {
    playerModel?.last();
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
  final playerModel = PlayerModel(audioHandler);
  audioHandler.setPlayerModel(playerModel); // <-- link handler -> model
  runApp(
    ChangeNotifierProvider(create: (_) => playerModel, child: const MyApp()),
  );
}

// --------------------
// Player Model
// --------------------

class PlayerModel extends ChangeNotifier {
  final MyAudioHandler _audioHandler;
  AudioMetadata? currentSong;
  int currentIndex = -1;
  bool isPlaying = false;

  PlayerModel(this._audioHandler);

  void setIndex(int index) {
    currentIndex = index;
  }

  Future<void> playSong() async {
    if (currentIndex < 0 || currentIndex >= songs.length) return;
    currentSong = songs[currentIndex];
    isPlaying = true;
    notifyListeners();
    await _audioHandler.playFile(currentSong!.file.path);
  }

  Future<void> last() async {
    if (songs.isEmpty) return;
    currentIndex = (currentIndex == 0) ? songs.length - 1 : currentIndex - 1;
    await playSong();
  }

  Future<void> next() async {
    if (songs.isEmpty) return;
    currentIndex = (currentIndex == songs.length - 1) ? 0 : currentIndex + 1;
    await playSong();
  }

  void togglePlayPause() {
    if (isPlaying) {
      _audioHandler.pause();
      isPlaying = false;
    } else {
      _audioHandler.play();
      isPlaying = true;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioHandler.stop();
    isPlaying = false;
    notifyListeners();
  }
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
    final player = Provider.of<PlayerModel>(context, listen: false);
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
                        player.setIndex(index);
                        player.playSong();
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
    return Consumer<PlayerModel>(
      builder: (context, player, child) {
        if (player.currentSong == null) return const SizedBox.shrink();

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
                  if (player.currentSong!.pictures.isNotEmpty)
                    ClipOval(
                      child: Image.memory(
                        player.currentSong!.pictures.first.bytes,
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
                            "${player.currentSong!.title ?? 'Unknown Title'} - ${player.currentSong!.artist ?? 'Unknown Artist'}";
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
                      player.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                    ),
                    onPressed: () => player.togglePlayPause(),
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
    final player = Provider.of<PlayerModel>(context);

    if (player.currentSong == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Lyrics")),
        body: const Center(child: Text("No song playing")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(player.currentSong!.title ?? "Unknown Title")),
      body: Column(
        children: [
          const SizedBox(height: 16),
          ClipOval(
            child: player.currentSong!.pictures.isNotEmpty
                ? Image.memory(
                    player.currentSong!.pictures.first.bytes,
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
                onPressed: player.last,
              ),
              IconButton(
                icon: Icon(
                  player.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 48,
                ),
                onPressed: player.togglePlayPause,
              ),
              IconButton(
                icon: Icon(Icons.skip_next, size: 48),
                onPressed: player.next,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
