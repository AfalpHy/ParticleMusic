import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/playlists.dart';
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
import 'song_list_tile.dart';
import 'art_widget.dart';
import 'package:path/path.dart' as p;

final GlobalKey<NavigatorState> homeNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<bool> moveDownNotifier = ValueNotifier(false);

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
      home: Stack(
        children: [
          // Navigator for normal pages (PlayerBar stays above)
          WillPopScope(
            onWillPop: () async {
              if (homeNavigatorKey.currentState!.canPop()) {
                homeNavigatorKey.currentState!.pop();
                return false; // prevent app from exiting
              }
              return true; // exit app if root
            },
            child: Navigator(
              key: homeNavigatorKey,
              onGenerateRoute: (settings) {
                return MaterialPageRoute(builder: (_) => const HomePage());
              },
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: moveDownNotifier,
            builder: (context, moveDown, _) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: 20,
                right: 20,
                bottom: moveDown ? 30 : 90, // move down 30px when true
                child: const PlayerBar(),
              );
            },
          ),
        ],
      ),
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
  int displayPage = 1;
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

    List<AudioMetadata?> favoriteTmp = [];
    final appSupportDir = await getApplicationSupportDirectory();
    favoriteFile = File("${appSupportDir.path}/favorite.json");
    if (!favoriteFile.existsSync()) {
      favoriteFile.create();
    } else {
      final contents = await favoriteFile.readAsString();
      if (contents != "") {
        List<dynamic> decoded = jsonDecode(contents);
        favoriteBasenames = List.from(decoded);
        favoriteTmp = List<AudioMetadata?>.filled(
          favoriteBasenames.length,
          null,
          growable: true,
        );
      }
    }

    for (var file in docs.listSync()) {
      if ((file.path.endsWith('.mp3') || file.path.endsWith('.flac'))) {
        try {
          final meta = readMetadata(File(file.path), getImage: true);
          tempSongs.add(meta);
          final songBasename = p.basename(file.path);
          final favoriteIndex = favoriteBasenames.indexOf(songBasename);
          if (favoriteIndex >= 0) {
            favoriteTmp[favoriteIndex] = meta;
            songIsFavorite[songBasename] = ValueNotifier(true);
          } else {
            songIsFavorite[songBasename] = ValueNotifier(false);
          }
        } catch (_) {
          continue; // skip unreadable files
        }
      }
    }

    setState(() {
      favorite = favoriteTmp.cast();
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
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            backgroundColor: Colors.grey.shade100,
            elevation: 0,
            scrolledUnderElevation: 0,
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
                if (playQueue.isNotEmpty) {
                  listIsScrolling.value = true;
                  if (timer != null) {
                    timer!.cancel();
                    timer = null;
                  }
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
            child: displayPage == 1
                ? buildSongList()
                : displayPage == 2
                ? buildPlaylists()
                : buildSetting(),
          ),

          bottomNavigationBar: SizedBox(
            height: 80,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      displayPage = 1;
                    }),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          size: 28,
                          color: displayPage == 1
                              ? Colors.black
                              : Colors.black54,
                        ),

                        Text(
                          "Library",
                          style: TextStyle(
                            color: displayPage == 1
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
                      displayPage = 2;
                    }),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_add_outlined,
                          size: 28,
                          color: displayPage == 2
                              ? Colors.black
                              : Colors.black54,
                        ),

                        Text(
                          "Playlists",
                          style: TextStyle(
                            color: displayPage == 2
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
                      displayPage = 3;
                    }),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.settings_outlined,
                          size: 28,
                          color: displayPage == 3
                              ? Colors.black
                              : Colors.black54,
                        ),

                        Text(
                          "Settings",
                          style: TextStyle(
                            color: displayPage == 3
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

        Positioned(
          left: 0,
          right: 0,
          bottom: 180,
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
          return Selector<MyAudioHandler, AudioMetadata?>(
            selector: (_, audioHandler) => audioHandler.currentSong,
            builder: (_, _, _) {
              return SongListTile(index: index, source: filteredSongs);
            },
          );
        } else {
          return SizedBox(height: 60);
        }
      },
    );
  }

  Widget buildPlaylists() {
    filteredSongs = [];
    return ListView(
      children: [
        ListTile(
          contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
          leading: Icon(Icons.favorite_outline_outlined, size: 40),
          title: Text('Favorite'),
          onTap: () async {
            moveDownNotifier.value = true;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) {
                  return Stack(
                    children: [
                      Scaffold(
                        backgroundColor: Colors.white,
                        appBar: AppBar(
                          title: Text('Favorite'),
                          backgroundColor: Colors.white,
                          scrolledUnderElevation: 0,
                        ),

                        body: PlaylistSongList(
                          source: favorite,
                          notifier: notifier,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
            moveDownNotifier.value = false;
          },
          trailing: IconButton(onPressed: () {}, icon: Icon(Icons.more_vert)),
        ),
      ],
    );
  }

  Widget buildSetting() {
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
      selector: (_, audioHandler) => audioHandler.currentSong,
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
                    icon: Icon(Icons.my_location_rounded),
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
      selector: (_, audioHandler) => audioHandler.currentSong,
      builder: (_, currentSong, _) {
        if (currentSong == null) return const SizedBox.shrink();

        return SizedBox(
          height: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25), // rounded half-circle ends

            child: Material(
              color: Color.fromARGB(210, 240, 255, 255),
              child: InkWell(
                onTap: () {
                  // Open lyrics page
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const LyricsPage()));
                },

                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    ArtWidget(
                      size: 35,
                      borderRadius: 1,
                      source: currentSong.pictures.isEmpty
                          ? null
                          : currentSong.pictures.first,
                    ),

                    const SizedBox(width: 10),
                    Expanded(
                      child: AutoSizeText(
                        "${currentSong.title ?? 'Unknown Title'} - ${currentSong.artist ?? 'Unknown Artist'}",
                        maxLines: 1,
                        minFontSize: 16,
                        overflowReplacement: Marquee(
                          text:
                              "${currentSong.title ?? 'Unknown Title'} - ${currentSong.artist ?? 'Unknown Artist'}",
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
                        selector: (_, audioHandler) =>
                            audioHandler.player.playing,
                        builder: (_, playing, _) {
                          return Icon(
                            playing
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
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
                    const SizedBox(width: 10),
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
