import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/audio_handler.dart';
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
          desktopLyrcisCurrentPosition = Duration(
            microseconds: call.arguments as int,
          );
          updateDesktopLyricsNotifier.value++;
          break;
        case 'set_isKaraoke':
          desktopLyricsIsKaraoke = call.arguments as bool;
          break;
        case 'set_lyricLine':
          if (call.arguments == null) {
            desktopLyricLine = null;
            return;
          }
          final raw = call.arguments as Map;
          desktopLyricLine = LyricLine.fromMap(raw);
          break;
        case 'set_playing':
          isPlayingNotifier.value = call.arguments as bool;
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

  Future<void> sendPlaying(bool playing) {
    return invokeMethod('set_playing', playing);
  }

  Future<void> hideDesktopLyrics() {
    return invokeMethod('hide_desktop_lyrics');
  }
}
