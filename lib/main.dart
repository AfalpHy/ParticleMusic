import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:particle_music/artist_album_page.dart';
import 'package:particle_music/playlists.dart';
import 'package:particle_music/playlists_page.dart';
import 'package:particle_music/setting.dart';
import 'package:particle_music/songs_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'audio_handler.dart';
import 'lyrics_page.dart';
import 'play_queue_page.dart';
import 'art_widget.dart';
import 'package:path/path.dart' as p;
import 'common.dart';
import 'package:flutter_switch/flutter_switch.dart';

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
                child: bottomNavigator(),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget bottomNavigator() {
  return ValueListenableBuilder<int>(
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
  );
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
  late Directory appSupportDir;
  @override
  void initState() {
    super.initState();
    initial();
  }

  Future<void> initial() async {
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

    appSupportDir = await getApplicationSupportDirectory();
    playlistsManager = PlaylistsManager(
      File("${appSupportDir.path}/allPlaylists.txt"),
    );

    await loadSongs();
  }

  Future<void> loadSongs() async {
    for (var file in docs.listSync()) {
      if ((file.path.endsWith('.mp3') || file.path.endsWith('.flac'))) {
        final basename = p.basename(file.path);
        try {
          final meta = readMetadata(File(file.path), getImage: true);
          for (String artist in (meta.artist ?? "Unkown").split(
            RegExp(r'[/&,]'),
          )) {
            if (artist2SongList[artist] == null) {
              artist2SongList[artist] = [];
            }
            artist2SongList[artist]!.add(meta);
          }

          if (album2SongList[meta.album ?? "Unkown"] == null) {
            album2SongList[meta.album ?? "Unkown"] = [];
          }
          album2SongList[meta.album ?? "Unkown"]!.add(meta);

          librarySongs.add(meta);
          basename2LibrarySong[basename] = meta;
          songIsFavorite[meta] = ValueNotifier(false);
        } catch (error) {
          continue; // skip unreadable files
        }
      }
    }

    List<dynamic> allPlaylists = await playlistsManager.getAllPlaylists();

    for (String name in allPlaylists) {
      final playlist = Playlist(
        name: name,
        file: File("${appSupportDir.path}/$name.json"),
      );
      playlistsManager.addPlaylist(playlist);

      final contents = await playlist.file.readAsString();
      if (contents != "") {
        List<dynamic> decoded = jsonDecode(contents);
        for (String basename in decoded) {
          AudioMetadata? meta = basename2LibrarySong[basename];
          if (meta != null) {
            playlist.songs.add(meta);
            if (name == 'Favorite') {
              songIsFavorite[meta]!.value = true;
            }
          }
        }
      }
    }

    setState(() {});
  }

  Future<void> reloadSongs() async {
    audioHandler.clear();
    librarySongs = [];
    basename2LibrarySong = {};
    playlistsManager.clear();
    songIsFavorite = {};

    await loadSongs();
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
          body: ValueListenableBuilder(
            valueListenable: homeBody,
            builder: (context, value, child) {
              return value == 1 ? buildLibrary() : buildSetting();
            },
          ),
        ),
      ],
    );
  }

  Widget buildLibrary() {
    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        ListTile(
          leading: const ImageIcon(
            AssetImage("assets/images/playlists.png"),
            size: 30,
            color: Color.fromARGB(255, 120, 240, 240),
          ),
          title: Text('Playlists'),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PlaylistsScaffold()));
          },
        ),
        ListTile(
          leading: const ImageIcon(
            AssetImage("assets/images/artist.png"),
            size: 30,
            color: Color.fromARGB(255, 120, 240, 240),
          ),
          title: Text('Artists'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtistAlbumScaffold(isArtist: true),
              ),
            );
          },
        ),
        ListTile(
          leading: const ImageIcon(
            AssetImage("assets/images/album.png"),
            size: 30,
            color: Color.fromARGB(255, 120, 240, 240),
          ),
          title: Text('Albums'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtistAlbumScaffold(isArtist: false),
              ),
            );
          },
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
                builder: (_) => SongsScaffold(reload: reloadSongs),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildSetting() {
    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        ListTile(
          leading: Icon(
            Icons.timer_outlined,
            color: Color.fromARGB(255, 120, 240, 240),
          ),
          title: Text('Timed Pause'),
          trailing: SizedBox(
            width: 150,
            child: Row(
              children: [
                Spacer(),
                ValueListenableBuilder(
                  valueListenable: remainTimes,
                  builder: (context, value, child) {
                    final hours = (value ~/ 3600).toString().padLeft(2, '0');
                    final minutes = ((value % 3600) ~/ 60).toString().padLeft(
                      2,
                      '0',
                    );
                    final secs = (value % 60).toString().padLeft(2, '0');
                    return ValueListenableBuilder(
                      valueListenable: timedPause,
                      builder: (context, on, child) {
                        return value > 0 || on
                            ? Text('$hours:$minutes:$secs')
                            : SizedBox();
                      },
                    );
                  },
                ),
                SizedBox(width: 10),
                ValueListenableBuilder(
                  valueListenable: timedPause,
                  builder: (context, value, child) {
                    return FlutterSwitch(
                      width: 45,
                      height: 20,
                      toggleSize: 15,
                      activeColor: Color.fromARGB(255, 120, 240, 240),
                      inactiveColor: Colors.grey.shade300,
                      value: value,
                      onToggle: (value) async {
                        if (hasVibration) {
                          Vibration.vibrate(duration: 5);
                        }
                        timedPause.value = value;
                        if (value) {
                          displayTimedPauseSetting(context);
                        } else {
                          pauseTimer?.cancel();
                          pauseTimer = null;
                          remainTimes.value = 0;
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: timedPause,
          builder: (_, value, _) {
            return value
                ? ListTile(
                    trailing: SizedBox(
                      width: 200,
                      child: Row(
                        children: [
                          Spacer(),
                          Text('Pause After Compelete'),
                          SizedBox(width: 10),
                          ValueListenableBuilder(
                            valueListenable: pauseAfterCompleted,
                            builder: (_, value, _) {
                              return FlutterSwitch(
                                width: 45,
                                height: 20,
                                toggleSize: 15,
                                activeColor: Color.fromARGB(255, 120, 240, 240),
                                inactiveColor: Colors.grey.shade300,
                                value: value,
                                onToggle: (value) {
                                  if (hasVibration) {
                                    Vibration.vibrate(duration: 5);
                                  }
                                  pauseAfterCompleted.value = value;
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : SizedBox();
          },
        ),
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
                      child: MyAutoSizeText(
                        "${currentSong.title ?? 'Unknown Title'} - ${currentSong.artist ?? 'Unknown Artist'}",
                        maxLines: 1,
                        fontsize: 16,
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
                            isScrollControlled: true,
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
