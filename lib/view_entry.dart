import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/landscape_view/landscape_view.dart';
import 'package:particle_music/landscape_view/pages/play_queue_page.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/mini_view/mini_view.dart';
import 'package:particle_music/portrait_view/portrait_view.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

class ViewEntry extends StatefulWidget {
  const ViewEntry({super.key});

  @override
  State<StatefulWidget> createState() => _ViewEntryState();
}

class _ViewEntryState extends State<ViewEntry> with WidgetsBindingObserver {
  bool systemCanPop = false;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isAndroid && state == AppLifecycleState.resumed) {
      systemCanPop = false;
      _exitTimer?.cancel();
      // rebuild PopScope to allow it to handle pop
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return PopScope(
        key: UniqueKey(),
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          if (displayLyricsPageNotifier.value) {
            displayLyricsPageNotifier.value = false;
            return;
          }

          if (portraitKey.currentState?.isDrawerOpen ?? false) {
            Navigator.of(portraitKey.currentContext!).pop();
            return;
          }

          if (layersManager.layerHistory.length > 1) {
            layersManager.popLayer();
            return;
          }
          if (!systemCanPop) {
            systemCanPop = true;
            showCenterMessage(
              context,
              AppLocalizations.of(context).tapAgain,
              duration: 1500,
            );
            _exitTimer?.cancel();
            _exitTimer = Timer(const Duration(seconds: 2), () {
              systemCanPop = false;
            });
          } else {
            SystemNavigator.pop();
          }
        },
        child: content(),
      );
    }
    return content();
  }

  Widget content() {
    return ValueListenableBuilder(
      valueListenable: miniModeNotifier,
      builder: (context, miniMode, child) {
        if (miniMode) {
          return MiniView();
        }
        return Stack(
          children: [
            mainView(context),

            if (!isMobile)
              ValueListenableBuilder(
                valueListenable: displayPlayQueuePageNotifier,
                builder: (context, display, _) {
                  if (display) {
                    return GestureDetector(
                      onTap: () {
                        displayPlayQueuePageNotifier.value = false;
                      },
                      child: Container(color: Colors.black.withAlpha(25)),
                    );
                  } else {
                    return SizedBox.shrink();
                  }
                },
              ),

            if (!isMobile)
              Positioned(
                top: 75,
                bottom: 100,
                right: 0,
                child: ValueListenableBuilder(
                  valueListenable: displayPlayQueuePageNotifier,
                  builder: (context, display, _) {
                    return ValueListenableBuilder(
                      valueListenable: currentSongNotifier,
                      builder: (context, value, child) {
                        return AnimatedSlide(
                          offset: display ? Offset.zero : Offset(1, 0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.linear,
                          child: Material(
                            elevation: 1,
                            color: colorManager.getSpecificBgBaseColor(),
                            shape: SmoothRectangleBorder(
                              smoothness: 1,
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(10),
                              ),
                            ),
                            clipBehavior: .antiAliasWithSaveLayer,
                            child: Container(
                              color: colorManager.getSpecificBgColor(),
                              width: max(
                                350,
                                MediaQuery.widthOf(context) * 0.2,
                              ),
                              child: PlayQueuePage(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget mainView(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          return PortraitView();
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
          return LandscapeView();
        }
      },
    );
  }
}
