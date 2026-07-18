import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/keyboard.dart';
import 'package:sylvakru/base/services/network_error_reporter.dart';
import 'package:sylvakru/base/utils/dynamic_lyrics_page_route.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/big_picture_view/big_picture_view.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/landscape_view.dart';
import 'package:sylvakru/landscape_view/sidebar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/lyrics_page_layer.dart';
import 'package:sylvakru/mini_view/mini_view.dart';
import 'package:sylvakru/portrait_view/portrait_view.dart';

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

    if (autoPlayOnStartupNotifier.value && currentSongNotifier.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context, rootNavigator: true).push(
          DynamicLyricsPageRoute(pageBuilder: (_, _, _) => LyricsPageLayer()),
        );
      });
    }

    if (Platform.isIOS || Platform.isMacOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (Platform.isIOS) {
          await NativeMenu.init();
        }
        await NativeMenu.initIcons();
      });
    }

    networkErrorNotifier.addListener(_onNetworkError);
  }

  // Server clients report failures here since they have no BuildContext of
  // their own; this is the single place that turns that into something the
  // user actually sees, instead of the failure only ever reaching the log.
  void _onNetworkError() {
    final message = lastNetworkErrorMessage;
    if (message != null && mounted) {
      showCenterMessage(context, message, duration: 3000);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    networkErrorNotifier.removeListener(_onNetworkError);
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
    if (!Platform.isAndroid) {
      return view();
    }
    return PopScope(
      canPop: false,
      key: UniqueKey(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop | isTyping) {
          return;
        }
        if (portraitKey.currentState?.isDrawerOpen ?? false) {
          portraitKey.currentState?.closeDrawer();
          return;
        }
        if (await layersManager.popDetail(sidebarHighlighLabel.value)) {
          return;
        }

        if (systemCanPop) {
          systemCanPop = false;
          _exitTimer?.cancel();
          SystemNavigator.pop();
        } else {
          systemCanPop = true;
          if (context.mounted) {
            showCenterMessage(context, AppLocalizations.of(context).tapAgain);
          }
          _exitTimer = Timer(const Duration(seconds: 2), () {
            systemCanPop = false;
          });
        }
      },
      child: view(),
    );
  }

  Widget view() {
    return ValueListenableBuilder(
      valueListenable: viewModeNotifier,
      builder: (context, viewMode, child) {
        if (viewMode == .mini) {
          return MiniView();
        }
        if (viewMode == .bigPicture) {
          return BigPictureView();
        }
        if (isTooNarrow(context)) {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: [SystemUiOverlay.top],
          );
          return PortraitView();
        }
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
        return LandscapeView();
      },
    );
  }
}
