import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/load_library.dart';
import 'package:particle_music/mobile/pages/albums_page.dart';
import 'package:particle_music/mobile/pages/artists_page.dart';
import 'package:particle_music/mobile/pages/folders_page.dart';
import 'package:particle_music/mobile/pages/playlists_page.dart';
import 'package:particle_music/mobile/player_bar.dart';
import 'package:particle_music/setting.dart';
import 'package:particle_music/mobile/pages/songs_page.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:smooth_corner/smooth_corner.dart';

final ValueNotifier<double> swipeProgressNotifier = ValueNotifier<double>(0.0);
final ValueNotifier<int> homeBody = ValueNotifier<int>(1);

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

  void resetDeep() {
    deep = 0;
  }
}

final swipeObserver = SwipeObserver();

class MobileMainPage extends StatelessWidget {
  final GlobalKey<NavigatorState> homeNavigatorKey =
      GlobalKey<NavigatorState>();

  MobileMainPage({super.key});

  @override
  Widget build(BuildContext context) {
    appWidth = MediaQuery.widthOf(context);
    return Stack(
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
    );
  }

  Widget bottomNavigator() {
    return ValueListenableBuilder<int>(
      valueListenable: homeBody,
      builder: (context, which, _) {
        // must use Material to avoid layout problem
        return Material(
          color: Colors.grey.shade50,

          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 80,
                  child: InkWell(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () {
                      tryVibrate();
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
                      tryVibrate();
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
}

// --------------------
// Home Page
// --------------------
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
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
    );
  }

  Widget buildLibrary(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        ListTile(
          leading: const ImageIcon(playlistsImage, size: 35, color: mainColor),
          title: Text(l10n.playlists),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PlaylistsPage()));
          },
        ),
        ListTile(
          leading: const ImageIcon(artistImage, size: 35, color: mainColor),
          title: Text(l10n.artists),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ArtistsPage()));
          },
        ),
        ListTile(
          leading: const ImageIcon(albumImage, size: 35, color: mainColor),
          title: Text(l10n.albums),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => AlbumsPage()));
          },
        ),

        ListTile(
          leading: const ImageIcon(folderImage, size: 35, color: mainColor),
          title: Text(l10n.folders),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => FoldersPage()));
          },
        ),

        ListTile(
          leading: const ImageIcon(songsImage, size: 35, color: mainColor),
          title: Text(l10n.songs),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => SongsPage()));
          },
        ),
      ],
    );
  }

  Widget buildSetting(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        ListTile(
          leading: ImageIcon(timerImage, color: mainColor, size: 30),

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
                        tryVibrate();
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
                          Text('Pause After Complete'),
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
                                  tryVibrate();
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
          leading: ImageIcon(infoImage, color: mainColor, size: 30),
          title: const Text('Open Source Licenses'),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => Theme(
                  data: ThemeData(
                    colorScheme: ColorScheme.light(
                      surface: Colors
                          .grey
                          .shade50, // <- this is what LicensePage uses
                    ),
                    appBarTheme: const AppBarTheme(
                      scrolledUnderElevation: 0,
                      centerTitle: true,
                    ),
                  ),
                  child: const LicensePage(
                    applicationName: 'Particle Music',
                    applicationVersion: '1.0.4',
                    applicationLegalese: '© 2025 AfalpHy',
                  ),
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: ImageIcon(reloadImage, color: mainColor, size: 30),
          title: const Text('Reload'),
          onTap: () async {
            if (await showConfirmDialog(context, 'Reload Action')) {
              await libraryLoader.reload();
            }
          },
        ),
        ListTile(
          leading: ImageIcon(folderImage, color: mainColor, size: 30),
          title: const Text('Select Music Folders'),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SizedBox(
                    height: 450,
                    width: 300,
                    child: Column(
                      children: [
                        SizedBox(height: 10),
                        Text(
                          'Folders',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        Expanded(
                          child: ValueListenableBuilder(
                            valueListenable: foldersChangeNotifier,
                            builder: (_, _, _) {
                              return ListView.builder(
                                itemCount: folderPaths.length,
                                itemBuilder: (_, index) {
                                  return ListTile(
                                    title: Text(folderPaths[index]),

                                    trailing: IconButton(
                                      onPressed: () {
                                        libraryLoader.removeFolder(
                                          folderPaths[index],
                                        );
                                      },
                                      icon: Icon(Icons.clear_rounded),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Spacer(),
                            ElevatedButton(
                              onPressed: () async {
                                String? result = await FilePicker.platform
                                    .getDirectoryPath();
                                if (result == null) {
                                  return;
                                }

                                if (Platform.isIOS) {
                                  if (result.contains(appDocs.path)) {
                                    result = result.substring(
                                      result.indexOf('Documents'),
                                    );
                                    result = result.replaceFirst(
                                      'Documents',
                                      'Particle Music',
                                    );
                                  } else if (context.mounted) {
                                    showCenterMessage(
                                      context,
                                      'No access permission',
                                      duration: 2000,
                                    );
                                    return;
                                  }
                                }
                                if (folderPaths.contains(result) &&
                                    context.mounted) {
                                  showCenterMessage(
                                    context,
                                    'The folder already exists',
                                    duration: 2000,
                                  );
                                  return;
                                }
                                libraryLoader.addFolder(result);
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                padding: EdgeInsets.all(10),
                              ),
                              child: Text('Add Folder'),
                            ),
                            SizedBox(width: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                padding: EdgeInsets.all(10),
                              ),
                              child: Text('Complete'),
                            ),
                            Spacer(),
                          ],
                        ),
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        ListTile(
          leading: ImageIcon(infoImage, color: mainColor),
          title: Text(l10n.language),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  backgroundColor: Color.fromARGB(255, 235, 240, 245),
                  shape: SmoothRectangleBorder(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SizedBox(
                    height: 300,
                    width: 100,
                    child: ValueListenableBuilder(
                      valueListenable: localeNotifier,
                      builder: (context, value, child) {
                        final l10n = AppLocalizations.of(context);

                        return ListView(
                          children: [
                            ListTile(
                              title: Text(l10n.followSystem),
                              onTap: () {
                                localeNotifier.value = null;
                              },
                              trailing: value == null
                                  ? Icon(Icons.check)
                                  : null,
                            ),
                            ListTile(
                              title: Text('English'),
                              onTap: () {
                                localeNotifier.value = Locale('en');
                              },
                              trailing: value == Locale('en')
                                  ? Icon(Icons.check)
                                  : null,
                            ),
                            ListTile(
                              title: Text('中文'),
                              onTap: () {
                                localeNotifier.value = Locale('zh');
                              },
                              trailing: value == Locale('zh')
                                  ? Icon(Icons.check)
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
        ListTile(
          leading: ImageIcon(vibrationImage, color: mainColor, size: 30),
          title: const Text('Vibration'),
          trailing: ValueListenableBuilder(
            valueListenable: vibrationOnNoitifier,
            builder: (context, value, child) {
              return SizedBox(
                width: 50,
                child: FlutterSwitch(
                  width: 45,
                  height: 20,
                  toggleSize: 15,
                  activeColor: mainColor,
                  inactiveColor: Colors.grey.shade300,
                  value: value,
                  onToggle: (value) {
                    tryVibrate();
                    vibrationOnNoitifier.value = value;
                    setting.saveSetting();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
