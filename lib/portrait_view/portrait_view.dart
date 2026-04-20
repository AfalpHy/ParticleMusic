import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/sidebar.dart';
import 'package:particle_music/layer/layers_manager.dart';
import 'package:particle_music/portrait_view/pages/portrait_lyrics_page.dart';
import 'package:particle_music/portrait_view/play_bar.dart';
import 'package:particle_music/utils.dart';

class PortraitView extends StatefulWidget {
  const PortraitView({super.key});

  @override
  State<StatefulWidget> createState() => _PortraitViewState();
}

class _PortraitViewState extends State<PortraitView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool systemCanPop = false;
  Timer? _exitTimer;
  final rebuildNotifier = ValueNotifier(0);

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  void slideBegin() {
    _controller.forward(from: 0.0);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation =
        Tween<Offset>(
          begin: Offset(Platform.isIOS ? 1.0 : -1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
        );

    layersManager.switchNotifier.addListener(slideBegin);
    _controller.forward(from: 1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    layersManager.switchNotifier.removeListener(slideBegin);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // rebuild Navigator to allow it to handle pop
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (displayLyricsPageNotifier.value) {
          displayLyricsPageNotifier.value = false;
          return;
        }
        if (!systemCanPop) {
          systemCanPop = true;
          showCenterMessage(
            context,
            'Press back again to exit',
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

  Widget content() {
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
              ListenableBuilder(
                listenable: Listenable.merge([
                  rebuildNotifier,
                  layersManager.updateNotifier,
                ]),
                builder: (context, _) {
                  return Stack(
                    children: [
                      ...layersManager.pageMap.values
                          .where((page) => page != layersManager.currentPage)
                          .map(
                            (page) => Visibility(
                              visible: page == layersManager.prePage,
                              maintainState: true,
                              child: page,
                            ),
                          ),

                      SlideTransition(
                        position: _slideAnimation,
                        child: layersManager.currentPage!,
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
      valueListenable: layersManager.updateNotifier,
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
