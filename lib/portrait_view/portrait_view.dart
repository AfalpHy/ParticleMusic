import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/sidebar.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/pages/portrait_lyrics_page.dart';
import 'package:particle_music/portrait_view/play_bar.dart';

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

  void slideBegin() {
    _controller.forward(from: 0.0);
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

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
    layersManager.switchNotifier.removeListener(slideBegin);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
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
                  final slideAnimation = layersManager.isPush
                      ? _pushSlideAnimation
                      : _popSlideAnimation;

                  final bottomPage = layersManager.isPush
                      ? layersManager.helperPage
                      : layersManager.currentPage;

                  final topPage = layersManager.isPush
                      ? layersManager.currentPage
                      : layersManager.helperPage;

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

                      SlideTransition(position: slideAnimation, child: topPage),
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
