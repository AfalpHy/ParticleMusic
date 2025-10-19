import 'dart:io';
import 'package:flutter/material.dart';
import 'package:particle_music/desktop/main_page.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/artist_album_page.dart';
import 'package:particle_music/mobile/pages/lyrics_page.dart';
import 'package:particle_music/mobile/pages/playlists_page.dart';
import 'package:particle_music/setting.dart';
import 'package:particle_music/mobile/pages/songs_page.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'audio_handler.dart';
import 'play_queue_sheet.dart';
import 'art_widget.dart';
import 'common.dart';
import 'package:flutter_switch/flutter_switch.dart';

final GlobalKey<NavigatorState> homeNavigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<double> swipeProgressNotifier = ValueNotifier<double>(0.0);
final ValueNotifier<int> homeBody = ValueNotifier<int>(1);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    audioHandler = await AudioService.init(
      builder: () => MobileAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.afalphy.particle_music',
        androidNotificationChannelName: 'Music Playback',
        androidNotificationOngoing: true,
      ),
    );
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, // only allow portrait
    ]);
  } else {
    audioHandler = DesktopAudioHandler();
  }
  await libraryLoader.initial();
  await libraryLoader.load();
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
    appWidth = MediaQuery.widthOf(context);
    return MaterialApp(
      title: 'Particle Music',
      home: (Platform.isAndroid || Platform.isIOS)
          ? Stack(
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
                      return MaterialPageRoute(
                        builder: (_) => const HomePage(),
                      );
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
            )
          : DesktopMainPage(),
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
                    HapticFeedback.heavyImpact();
                    homeBody.value = 1;
                  },

                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.library_music_outlined,
                        color: which == 1 ? mainColor : Colors.black54,
                      ),

                      Text(
                        "Library",
                        style: TextStyle(
                          color: which == 1 ? mainColor : Colors.black54,
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
                    HapticFeedback.heavyImpact();
                    homeBody.value = 3;
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(
                        Icons.settings_outlined,
                        color: which == 3 ? mainColor : Colors.black54,
                      ),

                      Text(
                        "Settings",
                        style: TextStyle(
                          color: which == 3 ? mainColor : Colors.black54,
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
class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
              return value == 1 ? buildLibrary(context) : buildSetting(context);
            },
          ),
        ),
      ],
    );
  }

  Widget buildLibrary(BuildContext context) {
    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        ListTile(
          leading: const ImageIcon(
            AssetImage("assets/images/playlists.png"),
            size: 30,
            color: mainColor,
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
            color: mainColor,
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
            color: mainColor,
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
            AssetImage("assets/images/songs.png"),
            size: 30,
            color: mainColor,
          ),
          title: Text('Songs'),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => SongsScaffold()));
          },
        ),
      ],
    );
  }

  Widget buildSetting(BuildContext context) {
    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        ListTile(
          leading: Icon(Icons.timer_outlined, color: mainColor),
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
                      activeColor: mainColor,
                      inactiveColor: Colors.grey.shade300,
                      value: value,
                      onToggle: (value) async {
                        HapticFeedback.heavyImpact();
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
                                activeColor: mainColor,
                                inactiveColor: Colors.grey.shade300,
                                value: value,
                                onToggle: (value) {
                                  HapticFeedback.heavyImpact();
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
        ListTile(
          leading: Icon(Icons.info_outline_rounded, color: mainColor),
          title: const Text('Open Source Licenses'),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => Theme(
                  data: ThemeData(
                    colorScheme: ColorScheme.light(
                      surface: Colors.white, // <- this is what LicensePage uses
                    ),
                    appBarTheme: const AppBarTheme(
                      scrolledUnderElevation: 0,
                      centerTitle: true,
                    ),
                  ),
                  child: const LicensePage(
                    applicationName: 'Particle Music',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2025 AfalpHy',
                  ),
                ),
              ),
            );
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
          child: SmoothClipRRect(
            smoothness: 1,
            borderRadius: BorderRadius.circular(25), // rounded half-circle ends

            child: Material(
              color: Color.fromARGB(210, 240, 255, 255),
              child: InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) {
                      return DraggableScrollableSheet(
                        initialChildSize: 1.0,
                        builder: (_, _) => LyricsPage(),
                      );
                    },
                  );
                },

                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    ArtWidget(
                      size: 35,
                      borderRadius: 3,
                      source: getCoverArt(currentSong),
                    ),

                    const SizedBox(width: 10),
                    Expanded(
                      child: MyAutoSizeText(
                        "${getTitle(currentSong)} - ${getArtist(currentSong)}",
                        maxLines: 1,
                        textStyle: TextStyle(fontSize: 16),
                      ),
                    ),

                    // Play/Pause Button
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: isPlayingNotifier,
                          builder: (_, isPlaying, _) {
                            return isPlaying
                                ? const ImageIcon(
                                    AssetImage(
                                      "assets/images/pause_circle.png",
                                    ),
                                    color: Colors.black,
                                    size: 25,
                                  )
                                : const ImageIcon(
                                    AssetImage(
                                      "assets/images/play_circle_fill.png",
                                    ),
                                    color: Colors.black,
                                    size: 25,
                                  );
                          },
                        ),

                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          audioHandler.togglePlay();
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
                          HapticFeedback.heavyImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) {
                              return PlayQueueSheet();
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
