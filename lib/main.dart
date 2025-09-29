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
import 'package:searchfield/searchfield.dart';
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
  int deep = 0;
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PageRoute && deep == 1) {
      route.animation?.addListener(() {
        swipeProgressNotifier.value = route.animation!.value;
      });
    }
    deep++;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (deep == 1) {
      swipeProgressNotifier.value = 0;
    }
    deep--;
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
          PopScope(
            canPop: false, // we control when popping is allowed
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return; // already handled by system / parent

              if (homeNavigatorKey.currentState!.canPop()) {
                homeNavigatorKey.currentState!.pop();
              } else {
                Navigator.of(context).maybePop(); // fallback to root
              }
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 80,
                              color: Colors.white,
                              child: InkWell(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
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
                          ),
                          Expanded(
                            child: Container(
                              height: 80,
                              color: Colors.white,
                              child: InkWell(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
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
                          ),
                        ],
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

  List<String> librarySongBasenames = [];
  final TextEditingController textController = TextEditingController();

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
      final keepfile = File('${docs.path}/Particle Music.keep');
      if (!(await keepfile.exists())) {
        await keepfile.writeAsString("App initialized");
      }
    }

    final appSupportDir = await getApplicationSupportDirectory();
    allPlaylistsFile = File("${appSupportDir.path}/allPlaylists.txt");
    if (!(await allPlaylistsFile.exists())) {
      List<String> tmp = ['Favorite'];
      await allPlaylistsFile.writeAsString(jsonEncode(tmp));
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

    for (var file in docs.listSync()) {
      if ((file.path.endsWith('.mp3') || file.path.endsWith('.flac'))) {
        final basename = p.basename(file.path);
        try {
          final meta = readMetadata(File(file.path), getImage: true);
          tempSongs.add(meta);
          librarySongBasenames.add(basename);
          basename2LibrarySongs[basename] = meta;
          songIsFavorite[meta] = ValueNotifier(false);
        } catch (error) {
          continue; // skip unreadable files
        }
      }
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
          AudioMetadata? meta = basename2LibrarySongs[basename];
          if (meta != null) {
            tmp.songs.add(meta);
            if (name == 'Favorite') {
              songIsFavorite[meta]!.value = true;
            }
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

  Future<void> reloadSongs() async {
    final currentDocsList = docs.listSync();
    int j = 0;
    bool needReload = false;
    for (int i = 0; i < currentDocsList.length; i++) {
      final file = currentDocsList[i];
      if ((file.path.endsWith('.mp3') || file.path.endsWith('.flac'))) {
        final basename = p.basename(file.path);

        if (j >= librarySongBasenames.length ||
            basename != librarySongBasenames[j++]) {
          needReload = true;
          break;
        }
      }
    }
    if (!needReload) {
      return;
    }

    bool isPlaying = audioHandler.player.playing;
    if (isPlaying) {
      await audioHandler.pause();
    }
    basename2LibrarySongs = {};
    librarySongBasenames = [];
    playlists = [];
    playlistMap = {};
    songIsFavorite = {};

    await loadSongs();

    // update play queue meta
    if (playQueue.isNotEmpty) {
      List<AudioMetadata> tmp = [];

      for (AudioMetadata meta in playQueue) {
        final tmpMeta = basename2LibrarySongs[p.basename(meta.file.path)];
        if (tmpMeta != null) {
          tmp.add(tmpMeta);
        }
      }
      playQueue = tmp;

      // update current song meta
      final tmpMeta =
          basename2LibrarySongs[p.basename(
            currentSongNotifier.value!.file.path,
          )];
      if (tmpMeta == null) {
        if (playQueue.isNotEmpty) {
          audioHandler.currentIndex = 0;
          await audioHandler.load();
        } else {
          currentSongNotifier.value = null;
        }
      } else {
        audioHandler.currentIndex = playQueue.indexOf(tmpMeta);
        currentSongNotifier.value = tmpMeta;
        if (isPlaying) {
          audioHandler.play();
        }
      }
    }

    if (playQueueTmp.isNotEmpty) {
      List<AudioMetadata> tmp = [];
      for (AudioMetadata meta in playQueueTmp) {
        final tmpMeta = basename2LibrarySongs[p.basename(meta.file.path)];
        if (tmpMeta != null) {
          tmp.add(tmpMeta);
        }
      }
      playQueueTmp = tmp;
    }
  }

  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text("Particle Music"),
          ),
          body: ListView(
            children: [
              ListTile(
                leading: Icon(Icons.queue_music, size: 40),
                title: Text('Playlists'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.white,
                        appBar: AppBar(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          title: const Text("Playlists"),
                        ),
                        body: buildPlaylists(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.mic, size: 40),
                title: Text('Artists'),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.album_rounded, size: 40),
                title: Text('Albums'),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.music_note, size: 40),
                title: Text('Songs'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.white,
                        appBar: AppBar(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          scrolledUnderElevation: 0,
                          title: const Text("Songs"),
                        ),
                        body: buildSongList(),
                      ),
                    ),
                  );
                },
              ),
            ],
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

    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 20),

            Expanded(
              child: SizedBox(
                height: 40,
                child: SearchField(
                  autofocus: false,
                  controller: textController,
                  suggestions: [],
                  searchInputDecoration: SearchInputDecoration(
                    hintText: 'Search songs',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () => setState(() {
                              searchQuery = '';
                              textController.clear();
                              FocusScope.of(context).unfocus();
                            }),
                            icon: Icon(Icons.clear),
                            padding: EdgeInsets.zero,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSearchTextChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      itemScrollController.jumpTo(index: 0);
                    });
                    return null;
                  },
                ),
              ),
            ),

            IconButton(
              onPressed: () {
                reloadSongs();
              },
              icon: Icon(Icons.refresh),
            ),
          ],
        ),
        Expanded(
          child: ScrollablePositionedList.builder(
            itemScrollController: itemScrollController,
            physics: ClampingScrollPhysics(),
            itemCount: filteredSongs.length + 1,
            itemBuilder: (context, index) {
              if (index < filteredSongs.length) {
                return SongListTile(index: index, source: filteredSongs);
              } else {
                return SizedBox(height: 90);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget buildPlaylists() {
    searchQuery = '';
    textController.clear();
    return ValueListenableBuilder(
      valueListenable: playlistsChangeNotifier,
      builder: (_, _, _) {
        return ListView.builder(
          itemCount: playlists.length,
          itemBuilder: (_, index) {
            final playlist = playlists[index];
            return ListTile(
              contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
              visualDensity: const VisualDensity(horizontal: 0, vertical: -1),

              leading: ValueListenableBuilder(
                valueListenable: playlist.changeNotifier,
                builder: (_, _, _) {
                  return ArtWidget(
                    size: 50,
                    borderRadius: 3,
                    source:
                        playlist.songs.isNotEmpty &&
                            playlist.songs.first.pictures.isNotEmpty
                        ? playlist.songs.first.pictures.first
                        : null,
                  );
                },
              ),
              title: Text(playlist.name),
              subtitle: ValueListenableBuilder(
                valueListenable: playlist.changeNotifier,
                builder: (_, _, _) {
                  return Text("${playlist.songs.length} songs");
                },
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.white,
                      appBar: AppBar(
                        backgroundColor: Colors.white,
                        scrolledUnderElevation: 0,
                        actions: [
                          IconButton(
                            icon: Icon(Icons.more_vert),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true, // allows full-height
                                useRootNavigator: true,
                                builder: (context) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    ),
                                    child: Container(
                                      height: 500,
                                      color: Colors.white,
                                      child: Column(
                                        children: [
                                          ListTile(
                                            title: Text(
                                              "Playlist: ${playlist.name}",
                                            ),
                                          ),
                                          Divider(
                                            thickness: 0.5,
                                            height: 1,
                                            color: Colors.grey.shade300,
                                          ),
                                          playlist.name != 'Favorite'
                                              ? ListTile(
                                                  leading: Icon(
                                                    Icons.delete_rounded,
                                                    size: 25,
                                                  ),
                                                  title: Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                  visualDensity:
                                                      const VisualDensity(
                                                        horizontal: 0,
                                                        vertical: -4,
                                                      ),
                                                  onTap: () {
                                                    deletePlaylist(index);
                                                    Navigator.pop(
                                                      context,
                                                      true,
                                                    );
                                                  },
                                                )
                                              : SizedBox(),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ).then((value) {
                                if (value == true && mounted) {
                                  Navigator.pop(context);
                                }
                              });
                            },
                          ),
                        ],
                      ),

                      body: Column(
                        children: [
                          ValueListenableBuilder(
                            valueListenable: playlist.changeNotifier,
                            builder: (context, value, child) {
                              return Row(
                                children: [
                                  SizedBox(width: 20),

                                  Material(
                                    elevation: 5,
                                    borderRadius: BorderRadius.circular(6),
                                    child: ArtWidget(
                                      size: 120,
                                      borderRadius: 6,
                                      source:
                                          (playlist.songs.isNotEmpty &&
                                              playlist
                                                  .songs
                                                  .first
                                                  .pictures
                                                  .isNotEmpty)
                                          ? playlist.songs.first.pictures.first
                                          : null,
                                    ),
                                  ),

                                  Expanded(
                                    child: ListTile(
                                      title: Text(
                                        playlist.name,
                                        style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "${playlist.songs.length} songs",
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          SizedBox(height: 30),
                          Expanded(
                            child: PlaylistSongList(
                              playlist: playlist,
                              notifier: playlist.changeNotifier,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget buildSetting() {
    searchQuery = '';
    textController.clear();
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
        return ValueListenableBuilder(
          valueListenable: homeBody,
          builder: (_, value, _) {
            return value == 1 &&
                    widget.listIsScrolling.value &&
                    filteredSongs.contains(currentSong)
                ? Row(
                    children: [
                      Spacer(),
                      IconButton(
                        onPressed: () {
                          if (currentSongNotifier.value != null) {
                            for (int i = 0; i < filteredSongs.length; i++) {
                              if (filteredSongs[i] ==
                                  currentSongNotifier.value) {
                                widget.itemScrollController.scrollTo(
                                  index: i,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.linear,
                                );
                              }
                            }
                          }
                        },
                        icon: Icon(Icons.my_location_rounded, size: 20),
                      ),
                      SizedBox(width: 30),
                    ],
                  )
                : SizedBox();
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

                    // Play/Pause Button
                    SizedBox(
                      width: 40,
                      child: IconButton(
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
                    ),
                    SizedBox(
                      width: 35,
                      child: IconButton(
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
                    ),
                    const SizedBox(width: 20),
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
