import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:marquee/marquee.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:watcher/watcher.dart';
import 'dart:async';

List<AudioMetadata> songs = [];

class MyAudioHandler extends BaseAudioHandler with ChangeNotifier {
  final player = AudioPlayer();
  AudioMetadata? currentSong;
  int currentIndex = -1;
  bool isPlaying = false;

  MyAudioHandler() {
    player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await skipToNext(); // automatically go to next song
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
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

  Future<Uri> saveAlbumCover(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();

    // Append timestamp to filename to avoid overwriting
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/cover_$timestamp');

    await file.writeAsBytes(bytes);
    return file.uri;
  }

  Future<void> load() async {
    if (currentIndex < 0 || currentIndex >= songs.length) return;
    currentSong = songs[currentIndex];
    notifyListeners();

    Uri? artUri;
    if (currentSong!.pictures.isNotEmpty) {
      artUri = await saveAlbumCover(currentSong!.pictures.first.bytes);
    }
    mediaItem.add(
      MediaItem(
        id: currentSong!.file.path,
        title: currentSong!.title!,
        artist: currentSong!.artist,
        album: currentSong!.album,
        artUri: artUri, // file:// URI
        duration: currentSong!.duration,
      ),
    );
    final audioSource = ProgressiveAudioSource(
      Uri.file(currentSong!.file.path),
      options: ProgressiveAudioSourceOptions(
        darwinAssetOptions: DarwinAssetOptions(
          preferPreciseDurationAndTiming: true,
        ),
      ),
    );

    await player.setAudioSource(audioSource);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    notifyListeners();
    await player.play();
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    notifyListeners();
    await player.pause();
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    notifyListeners();
    await player.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (songs.isEmpty) return;
    currentIndex = (currentIndex == songs.length - 1) ? 0 : currentIndex + 1;
    await load();
  }

  @override
  Future<void> skipToPrevious() async {
    if (songs.isEmpty) return;
    currentIndex = (currentIndex == 0) ? songs.length - 1 : currentIndex - 1;
    await load();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
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
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late Directory docs;
  bool isChanged = false;
  @override
  void initState() {
    super.initState();
    loadAndWatch();
  }

  Future<void> loadAndWatch() async {
    docs = await getApplicationDocumentsDirectory();
    await loadSongs();
    final watcher = DirectoryWatcher(docs.path);

    watcher.events.listen((event) {
      isChanged = true;
    });

    // Check directory every 5 seconds
    Timer.periodic(Duration(seconds: 5), (timer) async {
      if (isChanged) {
        isChanged = false;
        await loadSongs();
      }
    });
  }

  Future<void> loadSongs() async {
    List<AudioMetadata> tempSongs = [];

    final keepfile = File('${docs.path}/Particle Music.keep');
    if (!(await keepfile.exists())) {
      await keepfile.writeAsString("App initialized");
    }
    for (var file in docs.listSync()) {
      if ((file.path.endsWith('.mp3') || file.path.endsWith('.flac'))) {
        try {
          final meta = readMetadata(File(file.path), getImage: true);
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

  bool isSearching = false;
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: isSearching
                ? TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Search songs...",
                      border: InputBorder.none,
                      hintStyle: TextStyle(),
                    ),
                    style: const TextStyle(),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  )
                : const Text("Particle Music"),
            actions: [
              IconButton(
                icon: Icon(isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    if (isSearching) {
                      isSearching = false;
                      searchQuery = "";
                    } else {
                      isSearching = true;
                    }
                  });
                },
              ),
            ],
          ),
          body: buildSongList(),
          bottomNavigationBar: SizedBox(height: 50),
        ),
        Positioned(left: 15, right: 15, bottom: 30, child: PlayerBar()),
      ],
    );
  }

  Widget buildSongList() {
    final audiohanlder = Provider.of<MyAudioHandler>(context, listen: false);

    final filteredSongs = songs
        .where(
          (song) =>
              (searchQuery.isEmpty) ||
              (song.title?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false) ||
              (song.artist?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false) ||
              (song.album?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                  false),
        )
        .toList();

    return ListView.builder(
      physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: filteredSongs.length,
      itemBuilder: (context, index) {
        final song = filteredSongs[index];
        return ListTile(
          leading: (() {
            if (song.pictures.isNotEmpty) {
              return ClipRRect(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(2), // same as you want
                child: Image.memory(
                  song.pictures.first.bytes,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.music_note, size: 40);
                  },
                ),
              );
            }
            return ClipRRect(
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(2),
              child: const Icon(Icons.music_note, size: 40),
            );
          })(),
          title: Text(
            song.title ?? "Unknown Title",
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            "${song.artist ?? "Unknown Artist"} - ${song.album ?? "Unknown Album"}",
            overflow: TextOverflow.ellipsis,
          ),
          visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
          onTap: () async {
            audiohanlder.setIndex(songs.indexOf(filteredSongs[index]));
            await audiohanlder.load();
            await audiohanlder.play();
          },
        );
      },
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
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.music_note, size: 40),
                      ),
                    )
                  else
                    ClipOval(child: const Icon(Icons.music_note, size: 40)),
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
    final duration = audioHandler.player.duration ?? Duration.zero;
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

          SeekBar(player: audioHandler.player, duration: duration),

          const SizedBox(height: 16),

          // -------- Play Controls --------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 48),
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
                icon: const Icon(Icons.skip_next, size: 48),
                onPressed: audioHandler.skipToNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SeekBar extends StatefulWidget {
  final AudioPlayer player;
  final Duration duration;

  const SeekBar({super.key, required this.player, required this.duration});

  @override
  State<SeekBar> createState() => SeekBarState();
}

class SeekBarState extends State<SeekBar> {
  double? dragValue;
  bool isDragging = false; // track if user is touching the thumb

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.player.durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        final durationMs = duration.inMilliseconds.toDouble();

        return StreamBuilder<Duration>(
          stream: widget.player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final sliderValue = dragValue ?? position.inMilliseconds.toDouble();

            return Padding(
              padding: const EdgeInsets.fromLTRB(30, 50, 30, 0),
              child: Column(
                children: [
                  SizedBox(
                    height: 40, // expand gesture area for easier touch
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Slider visuals
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: isDragging ? 4 : 2,
                            trackShape: const FullWidthTrackShape(),
                            thumbShape: isDragging
                                ? RoundSliderThumbShape(enabledThumbRadius: 4)
                                : RoundSliderThumbShape(enabledThumbRadius: 2),
                            overlayShape: SliderComponentShape.noOverlay,
                            activeTrackColor: Colors.blue,
                            inactiveTrackColor: Colors.grey.shade300,
                          ),
                          child: Slider(
                            min: 0.0,
                            max: durationMs,
                            value: sliderValue.clamp(0.0, durationMs),
                            onChanged: (value) {},
                          ),
                        ),

                        // Full-track GestureDetector to capture touches anywhere on the track
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (details) {
                              setState(() => isDragging = true);
                            },
                            onHorizontalDragUpdate: (details) {
                              seekByTouch(
                                details.globalPosition.dx,
                                context,
                                durationMs,
                              );
                            },
                            onHorizontalDragEnd: (_) async {
                              await widget.player.seek(
                                Duration(milliseconds: dragValue!.toInt()),
                              );
                              setState(() {
                                dragValue = null;
                                isDragging = false;
                              });
                            },
                            onTapUp: (details) async {
                              seekByTouch(
                                details.globalPosition.dx,
                                context,
                                durationMs,
                              );
                              await widget.player.seek(
                                Duration(milliseconds: dragValue!.toInt()),
                              );
                              setState(() {
                                dragValue = null;
                                isDragging = false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Duration labels
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 20, 5, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(
                            Duration(milliseconds: sliderValue.toInt()),
                          ),
                        ),
                        Text(formatDuration(duration)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Map horizontal touch to slider value
  void seekByTouch(double dx, BuildContext context, double durationMs) {
    final box = context.findRenderObject() as RenderBox;

    double relative = dx / box.size.width;
    relative = relative.clamp(0.0, 1.0);
    setState(() {
      dragValue = relative * durationMs;
    });
  }
}

/// Full-width rounded track
class FullWidthTrackShape extends SliderTrackShape {
  const FullWidthTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackLeft = offset.dx;
    final trackWidth = parentBox.size.width;

    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final radius = Radius.circular(trackRect.height / 2);

    final activeTrackRect = RRect.fromLTRBR(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
      radius,
    );

    final inactiveTrackRect = RRect.fromLTRBR(
      thumbCenter.dx,
      trackRect.top,
      trackRect.right,
      trackRect.bottom,
      radius,
    );

    final activePaint = Paint()
      ..color = sliderTheme.activeTrackColor!
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor!
      ..style = PaintingStyle.fill;

    context.canvas.drawRRect(activeTrackRect, activePaint);
    context.canvas.drawRRect(inactiveTrackRect, inactivePaint);
  }
}

// Helper class for combined stream
class PositionData {
  final Duration position;
  final Duration duration;
  PositionData(this.position, this.duration);
}
