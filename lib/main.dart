import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';

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
    // Request permissions
    await Permission.audio.request();

    // Let user pick a music directory
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;
    final musicDir = Directory(dirPath);

    List<AudioMetadata> tempSongs = [];

    // Read files recursively
    await for (var file in musicDir.list(recursive: true, followLinks: false)) {
      if (file is File &&
          (file.path.endsWith('.mp3') ||
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
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: (() {
                    if (song.pictures.isNotEmpty) {
                      return Image.memory(
                        song.pictures.first.bytes,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.music_note, size: 50);
                        },
                      );
                    }
                    return const Icon(Icons.music_note, size: 50);
                  })(),
                  title: Text(song.title ?? "Unknown Title"),
                  subtitle: Text(song.artist ?? "Unknown Artist"),
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

        return Container(
          color: Colors.grey[900],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (player.currentSong!.title != null)
                Image.memory(
                  player.currentSong!.pictures.first.bytes!,
                  width: 50,
                  height: 50,
                )
              else
                const Icon(Icons.music_note, size: 40),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      player.currentSong!.title ?? "Unknown Title",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      player.currentSong!.artist ?? "Unknown Artist",
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  player.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () => player.togglePlayPause(),
              ),
            ],
          ),
        );
      },
    );
  }
}
