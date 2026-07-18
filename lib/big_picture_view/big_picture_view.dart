import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_gamepads/flutter_gamepads.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/my_window_listener.dart';
import 'package:sylvakru/base/utils/dynamic_lyrics_page_route.dart';
import 'package:sylvakru/base/utils/metadata_utils.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/big_picture_view/panels/big_albums_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_home_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_songs_panel.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:window_manager/window_manager.dart';

class BigPictureView extends StatefulWidget {
  const BigPictureView({super.key});

  @override
  State<StatefulWidget> createState() => _BigPictureViewState();
}

class _BigPictureViewState extends State<BigPictureView> {
  final _pageController = PageController();
  final _currentIndexNotifier = ValueNotifier(0);

  final pages = const [BigHomePanel(), BigSongsPanel(), BigAlbumsPanel()];

  final tabNode = FocusScopeNode();
  final pageViewNode = FocusScopeNode();
  final bottomNode = FocusScopeNode();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [l10n.home, l10n.songs, l10n.albums];

    return Stack(
      fit: StackFit.expand,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([
            currentSongNotifier,
            mainPageThemeNotifier,
          ]),
          builder: (context, _) {
            if (mainPageThemeNotifier.value != .vivid) {
              return SizedBox.shrink();
            }
            return CoverArtWidget(
              song: currentSongNotifier.value,
              color: currentCoverArtColor,
            );
          },
        ),
        ListenableBuilder(
          listenable: Listenable.merge([
            currentSongNotifier,
            mainPageThemeNotifier,
          ]),
          builder: (context, child) {
            if (mainPageThemeNotifier.value != .vivid) {
              return SizedBox.shrink();
            }
            final pageWidth = MediaQuery.widthOf(context);
            final pageHight = MediaQuery.heightOf(context);

            return RepaintBoundary(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: pageWidth * 0.03,
                  sigmaY: pageHight * 0.03,
                ),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  color: currentCoverArtColor.withAlpha(180),
                ),
              ),
            );
          },
        ),

        Material(
          color: panelColor.value,
          child: Column(
            children: [
              // Selection bar
              FocusScope(
                node: tabNode,
                autofocus: true,
                child: GamepadInterceptor(
                  onBeforeIntent: (activator, intent) {
                    if (intent is DirectionalFocusIntent) {
                      if (intent.direction == .down) {
                        pageViewNode.requestFocus();
                      } else if (intent.direction == .up) {
                        bottomNode.requestFocus();
                      }
                    }
                    return true;
                  },
                  child: SizedBox(
                    height: 75,
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: SizedBox()),

                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: .center,
                            children: List.generate(tabs.length, (index) {
                              bool focus = false;

                              return ValueListenableBuilder(
                                valueListenable: _currentIndexNotifier,
                                builder: (context, value, child) {
                                  final selected = index == value;
                                  return StatefulBuilder(
                                    builder: (context, thisSetState) {
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          color: selected
                                              ? focus
                                                    ? selectedItemColor.value
                                                          .withAlpha(75)
                                                    : selectedItemColor.value
                                                          .withAlpha(50)
                                              : Colors.transparent,
                                        ),
                                        child: TextButton(
                                          onPressed: () {
                                            _pageController.animateToPage(
                                              index,
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                          onFocusChange: (value) {
                                            thisSetState(() {
                                              focus = value;
                                            });
                                          },
                                          child: Text(
                                            tabs[index],
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: selected
                                                  ? textColor.value
                                                  : textColor.value.withAlpha(
                                                      128,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: .end,
                            children: [
                              if (!isFullScreenNotifier.value)
                                IconButton(
                                  color: iconColor.value,
                                  onPressed: () async {
                                    if (!await showConfirmDialog(
                                      context,
                                      'Exit big picture mode',
                                    )) {
                                      return;
                                    }
                                    await Future.delayed(
                                      Duration(milliseconds: 250),
                                    );
                                    viewModeNotifier.value = .normal;
                                  },
                                  icon: ImageIcon(bigPictueModeImage),
                                ),
                              if (!isMobile && !isMaximizedNotifier.value)
                                IconButton(
                                  onPressed: () async {
                                    if (isFullScreenNotifier.value) {
                                      isFullScreenNotifier.value = false;
                                      await windowManager.setFullScreen(false);
                                    } else {
                                      isFullScreenNotifier.value = true;
                                      await windowManager.setFullScreen(true);
                                    }
                                  },
                                  icon: ImageIcon(
                                    isFullScreenNotifier.value
                                        ? fullscreenExitImage
                                        : fullscreenImage,
                                  ),
                                ),
                              if (!isMobile && !isFullScreenNotifier.value) ...[
                                IconButton(
                                  onPressed: () {
                                    windowManager.minimize();
                                  },
                                  icon: ImageIcon(minimizeImage),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    isMaximizedNotifier.value
                                        ? windowManager.unmaximize()
                                        : windowManager.maximize();
                                  },
                                  icon: ImageIcon(
                                    isMaximizedNotifier.value
                                        ? unmaximizeImage
                                        : maximizeImage,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    windowManager.close();
                                  },
                                  icon: ImageIcon(closeImage),
                                ),
                              ],

                              SizedBox(width: isMobile ? 10 : 30),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Pages
              Expanded(
                child: GamepadInterceptor(
                  onBeforeIntent: (activator, intent) {
                    if (intent is DismissIntent) {
                      tabNode.requestFocus();
                    }
                    return true;
                  },
                  child: FocusScope(
                    node: pageViewNode,
                    child: PageView(
                      controller: _pageController,

                      onPageChanged: (value) {
                        _currentIndexNotifier.value = value;
                      },
                      children: pages,
                    ),
                  ),
                ),
              ),

              FocusScope(
                node: bottomNode,
                child: GamepadInterceptor(
                  onBeforeIntent: (activator, intent) {
                    if (intent is DirectionalFocusIntent) {
                      if (intent.direction == .up) {
                        pageViewNode.requestFocus();
                      } else if (intent.direction == .down) {
                        tabNode.requestFocus();
                      }
                    }
                    return true;
                  },
                  child: SizedBox(
                    height: 75,
                    child: Row(
                      children: [
                        Spacer(),

                        Expanded(
                          child: ValueListenableBuilder(
                            valueListenable: currentSongNotifier,
                            builder: (_, currentSong, _) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  highlightColor: Colors.transparent,
                                  splashColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  shape: SmoothRectangleBorder(
                                    smoothness: 1,
                                    borderRadius: .all(.circular(10)),
                                  ),
                                  clipBehavior: .antiAlias,
                                  child: ListenableBuilder(
                                    listenable: Listenable.merge([
                                      currentSong?.updateNotifier,
                                    ]),
                                    builder: (context, _) {
                                      return ListTile(
                                        autofocus: true,
                                        leading: Hero(
                                          tag: 'cover',
                                          flightShuttleBuilder:
                                              (
                                                flightContext,
                                                animation,
                                                flightDirection,
                                                fromHeroContext,
                                                toHeroContext,
                                              ) => FittedBox(
                                                child: flightDirection == .push
                                                    ? toHeroContext.widget
                                                    : fromHeroContext.widget,
                                              ),
                                          child: CoverArtWidget(
                                            size: 50,
                                            borderRadius: 5,
                                            song: currentSong,
                                          ),
                                        ),
                                        title: Text(
                                          getTitle(currentSong),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: currentSong != null
                                            ? Text(
                                                "${getArtist(currentSong)} - ${getAlbum(currentSong)}",
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontSize: 13),
                                              )
                                            : null,
                                        onTap: () {
                                          if (playQueue.isEmpty) {
                                            return;
                                          }
                                          Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).push(
                                            DynamicLyricsPageRoute(
                                              pageBuilder: (_, _, _) =>
                                                  GamepadInterceptor(
                                                    onBeforeIntent:
                                                        (activator, intent) {
                                                          if (intent
                                                              is DismissIntent) {
                                                            Navigator.of(
                                                              context,
                                                            ).maybePop();
                                                          }
                                                          return true;
                                                        },
                                                    child: LyricsPageLayer(),
                                                  ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
