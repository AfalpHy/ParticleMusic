import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/lyrics.dart';
import 'package:particle_music/utils.dart';
import 'package:window_manager/window_manager.dart';

extension WindowControllerExtension on WindowController {
  Future<void> desktopLyricsCustomInitialize() async {
    return await setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'window_center':
          return await windowManager.center();
        case 'window_close':
          return await windowManager.close();
        case 'update_lyric':
          getLyricFromMap(call.arguments);
          break;
        case 'set_playing':
          isPlayingNotifier.value = call.arguments as bool;
          break;
        case 'unlock':
          await windowManager.setIgnoreMouseEvents(false);
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
        case 'skip_to_previous':
          audioHandler.skipToPrevious();
          break;
        case 'toggle_play':
          audioHandler.togglePlay();
          break;
        case 'skip_to_next':
          audioHandler.skipToNext();
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

  Future<void> updateLyric(
    Duration postion,
    LyricLine? lyricline,
    bool isKaraoke,
  ) {
    return invokeMethod('update_lyric', {
      'position': postion.inMicroseconds,
      'lyric_line': lyricline?.toMap(),
      'isKaraoke': isKaraoke,
    });
  }

  Future<void> sendPlaying(bool playing) {
    return invokeMethod('set_playing', playing);
  }

  Future<void> hideDesktopLyrics() {
    return invokeMethod('hide_desktop_lyrics');
  }

  Future<void> skipToPrevious() {
    return invokeMethod('skip_to_previous');
  }

  Future<void> togglePlay() {
    return invokeMethod('toggle_play');
  }

  Future<void> skipToNext() {
    return invokeMethod('skip_to_next');
  }

  Future<void> unlock() {
    return invokeMethod('unlock');
  }
}
