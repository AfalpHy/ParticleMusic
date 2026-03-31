import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/portrait_view/pages/home_page.dart';
import 'package:particle_music/portrait_view/play_bar.dart';
import 'package:particle_music/utils.dart';

final ValueNotifier<double> _swipeProgressNotifier = ValueNotifier<double>(0.0);

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
}

class PortraitView extends StatefulWidget {
  const PortraitView({super.key});

  @override
  State<StatefulWidget> createState() => _PortraitViewState();
}

class _PortraitViewState extends State<PortraitView> {
  final swipeObserver = SwipeObserver();

  final GlobalKey<NavigatorState> homeNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
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
    return ValueListenableBuilder(
      valueListenable: displayLibraryNotifier,
      builder: (context, value, _) {
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
                  child: GestureDetector(
                    onTap: () {
                      tryVibrate();
                      displayLibraryNotifier.value = true;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          color: value ? color : color.withAlpha(128),
                        ),

                        Text(
                          l10n.library,
                          style: TextStyle(
                            color: value ? color : color.withAlpha(128),
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
                  child: GestureDetector(
                    onTap: () {
                      tryVibrate();
                      displayLibraryNotifier.value = false;
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.settings_outlined,
                          color: !value ? color : color.withAlpha(128),
                        ),

                        Text(
                          l10n.settings,
                          style: TextStyle(
                            color: !value ? color : color.withAlpha(128),
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
