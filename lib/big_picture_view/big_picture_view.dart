import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gamepads/flutter_gamepads.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/history.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/my_window_listener.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/widgets/big_play_bar.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/scale_widget.dart';
import 'package:sylvakru/big_picture_view/panels/big_albums_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_artists_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_folders_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_home_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_playlists_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_ranking_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_recently_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_settings_panel.dart';
import 'package:sylvakru/big_picture_view/panels/big_songs_panel.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:window_manager/window_manager.dart';

class BigPictureView extends StatefulWidget {
  const BigPictureView({super.key});

  @override
  State<StatefulWidget> createState() => _BigPictureViewState();
}

class _BigPictureViewState extends State<BigPictureView> {
  final _pageController = PageController();
  final _currentIndexNotifier = ValueNotifier(0);

  final pages = const [
    BigHomePanel(),
    BigSongsPanel(),
    BigArtistsPanel(),
    BigAlbumsPanel(),
    BigFoldersPanel(),
    BigRankingPanel(),
    BigRecentlyPanel(),
    BigPlaylistsPanel(),
    BigSettingsPanel(),
  ];

  final topNode = FocusScopeNode();
  final pageViewNode = FocusScopeNode();
  final bottomNode = FocusScopeNode();

  @override
  void dispose() {
    topNode.dispose();
    pageViewNode.dispose();
    bottomNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: mainPageThemeNotifier,
      builder: (context, value, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ListenableBuilder(
              listenable: Listenable.merge([currentSongNotifier]),
              builder: (context, _) {
                if (mainPageThemeNotifier.value != .vivid) {
                  return SizedBox.shrink();
                }
                return CoverArtWidget(
                  picture: currentSongNotifier.value?.picture,
                  color: currentCoverArtColor,
                );
              },
            ),
            ListenableBuilder(
              listenable: Listenable.merge([currentSongNotifier]),
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
              child: KeyboardListener(
                focusNode: pageViewNode,
                onKeyEvent: (value) {
                  if (value is KeyUpEvent) {
                    return;
                  }
                  if (value.logicalKey == .goBack ||
                      value.logicalKey == .keyT) {
                    topNode.requestFocus();
                  }
                },
                child: GamepadInterceptor(
                  onBeforeIntent: (activator, intent) {
                    if (intent is DismissIntent) {
                      topNode.requestFocus();
                      return false;
                    }
                    return true;
                  },
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

            topBar(context),
            bottomBar(context),
          ],
        );
      },
    );
  }

  Widget topBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
      l10n.home,
      l10n.songs,
      l10n.artists,
      l10n.albums,
      l10n.folders,
      l10n.ranking,
      l10n.recently,
      l10n.playlists,
      l10n.settings,
    ];

    final windowsControl = isTV
        ? null
        : Row(
            children: [
              if (!isFullScreenNotifier.value)
                IconButton(
                  onPressed: () async {
                    if (!await showConfirmDialog(context, l10n.switchMode)) {
                      return;
                    }
                    await Future.delayed(Duration(milliseconds: 250));
                    viewModeNotifier.value = .normal;
                    layersManager.updateBackground();
                  },
                  icon: ImageIcon(bigPictureModeImage),
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
                    isMaximizedNotifier.value ? unmaximizeImage : maximizeImage,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    windowManager.close();
                  },
                  icon: ImageIcon(closeImage),
                ),
              ],
            ],
          );

    return Positioned(
      top: getTopOffset(context),
      left: 0,
      right: 0,

      child: KeyboardListener(
        focusNode: topNode,
        onKeyEvent: (value) {
          if (value is KeyUpEvent) {
            return;
          }
          if (value.logicalKey == .arrowDown) {
            pageViewNode.requestFocus();
          } else if (value.logicalKey == .arrowUp) {
            bottomNode.requestFocus();
          }
        },
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
                Expanded(
                  flex: 1,
                  child: Material(
                    color: Colors.transparent,
                    child: Row(
                      children: [
                        SizedBox(width: 30),

                        // Expanded(
                        //   child: GlassContainer(
                        //     settings: LiquidGlassSettings(
                        //       glassColor: glassColor.value,
                        //     ),
                        //     shape: const LiquidRoundedSuperellipse(
                        //       borderRadius: 30,
                        //     ),
                        //     child: TextField(
                        //       decoration: InputDecoration(
                        //         prefixIcon: Icon(Icons.search),
                        //         suffixIcon: IconButton(
                        //           onPressed: () {},
                        //           icon: const Icon(Icons.clear),
                        //           padding: EdgeInsets.zero,
                        //         ),
                        //         filled: true,
                        //         fillColor: Colors.transparent,
                        //         contentPadding: EdgeInsets.zero,
                        //         isDense: true,
                        //         border: OutlineInputBorder(
                        //           borderSide: BorderSide.none,
                        //         ),
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        SizedBox(width: 30),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GlassContainer(
                        settings: LiquidGlassSettings(
                          glassColor: glassColor.value,
                        ),
                        shape: const LiquidRoundedSuperellipse(
                          borderRadius: 30,
                        ),
                        clipBehavior: .antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 7.5,
                              ),
                              child: Row(
                                mainAxisAlignment: .center,
                                children: List.generate(tabs.length, (index) {
                                  return ValueListenableBuilder(
                                    valueListenable: _currentIndexNotifier,
                                    builder: (context, value, child) {
                                      return ValueListenableBuilder(
                                        valueListenable:
                                            selectedItemColor.valueNotifier,
                                        builder: (context, colorValue, child) {
                                          return Material(
                                            shape: SmoothRectangleBorder(
                                              smoothness: 1,
                                              borderRadius: .circular(25),
                                            ),
                                            color: index == value
                                                ? colorValue
                                                : Colors.transparent,
                                            clipBehavior: .antiAlias,
                                            child: child,
                                          );
                                        },
                                        child: ScaleWidget(
                                          onTap: () {
                                            _pageController.animateToPage(
                                              index,
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                          needFocusColor: true,
                                          autoFocus: index == 0,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 15,
                                              vertical: isMobile ? 4 : 0,
                                            ),
                                            child: Text(
                                              tabs[index],
                                              style: TextStyle(
                                                fontSize: 18.5,
                                                fontWeight: FontWeight.bold,
                                                color: index == value
                                                    ? textColor.value
                                                    : textColor.value.withAlpha(
                                                        128,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Expanded(
                  flex: 1,
                  child: isTV
                      ? SizedBox.shrink()
                      : Row(
                          mainAxisAlignment: .end,

                          children: [
                            GlassContainer(
                              settings: LiquidGlassSettings(
                                glassColor: glassColor.value,
                              ),
                              shape: const LiquidRoundedSuperellipse(
                                borderRadius: 30,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      windowsControl!.children.length > 1
                                      ? 10.0
                                      : 0,
                                ),
                                child: windowsControl,
                              ),
                            ),
                            SizedBox(width: isMobile ? 10 : 20),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget bottomBar(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: KeyboardListener(
        focusNode: bottomNode,
        onKeyEvent: (value) {
          if (value is KeyUpEvent) {
            return;
          }

          if (value.logicalKey == .arrowDown) {
            topNode.requestFocus();
          } else if (value.logicalKey == .arrowUp) {
            pageViewNode.requestFocus();
          }
        },
        child: GamepadInterceptor(
          onBeforeIntent: (activator, intent) {
            if (intent is DirectionalFocusIntent) {
              if (intent.direction == .down) {
                topNode.requestFocus();
                return false;
              } else if (intent.direction == .up) {
                pageViewNode.requestFocus();
                return false;
              }
            } else if (intent is DismissIntent) {
              topNode.requestFocus();
              return false;
            }
            return true;
          },
          child: Row(
            mainAxisAlignment: .center,
            children: [
              Expanded(flex: 1, child: SizedBox.shrink()),
              Expanded(flex: 3, child: Center(child: BigPlayBar())),
              Expanded(
                flex: 1,
                child: ValueListenableBuilder(
                  valueListenable: _currentIndexNotifier,
                  builder: (context, value, child) {
                    if (value == 0 || value == 4 || value >= 7) {
                      return SizedBox.shrink();
                    }
                    return Row(
                      mainAxisAlignment: .end,
                      children: [
                        GlassContainer(
                          settings: LiquidGlassSettings(
                            glassColor: glassColor.value,
                          ),
                          shape: const LiquidRoundedSuperellipse(
                            borderRadius: 30,
                          ),
                          child: IconButton(
                            onPressed: () {
                              switch (value) {
                                case 1:
                                  showSongListOptions(
                                    context,
                                    library.songList,
                                  );
                                case 2:
                                  showArtistsAlbumsOptions(context, true);
                                case 3:
                                  showArtistsAlbumsOptions(context, false);
                                case 5:
                                  showSongListOptions(
                                    context,
                                    history.rankingSongList,
                                  );
                                case 6:
                                  showSongListOptions(
                                    context,
                                    history.recentlySongList,
                                  );
                                default:
                              }
                            },
                            icon: ImageIcon(optionImage),
                          ),
                        ),
                        SizedBox(width: isMobile ? 10 : 20),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
