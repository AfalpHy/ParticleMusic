import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/mobile/pages/albums_page.dart';
import 'package:particle_music/mobile/pages/artists_page.dart';
import 'package:particle_music/mobile/pages/folders_page.dart';
import 'package:particle_music/mobile/pages/ranking_page.dart';
import 'package:particle_music/mobile/pages/playlists_page.dart';
import 'package:particle_music/mobile/pages/recently_page.dart';
import 'package:particle_music/mobile/play_bar.dart';
import 'package:particle_music/common_widgets/settings_list.dart';
import 'package:particle_music/mobile/pages/songs_page.dart';
import 'package:particle_music/utils.dart';

final ValueNotifier<double> _swipeProgressNotifier = ValueNotifier<double>(0.0);
final ValueNotifier<int> _homeBody = ValueNotifier<int>(1);

class SwipeObserver extends NavigatorObserver {
  int deep = 0;

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PageRoute && deep == 1) {
      route.animation?.addListener(() {
        _swipeProgressNotifier.value = route.animation!.value;
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

class MobileMainPage extends StatefulWidget {
  const MobileMainPage({super.key});

  @override
  State<StatefulWidget> createState() => MobileMainPageState();
}

class MobileMainPageState extends State<MobileMainPage> {
  final GlobalKey<NavigatorState> homeNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    appWidth = MediaQuery.widthOf(context);
    return Stack(
      children: [
        // Navigator for normal pages (PlayBar stays above)
        NavigatorPopHandler(
          onPopWithResult: (_) {
            if (homeNavigatorKey.currentState!.canPop()) {
              homeNavigatorKey.currentState!.pop();
            }
          },
          child: Navigator(
            key: homeNavigatorKey,
            observers: [swipeObserver],
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (_) => ValueListenableBuilder(
                  valueListenable: updateColorNotifier,
                  builder: (context, value, child) {
                    return HomePage();
                  },
                ),
              );
            },
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _swipeProgressNotifier,
          builder: (context, progress, _) {
            final double bottom = 80 - (40 * progress);
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 8),
              curve: Curves.linear,
              left: 20,
              right: 20,
              bottom: bottom,
              child: ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (context, value, child) {
                  return PlayBar();
                },
              ),
            );
          },
        ),

        ValueListenableBuilder<double>(
          valueListenable: _swipeProgressNotifier,
          builder: (context, progress, _) {
            final double bottom = -80 * progress;

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 8),
              curve: Curves.linear,
              left: 0,
              right: 0,
              bottom: bottom,
              child: ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (context, value, child) {
                  return bottomNavigator();
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget bottomNavigator() {
    return ValueListenableBuilder<int>(
      valueListenable: _homeBody,
      builder: (context, which, _) {
        final l10n = AppLocalizations.of(context);
        final color = iconColor;
        // must use Material to avoid layout problem
        return Material(
          color: pageBackgroundColor,

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
                      _homeBody.value = 1;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          color: which == 1 ? color : color.withAlpha(128),
                        ),

                        Text(
                          l10n.library,
                          style: TextStyle(
                            color: which == 1 ? color : color.withAlpha(128),
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
                      _homeBody.value = 3;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: which == 3 ? color : color.withAlpha(128),
                        ),

                        Text(
                          l10n.settings,
                          style: TextStyle(
                            color: which == 3 ? color : color.withAlpha(128),
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<StatefulWidget> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: AppBar(
        backgroundColor: pageBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          "Particle Music",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highlightTextColor,
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: updateColorNotifier,
        builder: (context, value, child) {
          return ValueListenableBuilder(
            valueListenable: _homeBody,
            builder: (context, value, child) {
              return value == 1 ? buildLibrary(context) : SettingsList();
            },
          );
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
          leading: ImageIcon(playlistsImage, size: 35, color: iconColor),
          title: Text(l10n.playlists),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => PlaylistsPage()));
          },
        ),
        ListTile(
          leading: ImageIcon(artistImage, size: 35, color: iconColor),
          title: Text(l10n.artists),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ArtistsPage()));
          },
        ),
        ListTile(
          leading: ImageIcon(albumImage, size: 35, color: iconColor),
          title: Text(l10n.albums),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => AlbumsPage()));
          },
        ),

        ListTile(
          leading: ImageIcon(folderImage, size: 35, color: iconColor),
          title: Text(l10n.folders),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => FoldersPage()));
          },
        ),

        ListTile(
          leading: ImageIcon(songsImage, size: 35, color: iconColor),
          title: Text(l10n.songs),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => SongsPage()));
          },
        ),

        ListTile(
          leading: ImageIcon(rankingImage, size: 35, color: iconColor),
          title: Text(l10n.ranking),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => RankingPage()));
          },
        ),

        ListTile(
          leading: ImageIcon(recentlyImage, size: 35, color: iconColor),
          title: Text(l10n.recently),
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => RecentlyPage()));
          },
        ),
      ],
    );
  }
}
