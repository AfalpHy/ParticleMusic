import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:marquee/marquee.dart';

void main() {
  runApp(
    ChangeNotifierProvider(create: (_) => PlayerModel(), child: const MyApp()),
  );
}

// --------------------
// Player Model
// --------------------
class PlayerModel extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  AudioMetadata? currentSong;
  bool isPlaying = false;

  PlayerModel() {
    _player.playbackEventStream.listen((event) {
      // optional: handle events like completion
      if (_player.processingState == ProcessingState.completed) {
        isPlaying = false;
        notifyListeners();
      }
    });
  }

  Future<void> playSong(AudioMetadata song) async {
    currentSong = song;
    try {
      await _player.setFilePath(song.file.path);
      _player.play();
      isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint("Error playing ${song.title}: $e");
    }
  }

  void togglePlayPause() {
    if (_player.playing) {
      _player.pause();
      isPlaying = false;
    } else {
      _player.play();
      isPlaying = true;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
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
  List<AudioMetadata> songs = [];

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
    return Scaffold(
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
                          5,
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
                      borderRadius: BorderRadius.circular(5),
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
                  onTap: () => player.playSong(song),
                );
              },
            ),
      bottomNavigationBar: const PlayerBar(),
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

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // gap from bottom
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25), // rounded half-circle ends
            child: Material(
              color: Colors.white,
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
                                accelerationDuration: const Duration(
                                  seconds: 1,
                                ),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(
                                  seconds: 1,
                                ),
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
                icon: Icon(
                  player.isPlaying ? Icons.pause_circle : Icons.play_circle,
                  size: 48,
                ),
                onPressed: player.togglePlayPause,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
