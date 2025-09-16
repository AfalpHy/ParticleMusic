import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:marquee/marquee.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:watcher/watcher.dart';
import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/services.dart';
import 'audio_handler.dart';
import 'lyrics_page.dart';
import 'play_queue_page.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // only allow portrait
  ]);
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
      scrollBehavior: ScrollConfiguration.of(
        context,
      ).copyWith(overscroll: false),
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
  bool displayLibrary = true;
  final ValueNotifier<bool> listIsScrolling = ValueNotifier(false);
  final ItemScrollController itemScrollController = ItemScrollController();
  Timer? timer;

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
      librarySongs = tempSongs;
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
          body: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              if (notification.direction != ScrollDirection.idle) {
                listIsScrolling.value = true;
                if (timer != null) {
                  timer!.cancel();
                  timer = null;
                }
              } else {
                if (listIsScrolling.value) {
                  timer ??= Timer(const Duration(milliseconds: 3000), () {
                    listIsScrolling.value = false;
                    timer = null;
                  });
                }
              }
              return false;
            },
            child: displayLibrary ? buildSongList() : buildPlaylists(),
          ),

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

        Positioned(
          left: 0,
          right: 0,
          bottom: 150,
          child: MyLocation(
            itemScrollController: itemScrollController,
            listIsScrolling: listIsScrolling,
          ),
        ),
      ],
    );
  }

  Widget buildSongList() {
    filteredSongs = librarySongs
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

    return ScrollablePositionedList.builder(
      itemScrollController: itemScrollController,
      physics: ClampingScrollPhysics(),
      itemCount: filteredSongs.length + 1,
      itemBuilder: (context, index) {
        if (index < filteredSongs.length) {
          final song = filteredSongs[index];
          return Selector<MyAudioHandler, String?>(
            selector: (_, audioHandeler) =>
                audioHandeler.currentSong?.file.path,
            builder: (_, currentFilePath, _) {
              final isCurrentSong = song.file.path == currentFilePath;

              return ListTile(
                contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
                tileColor: isCurrentSong ? Colors.white24 : null,
                leading: (() {
                  if (song.pictures.isNotEmpty) {
                    return ClipRRect(
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(
                        2,
                      ), // same as you want
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
                  style: TextStyle(
                    color: isCurrentSong ? Colors.brown : null,
                    fontWeight: isCurrentSong ? FontWeight.bold : null,
                  ),
                ),
                subtitle: Text(
                  "${song.artist ?? "Unknown Artist"} - ${song.album ?? "Unknown Album"}",
                  overflow: TextOverflow.ellipsis,
                ),
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                onTap: () async {
                  audioHandler.setIndex(index);
                  playQueue = List.from(filteredSongs);
                  if (audioHandler.playMode == 2) {
                    audioHandler.shuffle();
                  }
                  await audioHandler.load();
                  audioHandler.play();
                },
                trailing: IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true, // allows full-height

                      builder: (context) {
                        return SizedBox(
                          height: 500,
                          child: ListView(
                            physics: const ClampingScrollPhysics(),
                            children: [
                              ListTile(
                                leading: (() {
                                  if (song.pictures.isNotEmpty) {
                                    return ClipRRect(
                                      clipBehavior: Clip.antiAlias,
                                      borderRadius: BorderRadius.circular(
                                        2,
                                      ), // same as you want
                                      child: Image.memory(
                                        song.pictures.first.bytes,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.music_note,
                                                size: 40,
                                              );
                                            },
                                      ),
                                    );
                                  }
                                  return ClipRRect(
                                    clipBehavior: Clip.antiAlias,
                                    borderRadius: BorderRadius.circular(2),
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 40,
                                    ),
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
                              ),
                              ListTile(
                                title: Text(
                                  'Play',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                visualDensity: const VisualDensity(
                                  horizontal: 0,
                                  vertical: -4,
                                ),
                                onTap: () {
                                  audioHandler.singlePlay(index);
                                },
                              ),
                              ListTile(
                                title: Text(
                                  'Play next',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                visualDensity: const VisualDensity(
                                  horizontal: 0,
                                  vertical: -4,
                                ),
                                onTap: () {
                                  audioHandler.insert2Next(index);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.more_vert, size: 15),
                ),
              );
            },
          );
        } else {
          return SizedBox(height: 40);
        }
      },
    );
  }

  Widget buildPlaylists() {
    filteredSongs = [];
    return SizedBox();
  }
}

class MyLocation extends StatefulWidget {
  final ItemScrollController itemScrollController;
  final ValueNotifier<bool> listIsScrolling;

  const MyLocation({
    super.key,
    required this.itemScrollController,
    required this.listIsScrolling,
  });

  @override
  State<MyLocation> createState() => MyLocationState();
}

class MyLocationState extends State<MyLocation> {
  bool userDragging = false;

  @override
  void initState() {
    super.initState();
    widget.listIsScrolling.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Selector<MyAudioHandler, AudioMetadata?>(
      selector: (_, audioHandeler) => audioHandeler.currentSong,
      builder: (_, currentSong, _) {
        return currentSong != null &&
                filteredSongs.isNotEmpty &&
                widget.listIsScrolling.value
            ? Row(
                children: [
                  Spacer(),
                  IconButton(
                    onPressed: () {
                      if (audioHandler.currentSong != null) {
                        for (int i = 0; i < filteredSongs.length; i++) {
                          if (filteredSongs[i].file.path ==
                              audioHandler.currentSong!.file.path) {
                            widget.itemScrollController.scrollTo(
                              index: i,
                              duration: Duration(milliseconds: 300),
                              curve: Curves.linear,
                            );
                          }
                        }
                      }
                    },
                    icon: Icon(Icons.my_location),
                  ),
                  SizedBox(width: 40),
                ],
              )
            : SizedBox();
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
    return Selector<MyAudioHandler, AudioMetadata?>(
      selector: (_, audioHandeler) => audioHandeler.currentSong,
      builder: (_, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

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
                          MaterialPageRoute(builder: (_) => const LyricsPage()),
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
                            icon: Selector<MyAudioHandler, bool>(
                              selector: (_, audioHandeler) =>
                                  audioHandeler.player.playing,
                              builder: (_, playing, _) {
                                return Icon(
                                  playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                );
                              },
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

                                builder: (context) {
                                  return PlayQueuePage();
                                },
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
