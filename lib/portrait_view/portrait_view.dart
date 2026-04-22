import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/sidebar.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/pages/portrait_lyrics_page.dart';
import 'package:particle_music/portrait_view/play_bar.dart';

final GlobalKey<ScaffoldState> portraitKey = GlobalKey();

class PortraitView extends StatefulWidget {
  const PortraitView({super.key});

  @override
  State<StatefulWidget> createState() => _PortraitViewState();
}

class _PortraitViewState extends State<PortraitView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _pushSlideAnimation;
  late Animation<Offset> _popSlideAnimation;

  final dragDxNotifier = ValueNotifier(0.0);
  final dragNotifier = ValueNotifier(false);

  double slideBeginDx = 0.0;
  void slideBegin() {
    _controller.forward(from: slideBeginDx);
    slideBeginDx = 0;
    dragNotifier.value = false;
  }

  void statusListener(AnimationStatus status) {
    if (status != .completed) {
      return;
    }

    if (layersManager.switchType == .pop) {
      layersManager.afterPopLayer();
    } else {
      dragNotifier.value = true;
      dragDxNotifier.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _controller.addStatusListener(statusListener);

    _pushSlideAnimation =
        Tween<Offset>(
          begin: Offset(Platform.isIOS ? 1.0 : -1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        );

    _popSlideAnimation =
        Tween<Offset>(
          begin: Offset.zero,
          end: Offset(Platform.isIOS ? 1.0 : -1.0, 0.0),
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        );

    layersManager.switchNotifier.addListener(slideBegin);
    _controller.forward(from: 1);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(statusListener);
    layersManager.switchNotifier.removeListener(slideBegin);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          key: portraitKey,
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          drawer: Platform.isAndroid ? myDrawer() : null,
          endDrawer: Platform.isIOS ? myDrawer() : null,
          body: Stack(
            children: [
              ValueListenableBuilder(
                valueListenable: layersManager.switchNotifier,
                builder: (context, _, _) {
                  final slideAnimation = layersManager.switchType == .push
                      ? _pushSlideAnimation
                      : layersManager.switchType == .pop
                      ? _popSlideAnimation
                      : null;

                  final bottomPage = layersManager.switchType == .pop
                      ? layersManager.currentPage
                      : layersManager.helperPage;

                  final topPage = layersManager.switchType == .pop
                      ? layersManager.helperPage
                      : layersManager.currentPage;

                  return Stack(
                    children: [
                      ...layersManager.pageMap.values
                          .where((page) => page != topPage)
                          .map(
                            (page) => Visibility(
                              visible: page == bottomPage,
                              maintainState: true,
                              child: page,
                            ),
                          ),

                      ValueListenableBuilder(
                        valueListenable: dragNotifier,
                        builder: (context, value, child) {
                          if (value) {
                            return ValueListenableBuilder(
                              valueListenable: dragDxNotifier,
                              builder: (context, value, child) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  transform: .translationValues(value, 0, 0),
                                  child: topPage,
                                );
                              },
                            );
                          }
                          if (slideAnimation == null) {
                            return topPage!;
                          } else {
                            return SlideTransition(
                              position: slideAnimation,
                              child: topPage,
                            );
                          }
                        },
                      ),

                      if (Platform.isIOS &&
                          layersManager.layerHistory.length > 1)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              if (dragNotifier.value == false) {
                                return;
                              }
                              dragDxNotifier.value += details.delta.dx;
                              if (dragDxNotifier.value < 0) {
                                dragDxNotifier.value = 0;
                              }
                            },
                            onHorizontalDragEnd: (details) {
                              if (dragNotifier.value == false) {
                                return;
                              }
                              if (dragDxNotifier.value /
                                      MediaQuery.widthOf(context) <
                                  0.5) {
                                dragDxNotifier.value = 0;
                              } else {
                                slideBeginDx =
                                    dragDxNotifier.value /
                                    MediaQuery.widthOf(context);
                                layersManager.popLayer();
                              }
                            },

                            child: Container(
                              color: Colors.transparent,
                              width: 20,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              Positioned(left: 20, right: 20, bottom: 40, child: PlayBar()),
            ],
          ),
        ),
        PortraitLyricsPage(),
      ],
    );
  }

  Widget myDrawer() {
    return ValueListenableBuilder(
      valueListenable: layersManager.backgroundChangeNotifier,
      builder: (context, value, child) {
        return Drawer(
          backgroundColor: backgroundCoverArtColor,
          width: 220,
          child: Column(
            children: [
              ValueListenableBuilder(
                valueListenable: sidebarColor.valueNotifier,
                builder: (context, value, child) {
                  return Container(
                    color: value,
                    height: MediaQuery.of(context).padding.top,
                  );
                },
              ),
              Expanded(
                child: Sidebar(
                  closeDrawer: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
