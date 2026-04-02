import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _PortraitViewState extends State<PortraitView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (layersManager.layerStack.length == 1) {
          SystemNavigator.pop();
        } else {
          layersManager.popLayer();
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
              ValueListenableBuilder(
                valueListenable: updateColorNotifier,
                builder: (context, value, child) {
                  return Navigator(
                    pages: layersManager.buildPages(),
                    onDidRemovePage: (_) {},
                  );
                },
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 5,
                left: 5,
                child: Builder(
                  builder: (context) => IconButton(
                    icon: Icon(
                      Platform.isAndroid
                          ? Icons.menu
                          : Icons.arrow_back_ios_new_rounded,
                    ),
                    onPressed: () => Platform.isAndroid
                        ? Scaffold.of(context).openDrawer()
                        : layersManager.popLayer(),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 40,
                child: ValueListenableBuilder(
                  valueListenable: updateColorNotifier,
                  builder: (context, value, child) {
                    return PlayBar();
                  },
                ),
              ),
            ],
          ),
        ),
        PortraitLyricsPage(),
      ],
    );
  }

  Widget myDrawer() {
    return ValueListenableBuilder(
      valueListenable: updateColorNotifier,
      builder: (context, value, child) {
        return Drawer(
          backgroundColor: backgroundFilterColor,
          width: 220,
          child: Column(
            children: [
              Container(
                color: sidebarColor,
                height: MediaQuery.of(context).padding.top,
              ),
              Expanded(
                child: Sidebar(
                  closeDrawer: () {
                    Scaffold.of(context).closeDrawer();
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
