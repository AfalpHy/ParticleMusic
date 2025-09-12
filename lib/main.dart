import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:marquee/marquee.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:watcher/watcher.dart';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:auto_size_text/auto_size_text.dart';

List<AudioMetadata> songs = [];
List<AudioMetadata> playQueue = [];
List<AudioMetadata> filteredSongs = [];
List<LyricLine> lyrics = [];
late Color? artMixedColor;
// Create a GlobalKey for each line
List<GlobalKey> lineKeys = [];

class MyAudioHandler extends BaseAudioHandler with ChangeNotifier {
  final player = AudioPlayer();
  AudioMetadata? currentSong;
  int currentIndex = -1;

  MyAudioHandler() {
    player.playbackEventStream.map(transformEvent).pipe(playbackState);

    player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await skipToNext(); // automatically go to next song
      }
    });

    player.playingStream.listen((isPlaying) {
      notifyListeners();
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

    final regex = RegExp(r'\[(\d+):(\d+)(?:\.(\d+))?\](.*)');

    for (var line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final ms = match.group(3) != null
            ? int.parse(match.group(3)!.padRight(3, '0'))
            : 0;
        final text = match.group(4)!.trim();
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
    lineKeys = List.generate(lyrics.length, (_) => GlobalKey());
  }

  Color mixColorsWeighted(List<Color> colors) {
    double r = 0, g = 0, b = 0, a = 0;

    for (int i = 0; i < 5; i++) {
      if (i >= colors.length) {
        r += 255 * 0.2;
        g += 255 * 0.2;
        b += 255 * 0.2;
        a += 255 * 0.2;
        continue;
      }
      r += ((colors[i].r * 255.0).round() & 0xff) * 0.2;
      g += ((colors[i].g * 255.0).round() & 0xff) * 0.2;
      b += ((colors[i].b * 255.0).round() & 0xff) * 0.2;
      a += ((colors[i].a * 255.0).round() & 0xff) * 0.2;
    }

    return Color.fromARGB(a.round(), r.round(), g.round(), b.round());
  }

  Color computeMixedColor(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
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
    int luminance = img.getLuminanceRgb(r, g, b).toInt();
    if (luminance < 90) {
      r += 90 - luminance;
      g += 90 - luminance;
      b += 90 - luminance;
    }

    return Color.fromARGB(255, r.toInt(), g.toInt(), b.toInt());
  }

  Future<void> load() async {
    if (currentIndex < 0 || currentIndex >= playQueue.length) return;
    currentSong = playQueue[currentIndex];
    String path = currentSong!.file.path;
    await parseLyricsFile("${path.substring(0, path.lastIndexOf('.'))}.lrc");
    artMixedColor = computeMixedColor(currentSong!.pictures.first.bytes);
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
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() => player.stop();

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
  Future<void> seek(Duration position) => player.seek(position);
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
    return MaterialApp(title: 'Particle Music', home: const HomePage());
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
  bool displayLibrary = true;
  @override
  void initState() {
    super.initState();
    loadAndWatch();
  }

  Future<void> loadAndWatch() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.audio.request();
      final dir = await getExternalStorageDirectories();
      docs = Directory("${dir!.first.parent.parent.parent.parent.path}/Music");
    } else {
      docs = await getApplicationDocumentsDirectory();
    }

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

    if (Platform.isIOS) {
      final keepfile = File('${docs.path}/Particle Music.keep');
      if (!(await keepfile.exists())) {
        await keepfile.writeAsString("App initialized");
      }
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
      tempSongs.sort((a, b) {
        // First, compare album
        int comparison = (a.album ?? "Unknown Album").compareTo(
          b.album ?? "Unknown Album",
        );
        if (comparison != 0) {
          return comparison; // if different, use this
        }
        // If album is the same, compare artist
        comparison = (a.artist ?? "Unknown Artist").compareTo(
          b.artist ?? "Unknown Artist",
        );

        if (comparison != 0) {
          return comparison; // if different, use this
        }
        return (a.title ?? "Unknown Title").compareTo(
          b.title ?? "Unknown Title",
        );
      });
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
          backgroundColor: Colors.grey,
          appBar: AppBar(
            backgroundColor: Colors.grey,

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
          body: displayLibrary ? buildSongList() : buildPlaylists(),
          bottomNavigationBar: SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      displayLibrary = true;
                    }),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_music_rounded,
                          size: 28,
                          color: displayLibrary ? Colors.black : Colors.black54,
                        ),

                        Text(
                          "Library",
                          style: TextStyle(
                            color: displayLibrary
                                ? Colors.black
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      displayLibrary = false;
                    }),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_add_rounded,
                          size: 28,
                          color: !displayLibrary
                              ? Colors.black
                              : Colors.black54,
                        ),

                        Text(
                          "Playlists",
                          style: TextStyle(
                            color: !displayLibrary
                                ? Colors.black
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(left: 0, right: 0, bottom: 80, child: PlayerBar()),
      ],
    );
  }

  Widget buildSongList() {
    final audiohanlder = Provider.of<MyAudioHandler>(context, listen: false);

    filteredSongs = songs
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
            audiohanlder.setIndex(index);
            playQueue = filteredSongs;
            await audiohanlder.load();
            audiohanlder.play();
          },
        );
      },
    );
  }

  Widget buildPlaylists() {
    return SizedBox();
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
        if (playQueue.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 40,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 20, color: Colors.grey),
              ),
              Positioned(
                left: 15,
                right: 15,
                bottom: 0,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    20,
                  ), // rounded half-circle ends

                  child: Material(
                    color: artMixedColor,
                    child: InkWell(
                      onTap: () {
                        // Open lyrics page
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LyricPage()),
                        );
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
                            ClipOval(
                              child: const Icon(Icons.music_note, size: 40),
                            ),

                          const SizedBox(width: 12),
                          Expanded(
                            child: AutoSizeText(
                              "${audioHandler.currentSong!.title ?? 'Unknown Title'} - ${audioHandler.currentSong!.artist ?? 'Unknown Artist'}",
                              maxLines: 1,
                              minFontSize: 16,
                              overflowReplacement: Marquee(
                                text:
                                    "${audioHandler.currentSong!.title ?? 'Unknown Title'} - ${audioHandler.currentSong!.artist ?? 'Unknown Artist'}",
                                scrollAxis: Axis.horizontal,
                                blankSpace: 20,
                                velocity: 30.0,
                                pauseAfterRound: const Duration(seconds: 1),
                                accelerationDuration: const Duration(
                                  milliseconds: 500,
                                ),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(
                                  milliseconds: 500,
                                ),
                                decelerationCurve: Curves.linear,
                              ),
                            ),
                          ),
                          // Title - Artist Marquee

                          // Play/Pause Button
                          IconButton(
                            icon: Icon(
                              audioHandler.player.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              if (audioHandler.player.playing) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.queue_music_rounded,
                              color: Colors.black,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true, // allows full-height

                                builder: (context) => SizedBox(
                                  height: 500,
                                  child: Column(
                                    children: [
                                      // Optional drag handle
                                      Container(
                                        margin: EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        width: 50,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          physics: BouncingScrollPhysics(
                                            parent:
                                                AlwaysScrollableScrollPhysics(),
                                          ),
                                          itemCount: playQueue.length,
                                          itemBuilder: (context, index) {
                                            final song = playQueue[index];
                                            return ListTile(
                                              title: Text(
                                                "${song.title ?? "Unknown Title"} - ${song.artist ?? "Unknown Artist"}",
                                                overflow: TextOverflow.ellipsis,
                                              ),

                                              visualDensity:
                                                  const VisualDensity(
                                                    horizontal: 0,
                                                    vertical: -4,
                                                  ),
                                              onTap: () async {
                                                audioHandler.setIndex(index);
                                                await audioHandler.load();
                                                audioHandler.play();
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final duration = audioHandler.player.duration ?? Duration.zero;
    return Scaffold(
      backgroundColor: artMixedColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: artMixedColor,
        title: AutoSizeText(
          "${audioHandler.currentSong!.title ?? 'Unknown Title'} - ${audioHandler.currentSong!.artist ?? 'Unknown Artist'}",
          maxLines: 1,
          minFontSize: 20,
          overflowReplacement: SizedBox(
            height: kToolbarHeight, // finite height
            width: double.infinity, // takes whatever width AppBar gives
            child: Marquee(
              text:
                  "${audioHandler.currentSong?.title ?? 'Unknown Title'} - ${audioHandler.currentSong?.artist ?? 'Unknown Artist'}",
              scrollAxis: Axis.horizontal,
              blankSpace: 20,
              velocity: 30.0,
              pauseAfterRound: const Duration(seconds: 1),
              accelerationDuration: const Duration(milliseconds: 500),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.linear,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
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
          const SizedBox(height: 10),

          Expanded(
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent, // fade out at top
                    Colors.black, // fully visible
                    Colors.black, // fully visible
                    Colors.transparent, // fade out at bottom
                  ],
                  stops: [0.0, 0.1, 0.9, 1.0], // adjust fade height
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: StreamBuilder<Duration>(
                stream: audioHandler.player.positionStream,
                builder: (context, snapshot) {
                  final pos = snapshot.data ?? Duration.zero;
                  return LyricsListView(position: pos);
                },
              ),
            ),
          ),

          SeekBar(player: audioHandler.player, duration: duration),

          // -------- Play Controls --------
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 30),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  color: Colors.black,
                  icon: const Icon(Icons.loop_rounded, size: 30),
                  onPressed: () => {
                    // TODO:
                  },
                ),
                IconButton(
                  color: Colors.black,
                  icon: const Icon(Icons.skip_previous_rounded, size: 48),
                  onPressed: audioHandler.skipToPrevious,
                ),
                IconButton(
                  color: Colors.black,
                  icon: Icon(
                    audioHandler.player.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 48,
                  ),
                  onPressed: () => audioHandler.player.playing
                      ? audioHandler.pause()
                      : audioHandler.play(),
                ),
                IconButton(
                  color: Colors.black,
                  icon: const Icon(Icons.skip_next_rounded, size: 48),
                  onPressed: audioHandler.skipToNext,
                ),
                IconButton(
                  icon: Icon(
                    Icons.queue_music_rounded,
                    size: 30,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true, // allows full-height

                      builder: (context) => SizedBox(
                        height: 500,
                        child: Column(
                          children: [
                            // Optional drag handle
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 20),
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                physics: BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics(),
                                ),
                                itemCount: playQueue.length,
                                itemBuilder: (context, index) {
                                  final song = playQueue[index];
                                  return ListTile(
                                    title: Text(
                                      "${song.title ?? "Unknown Title"} - ${song.artist ?? "Unknown Artist"}",
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    visualDensity: const VisualDensity(
                                      horizontal: 0,
                                      vertical: -4,
                                    ),
                                    onTap: () async {
                                      audioHandler.setIndex(index);
                                      await audioHandler.load();
                                      audioHandler.play();
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LyricsListView extends StatefulWidget {
  final Duration position;

  const LyricsListView({super.key, required this.position});

  @override
  State<LyricsListView> createState() => LyricsListViewState();
}

class LyricsListViewState extends State<LyricsListView> {
  final ScrollController scrollController = ScrollController();
  bool userDragging = false;
  int currentIndex = -1;

  @override
  void didUpdateWidget(LyricsListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    currentIndex = lyrics.lastIndexWhere(
      (line) => widget.position >= line.timestamp,
    );

    // Only auto-scroll if user is not dragging
    if (!userDragging && scrollController.hasClients && currentIndex >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = lineKeys[currentIndex];
        final context = key.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: Duration(milliseconds: 300), // smooth animation
            curve: Curves.linear,
            alignment: 0.5,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) {
          userDragging = true;
        } else {
          Future.delayed(const Duration(milliseconds: 500), () {
            userDragging = false;
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        itemCount: lyrics.length,
        itemBuilder: (context, index) {
          final bool isActive = index == currentIndex;
          return Container(
            key: lineKeys[index],
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 50),
            child: Text(
              lyrics[index].text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isActive ? 20 : 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.black : Color.fromARGB(128, 0, 0, 0),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LyricLine {
  final Duration timestamp;
  final String text;
  LyricLine(this.timestamp, this.text);
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

            return SizedBox(
              height: 50, // expand gesture area for easier touch
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Duration labels
                  Positioned(
                    left: 30,
                    right: 30,
                    bottom: 0,
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

                  // Slider visuals
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: Colors.black,
                      trackHeight: isDragging ? 4 : 2,
                      trackShape: const FullWidthTrackShape(),
                      thumbShape: isDragging
                          ? RoundSliderThumbShape(enabledThumbRadius: 4)
                          : RoundSliderThumbShape(enabledThumbRadius: 2),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: Colors.black,
                      inactiveTrackColor: Colors.grey.shade300,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Slider(
                        min: 0.0,
                        max: durationMs,
                        value: sliderValue.clamp(0.0, durationMs),
                        onChanged: (value) {},
                      ),
                    ),
                  ),

                  // Full-track GestureDetector to capture touches anywhere on the track
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (_) {
                        setState(() => isDragging = true);
                      },
                      onHorizontalDragStart: (_) {
                        setState(() => isDragging = true);
                      },
                      onHorizontalDragUpdate: (details) {
                        seekByTouch(
                          details.localPosition.dx,
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
                          details.localPosition.dx,
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
            );
          },
        );
      },
    );
  }

  /// Map horizontal touch to slider value
  void seekByTouch(double dx, BuildContext context, double durationMs) {
    final box = context.findRenderObject() as RenderBox;

    double relative = (dx - 30) / (box.size.width - 60);
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
