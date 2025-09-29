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
import 'package:vibration/vibration.dart';
import 'audio_handler.dart';
import 'lyrics_page.dart';
import 'play_queue_page.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'song_list_tile.dart';
import 'art_widget.dart';
import 'package:path/path.dart' as p;
import 'common.dart';

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
  hasVibration = await Vibration.hasVibrator();
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
                      color: Colors.white,

                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 80,
                              child: InkWell(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () {
                                  if (hasVibration) {
                                    Vibration.vibrate(duration: 5);
                                  }
                                  homeBody.value = 1;
                                },

                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.library_music_outlined,
                                      color: which == 1
                                          ? Color.fromARGB(255, 120, 240, 240)
                                          : Colors.black54,
                                    ),

                                    Text(
                                      "Library",
                                      style: TextStyle(
                                        color: which == 1
                                            ? Color.fromARGB(255, 120, 240, 240)
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 80,
                              child: InkWell(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () {
                                  if (hasVibration) {
                                    Vibration.vibrate(duration: 5);
                                  }
                                  homeBody.value = 3;
                                },
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,

                                  children: [
                                    Icon(
                                      Icons.settings_outlined,
                                      color: which == 3
                                          ? Color.fromARGB(255, 120, 240, 240)
                                          : Colors.black54,
                                    ),

                                    Text(
                                      "Settings",
                                      style: TextStyle(
                                        color: which == 3
                                            ? Color.fromARGB(255, 120, 240, 240)
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

  Timer? timer;

  List<String> librarySongBasenames = [];

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
            title: const Text(
              "Particle Music",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            children: [
              ListTile(
                leading: const ImageIcon(
                  AssetImage("assets/images/playlists.png"),
                  size: 30,
                  color: Color.fromARGB(255, 120, 240, 240),
                ),
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
                leading: const ImageIcon(
                  AssetImage("assets/images/artist.png"),
                  size: 30,
                  color: Color.fromARGB(255, 120, 240, 240),
                ),
                title: Text('Artists'),
                onTap: () {},
              ),
              ListTile(
                leading: const ImageIcon(
                  AssetImage("assets/images/album.png"),
                  size: 30,
                  color: Color.fromARGB(255, 120, 240, 240),
                ),
                title: Text('Albums'),
                onTap: () {},
              ),
              ListTile(
                leading: const ImageIcon(
                  AssetImage("assets/images/music_note.png"),
                  size: 30,
                  color: Color.fromARGB(255, 120, 240, 240),
                ),
                title: Text('Songs'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.white,
                        resizeToAvoidBottomInset: false,
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
      ],
    );
  }

  Widget buildSongList() {
    final searchQuery = ValueNotifier('');
    final listIsScrolling = ValueNotifier(false);
    final itemScrollController = ItemScrollController();
    final textController = TextEditingController();

    return Stack(
      children: [
        NotificationListener<UserScrollNotification>(
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
          child: ValueListenableBuilder(
            valueListenable: searchQuery,
            builder: (context, value, child) {
              filteredSongs = librarySongs
                  .where(
                    (song) =>
                        (value.isEmpty) ||
                        (song.title?.toLowerCase().contains(
                              value.toLowerCase(),
                            ) ??
                            false) ||
                        (song.artist?.toLowerCase().contains(
                              value.toLowerCase(),
                            ) ??
                            false) ||
                        (song.album?.toLowerCase().contains(
                              value.toLowerCase(),
                            ) ??
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
                              suffixIcon: value.isNotEmpty
                                  ? IconButton(
                                      onPressed: () {
                                        searchQuery.value = '';
                                        textController.clear();
                                        // hide my location button immediately
                                        listIsScrolling.value = false;
                                        FocusScope.of(context).unfocus();
                                      },
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
                              searchQuery.value = value;
                              // hide my location button immediately
                              listIsScrolling.value = false;
                              itemScrollController.jumpTo(index: 0);

                              return null;
                            },
                          ),
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          if (hasVibration) {
                            Vibration.vibrate(duration: 5);
                          }
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
                          return SongListTile(
                            index: index,
                            source: filteredSongs,
                          );
                        } else {
                          return SizedBox(height: 90);
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 120,
          child: MyLocation(
            itemScrollController: itemScrollController,
            listIsScrolling: listIsScrolling,
          ),
        ),
      ],
    );
  }

  Widget buildPlaylists() {
    return ValueListenableBuilder(
      valueListenable: playlistsChangeNotifier,
      builder: (_, _, _) {
        return ListView.builder(
          itemCount: playlists.length + 1,
          itemBuilder: (_, index) {
            if (index == playlists.length) {
              return ListTile(
                contentPadding: EdgeInsets.fromLTRB(20, 0, 0, 0),
                leading: Material(
                  borderRadius: BorderRadius.circular(3),
                  child: Icon(Icons.add, size: 50),
                ),
                title: Text('New Playlist'),
                onTap: () {
                  final controller = TextEditingController();
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
                          child: SizedBox(
                            height: 250, // fixed height
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.start, // center vertically
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    30,
                                    30,
                                    30,
                                    0,
                                  ),
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: "Playlist Name",
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                      controller.text,
                                    ); // close with value
                                  },
                                  child: const Text("Complete"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ).then((name) {
                    if (name != null && name != '') {
                      newPlaylist(name);
                    }
                  });
                },
              );
            }
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
                    builder: (_) => PlaylistScaffold(index: index),
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
                              size: 25,
                            );
                          },
                        ),

                        onPressed: () {
                          if (hasVibration) {
                            Vibration.vibrate(duration: 5);
                          }
                          if (audioHandler.player.playing) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: Icon(
                          Icons.playlist_play_rounded,
                          color: Colors.black,
                          size: 30,
                        ),
                        onPressed: () {
                          if (hasVibration) {
                            Vibration.vibrate(duration: 5);
                          }
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
                    const SizedBox(width: 15),
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
