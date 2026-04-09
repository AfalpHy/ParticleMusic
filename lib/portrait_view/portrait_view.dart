import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    with WidgetsBindingObserver {
  bool systemCanPop = false;
  Timer? _exitTimer;
  final rebuildNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // rebuild Navigator to allow it to handle pop
      if (layersManager.layerStack.length == 1) {
        rebuildNotifier.value++;
      }
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
        if (layersManager.layerStack.length == 1) {
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
        } else {
          systemCanPop = false;
          layersManager.popLayer();
        }
      },
      child: content(),
    );
  }

  Widget content() {
    return Scaffold(
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
              updateColorNotifier,
              layersManager.updateNotifier,
            ]),
            builder: (context, _) {
              return Navigator(
                pages: layersManager.buildPages(),
                onDidRemovePage: (_) {
                  layersManager.popLayer();
                },
              );
            },
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
          PortraitLyricsPage(),
        ],
      ),
    );
  }

  Widget myDrawer() {
    return ValueListenableBuilder(
      valueListenable: updateColorNotifier,
      builder: (_, value, child) {
        return Drawer(
          backgroundColor: backgroundBaseColor,
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
