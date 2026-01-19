import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/desktop/desktop_lyrics.dart';
import 'package:particle_music/lyrics.dart';
import 'package:window_manager/window_manager.dart';

extension WindowControllerExtension on WindowController {
  Future<void> desktopLyricsCustomInitialize() async {
    return await setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'window_center':
          return await windowManager.center();
        case 'window_close':
          return await windowManager.close();
        case 'update_position':
          currentPositionNotifier.value = Duration(
            microseconds: call.arguments as int,
          );
          break;
        case 'set_isKaraoke':
          desktopLyricsIsKaraoke = call.arguments as bool;
          break;
        case 'set_lyricLine':
          if (call.arguments == null) {
            lyricLineNotifier.value = null;
            return;
          }
          final raw = call.arguments as Map;
          lyricLineNotifier.value = LyricLine.fromMap(raw);
          break;
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  Future<void> mainCustomInitialize() async {
    return await setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'hide_desktop_lyrics':
          lyricsWindowVisible = false;
          break;
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  Future<void> center() {
    return invokeMethod('window_center');
  }

  Future<void> close() {
    return invokeMethod('window_close');
  }

  Future<void> sendPosition(Duration position) {
    return invokeMethod('update_position', position.inMicroseconds);
  }

  Future<void> sendIsKaraoke(bool isKaraoke) {
    return invokeMethod('set_isKaraoke', isKaraoke);
  }

  Future<void> sendLyricLine(LyricLine? lyricline) {
    return invokeMethod('set_lyricLine', lyricline?.toMap());
  }

  Future<void> hideDesktopLyrics() {
    return invokeMethod('hide_desktop_lyrics');
  }
}
