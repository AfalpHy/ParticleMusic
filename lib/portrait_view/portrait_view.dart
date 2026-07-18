import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/portrait_view/play_bar.dart';

final GlobalKey<ScaffoldState> portraitKey = GlobalKey();
bool isDrawerOpen = false;

class PortraitView extends StatefulWidget {
  const PortraitView({super.key});

  @override
  State<StatefulWidget> createState() => _PortraitViewState();
}

class _PortraitViewState extends State<PortraitView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  void slideBegin() {
    _controller.forward(from: 0);
  }

  void statusListener(AnimationStatus status) {
    if (status != .completed) {
      return;
    }
    if (layersManager.bottomRootPage != null) {
      layersManager.bottomRootPage = null;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _controller.addStatusListener(statusListener);

    _slideAnimation =
        Tween<Offset>(
          begin: Offset(Platform.isIOS ? 1.0 : -1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.linearToEaseOut),
        );

    layersManager.switchNotifier.addListener(slideBegin);
    _controller.forward(from: 1);
  }

  @override
  void dispose() {
    layersManager.switchNotifier.removeListener(slideBegin);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: portraitKey,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      drawer: Platform.isAndroid ? myDrawer() : null,
      endDrawer: Platform.isIOS ? myDrawer() : null,
      onDrawerChanged: (isOpened) async {
        // ensure popscope gets correct drawer state
        if (!isOpened) {
          await Future.delayed(Duration(milliseconds: 250));
        }

        isDrawerOpen = isOpened;
      },
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: layersManager.switchNotifier,
            builder: (context, _, _) {
              return GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = (details.primaryVelocity ?? 0);

                  if (Platform.isAndroid && velocity > 500) {
                    portraitKey.currentState?.openDrawer();
                  } else if (Platform.isIOS && velocity < -500) {
                    portraitKey.currentState?.openEndDrawer();
                  }
                },
                child: Stack(
                  children: [
                    ...layersManager.rootPageMap.values
                        .where((page) => page != layersManager.topRootPage)
                        .map((page) {
                          return Visibility(
                            visible: page == layersManager.bottomRootPage,
                            maintainState: true,
                            child: page,
                          );
                        }),

                    SlideTransition(
                      position: _slideAnimation,
                      child: layersManager.topRootPage,
                    ),
                  ],
                ),
              );
            },
          ),

          Positioned(left: 20, right: 20, bottom: 40, child: PlayBar()),
        ],
      ),
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
                    Navigator.pop(context);
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
