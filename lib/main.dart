import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:particle_music/playlists.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:marquee/marquee.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:watcher/watcher.dart';
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
final ValueNotifier<double> swipeProgressNotifier = ValueNotifier<double>(0.0);
final ValueNotifier<int> homeBody = ValueNotifier<int>(1);

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
  runApp(MyApp());
}

class SwipeObserver extends NavigatorObserver {
  bool first = true;
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PageRoute && !first) {
      route.animation?.addListener(() {
        swipeProgressNotifier.value = route.animation!.value;
      });
    }
    first = false;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    swipeProgressNotifier.value = 0;
    super.didPop(route, previousRoute);
  }
}

final swipeObserver = SwipeObserver();

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
              observers: [swipeObserver],
              onGenerateRoute: (settings) {
                return MaterialPageRoute(builder: (_) => const HomePage());
              },
            ),
          ),
          ValueListenableBuilder<double>(
            valueListenable: swipeProgressNotifier,
            builder: (context, progress, _) {
              final double bottom = 80 - (40 * progress);
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 8),
                curve: Curves.linear,
                left: 20,
                right: 20,
                bottom: bottom,
                child: const PlayerBar(),
              );
            },
          ),

          ValueListenableBuilder<double>(
            valueListenable: swipeProgressNotifier,
            builder: (context, progress, _) {
              final double bottom = -80 * progress;

              return AnimatedPositioned(
                duration: const Duration(milliseconds: 8),
                curve: Curves.linear,
                left: 0,
                right: 0,
                bottom: bottom,
                child: ValueListenableBuilder<int>(
                  valueListenable: homeBody,
                  builder: (context, which, _) {
                    // must use Material to avoid layout problem
                    return Material(
                      child: Container(
                        color: Colors.grey.shade100,
                        height: 80,
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => homeBody.value = 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.library_music_outlined,
                                      color: which == 1
                                          ? Colors.black
                                          : Colors.black54,
                                    ),

                                    Text(
                                      "Library",
                                      style: TextStyle(
                                        color: which == 1
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
                                onTap: () => homeBody.value = 2,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,

                                  children: [
                                    Icon(
                                      Icons.library_add_outlined,
                                      color: which == 2
                                          ? Colors.black
                                          : Colors.black54,
                                    ),

                                    Text(
                                      "Playlists",
                                      style: TextStyle(
                                        color: which == 2
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
                                onTap: () => homeBody.value = 3,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,

                                  children: [
                                    Icon(
                                      Icons.settings_outlined,
                                      color: which == 3
                                          ? Colors.black
                                          : Colors.black54,
                                    ),

                                    Text(
                                      "Settings",
                                      style: TextStyle(
                                        color: which == 3
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
                    );
                  },
                ),
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
    // final watcher = DirectoryWatcher(docs.path);

    // watcher.events.listen((event) {
    //   isChanged = true;
    // });

    // // Check directory every 5 seconds
    // Timer.periodic(Duration(seconds: 5), (timer) async {
    //   if (isChanged) {
    //     isChanged = false;
    //     await loadSongs();
    //   }
    // });
  }

  Future<void> loadSongs() async {
    List<AudioMetadata> tempSongs = [];

    if (Platform.isIOS) {
      final keepfile = File('${docs.path}/Particle Music.keep');
      if (!(await keepfile.exists())) {
        await keepfile.writeAsString("App initialized");
      }
    }

    Map<String, AudioMetadata> basename2Meta = {};
    for (var file in docs.listSync()) {
      if ((file.path.endsWith('.mp3') || file.path.endsWith('.flac'))) {
        try {
          final meta = readMetadata(File(file.path), getImage: true);
          tempSongs.add(meta);
          basename2Meta[p.basename(file.path)] = meta;
          songIsFavorite[meta] = ValueNotifier(false);
        } catch (_) {
          continue; // skip unreadable files
        }
      }
    }

    final appSupportDir = await getApplicationSupportDirectory();
    allPlaylistsFile = File("${appSupportDir.path}/allPlaylists.txt");
    if (!(await allPlaylistsFile.exists())) {
      List<String> tmp = ['Favorite'];
      await allPlaylistsFile.writeAsString(jsonEncode(tmp));
    }

    List<dynamic> allPlaylists = jsonDecode(
      await allPlaylistsFile.readAsString(),
    );

    for (String name in allPlaylists) {
      final tmp = Playlist(name: name);
      playlists.add(tmp);

      final contents = await tmp.playlistFile.readAsString();
      if (contents != "") {
        List<dynamic> decoded = jsonDecode(contents);
        for (String basename in decoded) {
          AudioMetadata meta = basename2Meta[basename]!;
          tmp.songs.add(meta);
          if (name == 'Favorite') {
            songIsFavorite[meta]!.value = true;
          }
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
            child: ValueListenableBuilder<int>(
              valueListenable: homeBody,
              builder: (context, which, _) {
                if (which == 1) {
                  return buildSongList();
                } else if (which == 2) {
                  return buildPlaylists();
                } else {
                  return buildSetting();
                }
              },
            ),
          ),
        ),

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
          return SongListTile(index: index, source: filteredSongs);
        } else {
          return SizedBox(height: 130);
        }
      },
    );
  }

  Widget buildPlaylists() {
    filteredSongs = [];
    return ValueListenableBuilder(
      valueListenable: playlistsChangeNotifier,
      builder: (_, _, _) {
        return ListView.builder(
          itemCount: playlists.length,
          itemBuilder: (_, index) {
            final playlist = playlists[index];
            return ListTile(
              contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
              leading: Icon(Icons.music_note, size: 40),
              title: Text(playlist.name),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.grey.shade100,
                      appBar: AppBar(
                        title: Text(playlist.name),
                        backgroundColor: Colors.grey.shade100,
                        scrolledUnderElevation: 0,
                      ),
                      body: PlaylistSongList(
                        source: playlist.songs,
                        notifier: playlist.changeNotifier,
                      ),
                    ),
                  ),
                );
              },
              trailing: playlist.name != 'Favorite'
                  ? IconButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true, // allows full-height
                          builder: (_) {
                            return ClipRRect(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                              child: Container(
                                height: 500,
                                color: Colors.grey.shade100,
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: Icon(Icons.delete),
                                      title: Text('Delete'),
                                      onTap: () {
                                        deletePlaylist(index);
                                        Navigator.pop(context);
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      icon: Icon(Icons.more_vert),
                    )
                  : null,
            );
          },
        );
      },
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
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
      builder: (_, currentSong, _) {
        return currentSong != null &&
                filteredSongs.isNotEmpty &&
                widget.listIsScrolling.value
            ? Row(
                children: [
                  Spacer(),
                  IconButton(
                    onPressed: () {
                      if (currentSongNotifier.value != null) {
                        for (int i = 0; i < filteredSongs.length; i++) {
                          if (filteredSongs[i] == currentSongNotifier.value) {
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
                  SizedBox(width: 30),
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
    return ValueListenableBuilder(
      valueListenable: currentSongNotifier,
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
                      icon: ValueListenableBuilder(
                        valueListenable: isPlayingNotifier,
                        builder: (_, isPlaying, _) {
                          return Icon(
                            isPlaying
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
